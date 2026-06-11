///|
pub(all) enum PdfV2TextMarkerKind {
  HeadingMarker
  OrderedListMarker
  UnorderedListMarker
  UnknownMarker
} derive(Eq)

///|
pub(all) struct PdfV2TextMarkerCandidate {
  kind : PdfV2TextMarkerKind
  marker_text : String
  body_text : String
  marker_char_start : Int
  marker_char_end : Int
  body_char_start : Int
  body_char_end : Int
  level_hint : Int?
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
  confidence : Double
}

///|
pub(all) struct PdfV2LineTextSignal {
  normalized_text : String
  char_count : Int
  word_count : Int
  is_empty : Bool
  is_short : Bool
  ends_with_sentence_punctuation : Bool
  starts_with_unordered_marker : Bool
  starts_with_ordered_marker : Bool
  starts_with_page_number : Bool
  starts_with_caption_marker : Bool
  looks_like_title_line : Bool
  looks_like_noise_line : Bool
  marker_candidate : PdfV2TextMarkerCandidate?
  decode_confidence : PdfV2TextDecodeConfidence
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_build_line_text_signal(
  text : String,
  decode_confidence : PdfV2TextDecodeConfidence,
  source_refs : Array[PdfV2SourceRef],
  base_reason_tags : Array[String],
) -> PdfV2LineTextSignal {
  let normalized_text = pdf_v2_line_signal_normalize_text(text)
  let char_count = normalized_text.to_array().length()
  let word_count = pdf_v2_line_signal_word_count(normalized_text)
  let marker_candidate = pdf_v2_line_signal_marker_candidate(
    normalized_text, source_refs,
  )
  let starts_with_unordered_marker = match marker_candidate {
    Some(marker) => marker.kind == PdfV2TextMarkerKind::UnorderedListMarker
    None => false
  }
  let starts_with_ordered_marker = match marker_candidate {
    Some(marker) => marker.kind == PdfV2TextMarkerKind::OrderedListMarker
    None => false
  }
  let starts_with_page_number = pdf_v2_line_signal_page_number_like(
    normalized_text,
  )
  let starts_with_caption_marker = pdf_v2_line_signal_caption_like(
    normalized_text,
  )
  let ends_with_sentence_punctuation = pdf_v2_line_signal_ends_sentence(
    normalized_text,
  )
  let looks_like_noise_line = pdf_v2_line_signal_noise_like(
    normalized_text, starts_with_page_number,
  )
  let looks_like_title_line = pdf_v2_line_signal_title_like(
    normalized_text, char_count, word_count, ends_with_sentence_punctuation, starts_with_unordered_marker,
    starts_with_ordered_marker, starts_with_page_number, starts_with_caption_marker,
    looks_like_noise_line,
  )
  {
    normalized_text,
    char_count,
    word_count,
    is_empty: normalized_text == "",
    is_short: char_count <= 72,
    ends_with_sentence_punctuation,
    starts_with_unordered_marker,
    starts_with_ordered_marker,
    starts_with_page_number,
    starts_with_caption_marker,
    looks_like_title_line,
    looks_like_noise_line,
    marker_candidate,
    decode_confidence,
    reason_tags: pdf_v2_line_signal_reason_tags(
      base_reason_tags, marker_candidate, starts_with_page_number, starts_with_caption_marker,
      looks_like_title_line, looks_like_noise_line,
    ),
  }
}

///|
pub fn pdf_v2_empty_line_text_signal() -> PdfV2LineTextSignal {
  pdf_v2_build_line_text_signal("", PdfV2TextDecodeConfidence::Unknown, [], [
    "line_text_signal_empty",
  ])
}

///|
fn pdf_v2_line_signal_normalize_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn pdf_v2_line_signal_word_count(text : String) -> Int {
  let mut count = 0
  for raw in text.split(" ") {
    if raw.trim().to_owned() != "" {
      count = count + 1
    }
  }
  if count == 0 && text.trim().to_owned() != "" {
    1
  } else {
    count
  }
}

///|
fn pdf_v2_line_signal_marker_candidate(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  match pdf_v2_line_signal_heading_marker(text, source_refs) {
    Some(marker) => return Some(marker)
    None => ()
  }
  match pdf_v2_line_signal_unordered_marker(text, source_refs) {
    Some(marker) => return Some(marker)
    None => ()
  }
  pdf_v2_line_signal_ordered_marker(text, source_refs)
}

///|
fn pdf_v2_line_signal_heading_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  let chars = text.to_array()
  if chars.length() < 3 || chars[0] != '#' {
    return None
  }
  let mut count = 0
  while count < chars.length() && chars[count] == '#' {
    count = count + 1
  }
  if count == 0 || count > 6 || count >= chars.length() || chars[count] != ' ' {
    return None
  }
  let body = String::from_array(chars[count + 1:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some(
    pdf_v2_line_signal_marker(
      PdfV2TextMarkerKind::HeadingMarker,
      "#".repeat(count),
      body,
      0,
      count,
      count + 1,
      chars.length(),
      Some(count),
      source_refs,
      ["line_text_signal", "heading_marker_candidate"],
      0.98,
    ),
  )
}

///|
fn pdf_v2_line_signal_unordered_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  let chars = text.to_array()
  if chars.length() < 3 {
    return None
  }
  let marker = chars[0]
  if marker != '-' && marker != '*' && marker != '•' {
    return None
  }
  if chars[1] != ' ' {
    return None
  }
  let body = String::from_array(chars[2:].to_owned()).trim().to_owned()
  if body == "" || pdf_v2_line_signal_separator_line(body) {
    return None
  }
  Some(
    pdf_v2_line_signal_marker(
      PdfV2TextMarkerKind::UnorderedListMarker,
      marker.to_string(),
      body,
      0,
      1,
      2,
      chars.length(),
      Some(0),
      source_refs,
      ["line_text_signal", "unordered_marker_candidate"],
      0.94,
    ),
  )
}

///|
fn pdf_v2_line_signal_ordered_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  match pdf_v2_line_signal_ascii_ordered_marker(text, source_refs) {
    Some(marker) => return Some(marker)
    None => ()
  }
  match pdf_v2_line_signal_parenthesized_digit_marker(text, source_refs) {
    Some(marker) => return Some(marker)
    None => ()
  }
  pdf_v2_line_signal_cjk_ordered_marker(text, source_refs)
}

///|
fn pdf_v2_line_signal_ascii_ordered_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  let chars = text.to_array()
  if chars.length() < 4 || !pdf_v2_line_signal_ascii_digit(chars[0]) {
    return None
  }
  let mut i = 0
  while i < chars.length() && pdf_v2_line_signal_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 0 || i + 1 >= chars.length() {
    return None
  }
  let marker_end = chars[i]
  if marker_end != '.' && marker_end != ')' && marker_end != '）' {
    return None
  }
  if marker_end == '.' &&
    i + 1 < chars.length() &&
    pdf_v2_line_signal_ascii_digit(chars[i + 1]) {
    return None
  }
  if chars[i + 1] != ' ' {
    return None
  }
  let body = String::from_array(chars[i + 2:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some(
    pdf_v2_line_signal_marker(
      PdfV2TextMarkerKind::OrderedListMarker,
      String::from_array(chars[:i + 1].to_owned()),
      body,
      0,
      i + 1,
      i + 2,
      chars.length(),
      Some(0),
      source_refs,
      ["line_text_signal", "ordered_marker_candidate"],
      0.92,
    ),
  )
}

///|
fn pdf_v2_line_signal_parenthesized_digit_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  let chars = text.to_array()
  if chars.length() < 5 || (chars[0] != '(' && chars[0] != '（') {
    return None
  }
  let close = if chars[0] == '(' { ')' } else { '）' }
  let mut i = 1
  while i < chars.length() && pdf_v2_line_signal_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 1 ||
    i + 1 >= chars.length() ||
    chars[i] != close ||
    chars[i + 1] != ' ' {
    return None
  }
  let body = String::from_array(chars[i + 2:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some(
    pdf_v2_line_signal_marker(
      PdfV2TextMarkerKind::OrderedListMarker,
      String::from_array(chars[:i + 1].to_owned()),
      body,
      0,
      i + 1,
      i + 2,
      chars.length(),
      Some(0),
      source_refs,
      ["line_text_signal", "ordered_marker_candidate"],
      0.92,
    ),
  )
}

///|
fn pdf_v2_line_signal_cjk_ordered_marker(
  text : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2TextMarkerCandidate? {
  let chars = text.to_array()
  if chars.length() < 4 || (chars[0] != '(' && chars[0] != '（') {
    return None
  }
  let close = if chars[0] == '(' { ')' } else { '）' }
  if chars[2] != close || !pdf_v2_line_signal_cjk_order_token(chars[1]) {
    return None
  }
  let body = String::from_array(chars[3:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some(
    pdf_v2_line_signal_marker(
      PdfV2TextMarkerKind::OrderedListMarker,
      String::from_array(chars[:3].to_owned()),
      body,
      0,
      3,
      3,
      chars.length(),
      Some(0),
      source_refs,
      ["line_text_signal", "ordered_marker_candidate", "cjk_order_marker"],
      0.90,
    ),
  )
}

///|
fn pdf_v2_line_signal_marker(
  kind : PdfV2TextMarkerKind,
  marker_text : String,
  body_text : String,
  marker_char_start : Int,
  marker_char_end : Int,
  body_char_start : Int,
  body_char_end : Int,
  level_hint : Int?,
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
  confidence : Double,
) -> PdfV2TextMarkerCandidate {
  {
    kind,
    marker_text,
    body_text,
    marker_char_start,
    marker_char_end,
    body_char_start,
    body_char_end,
    level_hint,
    source_refs,
    reason_tags,
    confidence,
  }
}

///|
fn pdf_v2_line_signal_page_number_like(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if pdf_v2_line_signal_all_ascii_digits(t) && t.length() <= 4 {
    return true
  }
  if pdf_v2_line_signal_dash_wrapped_page_number(t) {
    return true
  }
  let lower = t.to_lower()
  if lower.has_prefix("page ") {
    return pdf_v2_line_signal_page_label_tail(lower[5:].to_owned())
  }
  if lower.has_prefix("p. ") {
    return pdf_v2_line_signal_ascii_digit_tail(lower[3:].to_owned())
  }
  if pdf_v2_line_signal_fraction_page_number(t) {
    return true
  }
  pdf_v2_line_signal_cjk_page_number(t)
}

///|
fn pdf_v2_line_signal_page_label_tail(tail : String) -> Bool {
  let t = tail.trim().to_owned()
  if t == "" {
    return false
  }
  if pdf_v2_line_signal_all_ascii_digits(t) {
    return true
  }
  let parts = t.split(" of ").to_array()
  parts.length() == 2 &&
  pdf_v2_line_signal_all_ascii_digits(parts[0].trim().to_owned()) &&
  pdf_v2_line_signal_all_ascii_digits(parts[1].trim().to_owned())
}

///|
fn pdf_v2_line_signal_ascii_digit_tail(text : String) -> Bool {
  let t = text.trim().to_owned()
  pdf_v2_line_signal_all_ascii_digits(t) && t.length() <= 4
}

///|
fn pdf_v2_line_signal_dash_wrapped_page_number(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 5 || chars[0] != '-' || chars[chars.length() - 1] != '-' {
    return false
  }
  let middle = String::from_array(chars[1:chars.length() - 1].to_owned())
    .trim()
    .to_owned()
  pdf_v2_line_signal_all_ascii_digits(middle) && middle.length() <= 4
}

///|
fn pdf_v2_line_signal_fraction_page_number(text : String) -> Bool {
  let compact = text.replace_all(old=" ", new="")
  let parts = compact.split("/").to_array()
  if parts.length() != 2 {
    return false
  }
  let left = parts[0].trim().to_owned()
  let right = parts[1].trim().to_owned()
  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  pdf_v2_line_signal_all_ascii_digits(left) &&
  pdf_v2_line_signal_all_ascii_digits(right)
}

///|
fn pdf_v2_line_signal_cjk_page_number(text : String) -> Bool {
  let compact = text.replace_all(old=" ", new="")
  let chars = compact.to_array()
  if chars.length() < 3 ||
    chars[0] != '第' ||
    chars[chars.length() - 1] != '页' {
    return false
  }
  let middle = String::from_array(chars[1:chars.length() - 1].to_owned())
    .trim()
    .to_owned()
  pdf_v2_line_signal_all_ascii_digits(middle) ||
  pdf_v2_line_signal_fraction_page_number(middle)
}

///|
fn pdf_v2_line_signal_caption_like(text : String) -> Bool {
  let t = text.trim().to_owned()
  let lower = t.to_lower()
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("table ") ||
  lower.has_prefix("chart ") ||
  pdf_v2_line_signal_cjk_caption_like(t)
}

///|
fn pdf_v2_line_signal_cjk_caption_like(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 2 {
    return false
  }
  if chars[0] != '图' && chars[0] != '表' {
    return false
  }
  chars[1] == ' ' || pdf_v2_line_signal_ascii_digit(chars[1])
}

///|
fn pdf_v2_line_signal_title_like(
  text : String,
  char_count : Int,
  word_count : Int,
  ends_with_sentence_punctuation : Bool,
  starts_with_unordered_marker : Bool,
  starts_with_ordered_marker : Bool,
  starts_with_page_number : Bool,
  starts_with_caption_marker : Bool,
  looks_like_noise_line : Bool,
) -> Bool {
  if text == "" ||
    char_count < 4 ||
    char_count > 72 ||
    ends_with_sentence_punctuation ||
    starts_with_unordered_marker ||
    starts_with_ordered_marker ||
    starts_with_page_number ||
    starts_with_caption_marker ||
    looks_like_noise_line ||
    text.contains("://") ||
    text.has_suffix(":") ||
    text.has_suffix("：") ||
    text.has_suffix(",") ||
    text.has_suffix("，") ||
    text.has_suffix(";") ||
    text.has_suffix("；") {
    return false
  }
  pdf_v2_line_signal_chapter_title(text) ||
  pdf_v2_line_signal_numbered_section_title(text) ||
  pdf_v2_line_signal_common_english_section_label(text) ||
  pdf_v2_line_signal_english_title(text, word_count) ||
  pdf_v2_line_signal_cjk_title(text)
}

///|
fn pdf_v2_line_signal_chapter_title(text : String) -> Bool {
  if !text.has_prefix("第") {
    return false
  }
  let n = text.to_array().length()
  n >= 4 &&
  n <= 30 &&
  (text.contains("章") || text.contains("节")) &&
  !text.contains("页")
}

///|
fn pdf_v2_line_signal_numbered_section_title(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 5 ||
    chars.length() > 48 ||
    !pdf_v2_line_signal_ascii_digit(chars[0]) {
    return false
  }
  let mut i = 0
  while i < chars.length() && pdf_v2_line_signal_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i >= chars.length() || chars[i] != '.' {
    return false
  }
  i = i + 1
  let mut saw_digit = false
  while i < chars.length() {
    if pdf_v2_line_signal_ascii_digit(chars[i]) {
      saw_digit = true
      i = i + 1
    } else if chars[i] == '.' {
      i = i + 1
    } else {
      break
    }
  }
  if !saw_digit || i >= chars.length() {
    return false
  }
  let tail = String::from_array(chars[i:].to_owned()).trim().to_owned()
  tail != "" && !pdf_v2_line_signal_ends_sentence(tail)
}

///|
fn pdf_v2_line_signal_common_english_section_label(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  lower == "abstract" ||
  lower == "introduction" ||
  lower == "background" ||
  lower == "method" ||
  lower == "methods" ||
  lower == "results" ||
  lower == "discussion" ||
  lower == "summary" ||
  lower == "details" ||
  lower == "conclusion" ||
  lower == "references"
}

///|
fn pdf_v2_line_signal_english_title(text : String, word_count : Int) -> Bool {
  if word_count < 2 || word_count > 6 {
    return false
  }
  let mut latin_words = 0
  let mut capitalized_words = 0
  for raw in text.split(" ") {
    let word = pdf_v2_line_signal_strip_edge_punct(raw.trim().to_owned())
    if word == "" {
      continue
    }
    match pdf_v2_line_signal_first_char(word) {
      Some(ch) =>
        if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
          latin_words = latin_words + 1
          if ch >= 'A' && ch <= 'Z' {
            capitalized_words = capitalized_words + 1
          }
        }
      None => ()
    }
  }
  latin_words >= 2 && capitalized_words >= 2
}

///|
fn pdf_v2_line_signal_cjk_title(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 || chars.length() > 16 || text.contains(" ") {
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
    if pdf_v2_line_signal_cjk_char(ch) {
      cjkish = cjkish + 1
    } else if !pdf_v2_line_signal_ascii_digit(ch) && ch != '.' {
      return false
    }
  }
  cjkish >= 4
}

///|
fn pdf_v2_line_signal_noise_like(
  text : String,
  starts_with_page_number : Bool,
) -> Bool {
  let t = text.trim().to_owned()
  if t == "" || starts_with_page_number {
    return true
  }
  if pdf_v2_line_signal_separator_line(t) {
    return true
  }
  let char_count = t.to_array().length()
  char_count <= 2 && !pdf_v2_line_signal_all_ascii_digits(t)
}

///|
fn pdf_v2_line_signal_separator_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 3 {
    return false
  }
  for ch in t {
    if ch != '-' && ch != '=' && ch != '_' && ch != '*' && ch != '—' {
      return false
    }
  }
  true
}

///|
fn pdf_v2_line_signal_ends_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_v2_line_signal_reason_tags(
  base_reason_tags : Array[String],
  marker_candidate : PdfV2TextMarkerCandidate?,
  starts_with_page_number : Bool,
  starts_with_caption_marker : Bool,
  looks_like_title_line : Bool,
  looks_like_noise_line : Bool,
) -> Array[String] {
  let tags : Array[String] = [
    "line_text_signal", "parser_owned_line_text_signal",
  ]
  for tag in base_reason_tags {
    if !tags.contains(tag) {
      tags.push(tag)
    }
  }
  match marker_candidate {
    Some(marker) =>
      if marker.kind == PdfV2TextMarkerKind::OrderedListMarker {
        tags.push("ordered_marker_candidate")
      } else if marker.kind == PdfV2TextMarkerKind::UnorderedListMarker {
        tags.push("unordered_marker_candidate")
      } else if marker.kind == PdfV2TextMarkerKind::HeadingMarker {
        tags.push("heading_marker_candidate")
      }
    None => ()
  }
  if starts_with_page_number {
    tags.push("page_number_candidate")
  }
  if starts_with_caption_marker {
    tags.push("caption_marker_candidate")
  }
  if looks_like_title_line {
    tags.push("title_line_candidate")
  }
  if looks_like_noise_line {
    tags.push("noise_line_candidate")
  }
  tags
}

///|
fn pdf_v2_line_signal_all_ascii_digits(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  for ch in t {
    if !pdf_v2_line_signal_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn pdf_v2_line_signal_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn pdf_v2_line_signal_cjk_order_token(ch : Char) -> Bool {
  ch == '一' ||
  ch == '二' ||
  ch == '三' ||
  ch == '四' ||
  ch == '五' ||
  ch == '六' ||
  ch == '七' ||
  ch == '八' ||
  ch == '九' ||
  ch == '十'
}

///|
fn pdf_v2_line_signal_first_char(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn pdf_v2_line_signal_strip_edge_punct(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 {
    return ""
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end && pdf_v2_line_signal_edge_punct(chars[start]) {
    start = start + 1
  }
  while end > start && pdf_v2_line_signal_edge_punct(chars[end - 1]) {
    end = end - 1
  }
  String::from_array(chars[start:end].to_owned())
}

///|
fn pdf_v2_line_signal_edge_punct(ch : Char) -> Bool {
  ch == '"' ||
  ch == '\'' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == ',' ||
  ch == '.'
}

///|
fn pdf_v2_line_signal_cjk_char(ch : Char) -> Bool {
  ch >= '\u4e00' && ch <= '\u9fff'
}
