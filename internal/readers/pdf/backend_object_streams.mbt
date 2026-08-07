///|
priv enum PdfNativeDictValue {
  Number(Double)
  Name(String)
  Word(String)
  LiteralString(PdfNativeTokenizedString)
  HexString(String)
  Array(Array[PdfNativeContentToken])
  Dict(String)
  Reference(Int, Int)
}

///|
fn pdf_expand_object_streams(
  objects : Array[PdfNativeObject],
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  let expanded : Array[PdfNativeObject] = []
  for object in objects {
    match pdf_extract_name_after(object.dict_text, "/Type") {
      Some("ObjStm") => {
        let parsed = match pdf_parse_object_stream_entries(object) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
        expanded.append(parsed[:])
      }
      _ => ()
    }
  }
  Ok(expanded)
}

///|
fn pdf_parse_object_stream_entries(
  object : PdfNativeObject,
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  let stream_text = match pdf_decode_stream_text(object, "object stream") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let first = match pdf_extract_int_after(object.dict_text, "/First") {
    Some(value) if value >= 0 && value <= stream_text.length() => value
    _ =>
      return Err(
        ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " is missing valid /First",
        ),
      )
  }
  let count = match pdf_extract_int_after(object.dict_text, "/N") {
    Some(value) if value >= 0 => value
    _ =>
      return Err(
        ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " is missing valid /N",
        ),
      )
  }
  let header_text = stream_text[:first].to_owned()
  let body_text = stream_text[first:].to_owned()
  let header_parts = pdf_split_ascii_whitespace(header_text)
  if header_parts.length() < count * 2 {
    return Err(
      ParseFailed(
        "object stream " + object.object_id.to_string() + " header is truncated",
      ),
    )
  }
  let entries : Array[(Int, Int)] = []
  let mut index = 0
  while index + 1 < count * 2 {
    match
      (
        pdf_parse_int(header_parts[index]),
        pdf_parse_int(header_parts[index + 1]),
      ) {
      (Some(object_id), Some(offset)) => entries.push((object_id, offset))
      _ =>
        return Err(
          ParseFailed(
            "object stream " +
            object.object_id.to_string() +
            " header contains invalid object entry",
          ),
        )
    }
    index += 2
  }
  let out : Array[PdfNativeObject] = []
  for idx in 0..<entries.length() {
    let (object_id, offset) = entries[idx]
    let next_offset = if idx + 1 < entries.length() {
      entries[idx + 1].1
    } else {
      body_text.length()
    }
    if offset < 0 || next_offset < offset || next_offset > body_text.length() {
      return Err(
        ParseFailed(
          "object stream " +
          object.object_id.to_string() +
          " has invalid embedded object offsets",
        ),
      )
    }
    let embedded_body = body_text[offset:next_offset].trim().to_owned()
    let embedded_bytes = pdf_ascii_bytes(embedded_body)
    let stream_slice = match pdf_extract_stream_slice(embedded_bytes) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let dict_text = match stream_slice {
      Some(slice) => slice.0
      None => embedded_body
    }
    let stream = match stream_slice {
      Some(slice) => Some(slice.1)
      None => None
    }
    out.push({ object_id, dict_text, stream })
  }
  Ok(out)
}

///|
fn pdf_extract_filter_names(dict_text : String) -> Array[String] {
  match pdf_extract_dict_value(dict_text, "/Filter") {
    Some(Name(value)) => [value]
    Some(Array(tokens)) => {
      let names : Array[String] = []
      for token in tokens {
        match token {
          Name(value) => names.push(value)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
}

///|
fn pdf_extract_stream_filter_specs(
  dict_text : String,
) -> Result[(Array[String], Array[PdfStreamDecodeParams?]), String] {
  let filter_value = match pdf_extract_dict_value(dict_text, "/Filter") {
    Some(value) => Some(value)
    None => pdf_extract_dict_value(dict_text, "/F")
  }
  let filters = match filter_value {
    Some(Name(value)) => [value]
    Some(Array(tokens)) => {
      let names : Array[String] = []
      for token in tokens {
        match token {
          Name(value) => names.push(value)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
  let params : Array[PdfStreamDecodeParams?] = []
  for _ in filters {
    params.push(None)
  }
  if filters.length() == 0 {
    return Ok((filters, params))
  }
  let decode_params_value = match
    pdf_extract_dict_value(dict_text, "/DecodeParms") {
    Some(value) => Some(value)
    None => pdf_extract_dict_value(dict_text, "/DP")
  }
  match decode_params_value {
    None => Ok((filters, params))
    Some(Array(tokens)) => {
      let mut filter_index = 0
      for token in tokens {
        if filter_index >= filters.length() {
          break
        }
        let value = match token {
          Dict(dict) => PdfNativeDictValue::Dict(dict)
          Word(word) => Word(word)
          Number(number) => Number(number)
          Name(name) => Name(name)
          Array(items) => Array(items)
          LiteralString(text) => LiteralString(text)
          HexString(hex) => HexString(hex)
        }
        match pdf_stream_decode_params_from_value(value) {
          Ok(parsed) => params[filter_index] = parsed
          Err(err) => return Err(err)
        }
        filter_index += 1
      }
      Ok((filters, params))
    }
    Some(value) =>
      if filters.length() == 1 {
        match pdf_stream_decode_params_from_value(value) {
          Ok(parsed) => {
            params[0] = parsed
            Ok((filters, params))
          }
          Err(err) => Err(err)
        }
      } else {
        Err("DecodeParms count does not match Filter count")
      }
  }
}

///|
fn pdf_stream_decode_params_from_value(
  value : PdfNativeDictValue,
) -> Result[PdfStreamDecodeParams?, String] {
  match value {
    Dict(dict_text) => Ok(Some(pdf_stream_decode_params_from_dict(dict_text)))
    Word("null") => Ok(None)
    Reference(object_id, generation) => {
      ignore(generation)
      Err(
        "indirect DecodeParms are unsupported for stream decode (object " +
        object_id.to_string() +
        ")",
      )
    }
    _ => Err("unsupported DecodeParms value")
  }
}

///|
fn pdf_stream_decode_params_from_dict(
  dict_text : String,
) -> PdfStreamDecodeParams {
  {
    predictor: pdf_extract_int_after(dict_text, "/Predictor"),
    colors: pdf_extract_int_after(dict_text, "/Colors"),
    bits_per_component: pdf_extract_int_after(dict_text, "/BitsPerComponent"),
    columns: pdf_extract_int_after(dict_text, "/Columns"),
    early_change: pdf_extract_int_after(dict_text, "/EarlyChange"),
  }
}

///|
fn pdf_collect_reference_ids_from_tokens(
  tokens : Array[PdfNativeContentToken],
) -> Array[Int] {
  let refs : Array[Int] = []
  let mut index = 0
  while index + 2 < tokens.length() {
    match (tokens[index], tokens[index + 1], tokens[index + 2]) {
      (Number(object_id), Number(_generation), Word("R")) =>
        if pdf_double_is_integral(object_id) {
          refs.push(object_id.to_int())
        }
      _ => ()
    }
    index += 1
  }
  refs
}

///|
fn pdf_extract_dict_value(text : String, key : String) -> PdfNativeDictValue? {
  let parsed = match pdf_parse_dict_entries(text) {
    Some(value) => value
    None => return None
  }
  for entry in parsed {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pdf_parse_dict_entries(
  text : String,
) -> Array[(String, PdfNativeDictValue)]? {
  let start = match text.find("<<") {
    Some(index) => index
    None => return None
  }
  let parsed = pdf_parse_dict_token(text, start)
  let dict_text = parsed.0
  if !dict_text.has_prefix("<<") || !dict_text.has_suffix(">>") {
    return None
  }
  let content = dict_text[2:dict_text.length() - 2].to_owned()
  let tokens = match pdf_scan_content_tokens(content) {
    Ok(value) => value
    Err(_) => return None
  }
  let entries : Array[(String, PdfNativeDictValue)] = []
  let mut index = 0
  while index < tokens.length() {
    match tokens[index] {
      Name(name) => {
        let (value, next_index) = pdf_dict_value_from_tokens(tokens, index + 1)
        if name != "" {
          entries.push(("/" + name, value))
        }
        index = next_index
      }
      _ => index += 1
    }
  }
  Some(entries)
}

///|
fn pdf_dict_value_from_tokens(
  tokens : Array[PdfNativeContentToken],
  start : Int,
) -> (PdfNativeDictValue, Int) {
  if start >= tokens.length() {
    return (Word(""), start)
  }
  if start + 2 < tokens.length() {
    match (tokens[start], tokens[start + 1], tokens[start + 2]) {
      (Number(object_id), Number(generation), Word("R")) =>
        if pdf_double_is_integral(object_id) &&
          pdf_double_is_integral(generation) {
          return (Reference(object_id.to_int(), generation.to_int()), start + 3)
        }
      _ => ()
    }
  }
  match tokens[start] {
    Number(value) => (Number(value), start + 1)
    Name(value) => (Name(value), start + 1)
    Word(value) => (Word(value), start + 1)
    LiteralString(value) => (LiteralString(value), start + 1)
    HexString(value) => (HexString(value), start + 1)
    Array(value) => (Array(value), start + 1)
    Dict(value) => (Dict(value), start + 1)
  }
}

///|
fn pdf_decode_hex_utf16be(hex : String) -> String? {
  let normalized = hex.trim().to_upper()
  if normalized.length() < 4 || normalized.length() % 2 != 0 {
    return None
  }
  let bytes : Array[Byte] = []
  let mut index = 0
  while index + 2 <= normalized.length() {
    match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
      Some(value) => bytes.push(value.to_byte())
      None => return None
    }
    index += 2
  }
  let decoded = @encoding.decode(Bytes::from_array(bytes), encoding=UTF16BE) catch {
    _ => return None
  }
  Some(pdf_strip_utf16_bom(decoded))
}

///|
fn pdf_strip_utf16_bom(text : String) -> String {
  let chars = text.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    String::from_array(chars[1:])
  } else {
    text
  }
}

///|
fn pdf_double_is_integral(value : Double) -> Bool {
  value.to_int().to_double() == value
}
