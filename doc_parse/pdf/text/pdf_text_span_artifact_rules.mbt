///|
fn ends_like_sentence_for_artifact(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn count_words_for_artifact(text : String) -> Int {
  let mut n = 0
  for sv in text.split(" ") {
    let t = sv.trim().to_owned()
    if t != "" {
      n = n + 1
    }
  }
  n
}

///|
fn normalize_single_span(span : @model.PdfTextSpan) -> @model.PdfTextSpan {
  let new_text = repair_pdf_span_text_artifacts(normalize_text(span.text))

  {
    id: span.id,
    bbox: span.bbox,
    origin: span.origin,
    text: new_text,
    font_name: span.font_name,
    font_family: span.font_family,
    font_size: span.font_size,
    is_bold: span.is_bold,
    is_italic: span.is_italic,
    is_monospace: span.is_monospace,
    fill_color: span.fill_color,
    stroke_color: span.stroke_color,
    char_spacing: span.char_spacing,
    word_spacing: span.word_spacing,
    text_rise: span.text_rise,
    scale_x: span.scale_x,
    writing_direction: span.writing_direction,
    language_hint: span.language_hint,
    chars: span.chars,
    source_refs: span.source_refs,
    break_before: span.break_before,
    break_reason: span.break_reason,
  }
}

///|
fn repair_pdf_span_text_artifacts(text : String) -> String {
  repair_missing_space_after_hyphen_connector_phrase(
    repair_missing_space_before_ligature_fragment_after_function_word(
      repair_missing_space_before_et_al_citation(text),
    ),
  )
}

///|
fn repair_missing_space_before_et_al_citation(text : String) -> String {
  let chars = text.to_array()
  if chars.length() < 6 {
    return text
  }

  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    if should_insert_missing_space_before_et_al(chars, i) {
      out.write_char(' ')
    }
    out.write_char(chars[i])
    i = i + 1
  }

  let repaired = out.to_string()
  if repaired == text {
    text
  } else {
    repaired
  }
}

///|
fn should_insert_missing_space_before_et_al(
  chars : Array[Char],
  index : Int,
) -> Bool {
  if !looks_like_et_al_citation_run(chars, index) || index <= 0 {
    return false
  }

  let prev = chars[index - 1]
  if !is_ascii_letter(prev) || !(prev >= 'a' && prev <= 'z') {
    return false
  }

  let word_start = find_ascii_word_start(chars, index - 1)
  if !looks_like_short_capitalized_citation_surname(chars, word_start, index) {
    return false
  }

  word_start == 0 || is_citation_boundary_char(chars[word_start - 1])
}

///|
fn looks_like_et_al_citation_run(chars : Array[Char], index : Int) -> Bool {
  index + 5 < chars.length() &&
  chars[index] == 'e' &&
  chars[index + 1] == 't' &&
  chars[index + 2] == ' ' &&
  chars[index + 3] == 'a' &&
  chars[index + 4] == 'l' &&
  chars[index + 5] == '.'
}

///|
fn find_ascii_word_start(chars : Array[Char], end_index : Int) -> Int {
  let mut start = end_index
  while start > 0 && is_ascii_letter(chars[start - 1]) {
    start = start - 1
  }
  start
}

///|
fn looks_like_short_capitalized_citation_surname(
  chars : Array[Char],
  start : Int,
  end_exclusive : Int,
) -> Bool {
  let len = end_exclusive - start
  if len < 2 || len > 4 {
    return false
  }

  if !(chars[start] >= 'A' && chars[start] <= 'Z') {
    return false
  }

  let mut i = start + 1
  while i < end_exclusive {
    let ch = chars[i]
    if !(ch >= 'a' && ch <= 'z') {
      return false
    }
    i = i + 1
  }

  true
}

///|
fn is_citation_boundary_char(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\t' ||
  ch == '(' ||
  ch == '[' ||
  ch == ';' ||
  ch == ',' ||
  ch == ':'
}

///|
fn repair_missing_space_before_ligature_fragment_after_function_word(
  text : String,
) -> String {
  let chars = text.to_array()
  if chars.length() < 8 {
    return text
  }

  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    if is_ascii_letter(chars[i]) {
      let start = i
      let mut end = i + 1
      while end < chars.length() && is_ascii_letter(chars[end]) {
        end = end + 1
      }
      let token = String::from_array(chars[start:end].to_owned())
      out.write_string(repair_ligature_compact_function_word_token(token))
      i = end
    } else {
      out.write_char(chars[i])
      i = i + 1
    }
  }

  let repaired = out.to_string()
  if repaired == text {
    text
  } else {
    repaired
  }
}

///|
fn repair_missing_space_after_hyphen_connector_phrase(text : String) -> String {
  let chars = text.to_array()
  if chars.length() < 5 {
    return text
  }

  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    out.write_char(ch)
    if ch == '-' &&
      i > 0 &&
      is_ascii_letter(chars[i - 1]) &&
      looks_like_hyphen_connector_phrase(chars, i + 1) {
      out.write_char(' ')
    }
    i = i + 1
  }

  let repaired = out.to_string()
  if repaired == text {
    text
  } else {
    repaired
  }
}

///|
fn looks_like_hyphen_connector_phrase(chars : Array[Char], start : Int) -> Bool {
  if start >= chars.length() || chars[start] == ' ' {
    return false
  }

  (
    start + 2 < chars.length() &&
    chars[start] == 'o' &&
    chars[start + 1] == 'r' &&
    chars[start + 2] == ' '
  ) ||
  (
    start + 3 < chars.length() &&
    chars[start] == 'a' &&
    chars[start + 1] == 'n' &&
    chars[start + 2] == 'd' &&
    chars[start + 3] == ' '
  ) ||
  (
    start + 2 < chars.length() &&
    chars[start] == 't' &&
    chars[start + 1] == 'o' &&
    chars[start + 2] == ' '
  )
}

///|
fn repair_ligature_compact_function_word_token(token : String) -> String {
  match ligature_compact_function_word_split_index(token) {
    Some(index) => token[:index].to_owned() + " " + token[index:].to_owned()
    None => token
  }
}

///|
fn ligature_compact_function_word_split_index(token : String) -> Int? {
  if token.length() < 8 {
    return None
  }

  let lower = token.to_lower()
  let split = match lower {
    _ if lower.has_prefix("the") => Some(3)
    _ if lower.has_prefix("and") => Some(3)
    _ if lower.has_prefix("for") => Some(3)
    _ if lower.has_prefix("with") => Some(4)
    _ if lower.has_prefix("from") => Some(4)
    _ if lower.has_prefix("this") => Some(4)
    _ if lower.has_prefix("that") => Some(4)
    _ if lower.has_prefix("than") => Some(4)
    _ if lower.has_prefix("then") => Some(4)
    _ if lower.has_prefix("your") => Some(4)
    _ if lower.has_prefix("their") => Some(5)
    _ if lower.has_prefix("there") => Some(5)
    _ if lower.has_prefix("where") => Some(5)
    _ if lower.has_prefix("while") => Some(5)
    _ if lower.has_prefix("when") => Some(4)
    _ => None
  }

  match split {
    Some(index) => {
      let remain = lower[index:].to_owned()
      if remain.length() < 4 || !starts_with_ligature_fragment(remain) {
        None
      } else {
        Some(index)
      }
    }
    None => None
  }
}

///|
fn starts_with_ligature_fragment(text : String) -> Bool {
  text.has_prefix("ffi") ||
  text.has_prefix("ffl") ||
  text.has_prefix("ff") ||
  text.has_prefix("fi") ||
  text.has_prefix("fl")
}

///|
/// 文本归一化：
/// 1. unicode_compat 先走 shared substrate 的低风险字符归一化，并保留 PDF
///    专属 compatibility glyph fallback。
/// 2. 纯字符串 cleanup 统一交给 core rule engine 的 PDF policy。
/// 3. 依赖 span/line/source_ref 的修复继续留在当前 lower-layer。
fn normalize_text(text : String) -> String {
  @cor.normalize_pdf_text_cleanup(text)
}

///|
fn should_merge_hyphenated_word_piece(
  left_text : String,
  right_text : String,
) -> Bool {
  let l = left_text.trim().to_owned()
  let r = right_text.trim().to_owned()
  if l == "" || r == "" {
    return false
  }

  let left_fragment = trailing_ascii_letters_before_hyphen(l)
  let right_fragment = leading_ascii_letters(r)
  if left_fragment == "" || right_fragment == "" {
    return false
  }

  looks_like_wrapped_hyphen_word_continuation(left_fragment, right_fragment)
}

///|
fn all_ascii_letters(text : String) -> Bool {
  if text == "" {
    return false
  }

  for ch in text {
    if !is_ascii_letter(ch) {
      return false
    }
  }

  true
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn starts_with_lower_ascii(text : String) -> Bool {
  for ch in text {
    return ch >= 'a' && ch <= 'z'
  }
  false
}

///|
fn trim_hyphen_suffix(text : String) -> String {
  let t = text.trim().to_owned()
  trim_word_wrap_hyphen_suffix(t)
}

///|
fn trim_word_wrap_hyphen_suffix(text : String) -> String {
  let t = text.trim().to_owned()
  if t.has_suffix("-") || t.has_suffix("\u{2010}") || t.has_suffix("\u{2011}") {
    t[:t.length() - 1].to_owned()
  } else {
    t
  }
}

///|
fn trailing_ascii_letters_before_hyphen(text : String) -> String {
  let trimmed = trim_word_wrap_hyphen_suffix(text)
  if trimmed == text.trim().to_owned() {
    return ""
  }

  trailing_ascii_letters(trimmed)
}

///|
fn looks_like_wrapped_hyphen_word_continuation(
  left_fragment : String,
  right_fragment : String,
) -> Bool {
  let word = left_fragment + right_fragment
  if word.length() < 4 || word.length() > 28 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  let left = left_fragment.to_lower()
  let right = right_fragment.to_lower()

  if looks_like_wrapped_hyphen_suffix_piece(right) && left.length() >= 3 {
    return true
  }

  if looks_like_bound_english_prefix(left) && right.length() >= 4 {
    return true
  }

  if left.length() == 3 &&
    right.length() >= 4 &&
    !looks_like_preserved_short_semantic_hyphen_prefix(left) {
    return true
  }

  has_ligature_fragment_hint(left) && right.length() <= 5
}

///|
fn looks_like_wrapped_hyphen_suffix_piece(text : String) -> Bool {
  looks_like_english_suffix_piece(text) ||
  text == "ity" ||
  text == "ities" ||
  text == "ation" ||
  text == "ations" ||
  text == "ative" ||
  text == "ality" ||
  text == "ility" ||
  text == "ally" ||
  text == "ially" ||
  text == "ically" ||
  text == "ming" ||
  text == "tially"
}

///|
fn looks_like_preserved_short_semantic_hyphen_prefix(text : String) -> Bool {
  text == "non" || text == "pre" || text == "sub" || text == "mid"
}
