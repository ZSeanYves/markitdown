///|
fn copy_bytes(bytes : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let out = Array::new(capacity=bytes.length())
  out.append(bytes[:])
  out
}

///|
fn deep_copy_pdfobject(obj : PdfObject) -> PdfObject {
  match obj {
    Array(values) => Array(values.map(v => deep_copy_pdfobject(v)))
    Dictionary(entries) =>
      Dictionary(entries.map(pair => (pair.0, deep_copy_pdfobject(pair.1))))
    Stream(r) => {
      let (dict, stream) = r.val
      let dict_copy = deep_copy_pdfobject(dict)
      let stream_copy = match stream {
        Stream::Got(bytes) => Stream::Got(copy_bytes(bytes))
        Stream::ToGet(toget) => Stream::ToGet(toget)
      }
      Stream(Ref::new((dict_copy, stream_copy)))
    }
    _ => obj
  }
}

///|
fn deep_copy_objdata(objdata : ObjectData) -> ObjectData {
  match objdata {
    Parsed(obj) => Parsed(deep_copy_pdfobject(obj))
    ParsedAlreadyDecrypted(obj) =>
      ParsedAlreadyDecrypted(deep_copy_pdfobject(obj))
    ToParse => ToParse
    ToParseFromObjectStream(themap, x, y, func) =>
      ToParseFromObjectStream(themap, x, y, func)
  }
}

///|
/// Create a deep copy of a PDF document.
pub fn Pdf::deep_copy(self : Pdf) -> Pdf {
  let object_stream_ids = Map::new(
    capacity=self.objects.object_stream_ids.length(),
  )
  for key, value in self.objects.object_stream_ids {
    object_stream_ids.set(key, value)
  }
  {
    major: self.major,
    minor: self.minor,
    root: self.root,
    objects: {
      max_obj_num: self.objects.max_obj_num,
      parse: self.objects.parse,
      objects: deep_copy_pdfobjects(self),
      object_stream_ids,
    },
    trailerdict: deep_copy_pdfobject(self.trailerdict),
    was_linearized: self.was_linearized,
    saved_encryption: self.saved_encryption,
  }
}
