///|
/// One decoded source chunk with offsets suitable for block provenance.
pub struct SourceTextChunk {
  text : String
  byte_start : Int64
  byte_end : Int64
  line_start : Int32
  line_end : Int32
  utf16_start : Int32
  utf16_end : Int32
}

///|
/// Return the decoded text portion of a source chunk.
pub fn source_text_chunk_text(chunk : SourceTextChunk) -> String {
  chunk.text
}

///|
/// Stateful UTF-8 chunk reader. EOF and failure release owned Path resources;
/// callers stopping early must defer `close`. Borrowed sessions stay open.
pub struct SourceTextChunkReader {
  next : async () -> Result[SourceTextChunk?, String] noraise
  input_error : () -> String?
  close : () -> Unit
}

///|
/// Open a streaming UTF-8 reader over any bounded source cursor.
pub async fn open_source_text_chunk_reader(
  source : @input.InputSource,
  max_bytes? : Int64,
  chunk_size~ : Int32 = 64 * 1024,
) -> Result[SourceTextChunkReader, String] noraise {
  if chunk_size <= 0 {
    return Err("text chunk size must be positive")
  }
  let session = @input.begin_input_session(source, max_bytes?)
  let handed_off = Ref(false)
  defer (if !handed_off.val { @input.end_input_session(session) })
  let cursor = match @input.open_source_cursor(session.source, max_bytes?) {
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
  let closed = Ref(false)
  let close = fn() {
    if !closed.val {
      closed.val = true
      @input.end_input_session(session)
    }
  }
  let reader : SourceTextChunkReader = {
    input_error: fn() { @input.source_cursor_error(cursor) },
    close,
    next: async fn() -> Result[SourceTextChunk?, String] noraise {
      let keep_open = Ref(false)
      defer (if !keep_open.val { close() })
      while true {
        if closed.val || (eof.val && carry.val.length() == 0) {
          close()
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
            Err(message) => {
              close()
              return Err(message)
            }
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
          Err(message) => {
            close()
            return Err(message)
          }
        }
        carry.val = decoded.1
        if decoded.0 == "" && !eof.val {
          continue
        }
        if decoded.0 == "" && eof.val {
          close()
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
        keep_open.val = true
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
  }
  handed_off.val = true
  Ok(reader)
}

///|
pub async fn collect_source_text_chunks(
  source : @input.InputSource,
  max_bytes? : Int64,
) -> Result[String, String] noraise {
  collect_source_text_with_extent(source, max_bytes?).map(value => value.0)
}

///|
// Keep the consumed raw extent from the successful UTF8 traversal. Counting
// the prepared String later can lose original bytes after text normalization.
async fn collect_source_text_with_extent(
  source : @input.InputSource,
  max_bytes? : Int64,
) -> Result[(String, Int64), String] noraise {
  let session = @input.begin_input_session(source, max_bytes?)
  defer @input.end_input_session(session)
  let reader = match open_source_text_chunk_reader(session.source, max_bytes?) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  defer (reader.close)()
  let out = StringBuilder()
  let mut physical_bytes = 0L
  while true {
    match (reader.next)() {
      Ok(Some(chunk)) => {
        out.write_string(chunk.text)
        physical_bytes = chunk.byte_end
      }
      Ok(None) => break
      Err(message) => return Err(message)
    }
  }
  Ok((out.to_string(), physical_bytes))
}

///|
/// Decode a complete UTF8 prefix and retain up to three trailing bytes for the
/// next chunk. At EOF every byte must form a complete, valid UTF8 sequence.
pub fn decode_utf8_source_chunk(
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
    let remainder = bytes.exact_view(start=prefix_length).to_owned()
    if !utf8_incomplete_prefix(remainder) {
      continue
    }
    let prefix = bytes.exact_view(end=prefix_length).to_owned()
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
  line : Ref[Int32],
  utf16 : Ref[Int32],
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
