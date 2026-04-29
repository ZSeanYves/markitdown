///|
/// Recursively rebuild an array.
pub fn recurse_array(
  f : (PdfObject) -> PdfObject,
  elts : Array[PdfObject],
) -> PdfObject {
  Array(elts.map(f))
}

///|
/// Recursively rebuild a dictionary.
fn recurse_dict(
  f : (PdfObject) -> PdfObject,
  elts : Array[(String, PdfObject)],
  preserve_order? : Bool = false,
) -> PdfObject {
  let _ = preserve_order
  let out = Array::new(capacity=elts.length())
  for entry in elts {
    out.push((entry.0, f(entry.1)))
  }
  Dictionary(out)
}

///|
/// Iterate over all objects in a document.
pub fn Pdf::objiter(
  self : Pdf,
  f : (Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  for key in self.objnumbers() {
    f(key, self.lookup_obj(key))
  }
}

///|
/// Iterate over all objects in a document, ordered by object number.
pub fn Pdf::objiter_inorder(
  self : Pdf,
  f : (Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  self.objiter(f)
}

///|
/// Iterate over all objects in a document with generation numbers.
pub fn Pdf::objiter_gen(
  self : Pdf,
  f : (Int, Int, PdfObject) -> Unit raise?,
) -> Unit raise? {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let (_obj_ref, gen) = entry.1
    f(key, gen, self.lookup_obj(key))
  }
}

///|
/// Map a function over all objects in a document.
pub fn Pdf::objselfmap(
  self : Pdf,
  f : (PdfObject) -> PdfObject raise?,
) -> Unit raise? {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  for entry in entries {
    let key = entry.0
    let obj = self.lookup_obj(key)
    let updated = f(obj)
    let (obj_ref, _gen) = entry.1
    match obj_ref.val {
      ParsedAlreadyDecrypted(_) => obj_ref.val = ParsedAlreadyDecrypted(updated)
      _ => obj_ref.val = Parsed(updated)
    }
  }
}

///|
/// Select objects matching a predicate and return their numbers.
pub fn Pdf::objselect(
  self : Pdf,
  f : (PdfObject) -> Bool raise?,
) -> Array[Int] raise? {
  // Upper bound: all objects could match.
  let out = Array::new(capacity=self.objects.objects.length())
  self.objiter((num, obj) => if f(obj) { out.push(num) })
  out
}

///|
fn Pdf::nullify_deleted_page_references(self : Pdf) -> Unit raise {
  fn nullify(numbers : Map[Int, Bool], obj : PdfObject) -> PdfObject {
    match obj {
      Indirect(i) => if numbers.contains(i) { Null } else { obj }
      Array(elts) => recurse_array(v => nullify(numbers, v), elts)
      Dictionary(elts) => recurse_dict(v => nullify(numbers, v), elts)
      Stream(r) => {
        let (dict, stream) = r.val
        r.val = (nullify(numbers, dict), stream)
        Stream(r)
      }
      _ => obj
    }
  }

  // Upper bound: all objects could be /Page dictionaries.
  let page_object_numbers = Array::new(capacity=self.objects.objects.length())
  self.objiter((objnum, obj) => match obj {
    Dictionary(_) =>
      match self.lookup_direct("/Type", obj) {
        Some(Name(name)) if name.equal_string_bytes("/Page") =>
          page_object_numbers.push(objnum)
        _ => ()
      }
    _ => ()
  })
  let refnums = self.page_reference_numbers()
  if refnums.length() != page_object_numbers.length() {
    let table = Map::new(capacity=page_object_numbers.length())
    for num in page_object_numbers {
      table.set(num, true)
    }
    for num in refnums {
      table.remove(num)
    }
    self.objselfmap(obj => nullify(table, obj))
  }
}

///|
/// Renumber indirect references using a change table.
pub fn Pdf::renumber_object_parsed(
  self : Pdf,
  changes : Map[Int, Int],
  obj : PdfObject,
  preserve_order? : Bool = false,
) -> PdfObject {
  match obj {
    Indirect(i) =>
      match changes.get(i) {
        Some(x) => Indirect(x)
        None => Indirect(i)
      }
    Array(values) =>
      Array(
        values.map(v => self.renumber_object_parsed(changes, v, preserve_order~)),
      )
    Dictionary(entries) =>
      recurse_dict(
        v => self.renumber_object_parsed(changes, v, preserve_order~),
        entries,
        preserve_order~,
      )
    Stream(r) => {
      let (dict, stream) = r.val
      let dict_updated = self.renumber_object_parsed(
        changes,
        dict,
        preserve_order~,
      )
      r.val = (dict_updated, stream)
      Stream(r)
    }
    _ => obj
  }
}
