///|
// Compact static PDF font encoding tables used by native decode.

///|
priv struct PdfFontStaticTables {
  glyph_unicode_map : Map[String, String]
  standard_encoding_map : Map[Int, String]
  winansi_encoding_map : Map[Int, String]
  macroman_encoding_map : Map[Int, String]
  symbol_encoding_map : Map[Int, String]
  dingbats_encoding_map : Map[Int, String]
}

///|
let pdf_font_static_tables_blob_base64 : String = "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"

///|
let pdf_font_static_tables : @lazy.Lazy[PdfFontStaticTables] = Lazy(() => {
  pdf_font_decode_static_tables()
})

///|
fn pdf_font_encoding_strip_leading_slash(name : String) -> String {
  if name.has_prefix("/") {
    name[1:].to_owned()
  } else {
    name
  }
}

///|
fn pdf_font_encoding_string_from_codepoints(codepoints : Array[Int]) -> String {
  let chars : Array[Char] = []
  for codepoint in codepoints {
    chars.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(chars)
}

///|
fn pdf_font_parse_uni_glyph_name(name : String) -> String? {
  let normalized = pdf_font_encoding_strip_leading_slash(name)
  if normalized.has_prefix("uni") && normalized.length() > 3 {
    let hex = normalized[3:].to_owned()
    if hex.length() == 0 || hex.length() % 4 != 0 {
      return None
    }
    let codepoints : Array[Int] = []
    let mut index = 0
    while index + 4 <= hex.length() {
      match pdf_parse_hex_int(hex[index:index + 4].to_owned()) {
        Some(value) => codepoints.push(value)
        None => return None
      }
      index += 4
    }
    return Some(pdf_font_encoding_string_from_codepoints(codepoints))
  }
  if normalized.has_prefix("u") && normalized.length() >= 5 {
    let hex = normalized[1:].to_owned()
    match pdf_parse_hex_int(hex) {
      Some(value) if value >= 0 && value <= 0x10FFFF =>
        Some(pdf_font_encoding_string_from_codepoints([value]))
      _ => None
    }
  } else if normalized.length() == 1 {
    Some(normalized)
  } else {
    None
  }
}

///|
fn pdf_font_decode_hex_codepoint_sequence(text : String) -> String? {
  let codepoints : Array[Int] = []
  for raw in text.split(",").to_array() {
    if raw == "" {
      continue
    }
    match pdf_parse_hex_int(raw.to_owned()) {
      Some(value) => codepoints.push(value)
      None => return None
    }
  }
  Some(pdf_font_encoding_string_from_codepoints(codepoints))
}

///|
fn pdf_font_glyph_name_to_unicode(name : String) -> String? {
  let normalized = pdf_font_encoding_strip_leading_slash(name)
  match pdf_font_static_tables.force().glyph_unicode_map.get(normalized) {
    Some(value) => Some(value)
    None => pdf_font_parse_uni_glyph_name(normalized)
  }
}

///|
fn pdf_font_base_encoding_code_to_glyph_map(
  encoding_name : String,
) -> Map[Int, String] {
  let tables = pdf_font_static_tables.force()
  let source = match encoding_name {
    "StandardEncoding" => tables.standard_encoding_map
    "WinAnsiEncoding" => tables.winansi_encoding_map
    "MacRomanEncoding" => tables.macroman_encoding_map
    "Symbol" => tables.symbol_encoding_map
    "ZapfDingbats" => tables.dingbats_encoding_map
    _ => return Map([])
  }
  pdf_font_clone_code_to_glyph_map(source)
}

///|
fn pdf_font_clone_code_to_glyph_map(
  source : Map[Int, String],
) -> Map[Int, String] {
  let out : Map[Int, String] = Map([])
  for entry in source.to_array() {
    out.set(entry.0, entry.1)
  }
  out
}

///|
fn pdf_font_decode_static_tables() -> PdfFontStaticTables {
  let text = pdf_decode_base64_zlib_text(
    pdf_font_static_tables_blob_base64, "pdf_font_static_tables",
  )
  let glyph_unicode_map : Map[String, String] = Map([])
  let standard_encoding_map : Map[Int, String] = Map([])
  let winansi_encoding_map : Map[Int, String] = Map([])
  let macroman_encoding_map : Map[Int, String] = Map([])
  let symbol_encoding_map : Map[Int, String] = Map([])
  let dingbats_encoding_map : Map[Int, String] = Map([])
  for raw_line in text.split("\n").to_array() {
    if raw_line == "" {
      continue
    }
    let parts = raw_line.split("\t").to_array()
    if parts.length() == 3 && parts[0] == "G" {
      match pdf_font_decode_hex_codepoint_sequence(parts[2].to_owned()) {
        Some(text) => glyph_unicode_map.set(parts[1].to_owned(), text)
        None => ()
      }
    } else if parts.length() == 4 && parts[0] == "E" {
      let code = match pdf_parse_int(parts[2].to_owned()) {
        Some(value) => value
        None => continue
      }
      let glyph_name = parts[3].to_owned()
      match parts[1].to_owned() {
        "StandardEncoding" => standard_encoding_map.set(code, glyph_name)
        "WinAnsiEncoding" => winansi_encoding_map.set(code, glyph_name)
        "MacRomanEncoding" => macroman_encoding_map.set(code, glyph_name)
        "Symbol" => symbol_encoding_map.set(code, glyph_name)
        "ZapfDingbats" => dingbats_encoding_map.set(code, glyph_name)
        _ => ()
      }
    }
  }
  {
    glyph_unicode_map,
    standard_encoding_map,
    winansi_encoding_map,
    macroman_encoding_map,
    symbol_encoding_map,
    dingbats_encoding_map,
  }
}
