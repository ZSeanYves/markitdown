///|
/// Name tree helpers.
fn compare_string(a : String, b : String) -> Int {
  // IMPORTANT:
  // - `StringView::compare` uses *shortlex* order (length-first), which is not a
  //   traditional lexicographical string ordering.
  // - Name trees assume their keys are sorted by a lexicographical order (PDF
  //   keys are compared byte-wise; in this library we use UTF-16 code units).
  //
  // Use `lexical_compare` to match the previous "scan until first difference,
  // then compare lengths" semantics.
  a[:].lexical_compare(b[:])
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let mut total = 0
  for list in lists {
    total = total + list.length()
  }
  let out = Array::new(capacity=total)
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn key_compare(a : PdfObject, b : PdfObject) -> Int? {
  match (a, b) {
    (String(sa), String(sb)) => Some(compare_string(sa, sb))
    (Integer(ia), Integer(ib)) => Some(ia - ib)
    _ => None
  }
}

///|
fn key_eq(a : PdfObject, b : PdfObject) -> Bool {
  match key_compare(a, b) {
    Some(0) => true
    _ => false
  }
}

///|
fn array_lookup(key : PdfObject, array : PdfObject) -> PdfObject? raise {
  match array {
    Array(elts) => {
      for i = 0; i + 1 < elts.length(); i = i + 2 {
        if key_eq(key, elts[i]) {
          return Some(elts[i + 1])
        }
      }
      None
    }
    _ => raise PdfError::Msg("Bad lookup array")
  }
}

///|
fn Pdf::nametree_lookup_kids(
  self : Pdf,
  key : PdfObject,
  kids : PdfObject,
) -> PdfObject? raise {
  match kids {
    Array(values) => {
      for kid in values {
        match self.nametree_lookup(key, kid) {
          Some(result) => return Some(result)
          None => ()
        }
      }
      None
    }
    _ => raise PdfError::Msg("nametree_lookup_kids: malformed name tree")
  }
}

///|
/// Look something up in a name tree.
pub fn Pdf::nametree_lookup(
  self : Pdf,
  key : PdfObject,
  dict : PdfObject,
) -> PdfObject? raise {
  match self.lookup_direct("/Limits", dict) {
    Some(Array([l, r])) => {
      match key_compare(key, l) {
        Some(cmp) if cmp < 0 => return None
        _ => ()
      }
      match key_compare(key, r) {
        Some(cmp) if cmp > 0 => return None
        _ => ()
      }
      match self.lookup_direct("/Kids", dict) {
        Some(kids) => self.nametree_lookup_kids(key, kids)
        None =>
          match self.lookup_direct_orelse("/Names", "/Nums", dict) {
            Some(names) => array_lookup(key, names)
            None => raise PdfError::Msg("Malformed name tree entry")
          }
      }
    }
    None =>
      match self.lookup_direct("/Kids", dict) {
        Some(kids) => self.nametree_lookup_kids(key, kids)
        None =>
          match self.lookup_direct_orelse("/Names", "/Nums", dict) {
            Some(names) => array_lookup(key, names)
            None => raise PdfError::Msg("Missing name tree entry")
          }
      }
    _ => raise PdfError::Msg("Malformed name tree")
  }
}

///|
/// Return an ordered list of all (k, v) pairs in a name tree.
pub fn Pdf::contents_of_nametree(
  self : Pdf,
  tree : PdfObject,
) -> Array[(PdfObject, PdfObject)] raise {
  match self.lookup_direct_orelse("/Names", "/Nums", tree) {
    Some(Array(names)) => {
      let out = Array::new(capacity=names.length() / 2)
      for i = 0; i + 1 < names.length(); i = i + 2 {
        out.push((names[i], names[i + 1]))
      }
      if names.length() % 2 == 1 {
        @pdfe.log("warning: contents_of_nametree: odd number of /Names\n")
      }
      out
    }
    _ =>
      match self.lookup_direct("/Kids", tree) {
        Some(Array(kids)) =>
          flatten(kids.map(kid => self.contents_of_nametree(kid)))
        _ => raise PdfError::Msg("contents_of_nametree: neither names nor kids")
      }
  }
}
