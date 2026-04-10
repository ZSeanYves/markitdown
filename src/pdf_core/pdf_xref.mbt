///|
fn parse_pdf_header(bytes : Bytes) -> String raise {
  if bytes.length() < 8 {
    raise InvalidHeader("too short")
  }
  if !starts_with_at(bytes, 0, "%PDF-") {
    raise InvalidHeader("missing %PDF- prefix")
  }
  let mut i = 5
  while i < bytes.length() && bytes[i] != b'\x0A' && bytes[i] != b'\x0D' {
    i = i + 1
  }
  bytes_to_string(bytes, 5, i)
}

///|
fn find_startxref(bytes : Bytes) -> Int raise PdfParseError {
  let pos = match find_last(bytes, "startxref") {
    Some(v) => v
    None => raise InvalidStructure("startxref not found")
  }
  let i = skip_ws_and_comment(bytes, pos + 9)
  match read_int_ascii(bytes, i) {
    Some((off, _)) => off
    None => raise InvalidStructure("invalid startxref offset")
  }
}

///|
fn parse_xref_and_trailer(
  bytes : Bytes,
  xref_offset : Int,
) -> (PdfXrefTable, Map[String, PdfValue]) raise {
  let i = skip_ws_and_comment(bytes, xref_offset)
  if !starts_with_at(bytes, i, "xref") {
    return parse_xref_stream_at(bytes, i)
  }

  let entries : Map[String, PdfXrefEntry] = Map::new()
  let mut state = skip_ws_and_comment(bytes, i + 4)

  while true {
    let p0 = skip_ws_and_comment(bytes, state)
    if starts_with_at(bytes, p0, "trailer") {
      let (trailer, _tnext) = parse_trailer(bytes, p0)
      break ({ entries, }, trailer)
    }

    let (obj_start, p1) = match read_int_ascii(bytes, p0) {
      Some(v) => v
      None => raise InvalidStructure("invalid xref subsection start")
    }
    let (count, p2) = match
      read_int_ascii(bytes, skip_ws_and_comment(bytes, p1)) {
      Some(v) => v
      None => raise InvalidStructure("invalid xref subsection count")
    }

    let mut p = skip_ws_and_comment(bytes, p2)
    let mut idx = 0
    while idx < count {
      let line_start = p
      let mut line_end = line_start
      while line_end < bytes.length() &&
            bytes[line_end] != b'\n' &&
            bytes[line_end] != b'\r' {
        line_end = line_end + 1
      }

      let line = bytes_to_string(bytes, line_start, line_end).trim().to_string()
      let parts = line.split(" ")
      let filtered : Array[String] = []
      for s in parts {
        if s != "" {
          filtered.push(s.to_string())
        }
      }
      if filtered.length() < 3 {
        raise InvalidStructure("malformed xref entry line")
      }

      let off = @string.parse_int(filtered[0]) catch {
        _ => raise InvalidStructure("bad xref entry offset")
      }
      let gen = @string.parse_int(filtered[1]) catch {
        _ => raise InvalidStructure("bad xref entry generation")
      }
      let in_use = filtered[2] == "n"

      let key = make_obj_key(obj_start + idx, gen)
      entries.set(key, {
        entry_type: if in_use { 1 } else { 0 },
        offset: off,
        gen,
        in_use,
        objstm_obj: None,
        objstm_index: None,
      })

      p = line_end
      while p < bytes.length() && (bytes[p] == b'\n' || bytes[p] == b'\r') {
        p = p + 1
      }
      idx = idx + 1
    }

    state = p
  } nobreak {
    raise InvalidStructure("unterminated xref table")
  }
}

///|
fn parse_trailer(
  bytes : Bytes,
  trailer_pos : Int,
) -> (Map[String, PdfValue], Int) raise {
  let p = skip_ws_and_comment(bytes, trailer_pos + 7)
  let (v, next) = parse_pdf_value(bytes, p)
  match v {
    PdfValue::Dict(dict) => (dict, next)
    _ => raise InvalidStructure("trailer should be a dictionary")
  }
}
