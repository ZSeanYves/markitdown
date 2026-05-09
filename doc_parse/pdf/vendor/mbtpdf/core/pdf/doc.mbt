///|
/// Object data state during parsing or decryption.
pub(all) enum ObjectData {
  Parsed(PdfObject)
  ParsedAlreadyDecrypted(PdfObject)
  ToParse
  ToParseFromObjectStream(
    Map[Int, Array[Int]],
    Int,
    Int,
    (Int, Array[Int]) -> Array[(Int, (Ref[ObjectData], Int))]
  )
}

///|
type PdfObjMapKey = Int

///|
type PdfObjMapEntry = (Ref[ObjectData], Int)

///|
pub type PdfObjMap = Map[Int, (Ref[ObjectData], Int)]

///|
/// Container for document objects.
pub(all) struct PdfObjects {
  mut max_obj_num : Int
  parse : ((PdfObjMapKey) -> PdfObject)?
  objects : PdfObjMap
  object_stream_ids : Map[Int, Int]
}

///|
/// In-memory PDF document.
pub(all) struct Pdf {
  major : Int
  minor : Int
  root : Int
  objects : PdfObjects
  mut trailerdict : PdfObject
  was_linearized : Bool
  mut saved_encryption : SavedEncryption?
}

///|
pub fn pdfobjmap_empty() -> PdfObjMap {
  Map::new()
}

///|
pub fn pdfobjmap_find(
  key : PdfObjMapKey,
  map : PdfObjMap,
) -> PdfObjMapEntry raise {
  match map.get(key) {
    Some(entry) => entry
    None => fail("Not_found")
  }
}

///|
pub fn pdfobjmap_bindings(
  map : PdfObjMap,
) -> Array[(PdfObjMapKey, PdfObjMapEntry)] {
  map.to_array()
}

///|
/// The empty document (PDF 2.0, no objects, no root, empty trailer dictionary).
pub fn Pdf::empty() -> Pdf {
  {
    major: 2,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: pdfobjmap_empty(),
      object_stream_ids: Map::new(),
    },
    trailerdict: Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
}

///|
/// Return the size of the object map.
pub fn Pdf::objcard(self : Pdf) -> Int {
  self.objects.objects.length()
}

///|
/// Return the object numbers in ascending order.
pub fn Pdf::objnumbers(self : Pdf) -> Array[Int] {
  let entries = self.objects.objects.to_array()
  entries.sort_by((a, b) => a.0 - b.0)
  entries.map(pair => pair.0)
}

///|
/// Remove the given object.
pub fn Pdf::removeobj(self : Pdf, objnum : Int) -> Unit {
  self.objects.objects.remove(objnum)
}

///|
/// Add an object. Returns the number chosen.
pub fn Pdf::addobj(self : Pdf, obj : PdfObject) -> Int {
  let next = self.objects.max_obj_num + 1
  self.addobj_given_num((next, obj))
  next
}

///|
/// Same as addobj, but pick a number ourselves.
pub fn Pdf::addobj_given_num(self : Pdf, pair : (Int, PdfObject)) -> Unit {
  let (num, obj) = pair
  if num > self.objects.max_obj_num {
    self.objects.max_obj_num = num
  }
  self.objects.objects.set(num, ({ val: Parsed(obj) }, 0))
}

///|
/// Return the document catalog.
pub fn Pdf::catalog_of_pdf(self : Pdf) -> PdfObject raise {
  let obj = self.lookup_obj(self.root)
  match obj {
    Null => raise PdfError::Msg("No catalog")
    _ => obj
  }
}

///|
fn deep_copy_pdfobjects(from : Pdf) -> PdfObjMap {
  let out : PdfObjMap = Map::new(capacity=from.objects.objects.length())
  for objnum, entry in from.objects.objects {
    let (obj_ref, gen) = entry
    out.set(objnum, (Ref::new(deep_copy_objdata(obj_ref.val)), gen))
  }
  out
}
