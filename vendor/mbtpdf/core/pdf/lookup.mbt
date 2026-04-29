///|
/// Lookup an object in a document, parsing it if required.
pub fn Pdf::lookup_obj(self : Pdf, objnum : Int) -> PdfObject {
  match self.objects.objects.get(objnum) {
    None => Null
    Some((obj_ref, _gen)) =>
      match obj_ref.val {
        Parsed(obj) | ParsedAlreadyDecrypted(obj) => obj
        ToParse =>
          match self.objects.parse {
            None => Null
            Some(parser) => {
              let obj = parser(objnum)
              obj_ref.val = Parsed(obj)
              obj
            }
          }
        ToParseFromObjectStream(themap, streamobjnum, _index, objstreamparser) =>
          self.parse_delayed_object_stream(
            themap, objnum, streamobjnum, objstreamparser,
          )
      }
  }
}

///|
fn Pdf::parse_delayed_object_stream(
  self : Pdf,
  themap : Map[Int, Array[Int]],
  objnum : Int,
  streamobjnum : Int,
  parser : (Int, Array[Int]) -> Array[(Int, (Ref[ObjectData], Int))],
) -> PdfObject {
  let indexes = match themap.get(objnum) {
    Some(value) => value
    None => return Null
  }
  let objects_from_stream = parser(streamobjnum, indexes)
  let mut found = false
  for pair in objects_from_stream {
    if pair.0 == objnum {
      found = true
    }
    self.objects.objects.set(pair.0, pair.1)
  }
  self.removeobj(streamobjnum)
  if found {
    self.lookup_obj(objnum)
  } else {
    Null
  }
}

///|
/// Make a PDF object direct -- that is, follow any indirect links.
pub fn Pdf::direct(self : Pdf, obj : PdfObject) -> PdfObject {
  match obj {
    Indirect(i) => self.direct(self.lookup_obj(i))
    _ => obj
  }
}

///|
/// Lookup the key, resolving indirections at source and destination.
pub fn Pdf::lookup_direct(
  self : Pdf,
  key : String,
  dict : PdfObject,
) -> PdfObject? {
  let dict_obj = self.direct(dict)
  let entry = match dict_obj {
    Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == key) {
        None => None
        Some(i) => Some(entries[i].1)
      }
    Stream(r) => {
      let (inner, _) = r.val
      match inner {
        Dictionary(entries) =>
          match entries.search_by(pair => pair.0 == key) {
            None => None
            Some(i) => Some(entries[i].1)
          }
        _ => None
      }
    }
    _ => None
  }
  match entry {
    None => None
    Some(value) => Some(self.direct(value))
  }
}

///|
/// Parse array index keys of the form "/[<digits>]".
fn array_index_from_key(key : String) -> Int? {
  if !key.has_prefix("/[") {
    return None
  }
  let rest = try key[2:] catch {
    _ => return None
  } noraise {
    view => view
  }
  let mut value = 0
  let mut seen = false
  for ch in rest {
    if ch >= '0' && ch <= '9' {
      value = value * 10 + (ch.to_int() - '0'.to_int())
      seen = true
    } else {
      break
    }
  }
  if seen {
    Some(value)
  } else {
    None
  }
}

///|
/// Lookup a key, allowing array index chains.
fn Pdf::lookup_direct_or_array(
  self : Pdf,
  key : String,
  obj : PdfObject,
) -> PdfObject? {
  match array_index_from_key(key) {
    Some(index) =>
      match obj {
        Array(items) => Some(self.direct(items[index]))
        _ => None
      }
    None => self.lookup_direct(key, obj)
  }
}

///|
/// Lookup a key in a nested dictionary chain.
pub fn Pdf::lookup_chain(
  self : Pdf,
  start : PdfObject,
  keys : ArrayView[String],
) -> PdfObject? {
  let mut current = start
  for key in keys {
    match self.lookup_direct_or_array(key, current) {
      None => return None
      Some(next) => current = next
    }
  }
  Some(current)
}

///|
/// Replace or insert a chain from the trailer dictionary.
pub fn Pdf::replace_chain(
  self : Pdf,
  chain : ArrayView[String],
  obj : PdfObject,
) -> Unit raise {
  fn replace_in_obj(
    pdf : Pdf,
    current : PdfObject,
    chain : ArrayView[String],
    obj : PdfObject,
  ) -> PdfObject raise {
    if chain.length() == 0 {
      return obj
    }
    let key = chain[0]
    let rest = chain.sub(start=1)
    match array_index_from_key(key) {
      Some(index) =>
        match current {
          Array(items) => {
            if index < 0 || index >= items.length() {
              raise PdfError::Msg("replace_chain: array index out of range")
            }
            let updated = if rest.length() == 0 {
              obj
            } else {
              replace_in_obj(pdf, items[index], rest, obj)
            }
            let out = items.copy()
            out[index] = updated
            Array(out)
          }
          _ => raise PdfError::Msg("replace_chain: bad array chain")
        }
      None =>
        match current {
          Null => {
            let child = replace_in_obj(pdf, Dictionary([]), rest, obj)
            Dictionary([(key, child)])
          }
          Dictionary(entries) => {
            let mut found = false
            let out = Array::new(capacity=entries.length() + 1)
            for entry in entries {
              let (k, v) = entry
              if k == key {
                let child = replace_in_obj(pdf, v, rest, obj)
                out.push((k, child))
                found = true
              } else {
                out.push((k, v))
              }
            }
            if !found {
              let child = replace_in_obj(pdf, Dictionary([]), rest, obj)
              out.push((key, child))
            }
            Dictionary(out)
          }
          Stream(r) => {
            let (inner, stream) = r.val
            let updated = replace_in_obj(pdf, inner, chain, obj)
            r.val = (updated, stream)
            Stream(r)
          }
          _ => raise PdfError::Msg("replace_chain: not a dictionary")
        }
    }
  }

  self.trailerdict = replace_in_obj(self, self.trailerdict, chain, obj)
}

///|
/// Return the object number of an indirect dictionary object, if it is indirect.
pub fn Pdf::indirect_number(self : Pdf, key : String, dict : PdfObject) -> Int? {
  match self.direct(dict) {
    Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == key) {
        None => None
        Some(i) =>
          match entries[i].1 {
            Indirect(objnum) => Some(objnum)
            _ => None
          }
      }
    Stream(r) => {
      let (inner, _) = r.val
      self.indirect_number(key, inner)
    }
    _ => None
  }
}

///|
/// Same as lookup_direct, but allow a second alternative key.
pub fn Pdf::lookup_direct_orelse(
  self : Pdf,
  key : String,
  alt : String,
  dict : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(key, dict) {
    Some(obj) => Some(obj)
    None => self.lookup_direct(alt, dict)
  }
}

///|
/// Lookup an object, failing if not found.
pub fn Pdf::lookup_fail(
  self : Pdf,
  errtext : String,
  key : String,
  dict : PdfObject,
) -> PdfObject raise {
  match self.lookup_direct(key, dict) {
    Some(obj) => obj
    None => raise PdfError::Msg(errtext)
  }
}
