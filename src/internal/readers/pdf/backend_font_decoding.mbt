///|
fn pdf_find_bytes(bytes : Bytes, needle : Bytes, start : Int) -> Int? {
  let haystack = bytes.to_array()
  let target = needle.to_array()
  if target.length() == 0 {
    return Some(start)
  }
  let mut index = start
  while index + target.length() <= haystack.length() {
    let mut matched = true
    for offset in 0..<target.length() {
      if haystack[index + offset] != target[offset] {
        matched = false
        break
      }
    }
    if matched {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn pdf_bytes_have_prefix(bytes : Bytes, start : Int, prefix : String) -> Bool {
  let needle = pdf_ascii_bytes(prefix)
  if start < 0 || start + needle.length() > bytes.length() {
    return false
  }
  let target = needle.to_array()
  for offset in 0..<target.length() {
    if pdf_byte_at(bytes, start + offset) != target[offset].to_int() {
      return false
    }
  }
  true
}

///|
fn pdf_byte_at(bytes : Bytes, index : Int) -> Int {
  bytes.unsafe_get(index).to_int()
}

///|
fn pdf_is_ascii_whitespace_byte(byte : Int) -> Bool {
  byte == ' '.to_int() ||
  byte == '\t'.to_int() ||
  byte == '\n'.to_int() ||
  byte == '\r'.to_int() ||
  byte == '\u{000C}'.to_int()
}

///|
fn pdf_skip_ascii_whitespace_and_comments_bytes(
  bytes : Bytes,
  start : Int,
) -> Int {
  let mut index = start
  while index < bytes.length() {
    let byte = pdf_byte_at(bytes, index)
    if pdf_is_ascii_whitespace_byte(byte) {
      index += 1
      continue
    }
    if byte == '%'.to_int() {
      index += 1
      while index < bytes.length() {
        let comment_byte = pdf_byte_at(bytes, index)
        if comment_byte == '\n'.to_int() || comment_byte == '\r'.to_int() {
          break
        }
        index += 1
      }
      continue
    }
    break
  }
  index
}

///|
fn pdf_read_ascii_line(bytes : Bytes, start : Int) -> (String, Int) {
  let mut index = start
  while index < bytes.length() {
    let byte = pdf_byte_at(bytes, index)
    if byte == '\n'.to_int() || byte == '\r'.to_int() {
      break
    }
    index += 1
  }
  let line = pdf_byte_string(bytes[start:index].to_owned())
  if index < bytes.length() {
    let byte = pdf_byte_at(bytes, index)
    if byte == '\r'.to_int() {
      index += 1
      if index < bytes.length() && pdf_byte_at(bytes, index) == '\n'.to_int() {
        index += 1
      }
    } else if byte == '\n'.to_int() {
      index += 1
    }
  }
  (line, index)
}

///|
fn pdf_bytes_match_except_suffix(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() + 1 {
    return false
  }
  let left_arr = left.to_array()
  let right_arr = right.to_array()
  for i in 0..<right_arr.length() {
    if left_arr[i] != right_arr[i] {
      return false
    }
  }
  true
}

///|
fn pdf_stream_suffix_is_single_eol(
  declared_bytes : Bytes,
  trimmed_bytes : Bytes,
) -> Bool {
  if declared_bytes.length() != trimmed_bytes.length() + 1 {
    return false
  }
  let suffix = pdf_byte_at(declared_bytes, declared_bytes.length() - 1)
  suffix == '\n'.to_int() || suffix == '\r'.to_int()
}

///|
fn pdf_previous_line_start_bytes(bytes : Bytes, index : Int) -> Int {
  let arr = bytes.to_array()
  let mut cursor = index
  while cursor > 0 {
    let byte = arr[cursor - 1].to_int()
    if byte == '\n'.to_int() || byte == '\r'.to_int() {
      return cursor
    }
    cursor -= 1
  }
  0
}

///|
fn pdf_skip_object_header_whitespace_bytes(bytes : Bytes, start : Int) -> Int {
  let arr = bytes.to_array()
  let mut index = start
  while index < arr.length() {
    let byte = arr[index].to_int()
    if byte == ' '.to_int() ||
      byte == '\t'.to_int() ||
      byte == '\n'.to_int() ||
      byte == '\r'.to_int() ||
      byte == '\u{000C}'.to_int() {
      index += 1
    } else {
      break
    }
  }
  index
}

///|
fn pdf_find_substring(text : String, needle : String, start : Int) -> Int? {
  if start < 0 || start > text.length() {
    return None
  }
  match text[start:].find(needle) {
    Some(rel) => Some(start + rel)
    None => None
  }
}

///|
fn pdf_find_last_substring(text : String, needle : String) -> Int? {
  if needle == "" || needle.length() > text.length() {
    return None
  }
  let mut index = text.length() - needle.length()
  while true {
    if text[index:index + needle.length()].to_owned() == needle {
      return Some(index)
    }
    if index == 0 {
      break
    }
    index -= 1
  }
  None
}

///|
fn pdf_parse_dict_text_at(text : String, start : Int) -> String? {
  if start < 0 || start + 1 >= text.length() {
    return None
  }
  if pdf_char_at(text, start) != '<' || pdf_char_at(text, start + 1) != '<' {
    return None
  }
  let parsed = pdf_parse_dict_token(text, start)
  if parsed.0.has_prefix("<<") && parsed.0.has_suffix(">>") {
    Some(parsed.0)
  } else {
    None
  }
}

///|
fn pdf_identity_matrix() -> PdfNativeGraphicsMatrix {
  { a: 1.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
fn pdf_line_merge_tolerance(
  current : Array[PdfNativeTextFragment],
  next : PdfNativeTextFragment,
) -> Double {
  let mut size = next.font_size.unwrap_or(12.0)
  for fragment in current {
    let current_size = fragment.font_size.unwrap_or(12.0)
    if current_size < size {
      size = current_size
    }
  }
  pdf_double_max(2.0, size * 0.45)
}

///|
fn pdf_normalize_pdf_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut previous_space = false
  for ch in text.to_array() {
    if ch == '\u{0000}' {
      continue
    }
    let is_control_space = ch == '\r' ||
      ch == '\n' ||
      ch == '\t' ||
      ch == '\u{0008}' ||
      ch == '\u{000C}'
    if is_control_space {
      if !previous_space {
        out.write_char(' ')
      }
      previous_space = true
    } else {
      match txt_ligature_expansion(ch) {
        Some(value) => {
          out.write_string(value)
          previous_space = false
        }
        None => {
          out.write_char(ch)
          previous_space = ch == ' '
        }
      }
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_fragment_visual_compare(
  left : PdfNativeTextFragment,
  right : PdfNativeTextFragment,
) -> Int {
  if left.vertical_writing || right.vertical_writing {
    pdf_fragment_vertical_compare(left, right)
  } else if left.x < right.x {
    -1
  } else if left.x > right.x {
    1
  } else {
    0
  }
}

///|
fn pdf_fragment_vertical_compare(
  left : PdfNativeTextFragment,
  right : PdfNativeTextFragment,
) -> Int {
  let x_gap = pdf_abs_double(left.x - right.x)
  if x_gap > 2.0 {
    if left.x > right.x {
      -1
    } else {
      1
    }
  } else if left.y > right.y {
    -1
  } else if left.y < right.y {
    1
  } else {
    0
  }
}

///|
fn pdf_fragment_reading_order_compare(
  left : PdfNativeTextFragment,
  right : PdfNativeTextFragment,
) -> Int {
  if left.vertical_writing || right.vertical_writing {
    pdf_fragment_vertical_compare(left, right)
  } else {
    let y_gap = pdf_abs_double(left.y - right.y)
    if y_gap > 2.0 {
      if left.y > right.y {
        -1
      } else {
        1
      }
    } else {
      pdf_fragment_visual_compare(left, right)
    }
  }
}

///|
fn pdf_font_is_identity_v(info : PdfNativeFontInfo) -> Bool {
  info.encoding_name == Some("Identity-V")
}

///|
fn pdf_font_encoding_name_has_prefix(
  info : PdfNativeFontInfo,
  prefix : String,
) -> Bool {
  match info.encoding_name {
    Some(name) => name.has_prefix(prefix)
    None => false
  }
}

///|
fn pdf_font_encoding_name_has_suffix(
  info : PdfNativeFontInfo,
  suffix : String,
) -> Bool {
  match info.encoding_name {
    Some(name) => name.has_suffix(suffix)
    None => false
  }
}

///|
fn pdf_font_has_predefined_cid_encoding(info : PdfNativeFontInfo) -> Bool {
  match info.predefined_cmap {
    Some(_) => true
    None =>
      pdf_font_is_identity_h(info) ||
      pdf_font_is_identity_v(info) ||
      info.encoding_name == Some("EUC-H") ||
      info.encoding_name == Some("EUC-V") ||
      pdf_font_encoding_name_has_prefix(info, "UniJIS-") ||
      pdf_font_encoding_name_has_prefix(info, "UniCNS-") ||
      pdf_font_encoding_name_has_prefix(info, "UniKS-") ||
      pdf_font_encoding_name_has_prefix(info, "GB-EUC-") ||
      pdf_font_encoding_name_has_prefix(info, "GBK-EUC-") ||
      pdf_font_encoding_name_has_prefix(info, "ETen-B5-") ||
      pdf_font_encoding_name_has_prefix(info, "90ms-RKSJ-") ||
      pdf_font_encoding_name_has_prefix(info, "KSC-EUC-")
  }
}

///|
fn pdf_font_uses_vertical_writing(info : PdfNativeFontInfo) -> Bool {
  pdf_font_is_identity_v(info) ||
  (
    pdf_font_has_predefined_cid_encoding(info) &&
    pdf_font_encoding_name_has_suffix(info, "-V")
  )
}

///|
fn pdf_font_has_cjk_encoding_evidence(info : PdfNativeFontInfo) -> Bool {
  pdf_font_has_predefined_cid_encoding(info)
}

///|
fn pdf_font_should_fail_closed_after_tounicode(
  info : PdfNativeFontInfo,
) -> Bool {
  info.has_tounicode &&
  info.unicode_map.length() == 0 &&
  (
    pdf_font_is_identity_h(info) ||
    pdf_font_is_identity_v(info) ||
    info.descendant_subtype == Some("CIDFontType0") ||
    info.descendant_subtype == Some("CIDFontType2") ||
    pdf_font_has_predefined_cid_encoding(info)
  )
}

///|
fn pdf_font_uses_code_unit_decode(info : PdfNativeFontInfo) -> Bool {
  info.has_tounicode ||
  info.tounicode_builtin_name is Some(_) ||
  info.unicode_map.length() > 0 ||
  info.cid_collection_cmap is Some(_) ||
  info.embedded_font_program is Some(_) ||
  info.predefined_cmap is Some(_) ||
  pdf_font_has_predefined_cid_encoding(info) ||
  pdf_font_has_multibyte_widths(info.code_hex_widths)
}

///|
fn pdf_font_decode_widths(info : PdfNativeFontInfo) -> Array[Int] {
  if info.code_hex_widths.length() > 0 {
    info.code_hex_widths
  } else if pdf_font_has_predefined_cid_encoding(info) {
    match info.predefined_cmap {
      Some(cmap) => pdf_predefined_code_widths_from_mask(cmap.code_width_mask)
      None => [2]
    }
  } else if info.embedded_font_program is Some(_) &&
    (
      info.descendant_subtype == Some("CIDFontType0") ||
      info.descendant_subtype == Some("CIDFontType2") ||
      pdf_font_is_identity_h(info) ||
      pdf_font_is_identity_v(info)
    ) {
    [2]
  } else {
    [1]
  }
}

///|
fn pdf_font_may_use_raw_cjk_decode(info : PdfNativeFontInfo) -> Bool {
  if info.has_tounicode {
    return false
  }
  if pdf_font_is_identity_h(info) || pdf_font_is_identity_v(info) {
    return false
  }
  pdf_font_has_cjk_name_evidence(info) ||
  pdf_font_has_cjk_encoding_evidence(info)
}

///|
fn pdf_font_has_cjk_name_evidence(info : PdfNativeFontInfo) -> Bool {
  let normalized = match info.normalized_base_font {
    Some(value) => value
    None => return pdf_font_has_cjk_encoding_evidence(info)
  }
  if pdf_string_contains_cjk_char(normalized) {
    return true
  }
  normalized.contains("gb2312") ||
  normalized.contains("gbk") ||
  normalized.contains("big5") ||
  normalized.contains("eten") ||
  normalized.contains("sjis") ||
  normalized.contains("rksj") ||
  normalized.contains("jis") ||
  normalized.contains("euc") ||
  normalized.contains("gothic") ||
  normalized.contains("mincho") ||
  normalized.contains("cns") ||
  normalized.contains("ksc") ||
  normalized.contains("korean") ||
  normalized.contains("japan") ||
  normalized.contains("cjk") ||
  normalized.contains("song") ||
  normalized.contains("fang") ||
  normalized.contains("hei") ||
  normalized.contains("kai") ||
  normalized.contains("ming") ||
  normalized.contains("sim")
}

///|
fn pdf_font_prefers_raw_gb_family_decode(info : PdfNativeFontInfo) -> Bool {
  if pdf_font_encoding_name_has_prefix(info, "GB-EUC-") ||
    pdf_font_encoding_name_has_prefix(info, "GBK-EUC-") {
    return true
  }
  let normalized = match info.normalized_base_font {
    Some(value) => value
    None => return false
  }
  normalized.contains("gb2312") ||
  normalized.contains("gbk") ||
  normalized.contains("song") ||
  normalized.contains("fang") ||
  normalized.contains("hei") ||
  normalized.contains("kai") ||
  normalized.contains("ming") ||
  normalized.contains("sim") ||
  normalized.contains("宋") ||
  normalized.contains("体") ||
  normalized.contains("仿") ||
  normalized.contains("黑") ||
  normalized.contains("楷") ||
  normalized.contains("明")
}

///|
fn pdf_font_prefers_raw_euc_jp_decode(info : PdfNativeFontInfo) -> Bool {
  if info.encoding_name == Some("EUC-H") || info.encoding_name == Some("EUC-V") {
    return true
  }
  let normalized = match info.normalized_base_font {
    Some(value) => value
    None => return false
  }
  normalized.contains("gothic") ||
  normalized.contains("mincho") ||
  normalized.contains("jis") ||
  normalized.contains("japan")
}

///|
fn pdf_font_prefers_raw_shift_jis_decode(info : PdfNativeFontInfo) -> Bool {
  if pdf_font_encoding_name_has_prefix(info, "90ms-RKSJ-") ||
    pdf_font_encoding_name_has_prefix(info, "83pv-RKSJ-") {
    return true
  }
  let normalized = match info.normalized_base_font {
    Some(value) => value
    None => return false
  }
  normalized.contains("sjis") ||
  normalized.contains("rksj") ||
  normalized.contains("gothic") ||
  normalized.contains("mincho") ||
  normalized.contains("japan")
}

///|
fn pdf_font_raw_cjk_encoding_kind(
  info : PdfNativeFontInfo,
) -> PdfRawCjkEncodingKind? {
  if pdf_font_prefers_raw_gb_family_decode(info) {
    Some(Gb2312)
  } else if info.encoding_name == Some("EUC-H") ||
    info.encoding_name == Some("EUC-V") {
    Some(EucJp)
  } else if pdf_font_encoding_name_has_prefix(info, "90ms-RKSJ-") ||
    pdf_font_encoding_name_has_prefix(info, "83pv-RKSJ-") {
    Some(ShiftJis)
  } else if pdf_font_prefers_raw_shift_jis_decode(info) {
    Some(ShiftJis)
  } else if pdf_font_prefers_raw_euc_jp_decode(info) {
    Some(EucJp)
  } else {
    None
  }
}

///|
fn pdf_font_is_winansi(info : PdfNativeFontInfo) -> Bool {
  info.encoding_name == Some("WinAnsiEncoding")
}

///|
fn pdf_decode_raw_cjk_bytes_for_font(
  bytes : Array[Int],
  info : PdfNativeFontInfo,
) -> String? {
  let encoding_kind = match pdf_font_raw_cjk_encoding_kind(info) {
    Some(value) => value
    None => return None
  }
  if !pdf_raw_cjk_bytes_need_decode(bytes, encoding_kind) {
    return None
  }
  let decoded = pdf_decode_raw_cjk_bytes(bytes, encoding_kind)
  let strong_cjk_evidence = pdf_font_has_cjk_name_evidence(info)
  if pdf_raw_cjk_decode_result_is_confident(decoded) ||
    (
      strong_cjk_evidence &&
      pdf_raw_cjk_decode_result_is_safe_gb2312_token(decoded)
    ) {
    Some(decoded.text)
  } else {
    None
  }
}

///|
fn pdf_raw_cjk_decode_result_is_safe_gb2312_token(
  result : PdfRawCjkDecodeResult,
) -> Bool {
  result.invalid_byte_count == 0 &&
  result.has_high_bytes &&
  result.decoded_two_byte_count > 0 &&
  result.text != ""
}

///|
fn pdf_string_from_codepoints(codepoints : Array[Int]) -> String {
  let chars : Array[Char] = []
  for codepoint in codepoints {
    chars.push(Int::unsafe_to_char(codepoint))
  }
  String::from_array(chars)
}

///|
fn pdf_normalized_pdf_font_name(name : String?) -> String? {
  let raw = match name {
    Some(value) => value.trim().to_owned()
    None => return None
  }
  if raw == "" {
    return None
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index < raw.length() {
    let ch = pdf_char_at(raw, index)
    if ch == '#' && index + 2 < raw.length() {
      match pdf_parse_hex_int(raw[index + 1:index + 3].to_owned()) {
        Some(code) => {
          bytes.push(code)
          index += 3
          continue
        }
        None => ()
      }
    }
    bytes.push(ch.to_int())
    index += 1
  }
  let decoded = pdf_decode_gb2312_first_bytes(bytes)
  if pdf_raw_cjk_decode_result_is_confident_gb2312(decoded) {
    Some(decoded.text.to_lower())
  } else {
    let chars : Array[Char] = []
    for byte in bytes {
      chars.push(Int::unsafe_to_char(byte))
    }
    Some(String::from_array(chars).to_lower())
  }
}

///|
fn pdf_is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn pdf_is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0x3040 && code <= 0x30FF) ||
  (code >= 0xAC00 && code <= 0xD7AF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn pdf_native_source_id(source : @input.InputSource) -> String {
  match @input.input_path(source) {
    Some(path) => path
    None => source.source_name
  }
}

///|
fn pdf_native_line_reading_order_compare(
  left : PdfNativeTextLine,
  right : PdfNativeTextLine,
) -> Int {
  match (left.reading_order_index, right.reading_order_index) {
    (Some(a), Some(b)) =>
      if a < b {
        -1
      } else if a > b {
        1
      } else {
        pdf_native_line_bbox_compare(left, right)
      }
    _ => pdf_native_line_bbox_compare(left, right)
  }
}

///|
fn pdf_native_line_bbox_compare(
  left : PdfNativeTextLine,
  right : PdfNativeTextLine,
) -> Int {
  let y_gap = pdf_abs_double(left.bbox.y - right.bbox.y)
  if y_gap > 2.0 {
    if left.bbox.y < right.bbox.y {
      -1
    } else {
      1
    }
  } else if left.bbox.x < right.bbox.x {
    -1
  } else if left.bbox.x > right.bbox.x {
    1
  } else {
    0
  }
}

///|
fn pdf_native_lines_bbox(lines : Array[PdfNativeTextLine]) -> PdfBBox {
  let mut bbox = make_pdf_bbox(0.0, 0.0, 0.0, 0.0)
  for line in lines {
    bbox = if pdf_bbox_is_empty(bbox) {
      line.bbox
    } else {
      pdf_union_bbox(bbox, line.bbox)
    }
  }
  bbox
}

///|
fn pdf_font_has_multibyte_widths(widths : Array[Int]) -> Bool {
  for width in widths {
    if width > 1 {
      return true
    }
  }
  false
}

///|
fn pdf_font_is_identity_h(info : PdfNativeFontInfo) -> Bool {
  info.encoding_name == Some("Identity-H")
}

///|
fn pdf_decode_font_code_fallback(
  key : String,
  info : PdfNativeFontInfo,
) -> String? {
  if pdf_font_is_winansi(info) &&
    (key.length() == 2 || (key.length() == 4 && key.has_prefix("00"))) {
    let byte_hex = if key.length() == 4 { key[2:].to_owned() } else { key }
    match pdf_parse_hex_int(byte_hex) {
      Some(byte) => return Some(pdf_decode_winansi_bytes([byte]))
      None => ()
    }
  }
  if pdf_font_prefers_raw_gb_family_decode(info) {
    match pdf_hex_byte_values(key) {
      Some(bytes) =>
        for byte in bytes {
          if byte > 0x7F {
            return None
          }
        }
      None => ()
    }
  }
  let decoded = match pdf_hex_to_string(key) {
    Some(value) => value
    None => return None
  }
  if !pdf_text_has_disallowed_control(decoded) {
    return Some(decoded)
  }
  if pdf_font_is_identity_h(info) && key == "0001" {
    return Some(" ")
  }
  None
}

///|
fn pdf_decode_raw_cjk_hex_fallback(
  hex : String,
  info : PdfNativeFontInfo,
) -> String? {
  if !pdf_font_may_use_raw_cjk_decode(info) {
    return None
  }
  let bytes = match pdf_hex_byte_values(hex) {
    Some(value) => value
    None => return None
  }
  pdf_decode_raw_cjk_bytes_for_font(bytes, info)
}

///|
fn pdf_text_has_disallowed_control(text : String) -> Bool {
  for ch in text.to_array() {
    let code = ch.to_int()
    if code == 0x0000 {
      return true
    }
    if code < 0x0020 &&
      ch != '\t' &&
      ch != '\n' &&
      ch != '\r' &&
      ch != '\u{0008}' &&
      ch != '\u{000C}' {
      return true
    }
  }
  false
}

///|
fn pdf_is_usable_tounicode_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text.to_array() {
    if pdf_codepoint_is_noncharacter(ch.to_int()) {
      return false
    }
  }
  true
}

///|
fn pdf_codepoint_is_noncharacter(code : Int) -> Bool {
  (code >= 0xFDD0 && code <= 0xFDEF) || (code & 0xFFFE) == 0xFFFE
}

///|
fn pdf_hex_byte_values(hex : String) -> Array[Int]? {
  let normalized = hex.trim().to_upper()
  if normalized == "" || normalized.length() % 2 != 0 {
    return None
  }
  let bytes : Array[Int] = []
  let mut index = 0
  while index + 2 <= normalized.length() {
    match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
      Some(value) => bytes.push(value)
      None => return None
    }
    index += 2
  }
  Some(bytes)
}

///|
fn pdf_string_contains_cjk_char(text : String) -> Bool {
  for ch in text.to_array() {
    if pdf_is_cjk_char(ch) {
      return true
    }
  }
  false
}

///|
fn pdf_native_count_line_spans(lines : Array[PdfNativeTextLine]) -> Int {
  let mut count = 0
  for line in lines {
    count += line.spans.length()
  }
  count
}

///|
fn pdf_native_page_line_count(page : PdfNativePage) -> Int {
  let mut count = 0
  for block in page.text_blocks {
    count += block.lines.length()
  }
  count
}

///|
fn pdf_native_page_span_count(page : PdfNativePage) -> Int {
  let mut count = 0
  for block in page.text_blocks {
    for line in block.lines {
      count += line.spans.length()
    }
  }
  count
}

///|
fn pdf_is_ascii_whitespace_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\u{000C}'
}

///|
fn pdf_is_token_delimiter(ch : Char) -> Bool {
  ch == '(' ||
  ch == ')' ||
  ch == '<' ||
  ch == '>' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '/' ||
  ch == '%'
}

///|
fn pdf_is_octal_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '7'
}

///|
fn pdf_is_ascii_punctuation(ch : Char) -> Bool {
  (ch >= '!' && ch <= '/') ||
  (ch >= ':' && ch <= '@') ||
  (ch >= '[' && ch <= '`') ||
  (ch >= '{' && ch <= '~')
}

///|
fn pdf_is_cjk_punctuation(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x3000 && code <= 0x303F) ||
  (code >= 0xFF00 && code <= 0xFF0F) ||
  (code >= 0xFF1A && code <= 0xFF20) ||
  (code >= 0xFF3B && code <= 0xFF40) ||
  (code >= 0xFF5B && code <= 0xFF65)
}

///|
fn pdf_abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn pdf_char_at(text : String, index : Int) -> Char {
  text.unsafe_get(index).unsafe_to_char()
}
