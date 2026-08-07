///|
fn pdf_native_source_ref(
  source : @input.InputSource,
  page_no : Int,
  bbox : PdfBBox,
  line_index : Int?,
  font_name : String?,
  font_size : Double,
  reading_order_index? : Int? = None,
) -> @core.SourceRef {
  let source_id = pdf_native_source_id(source)
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source_id),
    Some("pdf"),
    line_index,
    line_index,
  )
  let next = {
    ..base,
    page: Some(page_no),
    bbox: Some({
      x0: bbox.x,
      y0: bbox.y,
      x1: pdf_bbox_right(bbox),
      y1: pdf_bbox_bottom(bbox),
    }),
  }
  next.extra.set("pdf_backend", "root_native_minimal")
  next.extra.set("page_no", page_no.to_string())
  if font_size > 0.0 {
    next.extra.set("font_size", font_size.to_string())
  }
  match font_name {
    Some(value) => next.extra.set("font_name", value)
    None => ()
  }
  match reading_order_index {
    Some(value) => next.extra.set("reading_order_index", value.to_string())
    None => ()
  }
  next
}

///|
fn pdf_effective_font_size(
  text_matrix : PdfNativeGraphicsMatrix,
  current_font_size : Double?,
) -> Double {
  let tf = current_font_size.unwrap_or(0.0)
  let scale = pdf_double_max(
    pdf_abs_double(text_matrix.a),
    pdf_abs_double(text_matrix.d),
  )
  if tf <= 0.0 {
    if scale > 0.0 {
      scale
    } else {
      12.0
    }
  } else if scale > 1.5 {
    scale * tf
  } else {
    tf
  }
}

///|
fn pdf_text_matrix_x_scale(matrix : PdfNativeGraphicsMatrix) -> Double {
  let scale = pdf_abs_double(matrix.a)
  if scale > 0.0 {
    scale
  } else {
    1.0
  }
}

///|
fn pdf_text_matrix_translated(
  matrix : PdfNativeGraphicsMatrix,
  tx : Double,
  ty : Double,
) -> PdfNativeGraphicsMatrix {
  {
    ..matrix,
    e: matrix.e + tx * pdf_text_matrix_x_scale(matrix),
    f: matrix.f + ty * pdf_text_matrix_y_scale(matrix),
  }
}

///|
fn pdf_text_matrix_y_scale(matrix : PdfNativeGraphicsMatrix) -> Double {
  let scale = pdf_abs_double(matrix.d)
  if scale > 0.0 {
    scale
  } else {
    1.0
  }
}

///|
fn pdf_estimate_text_bbox(
  text : String,
  x : Double,
  baseline_y : Double,
  font_size : Double,
) -> PdfBBox {
  let width = pdf_estimate_text_width(text, font_size)
  let height = if font_size > 0.0 { font_size * 1.2 } else { 12.0 }
  let top = if baseline_y - height * 0.85 > 0.0 {
    baseline_y - height * 0.85
  } else {
    baseline_y
  }
  make_pdf_bbox(x, top, width, height)
}

///|
fn pdf_estimate_text_width(text : String, font_size : Double) -> Double {
  let mut width = 0.0
  for ch in text.to_array() {
    width += if ch == ' ' {
      font_size * 0.35
    } else if pdf_is_ascii_punctuation(ch) {
      font_size * 0.4
    } else if ch.to_int() < 128 {
      font_size * 0.62
    } else {
      font_size
    }
  }
  if width <= 0.0 {
    font_size
  } else {
    width
  }
}

///|
fn pdf_prepare_line_text_fragment(
  text : String,
  gap : Double?,
  font_size : Double?,
  preserve_outer_space? : Bool = false,
) -> String {
  let normalized = if preserve_outer_space {
    pdf_normalize_pdf_fragment_text(text)
  } else {
    pdf_normalize_line_fragment_text(text)
  }
  match gap {
    Some(value) => {
      let size = font_size.unwrap_or(12.0)
      if normalized.has_prefix(" ") {
        normalized
      } else if value > size * 0.45 && !pdf_text_prefers_no_gap(normalized) {
        " " + normalized
      } else {
        normalized
      }
    }
    None => normalized
  }
}

///|
fn pdf_normalize_line_fragment_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  let mut saw_non_space = false
  for ch in text.to_array() {
    let is_space = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    if is_space {
      if saw_non_space && !previous_space {
        chars.push(' ')
      }
      previous_space = true
    } else {
      chars.push(ch)
      previous_space = false
      saw_non_space = true
    }
  }
  if chars.length() > 0 && chars[chars.length() - 1] == ' ' {
    ignore(chars.pop())
  }
  String::from_array(chars)
}

///|
fn pdf_normalize_pdf_fragment_text(text : String) -> String {
  let chars : Array[Char] = []
  let mut previous_space = false
  let mut saw_non_space = false
  let mut started_with_space = false
  let mut ended_with_space = false
  for ch in text.to_array() {
    if ch == '\u{0000}' {
      continue
    }
    let is_space = pdf_is_pdf_space(ch)
    if is_space {
      if saw_non_space {
        if !previous_space {
          chars.push(' ')
        }
        ended_with_space = true
      } else {
        started_with_space = true
      }
      previous_space = true
    } else {
      match txt_ligature_expansion(ch) {
        Some(value) => {
          chars.append(value.to_array())
          previous_space = false
          saw_non_space = true
          ended_with_space = false
        }
        None => {
          chars.push(ch)
          previous_space = false
          saw_non_space = true
          ended_with_space = false
        }
      }
    }
  }
  if chars.length() == 0 {
    return ""
  }
  let body = String::from_array(chars)
  let prefix = if started_with_space { " " } else { "" }
  let suffix = if ended_with_space { " " } else { "" }
  prefix + body + suffix
}

///|
fn pdf_text_has_outer_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  pdf_is_pdf_space(chars[0]) || pdf_is_pdf_space(chars[chars.length() - 1])
}

///|
fn pdf_text_outer_space_is_latinish(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let mut has_ascii_word_char = false
  for ch in trimmed.to_array() {
    if pdf_is_cjk_char(ch) {
      return false
    }
    if pdf_is_ascii_digit(ch) ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') {
      has_ascii_word_char = true
    }
  }
  has_ascii_word_char
}

///|
fn pdf_is_pdf_space(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{0008}' ||
  ch == '\u{000C}'
}

///|
fn pdf_text_prefers_no_gap(text : String) -> Bool {
  match text.to_array() {
    [first, ..] =>
      pdf_is_cjk_char(first) ||
      pdf_is_ascii_punctuation(first) ||
      pdf_is_cjk_punctuation(first)
    _ => false
  }
}

///|
fn pdf_actual_text_from_operands(
  operands : Array[PdfNativeContentToken],
) -> String? {
  for token in operands {
    match token {
      Dict(text) =>
        match pdf_extract_literal_string_after(text, "/ActualText") {
          Some(value) if value.trim() != "" =>
            match pdf_decode_actual_text_literal(value) {
              Some(decoded) if decoded.trim() != "" => return Some(decoded)
              _ => return Some(value)
            }
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_decode_actual_text_literal(value : String) -> String? {
  let chars = value.to_array()
  if chars.length() < 4 || (chars.length() - 2) % 2 != 0 {
    return None
  }
  if chars[0] != '\u{00FE}' || chars[1] != '\u{00FF}' {
    return None
  }
  let hex_parts : Array[String] = ["FEFF"]
  let mut index = 2
  while index < chars.length() {
    hex_parts.push(pdf_hex_upper(chars[index].to_int(), 2))
    index += 1
  }
  pdf_hex_to_string(hex_parts.join(""))
}

///|
fn pdf_matrix_from_operands(
  operands : Array[PdfNativeContentToken],
) -> PdfNativeGraphicsMatrix {
  let base = operands.length() - 6
  {
    a: pdf_token_number(operands[base]).unwrap_or(1.0),
    d: pdf_token_number(operands[base + 3]).unwrap_or(1.0),
    e: pdf_token_number(operands[base + 4]).unwrap_or(0.0),
    f: pdf_token_number(operands[base + 5]).unwrap_or(0.0),
  }
}

///|
fn pdf_token_number(token : PdfNativeContentToken) -> Double? {
  match token {
    Number(value) => Some(value)
    _ => None
  }
}

///|
fn pdf_token_name(token : PdfNativeContentToken) -> String? {
  match token {
    Name(value) => Some(value)
    _ => None
  }
}

///|
fn pdf_hex_to_string(hex : String) -> String? {
  if hex == "" {
    return None
  }
  let normalized = hex.trim().to_owned()
  if normalized == "" {
    return None
  }
  if normalized.length() >= 4 && normalized[0:4].to_upper() == "FEFF" {
    match pdf_decode_hex_utf16be(normalized) {
      Some(text) if text != "" => return Some(text)
      _ => ()
    }
  }
  if normalized.length() % 4 == 0 {
    let chars : Array[Char] = []
    let mut index = 0
    while index + 4 <= normalized.length() {
      match pdf_parse_hex_int(normalized[index:index + 4].to_owned()) {
        Some(codepoint) =>
          if pdf_codepoint_is_noncharacter(codepoint) {
            return None
          } else {
            chars.push(Int::unsafe_to_char(codepoint))
          }
        None => ()
      }
      index += 4
    }
    let text = String::from_array(chars)
    if text != "" {
      return Some(text)
    }
  }
  if normalized.length() % 2 == 0 {
    let chars : Array[Char] = []
    let mut index = 0
    while index + 2 <= normalized.length() {
      match pdf_parse_hex_int(normalized[index:index + 2].to_owned()) {
        Some(codepoint) =>
          if pdf_codepoint_is_noncharacter(codepoint) {
            return None
          } else {
            chars.push(Int::unsafe_to_char(codepoint))
          }
        None => ()
      }
      index += 2
    }
    let text = String::from_array(chars)
    if text != "" {
      return Some(text)
    }
  }
  None
}

///|
fn pdf_first_codepoint_from_hex(hex : String) -> Int? {
  if hex.length() % 4 == 0 && hex.length() >= 4 {
    pdf_parse_hex_int(hex[0:4].to_owned())
  } else if hex.length() % 2 == 0 && hex.length() >= 2 {
    pdf_parse_hex_int(hex[0:2].to_owned())
  } else {
    None
  }
}

///|
fn pdf_hex_upper(value : Int, width : Int) -> String {
  let hex = pdf_int_to_hex(value).to_upper()
  if hex.length() >= width {
    hex
  } else {
    "0".repeat(width - hex.length()) + hex
  }
}

///|
fn pdf_int_to_hex(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let rev_digits : Array[Char] = []
  let mut n = value
  while n > 0 {
    let rem = n % 16
    let ch = if rem < 10 {
      Int::unsafe_to_char('0'.to_int() + rem)
    } else {
      Int::unsafe_to_char('A'.to_int() + rem - 10)
    }
    rev_digits.push(ch)
    n = n / 16
  }
  let digits : Array[Char] = []
  let mut index = rev_digits.length()
  while index > 0 {
    index -= 1
    digits.push(rev_digits[index])
  }
  String::from_array(digits)
}

///|
fn pdf_collect_octal_escape(content : String, start : Int) -> (String, Int) {
  let out : Array[Char] = []
  let mut index = start
  let mut count = 0
  while index < content.length() &&
        count < 3 &&
        pdf_is_octal_digit(pdf_char_at(content, index)) {
    out.push(pdf_char_at(content, index))
    index += 1
    count += 1
  }
  (String::from_array(out), index)
}

///|
fn pdf_parse_octal(value : String) -> Int? {
  let mut out = 0
  for ch in value.to_array() {
    if !pdf_is_octal_digit(ch) {
      return None
    }
    out = out * 8 + (ch.to_int() - '0'.to_int())
  }
  Some(out)
}

///|
fn pdf_parse_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  Some(@string.parse_int(trimmed) catch { _ => return None })
}

///|
fn pdf_parse_double(text : String) -> Double? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  Some(@string.parse_double(trimmed) catch { _ => return None })
}

///|
fn pdf_parse_hex_int(hex : String) -> Int? {
  let trimmed = hex.trim().to_upper()
  if trimmed == "" {
    return None
  }
  let mut out = 0
  for ch in trimmed.to_array() {
    let value = if ch >= '0' && ch <= '9' {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'A' && ch <= 'F' {
      10 + ch.to_int() - 'A'.to_int()
    } else {
      return None
    }
    out = out * 16 + value
  }
  Some(out)
}

///|
fn pdf_first_matching_code_width(
  widths : Array[Int],
  remaining_hex_chars : Int,
) -> Int? {
  for width in widths {
    if width > 0 && width * 2 <= remaining_hex_chars {
      return Some(width)
    }
  }
  None
}

///|
fn pdf_split_ascii_whitespace(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut start : Int? = None
  for index in 0..<text.length() {
    if pdf_is_ascii_whitespace_char(pdf_char_at(text, index)) {
      match start {
        Some(value) if index > value => out.push(text[value:index].to_owned())
        _ => ()
      }
      start = None
    } else if start is None {
      start = Some(index)
    }
  }
  match start {
    Some(value) if value < text.length() => out.push(text[value:].to_owned())
    _ => ()
  }
  out
}

///|
fn pdf_byte_string(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes.to_array() {
    chars.push(Int::unsafe_to_char(byte.to_int()))
  }
  String::from_array(chars)
}

///|
fn pdf_decode_big_endian_int(bytes : Bytes, start : Int, width : Int) -> Int {
  if width <= 0 {
    return 0
  }
  let mut out = 0
  let mut index = 0
  while index < width && start + index < bytes.length() {
    out = out * 256 + pdf_byte_at(bytes, start + index)
    index += 1
  }
  out
}

///|
fn pdf_ascii_bytes(text : String) -> Bytes {
  @utf8.encode(text)
}
