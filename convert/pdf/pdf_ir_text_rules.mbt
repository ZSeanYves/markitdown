///|
/// Final PDF IR text-shape rules.
///
/// These helpers are deliberately package-local: they are the final guardrail
/// between PDF block classification and unified IR emission.
fn try_parse_bullet_list_item_for_ir(text : String) -> String? {
  let t = text.trim().to_owned()
  if t == "" {
    return None
  }

  if t.has_prefix("•") {
    let body = t[1:].trim().to_owned()
    if body != "" {
      return Some(body)
    }
  }

  if t.has_prefix("- ") || t.has_prefix("* ") {
    let body = t[2:].trim().to_owned()
    if body != "" && !looks_like_separator_line_for_ir(body) {
      return Some(body)
    }
  }

  None
}

///|
fn try_split_run_in_numbered_heading_for_ir(
  text : String,
) -> (String, String, Int)? {
  let t = text.trim().to_owned()
  if t == "" {
    return None
  }

  let arr = t.to_array()
  if arr.is_empty() || !(arr[0] >= '0' && arr[0] <= '9') {
    return None
  }

  let heading_end = find_run_in_heading_end_for_ir(arr)
  if heading_end <= 0 || heading_end >= arr.length() {
    return None
  }

  let heading = t[:heading_end].trim().to_owned()
  let body = t[heading_end:].trim().to_owned()
  if heading == "" || body == "" {
    return None
  }

  if !looks_like_run_in_heading_text_for_ir(heading, body) {
    return None
  }

  let depth = infer_section_depth_for_ir(heading)
  Some((heading, body, if depth > 0 { depth } else { 1 }))
}

///|
fn find_run_in_heading_end_for_ir(chars : Array[Char]) -> Int {
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '.' || ch == '。' || ch == ':' || ch == '：' {
      return i + 1
    }
    i += 1
  }
  -1
}

///|
fn looks_like_run_in_heading_text_for_ir(
  heading : String,
  body : String,
) -> Bool {
  let h = heading.trim().to_owned()
  let b = body.trim().to_owned()
  if h == "" || b == "" {
    return false
  }

  if is_probable_page_number_for_ir(h) ||
    looks_like_list_item_sentence_for_ir(h) ||
    looks_like_figure_or_table_caption_for_ir(h) ||
    looks_like_intro_phrase_for_ir(h) {
    return false
  }

  if infer_section_depth_for_ir(h) <= 0 {
    return false
  }

  if !starts_with_upper_ascii_or_digit_section_for_ir(h) {
    return false
  }

  if !body_looks_like_paragraph_start_for_ir(b) {
    return false
  }

  let words = heading_word_count_for_ir(h)
  words >= 2 && words <= 8
}

///|
fn starts_with_upper_ascii_or_digit_section_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let arr = t.to_array()
  let mut i = 0
  while i < arr.length() && arr[i] >= '0' && arr[i] <= '9' {
    i += 1
  }
  while i < arr.length() &&
        (arr[i] == '.' || arr[i] == ')' || arr[i] == '）' || arr[i] == ' ') {
    i += 1
  }
  if i >= arr.length() {
    return false
  }

  let ch = arr[i]
  (ch >= 'A' && ch <= 'Z') || is_cjkish_for_ir(ch)
}

///|
fn body_looks_like_paragraph_start_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    is_probable_page_number_for_ir(t) {
    return false
  }

  t.length() > 24 || heading_word_count_for_ir(t) >= 5
}

///|
fn heading_word_count_for_ir(text : String) -> Int {
  let t = text.trim().to_owned()
  if t == "" {
    return 0
  }

  let mut count = 0
  let mut in_word = false
  for ch in t {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if in_word {
        in_word = false
      }
    } else if !in_word {
      count += 1
      in_word = true
    }
  }
  count
}

///|
fn looks_like_separator_line_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 3 {
    return false
  }

  for ch in t {
    if ch != '-' && ch != '=' && ch != '_' && ch != '*' {
      return false
    }
  }
  true
}

///|
fn debug_block_kind_for_ir(kind : PdfConvertBlockKind) -> String {
  match kind {
    PdfConvertBlockKind::Heading => "Heading"
    PdfConvertBlockKind::Paragraph => "Paragraph"
    PdfConvertBlockKind::Noise => "Noise"
  }
}

///|
fn split_non_empty_words_for_ir(text : String) -> Array[String] {
  let out : Array[String] = []
  for sv in text.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      out.push(w)
    }
  }
  out
}

///|
fn ascii_lower_for_ir(text : String) -> String {
  let mut out = ""
  for c in text.to_array() {
    if c >= 'A' && c <= 'Z' {
      let d = c.to_int() - 'A'.to_int() + 'a'.to_int()
      out = out + Int::unsafe_to_char(d).to_string()
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
fn strip_edge_punct_for_ir(text : String) -> String {
  let cs = text.to_array()
  if cs.length() == 0 {
    return text
  }

  let mut start = 0
  let mut end_ = cs.length()

  while start < end_ && is_simple_edge_punct_for_ir(cs[start]) {
    start += 1
  }

  while end_ > start && is_simple_edge_punct_for_ir(cs[end_ - 1]) {
    end_ -= 1
  }

  let mut out = ""
  let mut i = start
  while i < end_ {
    out = out + cs[i].to_string()
    i += 1
  }
  out
}

///|
fn is_simple_edge_punct_for_ir(c : Char) -> Bool {
  c == '"' ||
  c == '\'' ||
  c == '(' ||
  c == ')' ||
  c == '[' ||
  c == ']' ||
  c == '{' ||
  c == '}' ||
  c == ',' ||
  c == '.' ||
  c == ':' ||
  c == ';' ||
  c == '!' ||
  c == '?' ||
  c == '“' ||
  c == '”' ||
  c == '‘' ||
  c == '’' ||
  c == '（' ||
  c == '）'
}

///|
fn is_statement_stopword_for_ir(word : String) -> Bool {
  word == "this" ||
  word == "the" ||
  word == "a" ||
  word == "an" ||
  word == "that" ||
  word == "these" ||
  word == "those" ||
  word == "it" ||
  word == "its" ||
  word == "their" ||
  word == "his" ||
  word == "her"
}

///|
fn is_statement_verb_for_ir(word : String) -> Bool {
  word == "is" ||
  word == "are" ||
  word == "was" ||
  word == "were" ||
  word == "be" ||
  word == "been" ||
  word == "being" ||
  word == "has" ||
  word == "have" ||
  word == "had" ||
  word == "does" ||
  word == "do" ||
  word == "did"
}

///|
fn is_statement_clause_marker_for_ir(word : String) -> Bool {
  word == "because" ||
  word == "which" ||
  word == "when" ||
  word == "where" ||
  word == "while" ||
  word == "although" ||
  word == "though" ||
  word == "since" ||
  word == "if"
}

///|
fn ends_like_sentence_for_heading(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？") ||
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("；") ||
  t.has_suffix(";") ||
  t.has_suffix("：") ||
  t.has_suffix(":")
}

///|
fn looks_like_list_item_sentence_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
fn looks_like_figure_or_table_caption_for_ir(text : String) -> Bool {
  @text.looks_like_figure_or_table_caption(text)
}

///|
fn looks_like_intro_phrase_for_ir(text : String) -> Bool {
  @text.looks_like_intro_phrase(text)
}

///|
fn looks_like_list_intro_line_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if !t.has_suffix(":") && !t.has_suffix("：") {
    return false
  }

  t.to_array().length() <= 30
}

///|
fn looks_like_side_marker_label_line_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" || !t.contains(" ") || !t.contains("-") {
    return false
  }

  let mut first = ""
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      first = w
      break
    }
  }
  if first == "" {
    return false
  }

  if first.has_prefix("LEFT-") || first.has_prefix("RIGHT-") {
    return true
  }

  let mut has_upper = false
  for c in first.to_array() {
    let ok = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-'
    if !ok {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      has_upper = true
    }
  }

  has_upper && first.contains("-")
}

///|
fn is_probable_page_number_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if is_probable_page_number_like(t) {
    return true
  }

  t.contains("第") && t.contains("页")
}

///|
fn starts_with_latin_for_ir(s : String) -> Bool {
  match first_char_for_ir(s) {
    Some(c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    None => false
  }
}

///|
fn first_char_for_ir(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    return None
  }
  Some(cs[0])
}

///|
fn contains_sentence_punct_inside_for_ir(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n <= 2 {
    return false
  }

  let mut i = 1
  while i + 1 < n {
    let c = cs[i]
    if c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '；' ||
      c == ';' ||
      c == '：' ||
      c == ':' {
      return true
    }
    i = i + 1
  }

  false
}

///|
fn is_cjkish_for_ir(c : Char) -> Bool {
  is_cjk_char(c) || c == '（' || c == '）' || c == '《' || c == '》'
}

///|
/// 常见 CJK 统一表意文字范围 + 扩展 A + 兼容表意文字。
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_digit_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x30 && code <= 0x39
}
