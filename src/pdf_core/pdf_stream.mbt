///|
fn parse_stream_bounds(
  bytes : Bytes,
  dict_value : PdfValue,
  stream_kw_pos : Int,
) -> (Int, Int) raise PdfParseError {
  let mut start = stream_kw_pos + 6
  if start < bytes.length() && bytes[start] == 13.to_byte() {
    start = start + 1
    if start < bytes.length() && bytes[start] == 10.to_byte() {
      start = start + 1
    }
  } else if start < bytes.length() && bytes[start] == 10.to_byte() {
    start = start + 1
  }

  let length = extract_stream_length(dict_value)
  match length {
    Some(len) => {
      let end_ = start + len
      if end_ > bytes.length() {
        raise UnexpectedEOF("stream bytes")
      }
      (start, end_)
    }
    None => {
      let mut i = start
      while i + 9 <= bytes.length() {
        if starts_with_at(bytes, i, "endstream") {
          let end_ = if i > start && bytes[i - 1] == 10.to_byte() { i - 1 } else { i }
          return (start, end_)
        }
        i = i + 1
      }
      raise UnexpectedEOF("endstream")
    }
  }
}

///|
fn extract_stream_length(dict_value : PdfValue) -> Int? {
  match dict_value {
    PdfValue::Dict(dict) =>
      match dict.get("Length") {
        Some(PdfValue::Int(v)) => Some(v)
        _ => None
      }
    _ => None
  }
}
