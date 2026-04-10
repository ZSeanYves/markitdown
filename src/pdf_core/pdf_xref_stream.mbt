///|
fn parse_xref_stream_at(
  bytes : Bytes,
  xref_offset : Int,
) -> (PdfXrefTable, Map[String, PdfValue]) raise {
  let obj = parse_indirect_object_at(bytes, xref_offset)
  let dict = match obj.value {
    PdfValue::Dict(d) => d
    _ => raise InvalidStructure("xref stream object must be dictionary")
  }
  match dict.get("Type") {
    Some(PdfValue::Name(t)) if t == "XRef" => ()
    _ => raise UnsupportedFeature("startxref does not point to xref table/stream")
  }

  let stream = match obj.stream {
    Some(bs) => bs
    None => raise InvalidStructure("xref stream object missing stream data")
  }

  let (w0, w1, w2) = parse_xref_stream_w(dict)
  let sections = parse_xref_stream_index(dict)
  let entries = parse_xref_stream_entries(stream, sections, (w0, w1, w2))

  ({ entries, }, dict)
}

///|
fn parse_xref_stream_w(dict : Map[String, PdfValue]) -> (Int, Int, Int) raise {
  let w = match dict.get("W") {
    Some(PdfValue::Array(arr)) => arr
    _ => raise UnsupportedFeature("xref stream /W must be an integer array")
  }
  if w.length() != 3 {
    raise UnsupportedFeature("xref stream /W must have 3 integers")
  }
  let w0 = as_int_value(w[0], "xref stream /W[0]")
  let w1 = as_int_value(w[1], "xref stream /W[1]")
  let w2 = as_int_value(w[2], "xref stream /W[2]")
  if w0 < 0 || w1 < 0 || w2 < 0 {
    raise UnsupportedFeature("xref stream /W contains negative width")
  }
  if w0 + w1 + w2 <= 0 {
    raise UnsupportedFeature("xref stream /W width sum is zero")
  }
  (w0, w1, w2)
}

///|
fn parse_xref_stream_index(
  dict : Map[String, PdfValue],
) -> Array[(Int, Int)] raise {
  match dict.get("Index") {
    Some(PdfValue::Array(items)) => {
      if items.length() % 2 != 0 {
        raise UnsupportedFeature("xref stream /Index should have even length")
      }
      let out : Array[(Int, Int)] = []
      let mut i = 0
      while i + 1 < items.length() {
        let start = as_int_value(items[i], "xref stream /Index start")
        let count = as_int_value(items[i + 1], "xref stream /Index count")
        if start < 0 || count < 0 {
          raise UnsupportedFeature("xref stream /Index has negative value")
        }
        out.push((start, count))
        i = i + 2
      }
      out
    }
    Some(_) => raise UnsupportedFeature("xref stream /Index must be an array")
    None => {
      let size = match dict.get("Size") {
        Some(PdfValue::Int(v)) => v
        _ => raise UnsupportedFeature("xref stream /Size must be integer")
      }
      if size < 0 {
        raise UnsupportedFeature("xref stream /Size is negative")
      }
      [(0, size)]
    }
  }
}

///|
fn parse_xref_stream_entries(
  stream : Bytes,
  sections : Array[(Int, Int)],
  widths : (Int, Int, Int),
) -> Map[String, PdfXrefEntry] raise {
  let (w0, w1, w2) = widths
  let row = w0 + w1 + w2
  if row <= 0 {
    raise UnsupportedFeature("invalid xref stream row width")
  }
  let entries : Map[String, PdfXrefEntry] = Map::new()

  let mut p = 0
  for section in sections {
    let (start_obj, count) = section
    let mut idx = 0
    while idx < count {
      if p + row > stream.length() {
        raise InvalidStructure("xref stream bytes truncated")
      }
      let t = read_be_int_or_default(stream, p, w0, 1)
      let f1 = read_be_int_or_default(stream, p + w0, w1, 0)
      let f2 = read_be_int_or_default(stream, p + w0 + w1, w2, 0)
      let obj_num = start_obj + idx
      let key = make_obj_key(obj_num, if t == 0 { f2 } else { 0 })

      if t == 0 {
        entries.set(key, {
          entry_type: 0,
          offset: f1,
          gen: f2,
          in_use: false,
          objstm_obj: None,
          objstm_index: None,
        })
      } else if t == 1 {
        entries.set(key, {
          entry_type: 1,
          offset: f1,
          gen: f2,
          in_use: true,
          objstm_obj: None,
          objstm_index: None,
        })
      } else if t == 2 {
        entries.set(key, {
          entry_type: 2,
          offset: -1,
          gen: 0,
          in_use: true,
          objstm_obj: Some(f1),
          objstm_index: Some(f2),
        })
      } else {
        raise UnsupportedFeature(
          "xref stream entry type is unsupported: " + t.to_string(),
        )
      }

      p = p + row
      idx = idx + 1
    }
  }

  entries
}

///|
fn read_be_int_or_default(
  bs : Bytes,
  pos : Int,
  width : Int,
  default_value : Int,
) -> Int {
  if width == 0 {
    return default_value
  }
  let mut v = 0
  let mut i = 0
  while i < width {
    v = v * 256 + bs[pos + i].to_int()
    i = i + 1
  }
  v
}

///|
fn as_int_value(v : PdfValue, ctx : String) -> Int raise {
  match v {
    PdfValue::Int(i) => i
    _ => raise UnsupportedFeature(ctx + " must be integer")
  }
}
