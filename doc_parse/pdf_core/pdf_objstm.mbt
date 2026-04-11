///|
fn parse_objstm_dict(obj : PdfIndirectObject) -> (Int, Int) raise {
  let dict = match obj.value {
    PdfValue::Dict(d) => d
    _ => raise InvalidStructure("ObjStm object value must be dictionary")
  }

  match dict.get("Type") {
    Some(PdfValue::Name(t)) if t == "ObjStm" => ()
    _ => raise InvalidStructure("object stream /Type must be /ObjStm")
  }

  match dict.get("Filter") {
    Some(_) =>
      raise PdfNativeError::UnsupportedFeature(
        "ObjStm with /Filter is not supported in phase-7A step-2",
      )
    None => ()
  }

  let n = match dict.get("N") {
    Some(PdfValue::Int(v)) => v
    _ => raise InvalidStructure("ObjStm /N must be integer")
  }
  let first = match dict.get("First") {
    Some(PdfValue::Int(v)) => v
    _ => raise InvalidStructure("ObjStm /First must be integer")
  }
  if n < 0 || first < 0 {
    raise InvalidStructure("ObjStm /N and /First must be non-negative")
  }
  (n, first)
}

///|
fn parse_objstm_header_pairs(
  stream : Bytes,
  n : Int,
  first : Int,
) -> Array[(Int, Int)] raise {
  if first > stream.length() {
    raise InvalidStructure("ObjStm /First exceeds stream length")
  }

  let pairs : Array[(Int, Int)] = []
  let mut p = 0
  let mut i = 0
  while i < n {
    let (obj_num, p1) = match
      read_int_ascii(stream, skip_ws_and_comment(stream, p)) {
      Some(v) => v
      None => raise InvalidStructure("ObjStm header object number is invalid")
    }
    let (off, p2) = match
      read_int_ascii(stream, skip_ws_and_comment(stream, p1)) {
      Some(v) => v
      None => raise InvalidStructure("ObjStm header object offset is invalid")
    }
    if obj_num < 0 || off < 0 {
      raise InvalidStructure("ObjStm header values must be non-negative")
    }
    pairs.push((obj_num, off))
    p = p2
    i = i + 1
  }

  let header_end = skip_ws_and_comment(stream, p)
  if header_end > first {
    raise InvalidStructure("ObjStm header exceeds /First boundary")
  }
  pairs
}

///|
fn resolve_objstm_embedded_value(
  objstm_obj : PdfIndirectObject,
  target_obj_num : Int,
  target_index : Int?,
) -> PdfValue raise {
  let (n, first) = parse_objstm_dict(objstm_obj)
  let stream = match objstm_obj.stream {
    Some(bs) => bs
    None => raise InvalidStructure("ObjStm object missing stream data")
  }
  let pairs = parse_objstm_header_pairs(stream, n, first)

  let mut resolved : (Int, Int)? = None
  match target_index {
    Some(idx) => {
      if idx < 0 || idx >= pairs.length() {
        raise InvalidStructure("ObjStm index out of range")
      }
      resolved = Some(pairs[idx])
    }
    None => ()
  }

  let mut found_pair : (Int, Int)? = None
  for pair in pairs {
    if pair.0 == target_obj_num {
      found_pair = Some(pair)
      break
    }
  }

  let (obj_num, rel_off) = match found_pair {
    Some(v) => v
    None => raise ObjectNotFound(target_obj_num, 0)
  }
  match resolved {
    Some((idx_obj_num, _)) if idx_obj_num != obj_num =>
      raise InvalidStructure(
        "ObjStm header index/object-number mismatch for object " +
        target_obj_num.to_string(),
      )
    _ => ()
  }

  let body_start = first + rel_off
  if body_start < first || body_start >= stream.length() {
    raise InvalidStructure("ObjStm object offset out of stream bounds")
  }

  let (value, _) = parse_pdf_value(stream, body_start)
  value
}
