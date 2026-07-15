///|
fn pdf_decode_literal_pdf_text(value : String) -> String {
  match pdf_decode_utf16_literal_string(value) {
    Some(decoded) => decoded
    None => pdf_decode_pdfdoc_byte_string(value)
  }
}

///|
fn pdf_decode_content_literal_pdf_text(
  value : String,
  font_info : PdfNativeFontInfo?,
) -> String {
  match pdf_decode_utf16_literal_string(value) {
    Some(decoded) => decoded
    None => {
      let bytes = pdf_string_byte_values(value)
      match font_info {
        Some(info) if pdf_font_uses_code_unit_decode(info) => {
          let invalid_tounicode_bytes = pdf_bytes_hit_invalid_tounicode(
            bytes, info,
          )
          match pdf_decode_literal_bytes_with_font(bytes, info) {
            Some(decoded) => decoded
            None =>
              if invalid_tounicode_bytes ||
                pdf_font_should_fail_closed_after_tounicode(info) {
                ""
              } else {
                pdf_decode_pdfdoc_bytes(bytes)
              }
          }
        }
        Some(info) if pdf_font_is_winansi(info) =>
          match pdf_decode_raw_cjk_bytes_for_font(bytes, info) {
            Some(decoded) => decoded
            None => pdf_decode_winansi_bytes(bytes)
          }
        _ => pdf_decode_pdfdoc_bytes(bytes)
      }
    }
  }
}

///|
fn pdf_decode_utf16_literal_string(value : String) -> String? {
  let chars = value.to_array()
  if chars.length() < 2 {
    return None
  }
  if chars[0] == '\u{00FE}' && chars[1] == '\u{00FF}' {
    let hex_parts : Array[String] = ["FEFF"]
    let mut index = 2
    while index < chars.length() {
      hex_parts.push(pdf_hex_upper(chars[index].to_int(), 2))
      index += 1
    }
    return pdf_hex_to_string(hex_parts.join(""))
  }
  if chars[0] == '\u{00FF}' && chars[1] == '\u{00FE}' {
    let bytes : Array[Byte] = []
    let mut index = 2
    while index < chars.length() {
      bytes.push(chars[index].to_int().to_byte())
      index += 1
    }
    let decoded = @encoding.decode(
      Bytes::from_array(bytes),
      encoding=@encoding.UTF16LE,
    ) catch {
      _ => return None
    }
    return Some(pdf_strip_utf16_bom(decoded))
  }
  None
}

///|
fn pdf_decode_literal_bytes_with_font(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> String? {
  match pdf_decode_literal_bytes_with_font_result(bytes, info) {
    Some(decoded) => Some(decoded.text)
    None =>
      match pdf_decode_raw_cjk_bytes_for_font(bytes, info) {
        Some(decoded) => Some(decoded)
        None =>
          if pdf_font_is_winansi(info) {
            let decoded = pdf_decode_winansi_bytes(bytes)
            if decoded != "" {
              Some(decoded)
            } else {
              None
            }
          } else {
            None
          }
      }
  }
}

///|
fn pdf_decode_hex_pdf_text_result(
  hex : String,
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  let bytes = match pdf_hex_byte_values(hex) {
    Some(value) => value
    None => return None
  }
  pdf_decode_literal_bytes_with_font_result(bytes, info)
}

///|
fn pdf_decode_literal_bytes_with_font_result(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  let invalid_tounicode_bytes = pdf_bytes_hit_invalid_tounicode(bytes, info)
  match pdf_decode_bytes_with_unicode_map(bytes, info) {
    Some(decoded) => return Some(decoded)
    None =>
      if invalid_tounicode_bytes ||
        pdf_font_should_fail_closed_after_tounicode(info) {
        return None
      }
  }
  match info.tounicode_builtin_name {
    Some(name) =>
      match pdf_resolve_predefined_cmap(name) {
        Some(cmap) =>
          match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
            Some(decoded) => return Some(decoded)
            None => ()
          }
        None => ()
      }
    None => ()
  }
  match pdf_embedded_font_decode_bytes(bytes, info) {
    Some(decoded) => return Some(decoded)
    None => ()
  }
  match info.cid_collection_cmap {
    Some(cmap) =>
      match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
        Some(decoded) => return Some(decoded)
        None => ()
      }
    None => ()
  }
  match info.predefined_cmap {
    Some(cmap) =>
      match pdf_predefined_cmap_decode_bytes(bytes, cmap) {
        Some(decoded) => return Some(decoded)
        None => ()
      }
    None => ()
  }
  if pdf_font_is_identity_h(info) || pdf_font_is_identity_v(info) {
    return pdf_identity_ascii_decoded_units(bytes)
  }
  None
}

///|
fn pdf_decode_bytes_with_unicode_map(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> PdfDecodedFontBytes? {
  if !info.has_tounicode &&
    info.encoding_name == Some("WinAnsiEncoding") &&
    pdf_font_prefers_raw_gb_family_decode(info) {
    return None
  }
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 || info.unicode_map.length() == 0 {
    return None
  }
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index < bytes.length() {
    let mut matched = false
    for width in widths {
      if width <= 0 || index + width > bytes.length() {
        continue
      }
      let key = pdf_hex_from_bytes(bytes, index, width)
      match info.unicode_map.get(key) {
        Some(value) if pdf_is_usable_tounicode_text(value) => {
          units.push({
            byte_width: width,
            charcode: pdf_embedded_font_charcode_from_bytes(bytes, index, width),
            cid: pdf_font_unit_cid_hint(
              info,
              width,
              pdf_embedded_font_charcode_from_bytes(bytes, index, width),
            ),
            gid: None,
            text: value,
          })
          parts.push(value)
          index += width
          matched = true
          break
        }
        _ => ()
      }
    }
    if matched {
      continue
    }
    let width = match
      pdf_first_matching_code_width(widths, (bytes.length() - index) * 2) {
      Some(value) => value
      None => 1
    }
    if width <= 0 || index + width > bytes.length() {
      break
    }
    let key = pdf_hex_from_bytes(bytes, index, width)
    if info.has_tounicode &&
      info.tounicode_invalid_keys.get(key).unwrap_or(false) {
      return None
    }
    match pdf_decode_font_code_fallback(key, info) {
      Some(value) => {
        let charcode = pdf_embedded_font_charcode_from_bytes(
          bytes, index, width,
        )
        units.push({
          byte_width: width,
          charcode,
          cid: pdf_font_unit_cid_hint(info, width, charcode),
          gid: None,
          text: value,
        })
        parts.push(value)
        index += width
      }
      None => break
    }
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_bytes_hit_invalid_tounicode(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> Bool {
  if !info.has_tounicode || info.tounicode_invalid_keys.length() == 0 {
    return false
  }
  let widths = pdf_font_decode_widths(info)
  if widths.length() == 0 {
    return false
  }
  let mut index = 0
  while index < bytes.length() {
    let width = match
      pdf_first_matching_code_width(widths, (bytes.length() - index) * 2) {
      Some(value) => value
      None => 1
    }
    if width <= 0 || index + width > bytes.length() {
      break
    }
    let key = pdf_hex_from_bytes(bytes, index, width)
    if info.tounicode_invalid_keys.get(key).unwrap_or(false) {
      return true
    }
    index += width
  }
  false
}

///|
fn pdf_font_unit_cid_hint(
  info : PdfNativeFontInfo,
  byte_width : Int,
  charcode : Int,
) -> Int? {
  if byte_width > 1 ||
    pdf_font_is_identity_h(info) ||
    pdf_font_is_identity_v(info) ||
    info.descendant_subtype == Some("CIDFontType0") ||
    info.descendant_subtype == Some("CIDFontType2") ||
    pdf_font_has_predefined_cid_encoding(info) {
    Some(charcode)
  } else {
    None
  }
}

///|
fn pdf_identity_ascii_decoded_units(bytes : Array[Int]) -> PdfDecodedFontBytes? {
  let units : Array[PdfDecodedFontUnit] = []
  let parts : Array[String] = []
  let mut index = 0
  while index + 1 < bytes.length() {
    let charcode = pdf_embedded_font_charcode_from_bytes(bytes, index, 2)
    if charcode < 0 || charcode > 0x7F {
      break
    }
    let text = pdf_string_from_codepoints([charcode])
    parts.push(text)
    units.push({ byte_width: 2, charcode, cid: Some(charcode), gid: None, text })
    index += 2
  }
  if units.length() == 0 {
    None
  } else {
    Some({ text: parts.join(""), units })
  }
}

///|
fn pdf_string_byte_values(text : String) -> Array[Int] {
  let bytes : Array[Int] = []
  for ch in text.to_array() {
    bytes.push(ch.to_int() & 0xFF)
  }
  bytes
}

///|
fn pdf_hex_from_bytes(bytes : Array[Int], start : Int, width : Int) -> String {
  let parts : Array[String] = []
  let mut index = start
  while index < start + width && index < bytes.length() {
    parts.push(pdf_hex_upper(bytes[index] & 0xFF, 2))
    index += 1
  }
  parts.join("")
}

///|
fn pdf_decode_pdfdoc_byte_string(value : String) -> String {
  pdf_decode_pdfdoc_bytes(pdf_string_byte_values(value))
}

///|
fn pdf_decode_pdfdoc_bytes(bytes : Array[Int]) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(pdf_pdfdoc_byte_char(byte & 0xFF))
  }
  String::from_array(chars)
}

///|
fn pdf_decode_winansi_bytes(bytes : Array[Int]) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(pdf_winansi_byte_char(byte & 0xFF))
  }
  String::from_array(chars)
}

///|
fn pdf_pdfdoc_byte_char(byte : Int) -> Char {
  match byte {
    0x18 => '\u{02D8}'
    0x19 => '\u{02C7}'
    0x1A => '\u{02C6}'
    0x1B => '\u{02D9}'
    0x1C => '\u{02DD}'
    0x1D => '\u{02DB}'
    0x1E => '\u{02DA}'
    0x1F => '\u{02DC}'
    0x80 => '\u{2022}'
    0x81 => '\u{2020}'
    0x82 => '\u{2021}'
    0x83 => '\u{2026}'
    0x84 => '\u{2014}'
    0x85 => '\u{2013}'
    0x86 => '\u{0192}'
    0x87 => '\u{2044}'
    0x88 => '\u{2039}'
    0x89 => '\u{203A}'
    0x8A => '\u{2212}'
    0x8B => '\u{2030}'
    0x8C => '\u{201E}'
    0x8D => '\u{201C}'
    0x8E => '\u{201D}'
    0x8F => '\u{2018}'
    0x90 => '\u{2019}'
    0x91 => '\u{201A}'
    0x92 => '\u{2122}'
    0x93 => '\u{FB01}'
    0x94 => '\u{FB02}'
    0x95 => '\u{0141}'
    0x96 => '\u{0152}'
    0x97 => '\u{0160}'
    0x98 => '\u{0178}'
    0x99 => '\u{017D}'
    0x9A => '\u{0131}'
    0x9B => '\u{0142}'
    0x9C => '\u{0153}'
    0x9D => '\u{0161}'
    0x9E => '\u{017E}'
    0xA0 => '\u{20AC}'
    _ => Int::unsafe_to_char(byte)
  }
}

///|
fn pdf_winansi_byte_char(byte : Int) -> Char {
  match byte {
    0x80 => '\u{20AC}'
    0x82 => '\u{201A}'
    0x83 => '\u{0192}'
    0x84 => '\u{201E}'
    0x85 => '\u{2026}'
    0x86 => '\u{2020}'
    0x87 => '\u{2021}'
    0x88 => '\u{02C6}'
    0x89 => '\u{2030}'
    0x8A => '\u{0160}'
    0x8B => '\u{2039}'
    0x8C => '\u{0152}'
    0x8E => '\u{017D}'
    0x90 => '\u{2019}'
    0x91 => '\u{2018}'
    0x92 => '\u{2019}'
    0x93 => '\u{201C}'
    0x94 => '\u{201D}'
    0x95 => '\u{2022}'
    0x96 => '\u{2013}'
    0x97 => '\u{2014}'
    0x98 => '\u{02DC}'
    0x99 => '\u{2122}'
    0x9A => '\u{0161}'
    0x9B => '\u{203A}'
    0x9C => '\u{0153}'
    0x9E => '\u{017E}'
    0x9F => '\u{0178}'
    _ => Int::unsafe_to_char(byte)
  }
}
