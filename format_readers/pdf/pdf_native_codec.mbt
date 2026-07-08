///|
pub fn inflate_pdf_stream(compressed : Bytes) -> Result[Bytes, String] {
  try @zlib.decompress(compressed) |> Ok catch {
    err => Err(err.to_string())
  }
}

///|
fn pdf_ascii_is_whitespace(byte : Int) -> Bool {
  byte == 0 || byte == 9 || byte == 10 || byte == 12 || byte == 13 || byte == 32
}

///|
fn pdf_hex_nibble(byte : Int) -> Int? {
  if byte >= '0'.to_int() && byte <= '9'.to_int() {
    Some(byte - '0'.to_int())
  } else if byte >= 'A'.to_int() && byte <= 'F'.to_int() {
    Some(byte - 'A'.to_int() + 10)
  } else if byte >= 'a'.to_int() && byte <= 'f'.to_int() {
    Some(byte - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
pub fn decode_pdf_ascii_hex_stream(encoded : Bytes) -> Result[Bytes, String] {
  let out : Array[Byte] = []
  let mut high : Int? = None
  for byte in encoded {
    let value = byte.to_int()
    if pdf_ascii_is_whitespace(value) {
      continue
    }
    if value == '>'.to_int() {
      break
    }
    let nibble = match pdf_hex_nibble(value) {
      Some(value) => value
      None => return Err("ASCIIHexDecode encountered a non-hex byte")
    }
    match high {
      Some(value) => {
        out.push((value * 16 + nibble).to_byte())
        high = None
      }
      None => high = Some(nibble)
    }
  }
  match high {
    Some(value) => out.push((value * 16).to_byte())
    None => ()
  }
  Ok(Bytes::from_array(out))
}

///|
fn ascii85_value(byte : Int) -> Int? {
  if byte >= '!'.to_int() && byte <= 'u'.to_int() {
    Some(byte - '!'.to_int())
  } else {
    None
  }
}

///|
pub fn decode_pdf_ascii85_stream(encoded : Bytes) -> Result[Bytes, String] {
  let out : Array[Byte] = []
  let digits : Array[Int] = []
  let mut index = 0
  while index < encoded.length() {
    let byte = encoded[index].to_int()
    index += 1
    if pdf_ascii_is_whitespace(byte) {
      continue
    }
    if byte == '~'.to_int() {
      if index < encoded.length() && encoded[index].to_int() == '>'.to_int() {
        break
      } else {
        return Err("ASCII85Decode encountered malformed terminator")
      }
    }
    if byte == 'z'.to_int() {
      if digits.length() != 0 {
        return Err("ASCII85Decode encountered `z` inside a partial group")
      }
      out.append([0, 0, 0, 0].map(fn(v) { v.to_byte() }))
      continue
    }
    let value = match ascii85_value(byte) {
      Some(v) => v
      None => return Err("ASCII85Decode encountered an invalid byte")
    }
    digits.push(value)
    if digits.length() == 5 {
      let mut acc : Int = 0
      for digit in digits {
        acc = acc * 85 + digit
      }
      out.push(((acc >> 24) & 0xFF).to_byte())
      out.push(((acc >> 16) & 0xFF).to_byte())
      out.push(((acc >> 8) & 0xFF).to_byte())
      out.push((acc & 0xFF).to_byte())
      digits.clear()
    }
  }
  if digits.length() > 0 {
    let original_len = digits.length()
    while digits.length() < 5 {
      digits.push(84)
    }
    let mut acc : Int = 0
    for digit in digits {
      acc = acc * 85 + digit
    }
    let tail = [
      ((acc >> 24) & 0xFF).to_byte(),
      ((acc >> 16) & 0xFF).to_byte(),
      ((acc >> 8) & 0xFF).to_byte(),
      (acc & 0xFF).to_byte(),
    ]
    for i in 0..<(original_len - 1) {
      out.push(tail[i])
    }
  }
  Ok(Bytes::from_array(out))
}

///|
pub fn decode_pdf_run_length_stream(encoded : Bytes) -> Result[Bytes, String] {
  let out : Array[Byte] = []
  let mut index = 0
  while index < encoded.length() {
    let length_byte = encoded[index].to_int()
    index += 1
    if length_byte == 128 {
      break
    }
    if length_byte <= 127 {
      let run_length = length_byte + 1
      if index + run_length > encoded.length() {
        return Err("RunLengthDecode literal run exceeds input length")
      }
      out.append(encoded[index:index + run_length].to_array())
      index += run_length
    } else {
      let repeat_count = 257 - length_byte
      if index >= encoded.length() {
        return Err("RunLengthDecode repeat run missing source byte")
      }
      let value = encoded[index]
      index += 1
      for _ in 0..<repeat_count {
        out.push(value)
      }
    }
  }
  Ok(Bytes::from_array(out))
}

///|
fn apply_pdf_stream_filter(
  payload : Bytes,
  filter_name : String,
) -> Result[Bytes, String] {
  match filter_name {
    "FlateDecode" => inflate_pdf_stream(payload)
    "ASCIIHexDecode" => decode_pdf_ascii_hex_stream(payload)
    "ASCII85Decode" => decode_pdf_ascii85_stream(payload)
    "RunLengthDecode" => decode_pdf_run_length_stream(payload)
    _ => Err("unsupported PDF stream filter: " + filter_name)
  }
}

///|
pub fn decode_pdf_stream_filters(
  payload : Bytes,
  filters : Array[String],
) -> Result[Bytes, String] {
  let mut decoded = payload
  for filter_name in filters {
    decoded = match apply_pdf_stream_filter(decoded, filter_name) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  }
  Ok(decoded)
}
