///|
fn check_object_contains_renumbering(
  changes : Map[Int, Int],
  obj : PdfObject,
) -> Bool {
  match obj {
    Indirect(i) => changes.get(i) is Some(_)
    Array(values) =>
      values.any(v => check_object_contains_renumbering(changes, v))
    Dictionary(entries) =>
      entries.any(pair => check_object_contains_renumbering(changes, pair.1))
    Stream(r) => {
      let (dict, _) = r.val
      check_object_contains_renumbering(changes, dict)
    }
    _ => false
  }
}

///|
/// Calculate the change table required to renumber objects 1..n.
pub fn Pdf::changes(self : Pdf) -> Map[Int, Int] {
  let keys = self.objnumbers()
  let table : Map[Int, Int] = Map::new(capacity=keys.length())
  let mut num = 1
  for key in keys {
    table.set(key, num)
    num = num + 1
  }
  table
}

///|
/// Renumber a PDF's objects using a change table.
pub fn Pdf::renumber(
  self : Pdf,
  change_table : Map[Int, Int],
  preserve_order? : Bool = false,
) -> Pdf {
  let root = match change_table.get(self.root) {
    Some(value) => value
    None => self.root
  }
  let trailerdict = if check_object_contains_renumbering(
      change_table,
      self.trailerdict,
    ) {
    self.renumber_object_parsed(change_table, self.trailerdict, preserve_order~)
  } else {
    self.trailerdict
  }
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  let objects : PdfObjMap = Map::new(capacity=entries.length())
  let mut max_obj_num = 0
  for entry in entries {
    let old_num = entry.0
    let new_num = match change_table.get(old_num) {
      Some(value) => value
      None => old_num
    }
    let obj = self.lookup_obj(old_num)
    let updated = if check_object_contains_renumbering(change_table, obj) {
      self.renumber_object_parsed(change_table, obj, preserve_order~)
    } else {
      obj
    }
    objects.set(new_num, ({ val: ObjectData::Parsed(updated) }, 0))
    if new_num > max_obj_num {
      max_obj_num = new_num
    }
  }
  let object_stream_ids = Map::new(
    capacity=self.objects.object_stream_ids.length(),
  )
  for key, value in self.objects.object_stream_ids {
    match change_table.get(key) {
      Some(new_key) => object_stream_ids.set(new_key, value)
      None => ()
    }
  }
  {
    major: self.major,
    minor: self.minor,
    root,
    objects: {
      max_obj_num,
      parse: self.objects.parse,
      objects,
      object_stream_ids,
    },
    trailerdict,
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
  }
}

///|
/// Renumber a list of PDFs so their object numbers are mutually exclusive.
pub fn renumber_pdfs(pdfs : Array[Pdf]) -> Array[Pdf] {
  let out = Array::new(capacity=pdfs.length())
  let mut base = 1
  for pdf in pdfs {
    let keys = pdf.objnumbers()
    let changes : Map[Int, Int] = Map::new(capacity=keys.length())
    let mut i = 0
    for key in keys {
      changes.set(key, base + i)
      i = i + 1
    }
    base = base + keys.length()
    out.push(pdf.renumber(changes))
  }
  out
}
