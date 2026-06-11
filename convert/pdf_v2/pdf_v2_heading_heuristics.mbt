///|
fn pdf_v2_should_emit_minimal_heading(
  text : String,
  fragment : PdfV2FactFragment,
  paragraph_line_count : Int,
  next_text : String?,
  options : PdfV2ProductBridgeOptions,
) -> Bool {
  if !options.emit_minimal_headings ||
    fragment.kind != PdfV2FactFragmentKind::PlainText {
    return false
  }
  if paragraph_line_count > 1 {
    return false
  }
  let t = pdf_v2_heading_normalize(text)
  if !pdf_v2_heading_basic_shape_ok(t) {
    return false
  }
  if !pdf_v2_heading_next_looks_like_body(next_text) {
    return false
  }
  pdf_v2_heading_has_title_shape(t)
}

///|
fn pdf_v2_heading_normalize(text : String) -> String {
  pdf_v2_normalize_paragraph_text(text).trim().to_owned()
}

///|
fn pdf_v2_heading_basic_shape_ok(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if t.length() < 4 || t.length() > 72 {
    return false
  }
  if t.contains("\n") || t.contains("<br") || t.contains("://") {
    return false
  }
  if pdf_v2_heading_ends_sentence(t) ||
    t.has_suffix(":") ||
    t.has_suffix("：") ||
    t.has_suffix(",") ||
    t.has_suffix("，") ||
    t.has_suffix(";") ||
    t.has_suffix("；") {
    return false
  }
  if pdf_v2_is_page_number_like_noise(t) ||
    pdf_v2_heading_looks_like_caption(t) ||
    pdf_v2_heading_looks_like_bullet_or_list_item(t) ||
    pdf_v2_heading_looks_like_complete_statement(t) ||
    pdf_v2_heading_looks_like_intro_phrase(t) {
    return false
  }
  true
}

///|
fn pdf_v2_heading_has_title_shape(text : String) -> Bool {
  pdf_v2_heading_looks_like_chapter_title(text) ||
  pdf_v2_heading_looks_like_numbered_section(text) ||
  pdf_v2_heading_looks_like_english_title(text) ||
  pdf_v2_heading_looks_like_cjk_title(text)
}

///|
fn pdf_v2_heading_next_looks_like_body(next_text : String?) -> Bool {
  match next_text {
    None => false
    Some(value) => {
      let t = pdf_v2_heading_normalize(value)
      if t == "" {
        return false
      }
      if pdf_v2_heading_looks_like_bullet_or_list_item(t) {
        return true
      }
      if pdf_v2_heading_ends_sentence(t) {
        return true
      }
      if t.length() >= 24 || pdf_v2_heading_word_count(t) >= 5 {
        return true
      }
      false
    }
  }
}

///|
fn pdf_v2_heading_looks_like_chapter_title(text : String) -> Bool {
  if !text.has_prefix("第") {
    return false
  }
  let n = text.to_array().length()
  n >= 4 && n <= 30 && !pdf_v2_heading_contains_sentence_punct(text)
}

///|
fn pdf_v2_heading_looks_like_numbered_section(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 3 || chars.length() > 48 {
    return false
  }
  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
    saw_digit = true
    i = i + 1
  }
  if !saw_digit || i >= chars.length() {
    return false
  }
  if chars[i] != '.' {
    return false
  }
  i = i + 1
  let mut saw_section_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_is_ascii_digit(ch) {
      saw_section_digit = true
      i = i + 1
    } else if ch == '.' {
      i = i + 1
    } else {
      break
    }
  }
  if !saw_section_digit {
    return false
  }
  if i >= chars.length() {
    return false
  }
  let tail = String::from_array(chars[i:].to_owned()).trim().to_owned()
  tail != "" &&
  tail.length() <= 32 &&
  !pdf_v2_heading_ends_sentence(tail) &&
  !pdf_v2_heading_looks_like_numbered_body_sentence(text)
}

///|
fn pdf_v2_heading_looks_like_english_title(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() < 2 || words.length() > 6 {
    return false
  }
  let first = pdf_v2_heading_ascii_lower(
    pdf_v2_heading_strip_edge_punct(words[0]),
  )
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }
  let mut latin_words = 0
  let mut capitalized_words = 0
  let mut has_title_keyword = false
  let mut has_connector = false
  for word in words {
    let stripped = pdf_v2_heading_strip_edge_punct(word)
    let lower = pdf_v2_heading_ascii_lower(stripped)
    if lower == "vs" || lower == "and" || lower == "or" {
      has_connector = true
    }
    if lower == "report" ||
      lower == "pipeline" ||
      lower == "test" ||
      lower == "sample" ||
      lower == "heading" ||
      lower == "introduction" ||
      lower == "method" ||
      lower == "methods" ||
      lower == "summary" ||
      lower == "background" ||
      lower == "details" ||
      lower == "conclusion" {
      has_title_keyword = true
    }
    if pdf_v2_heading_starts_latin(stripped) {
      latin_words = latin_words + 1
      match pdf_v2_first_char(stripped) {
        Some(ch) =>
          if ch >= 'A' && ch <= 'Z' {
            capitalized_words = capitalized_words + 1
          }
        None => ()
      }
    }
  }
  latin_words >= 2 &&
  capitalized_words >= 2 &&
  (has_title_keyword || has_connector || capitalized_words == latin_words)
}

///|
fn pdf_v2_heading_looks_like_cjk_title(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 || chars.length() > 16 {
    return false
  }
  if text.contains(" ") || pdf_v2_heading_contains_sentence_punct(text) {
    return false
  }
  if text.has_prefix("本") ||
    text.has_prefix("该") ||
    text.has_prefix("此") ||
    text.has_prefix("这") {
    return false
  }
  let mut cjkish = 0
  for ch in chars {
    if pdf_v2_is_cjk(ch) {
      cjkish = cjkish + 1
    } else if !pdf_v2_is_ascii_digit(ch) && ch != '.' {
      return false
    }
  }
  cjkish >= 4 && pdf_v2_heading_looks_like_common_cjk_section_label(text)
}

///|
fn pdf_v2_heading_looks_like_common_cjk_section_label(text : String) -> Bool {
  text == "研究内容" ||
  text == "技术路线" ||
  text == "研究方法" ||
  text == "研究目标" ||
  text == "研究背景" ||
  text == "项目概述" ||
  text == "系统概述" ||
  text == "方案概述" ||
  text == "总结" ||
  text == "结论" ||
  text == "下一节"
}

///|
fn pdf_v2_heading_ends_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_v2_heading_contains_sentence_punct(text : String) -> Bool {
  text.contains("。") ||
  text.contains("！") ||
  text.contains("？") ||
  text.contains("；") ||
  text.contains(";")
}

///|
fn pdf_v2_heading_looks_like_caption(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("table ") ||
  lower.has_prefix("chart ") ||
  lower.has_prefix("image ") ||
  text.has_prefix("图") ||
  text.has_prefix("表")
}

///|
fn pdf_v2_heading_looks_like_bullet_or_list_item(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.has_prefix("- ") ||
    t.has_prefix("* ") ||
    t.has_prefix("• ") ||
    t.has_prefix("· ") {
    return true
  }
  let chars = t.to_array()
  if chars.length() >= 3 && pdf_v2_is_ascii_digit(chars[0]) {
    let mut i = 0
    while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
      i = i + 1
    }
    if i < chars.length() && (chars[i] == ')' || chars[i] == '）') {
      return true
    }
  }
  false
}

///|
fn pdf_v2_heading_looks_like_numbered_body_sentence(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.contains(" this ") ||
  lower.contains(" is ") ||
  lower.contains(" inside ") ||
  lower.contains(" should ") ||
  lower.contains(" paragraph ")
}

///|
fn pdf_v2_heading_looks_like_intro_phrase(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower == "in conclusion," ||
  lower == "in conclusion" ||
  lower == "key points:" ||
  lower == "key points" ||
  lower == "as follows" ||
  text.has_suffix("如下。") ||
  text.has_suffix("如下")
}

///|
fn pdf_v2_heading_looks_like_complete_statement(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() >= 8 {
    return true
  }
  let lower = pdf_v2_heading_ascii_lower(text)
  if lower.contains(" actually ") ||
    lower.contains(" should ") ||
    lower.contains(" remain ") ||
    lower.contains(" across ") ||
    lower.contains(" method") {
    return true
  }
  false
}

///|
fn pdf_v2_heading_words(text : String) -> Array[String] {
  let out : Array[String] = []
  for raw in text.split(" ") {
    let word = raw.trim().to_owned()
    if word != "" {
      out.push(word)
    }
  }
  out
}

///|
fn pdf_v2_heading_word_count(text : String) -> Int {
  pdf_v2_heading_words(text).length()
}

///|
fn pdf_v2_heading_starts_latin(text : String) -> Bool {
  match pdf_v2_first_char(text) {
    Some(ch) => (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
    None => false
  }
}

///|
fn pdf_v2_heading_strip_edge_punct(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 {
    return ""
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end && pdf_v2_heading_edge_punct(chars[start]) {
    start = start + 1
  }
  while end > start && pdf_v2_heading_edge_punct(chars[end - 1]) {
    end = end - 1
  }
  String::from_array(chars[start:end].to_owned())
}

///|
fn pdf_v2_heading_edge_punct(ch : Char) -> Bool {
  ch == '"' ||
  ch == '\'' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == ',' ||
  ch == '.' ||
  ch == ':' ||
  ch == ';'
}

///|
fn pdf_v2_heading_ascii_lower(text : String) -> String {
  text.to_lower()
}
