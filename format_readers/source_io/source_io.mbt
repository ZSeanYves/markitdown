///|
pub struct SourceBytesPayload {
  bytes : Bytes
  prepared_source : @input.InputSource
}

///|
pub struct SourceTextPayload {
  text : String
  prepared_source : @input.InputSource
}

///|
pub fn read_source_bytes(
  source : @input.InputSource,
) -> Result[SourceBytesPayload, String] {
  match @input.read_input_bytes(source) {
    Ok(bytes) =>
      Ok({
        bytes,
        prepared_source: if @input.input_bytes(source) is Some(_) {
          source
        } else {
          @input.with_bytes_payload(source, bytes)
        },
      })
    Err(err) => Err(err)
  }
}

///|
pub fn read_source_text(
  source : @input.InputSource,
) -> Result[SourceTextPayload, String] {
  let text_result = match @input.input_text(source) {
    Some(text) => Ok(text)
    None => collect_source_text_chunks(source)
  }
  match text_result {
    Ok(text) =>
      Ok({
        text,
        prepared_source: if @input.input_text(source) is Some(_) {
          source
        } else {
          @input.with_text_payload(source, text)
        },
      })
    Err(err) => Err(err)
  }
}

///|
pub fn read_source_text_with_utf16_bom(
  source : @input.InputSource,
) -> Result[SourceTextPayload, String] {
  let prefix = match @input.read_input_prefix(source, 2) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if decode_utf16_text_bytes(prefix) is None {
    return read_source_text(source)
  }
  let bytes_payload = match read_source_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let text = match decode_utf16_text_bytes(bytes_payload.bytes) {
    Some(decoded) => decoded
    None =>
      match @input.read_input_text(bytes_payload.prepared_source) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
  }
  Ok({
    text,
    prepared_source: if @input.input_text(bytes_payload.prepared_source)
      is Some(_) {
      bytes_payload.prepared_source
    } else {
      @input.with_text_payload(bytes_payload.prepared_source, text)
    },
  })
}

///|
pub fn read_xml_source_text(
  source : @input.InputSource,
) -> Result[SourceTextPayload, String] {
  match @input.input_text(source) {
    Some(text) => Ok({ text, prepared_source: source })
    None => {
      let prefix = match @input.read_input_prefix(source, 256) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      match sniff_xml_declared_encoding(prefix) {
        Some("iso-8859-1") | Some("latin1") => ()
        _ => return read_source_text(source)
      }
      let bytes_payload = match read_source_bytes(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let text = match decode_xml_input_bytes(bytes_payload.bytes) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      Ok({
        text,
        prepared_source: @input.with_text_payload(
          bytes_payload.prepared_source,
          text,
        ),
      })
    }
  }
}

///|
pub fn decode_utf16_text_bytes(bytes : Bytes) -> String? {
  let arr = bytes.to_array()
  if arr.length() < 2 {
    return None
  }
  let first = arr[0].to_int()
  let second = arr[1].to_int()
  if first == 0xFF && second == 0xFE {
    let decoded = @encoding.decode(bytes, encoding=@encoding.UTF16LE) catch {
      _ => return None
    }
    return Some(strip_leading_bom(decoded))
  }
  if first == 0xFE && second == 0xFF {
    let decoded = @encoding.decode(bytes, encoding=@encoding.UTF16BE) catch {
      _ => return None
    }
    return Some(strip_leading_bom(decoded))
  }
  None
}

///|
pub fn decode_xml_input_bytes(bytes : Bytes) -> Result[String, String] {
  let declared = sniff_xml_declared_encoding(bytes)
  match declared {
    Some(encoding) =>
      if encoding == "iso-8859-1" || encoding == "latin1" {
        return Ok(decode_iso_8859_1_bytes(bytes))
      }
    None => ()
  }
  try @utf8.decode(bytes, ignore_bom=false) |> Ok catch {
    _ => Err("utf8 decode failed")
  }
}

///|
pub fn sniff_xml_declared_encoding(bytes : Bytes) -> String? {
  let mut limit = bytes.length()
  if limit > 256 {
    limit = 256
  }
  let chars : Array[Char] = []
  let mut index = 0
  while index < limit {
    chars.push(Int::unsafe_to_char(bytes[index].to_int()))
    index += 1
  }
  let prefix = String::from_array(chars)
  match prefix.find("encoding") {
    Some(rel_start) => {
      let start = rel_start + 8
      let suffix = prefix[start:].to_owned()
      match suffix.find("=") {
        Some(eq_rel) => {
          let mut pos = eq_rel + 1
          while pos < suffix.length() {
            let ch = suffix.unsafe_get(pos).unsafe_to_char()
            if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
              pos += 1
            } else {
              break
            }
          }
          if pos >= suffix.length() {
            return None
          }
          let quote = suffix.unsafe_get(pos).unsafe_to_char()
          if quote != '"' && quote != '\'' {
            return None
          }
          pos += 1
          let start_value = pos
          while pos < suffix.length() {
            let ch = suffix.unsafe_get(pos).unsafe_to_char()
            if ch == quote {
              return Some(
                suffix[start_value:pos].to_owned().trim().to_owned().to_lower(),
              )
            }
            pos += 1
          }
          None
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn strip_leading_bom(text : String) -> String {
  let chars = text.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    String::from_array(chars[1:])
  } else {
    text
  }
}

///|
fn decode_iso_8859_1_bytes(bytes : Bytes) -> String {
  let out : Array[Char] = []
  for b in bytes {
    let value = b.to_int()
    out.push(Int::unsafe_to_char(if value >= 0 { value } else { value + 256 }))
  }
  String::from_array(out)
}
