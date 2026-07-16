///|
priv enum PdfResolvedImageColorSpace {
  Gray
  RGB
  CMYK
  Indexed(PdfResolvedImageColorSpace, Int, Bytes)
}

///|
fn pdf_resolve_image_color_space(
  object : PdfNativeObject,
  object_index : Map[Int, PdfNativeObject],
) -> PdfResolvedImageColorSpace? {
  if object.dict_text.contains("/ImageMask true") {
    return Some(Gray)
  }
  let value = match pdf_extract_dict_value(object.dict_text, "/ColorSpace") {
    Some(value) => value
    None => return None
  }
  pdf_resolve_image_color_space_value(value, object_index, 0, [])
}

///|
fn pdf_resolve_image_color_space_value(
  value : PdfNativeDictValue,
  object_index : Map[Int, PdfNativeObject],
  depth : Int,
  visited : Array[Int],
) -> PdfResolvedImageColorSpace? {
  if depth > 8 {
    return None
  }
  match value {
    Name("DeviceGray") => Some(Gray)
    Name("DeviceRGB") => Some(RGB)
    Name("DeviceCMYK") => Some(CMYK)
    Array(tokens) =>
      pdf_resolve_image_color_space_array(
        tokens,
        object_index,
        depth + 1,
        visited,
      )
    Reference(object_id, generation) => {
      ignore(generation)
      if visited.contains(object_id) {
        return None
      }
      let target = match object_index.get(object_id) {
        Some(value) => value
        None => return None
      }
      let target_value = match pdf_standalone_object_value(target.dict_text) {
        Some(value) => value
        None => return None
      }
      let next_visited = visited.copy()
      next_visited.push(object_id)
      pdf_resolve_image_color_space_value(
        target_value,
        object_index,
        depth + 1,
        next_visited,
      )
    }
    _ => None
  }
}

///|
fn pdf_resolve_image_color_space_array(
  tokens : Array[PdfNativeContentToken],
  object_index : Map[Int, PdfNativeObject],
  depth : Int,
  visited : Array[Int],
) -> PdfResolvedImageColorSpace? {
  if tokens.length() == 0 || depth > 8 {
    return None
  }
  match tokens[0] {
    Name("ICCBased") =>
      pdf_resolve_icc_image_color_space(tokens, object_index, depth, visited)
    Name("Indexed") =>
      pdf_resolve_indexed_image_color_space(
        tokens, object_index, depth, visited,
      )
    Name("DeviceGray") => Some(Gray)
    Name("DeviceRGB") => Some(RGB)
    Name("DeviceCMYK") => Some(CMYK)
    _ => None
  }
}

///|
fn pdf_resolve_icc_image_color_space(
  tokens : Array[PdfNativeContentToken],
  object_index : Map[Int, PdfNativeObject],
  depth : Int,
  visited : Array[Int],
) -> PdfResolvedImageColorSpace? {
  let (profile_value, _) = pdf_dict_value_from_tokens(tokens, 1)
  let profile_id = match profile_value {
    Reference(object_id, generation) => {
      ignore(generation)
      object_id
    }
    _ => return None
  }
  if visited.contains(profile_id) {
    return None
  }
  let profile = match object_index.get(profile_id) {
    Some(value) => value
    None => return None
  }
  let next_visited = visited.copy()
  next_visited.push(profile_id)
  match pdf_extract_dict_value(profile.dict_text, "/Alternate") {
    Some(alternate) =>
      match
        pdf_resolve_image_color_space_value(
          alternate,
          object_index,
          depth + 1,
          next_visited,
        ) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match pdf_extract_int_after(profile.dict_text, "/N") {
    Some(1) => Some(Gray)
    Some(3) => Some(RGB)
    Some(4) => Some(CMYK)
    _ => None
  }
}

///|
fn pdf_resolve_indexed_image_color_space(
  tokens : Array[PdfNativeContentToken],
  object_index : Map[Int, PdfNativeObject],
  depth : Int,
  visited : Array[Int],
) -> PdfResolvedImageColorSpace? {
  let (base_value, after_base) = pdf_dict_value_from_tokens(tokens, 1)
  let base = match
    pdf_resolve_image_color_space_value(
      base_value,
      object_index,
      depth + 1,
      visited,
    ) {
    Some(value) => value
    None => return None
  }
  let (high_value, after_high) = pdf_dict_value_from_tokens(tokens, after_base)
  let high = match high_value {
    Number(value) if pdf_double_is_integral(value) => value.to_int()
    _ => return None
  }
  if high < 0 || high > 255 {
    return None
  }
  let (lookup_value, _) = pdf_dict_value_from_tokens(tokens, after_high)
  let lookup = match
    pdf_image_lookup_bytes(lookup_value, object_index, depth + 1, visited) {
    Some(value) => value
    None => return None
  }
  let components = pdf_resolved_image_color_components(base)
  if components <= 0 || lookup.length() < (high + 1) * components {
    return None
  }
  Some(Indexed(base, high, lookup))
}

///|
fn pdf_image_lookup_bytes(
  value : PdfNativeDictValue,
  object_index : Map[Int, PdfNativeObject],
  depth : Int,
  visited : Array[Int],
) -> Bytes? {
  if depth > 8 {
    return None
  }
  match value {
    HexString(hex) => {
      let values = match pdf_hex_byte_values(hex) {
        Some(value) => value
        None => return None
      }
      Some(Bytes::from_array(values.map(Int::to_byte)))
    }
    LiteralString(value) => Some(pdf_image_literal_bytes(value.decoded))
    Reference(object_id, generation) => {
      ignore(generation)
      if visited.contains(object_id) {
        return None
      }
      let object = match object_index.get(object_id) {
        Some(value) => value
        None => return None
      }
      match object.stream {
        Some(_) =>
          match pdf_decode_stream_bytes(object, "indexed color lookup") {
            Ok(bytes) => Some(bytes)
            Err(_) => None
          }
        None => {
          let nested = match pdf_standalone_object_value(object.dict_text) {
            Some(value) => value
            None => return None
          }
          let next_visited = visited.copy()
          next_visited.push(object_id)
          pdf_image_lookup_bytes(nested, object_index, depth + 1, next_visited)
        }
      }
    }
    _ => None
  }
}

///|
fn pdf_standalone_object_value(text : String) -> PdfNativeDictValue? {
  let tokens = match pdf_scan_content_tokens(text.trim().to_owned()) {
    Ok(value) => value
    Err(_) => return None
  }
  if tokens.length() == 0 {
    return None
  }
  Some(pdf_dict_value_from_tokens(tokens, 0).0)
}

///|
fn pdf_image_literal_bytes(value : String) -> Bytes {
  let bytes : Array[Byte] = []
  for ch in value.to_array() {
    bytes.push(ch.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn pdf_resolved_image_color_components(
  color_space : PdfResolvedImageColorSpace,
) -> Int {
  match color_space {
    Gray => 1
    RGB => 3
    CMYK => 4
    Indexed(_, _, _) => 1
  }
}

///|
fn pdf_resolved_image_color_space_label(
  color_space : PdfResolvedImageColorSpace?,
) -> String {
  match color_space {
    Some(Gray) => "DeviceGray"
    Some(RGB) => "DeviceRGB"
    Some(CMYK) => "DeviceCMYK"
    Some(Indexed(_, _, _)) => "Indexed"
    None => "unresolved"
  }
}
