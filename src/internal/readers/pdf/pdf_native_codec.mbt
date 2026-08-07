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
priv struct PdfStreamDecodeParams {
  predictor : Int?
  colors : Int?
  bits_per_component : Int?
  columns : Int?
  early_change : Int?
}

///|
fn pdf_lzw_initial_dictionary() -> Map[Int, Array[Byte]] {
  let dictionary : Map[Int, Array[Byte]] = Map([])
  for value in 0..<256 {
    dictionary.set(value, [value.to_byte()])
  }
  dictionary
}

///|
fn pdf_lzw_read_code(encoded : Bytes, bit_offset : Int, width : Int) -> Int? {
  if width <= 0 {
    return None
  }
  if bit_offset + width > encoded.length() * 8 {
    return None
  }
  let mut value = 0
  let mut cursor = bit_offset
  for _ in 0..<width {
    let byte_index = cursor / 8
    let bit_index = 7 - cursor % 8
    let bit = (encoded[byte_index].to_int() >> bit_index) & 1
    value = (value << 1) | bit
    cursor += 1
  }
  Some(value)
}

///|
fn pdf_lzw_entry_with_suffix(
  prefix : Array[Byte],
  suffix : Byte,
) -> Array[Byte] {
  let out : Array[Byte] = []
  out.append(prefix[:])
  out.push(suffix)
  out
}

///|
fn decode_pdf_lzw_stream(
  encoded : Bytes,
  early_change? : Int = 1,
) -> Result[Bytes, String] {
  let clear_code = 256
  let end_code = 257
  let mut dictionary = pdf_lzw_initial_dictionary()
  let out : Array[Byte] = []
  let mut bit_offset = 0
  let mut code_width = 9
  let mut next_code = 258
  let mut previous : Array[Byte]? = None
  while true {
    let code = match pdf_lzw_read_code(encoded, bit_offset, code_width) {
      Some(value) => value
      None => break
    }
    bit_offset += code_width
    if code == clear_code {
      dictionary = pdf_lzw_initial_dictionary()
      code_width = 9
      next_code = 258
      previous = None
      continue
    }
    if code == end_code {
      break
    }
    let entry = match dictionary.get(code) {
      Some(value) => value
      None =>
        match previous {
          Some(prev) if code == next_code && prev.length() > 0 =>
            pdf_lzw_entry_with_suffix(prev, prev[0])
          _ => return Err("LZWDecode encountered an invalid code")
        }
    }
    out.append(entry[:])
    match previous {
      Some(prev) if prev.length() > 0 && entry.length() > 0 =>
        if next_code < 4096 {
          dictionary.set(next_code, pdf_lzw_entry_with_suffix(prev, entry[0]))
          next_code += 1
          if code_width < 12 && next_code + early_change >= 1 << code_width {
            code_width += 1
          }
        }
      _ => ()
    }
    previous = Some(entry)
  }
  Ok(Bytes::from_array(out))
}

///|
fn pdf_decode_param_or_default(value : Int?, fallback : Int) -> Int {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn pdf_predictor_row_bytes(
  params : PdfStreamDecodeParams,
) -> Result[(Int, Int), String] {
  let colors = pdf_decode_param_or_default(params.colors, 1)
  let bits_per_component = pdf_decode_param_or_default(
    params.bits_per_component,
    8,
  )
  let columns = pdf_decode_param_or_default(params.columns, 1)
  if colors <= 0 || columns <= 0 {
    return Err("predictor DecodeParms require positive Colors and Columns")
  }
  if bits_per_component != 8 {
    return Err(
      "predictor bits_per_component unsupported: " +
      bits_per_component.to_string(),
    )
  }
  let bytes_per_pixel = (colors * bits_per_component + 7) / 8
  let row_bytes = (colors * columns * bits_per_component + 7) / 8
  Ok((bytes_per_pixel, row_bytes))
}

///|
fn pdf_apply_tiff_predictor(
  decoded : Bytes,
  params : PdfStreamDecodeParams,
) -> Result[Bytes, String] {
  let (bytes_per_pixel, row_bytes) = match pdf_predictor_row_bytes(params) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if row_bytes == 0 {
    return Ok(decoded)
  }
  if decoded.length() % row_bytes != 0 {
    return Err("TIFF predictor row length mismatch")
  }
  let out = decoded.to_array()
  let mut row_start = 0
  while row_start < out.length() {
    let mut index = bytes_per_pixel
    while index < row_bytes {
      let current = out[row_start + index].to_int()
      let left = out[row_start + index - bytes_per_pixel].to_int()
      out[row_start + index] = ((current + left) & 0xFF).to_byte()
      index += 1
    }
    row_start += row_bytes
  }
  Ok(Bytes::from_array(out))
}

///|
fn pdf_png_paeth_predictor(left : Int, up : Int, up_left : Int) -> Int {
  let p = left + up - up_left
  let pa = (p - left).abs()
  let pb = (p - up).abs()
  let pc = (p - up_left).abs()
  if pa <= pb && pa <= pc {
    left
  } else if pb <= pc {
    up
  } else {
    up_left
  }
}

///|
fn pdf_apply_png_filter_row(
  out : Array[Byte],
  row_start : Int,
  row_bytes : Int,
  bytes_per_pixel : Int,
  previous_row_start : Int?,
  filter_type : Int,
) -> Result[Unit, String] {
  for index in 0..<row_bytes {
    let raw = out[row_start + index].to_int()
    let left = if index >= bytes_per_pixel {
      out[row_start + index - bytes_per_pixel].to_int()
    } else {
      0
    }
    let up = match previous_row_start {
      Some(prev) => out[prev + index].to_int()
      None => 0
    }
    let up_left = match previous_row_start {
      Some(prev) if index >= bytes_per_pixel =>
        out[prev + index - bytes_per_pixel].to_int()
      _ => 0
    }
    let value = match filter_type {
      0 => raw
      1 => (raw + left) & 0xFF
      2 => (raw + up) & 0xFF
      3 => (raw + (left + up) / 2) & 0xFF
      4 => (raw + pdf_png_paeth_predictor(left, up, up_left)) & 0xFF
      _ =>
        return Err(
          "unsupported PNG predictor row filter: " + filter_type.to_string(),
        )
    }
    out[row_start + index] = value.to_byte()
  }
  Ok(())
}

///|
fn pdf_apply_png_predictor(
  decoded : Bytes,
  params : PdfStreamDecodeParams,
) -> Result[Bytes, String] {
  let predictor = pdf_decode_param_or_default(params.predictor, 1)
  let (bytes_per_pixel, row_bytes) = match pdf_predictor_row_bytes(params) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if row_bytes == 0 {
    return Ok(decoded)
  }
  if predictor == 15 {
    let row_span = row_bytes + 1
    if decoded.length() % row_span != 0 {
      return Err("PNG predictor row length mismatch")
    }
    let source = decoded.to_array()
    let out : Array[Byte] = Array::new(capacity=decoded.length())
    let mut previous_row_start : Int? = None
    let mut source_row_start = 0
    while source_row_start < source.length() {
      let filter_type = source[source_row_start].to_int()
      let output_row_start = out.length()
      out.append(source[source_row_start + 1:source_row_start + row_span])
      match
        pdf_apply_png_filter_row(
          out, output_row_start, row_bytes, bytes_per_pixel, previous_row_start,
          filter_type,
        ) {
        Ok(_) => ()
        Err(err) => return Err(err)
      }
      previous_row_start = Some(output_row_start)
      source_row_start += row_span
    }
    return Ok(Bytes::from_array(out))
  }
  let fixed_filter = predictor - 10
  if fixed_filter < 0 || fixed_filter > 4 {
    return Err("unsupported PNG predictor: " + predictor.to_string())
  }
  if decoded.length() % row_bytes != 0 {
    return Err("PNG predictor row length mismatch")
  }
  let out = decoded.to_array()
  let mut previous_row_start : Int? = None
  let mut row_start = 0
  while row_start < out.length() {
    match
      pdf_apply_png_filter_row(
        out, row_start, row_bytes, bytes_per_pixel, previous_row_start, fixed_filter,
      ) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
    previous_row_start = Some(row_start)
    row_start += row_bytes
  }
  Ok(Bytes::from_array(out))
}

///|
fn pdf_apply_stream_predictor(
  decoded : Bytes,
  params : PdfStreamDecodeParams?,
) -> Result[Bytes, String] {
  let actual = match params {
    Some(value) => value
    None => return Ok(decoded)
  }
  let predictor = pdf_decode_param_or_default(actual.predictor, 1)
  if predictor <= 1 {
    return Ok(decoded)
  }
  match predictor {
    2 => pdf_apply_tiff_predictor(decoded, actual)
    10 => pdf_apply_png_predictor(decoded, actual)
    11 => pdf_apply_png_predictor(decoded, actual)
    12 => pdf_apply_png_predictor(decoded, actual)
    13 => pdf_apply_png_predictor(decoded, actual)
    14 => pdf_apply_png_predictor(decoded, actual)
    15 => pdf_apply_png_predictor(decoded, actual)
    _ => Err("unsupported PDF predictor: " + predictor.to_string())
  }
}

///|
fn apply_pdf_stream_filter(
  payload : Bytes,
  filter_name : String,
  params? : PdfStreamDecodeParams? = None,
) -> Result[Bytes, String] {
  let decoded = match filter_name {
    "FlateDecode" => inflate_pdf_stream(payload)
    "ASCIIHexDecode" => decode_pdf_ascii_hex_stream(payload)
    "ASCII85Decode" => decode_pdf_ascii85_stream(payload)
    "RunLengthDecode" => decode_pdf_run_length_stream(payload)
    "LZWDecode" =>
      decode_pdf_lzw_stream(
        payload,
        early_change=pdf_decode_param_or_default(
          match params {
            Some(value) => value.early_change
            None => None
          },
          1,
        ),
      )
    _ => Err("unsupported PDF stream filter: " + filter_name)
  }
  match decoded {
    Ok(bytes) => pdf_apply_stream_predictor(bytes, params)
    Err(err) => Err(err)
  }
}

///|
fn decode_pdf_stream_filters_with_params(
  payload : Bytes,
  filters : Array[String],
  params : Array[PdfStreamDecodeParams?],
) -> Result[Bytes, String] {
  let mut decoded = payload
  for i in 0..<filters.length() {
    let param = if i < params.length() { params[i] } else { None }
    decoded = match apply_pdf_stream_filter(decoded, filters[i], params=param) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  }
  Ok(decoded)
}

///|
pub fn decode_pdf_stream_filters(
  payload : Bytes,
  filters : Array[String],
) -> Result[Bytes, String] {
  let params : Array[PdfStreamDecodeParams?] = []
  for _ in filters {
    params.push(None)
  }
  decode_pdf_stream_filters_with_params(payload, filters, params)
}
