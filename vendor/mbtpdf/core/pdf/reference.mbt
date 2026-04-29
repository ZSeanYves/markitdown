///|
fn refset_empty() -> Map[Int, Bool] {
  Map::new()
}

///|
fn refset_add(n : Int, rs : Map[Int, Bool]) -> Unit {
  rs.set(n, true)
}

///|
fn refset_mem(n : Int, rs : Map[Int, Bool]) -> Bool {
  rs.contains(n)
}

///|
fn refset_elts(rs : Map[Int, Bool]) -> Array[Int] {
  let out = Array::new(capacity=rs.length())
  for key in rs.keys() {
    out.push(key)
  }
  out
}

///|
fn contains_string(xs : Array[String], key : String) -> Bool {
  xs[:].contains(key)
}

///|
fn dict_contains_name_entry(
  dict : Array[(String, PdfObject)],
  entry : (String, PdfObject),
) -> Bool {
  match entry {
    (key, Name(name)) =>
      dict.search_by(pair => match pair {
        (k, Name(vname)) => k == key && vname == name
        _ => false
      })
      is Some(_)
    _ => false
  }
}

///|
fn tocontinue(
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  dict : Array[(String, PdfObject)],
) -> Bool {
  if no_follow_entries.length() == 0 && no_follow_contains.length() == 0 {
    return true
  }
  for entry in no_follow_contains {
    if dict_contains_name_entry(dict, entry) {
      return false
    }
  }
  true
}

///|
fn Pdf::referenced_pdfobj(
  self : Pdf,
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  found : Map[Int, Bool],
  obj : PdfObject,
) -> Unit {
  match obj {
    Indirect(j) =>
      if !refset_mem(j, found) {
        let target = self.lookup_obj(j)
        match target {
          Dictionary(d) =>
            if tocontinue(no_follow_entries, no_follow_contains, d) {
              refset_add(j, found)
              self.referenced_pdfobj(
                no_follow_entries, no_follow_contains, found, target,
              )
            }
          _ => {
            refset_add(j, found)
            self.referenced_pdfobj(
              no_follow_entries, no_follow_contains, found, target,
            )
          }
        }
      }
    Dictionary(d) =>
      for pair in d {
        let (k, v) = pair
        if no_follow_entries.length() == 0 ||
          !contains_string(no_follow_entries, k) {
          self.referenced_pdfobj(
            no_follow_entries, no_follow_contains, found, v,
          )
        }
      }
    Array(values) =>
      for value in values {
        self.referenced_pdfobj(
          no_follow_entries, no_follow_contains, found, value,
        )
      }
    Stream(r) => {
      let (dict, _) = r.val
      self.referenced_pdfobj(no_follow_entries, no_follow_contains, found, dict)
    }
    _ => ()
  }
}

///|
/// Find the objects reachable from the given object.
pub fn Pdf::objects_referenced(
  self : Pdf,
  no_follow_entries : Array[String],
  no_follow_contains : Array[(String, PdfObject)],
  pdfobject : PdfObject,
) -> Array[Int] {
  let found = refset_empty()
  self.referenced_pdfobj(
    no_follow_entries, no_follow_contains, found, pdfobject,
  )
  refset_elts(found)
}

///|
/// Remove any unreferenced objects.
pub fn Pdf::remove_unreferenced(self : Pdf) -> Unit raise {
  self.nullify_deleted_page_references()
  let found = refset_empty()
  self.referenced_pdfobj([], [], found, self.lookup_obj(self.root))
  self.referenced_pdfobj([], [], found, self.trailerdict)
  refset_add(self.root, found)
  let eltnumbers = refset_elts(found)
  let elements = eltnumbers.map(num => self.lookup_obj(num))
  self.objects.max_obj_num = 0
  self.objects.objects.clear()
  self.objects.object_stream_ids.clear()
  for i, num in eltnumbers {
    self.addobj_given_num((num, elements[i]))
  }
}

///|
fn Pdf::page_reference_numbers_inner(
  self : Pdf,
  pages_node : PdfObject,
  node_number : Int,
) -> Array[Int] {
  if self.lookup_direct("/Type", pages_node) is Some(Name(name)) &&
    name.equal_string_bytes("/Page") {
    [node_number]
  } else {
    match self.lookup_direct("/Kids", pages_node) {
      Some(Array(elts)) => {
        let out = Array::new(capacity=elts.length())
        for elt in elts {
          match elt {
            Indirect(i) =>
              out.append(
                self.page_reference_numbers_inner(self.direct(Indirect(i)), i)[:],
              )
            _ => ()
          }
        }
        out
      }
      _ => [node_number]
    }
  }
}

///|
/// Return the page reference numbers in order.
pub fn Pdf::page_reference_numbers(self : Pdf) -> Array[Int] raise {
  let root = self.lookup_obj(self.root)
  let pages_node = match self.lookup_direct("/Pages", root) {
    Some(p) => p
    None => raise PdfError::Msg("No /Pages found in /Root")
  }
  self.page_reference_numbers_inner(pages_node, -1)
}
