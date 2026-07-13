///|
/// One decoded source chunk with offsets suitable for block provenance.
pub struct SourceTextChunk {
  text : String
  byte_start : Int64
  byte_end : Int64
  line_start : Int
  line_end : Int
  utf16_start : Int
  utf16_end : Int
}

///|
/// Stateful UTF-8 chunk reader. The callback returns `None` after EOF.
pub struct SourceTextChunkReader {
  next : () -> Result[SourceTextChunk?, String]
}

///|
/// Open a streaming UTF-8 reader over any bounded source cursor.
pub fn open_source_text_chunk_reader(
  source : @input.InputSource,
  max_bytes? : Int64 = 512L * 1024L * 1024L,
  chunk_size? : Int = 64 * 1024,
) -> Result[SourceTextChunkReader, String] {
  if chunk_size <= 0 {
    return Err("text chunk size must be positive")
  }
  let cursor = match @input.open_source_cursor(source, max_bytes~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let read_offset = Ref(0L)
  let consumed_offset = Ref(0L)
  let carry = Ref(Bytes::new(0))
  let eof = Ref(false)
  let line = Ref(1)
  let utf16 = Ref(0)
  let pending_cr = Ref(false)
  Ok({
    next: fn() {
      while true {
        if eof.val && carry.val.length() == 0 {
          return Ok(None)
        }
        let incoming = if eof.val {
          Bytes::new(0)
        } else {
          match
            @input.source_cursor_read_at(
              cursor,
              read_offset.val,
              length=chunk_size,
            ) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
        }
        if incoming.length() == 0 {
          eof.val = true
        } else {
          read_offset.val = read_offset.val + incoming.length().to_int64()
        }
        let combined = carry.val + incoming
        let decoded = match decode_utf8_source_chunk(combined, eof.val) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        carry.val = decoded.1
        if decoded.0 == "" && !eof.val {
          continue
        }
        if decoded.0 == "" && eof.val {
          return Ok(None)
        }
        let byte_start = consumed_offset.val
        let decoded_bytes = combined.length() - carry.val.length()
        consumed_offset.val = consumed_offset.val + decoded_bytes.to_int64()
        let line_start = line.val
        let utf16_start = utf16.val
        advance_source_text_position(decoded.0, line, utf16, pending_cr)
        if eof.val && pending_cr.val {
          line.val += 1
          pending_cr.val = false
        }
        return Ok(
          Some({
            text: decoded.0,
            byte_start,
            byte_end: consumed_offset.val,
            line_start,
            line_end: line.val,
            utf16_start,
            utf16_end: utf16.val,
          }),
        )
      }
      Ok(None)
    },
  })
}

///|
pub fn collect_source_text_chunks(
  source : @input.InputSource,
  max_bytes? : Int64 = 512L * 1024L * 1024L,
) -> Result[String, String] {
  let reader = match open_source_text_chunk_reader(source, max_bytes~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let out = StringBuilder::new()
  while true {
    match (reader.next)() {
      Ok(Some(chunk)) => out.write_string(chunk.text)
      Ok(None) => break
      Err(message) => return Err(message)
    }
  }
  Ok(out.to_string())
}

///|
fn decode_utf8_source_chunk(
  bytes : Bytes,
  eof : Bool,
) -> Result[(String, Bytes), String] {
  if eof {
    let text = try @utf8.decode(bytes, ignore_bom=false) |> Some catch {
      _ => None
    }
    return match text {
      Some(value) => Ok((value, Bytes::new(0)))
      None => Err("utf8 decode failed")
    }
  }
  for trailing in 0..<=3 {
    if trailing > bytes.length() {
      break
    }
    let prefix_length = bytes.length() - trailing
    let remainder = bytes.view(start=prefix_length).to_owned()
    if !utf8_incomplete_prefix(remainder) {
      continue
    }
    let prefix = bytes.view(end=prefix_length).to_owned()
    let text = try @utf8.decode(prefix, ignore_bom=false) |> Some catch {
      _ => None
    }
    match text {
      Some(value) => return Ok((value, remainder))
      None => ()
    }
  }
  Err("utf8 decode failed")
}

///|
fn utf8_incomplete_prefix(bytes : Bytes) -> Bool {
  if bytes.length() == 0 {
    return true
  }
  let first = bytes[0].to_int()
  let expected = if first >= 0xC2 && first <= 0xDF {
    2
  } else if first >= 0xE0 && first <= 0xEF {
    3
  } else if first >= 0xF0 && first <= 0xF4 {
    4
  } else {
    return false
  }
  if bytes.length() >= expected {
    return false
  }
  for index in 1..<bytes.length() {
    let value = bytes[index].to_int()
    if value < 0x80 || value > 0xBF {
      return false
    }
  }
  true
}

///|
fn advance_source_text_position(
  text : String,
  line : Ref[Int],
  utf16 : Ref[Int],
  pending_cr : Ref[Bool],
) -> Unit {
  for ch in text {
    utf16.val += if ch.to_int() > 0xFFFF { 2 } else { 1 }
    if pending_cr.val {
      line.val += 1
      pending_cr.val = false
      if ch == '\n' {
        continue
      }
    }
    if ch == '\r' {
      pending_cr.val = true
    } else if ch == '\n' {
      line.val += 1
    }
  }
}
