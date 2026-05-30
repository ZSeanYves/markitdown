///|
fn glue_between_adjacent_spans(
  left_text : String,
  left_span : PdfTextSpan,
  right_span : PdfTextSpan,
) -> String {
  match hyphen_glue_between_adjacent_spans(left_span, right_span) {
    Some(glue) => return glue
    None => ()
  }

  if should_glue_english_word_piece_with_context(left_span, right_span) {
    return ""
  }

  glue_between_spans(left_text, right_span.text)
}

///|
fn hyphen_glue_between_adjacent_spans(
  left_span : PdfTextSpan,
  right_span : PdfTextSpan,
) -> String? {
  let left_text = left_span.text.trim().to_owned()
  let right_word = first_ascii_word(right_span.text.trim().to_owned())
  if left_text.has_suffix("-") ||
    left_text.has_suffix("\u{2010}") ||
    left_text.has_suffix("\u{2011}") ||
    !span_has_raw_trailing_hyphen_char(left_span) ||
    !starts_with_lower_ascii(right_word) {
    return None
  }

  if looks_like_wrapped_hyphen_continuation_for_word_merge(
      left_span, right_span,
    ) &&
    should_drop_wrapped_raw_hyphenated_word_piece(left_text, right_word) {
    Some("")
  } else if looks_like_hyphen_connector_follow_word(right_word) {
    Some("- ")
  } else {
    Some("-")
  }
}

///|
fn should_insert_space_after_existing_hyphen(
  left : String,
  right : String,
) -> Bool {
  let l = left.trim()
  let r = right.trim()
  if l == "" || r == "" {
    return false
  }

  if !has_ascii_word_before_hyphen_suffix(l.to_owned()) {
    return false
  }

  looks_like_hyphen_connector_follow_word(first_ascii_word(r.to_owned()))
}

///|
fn should_glue_after_existing_hyphen_without_space(
  left : String,
  right : String,
) -> Bool {
  let l = left.trim()
  let r = right.trim()
  if l == "" || r == "" {
    return false
  }

  has_ascii_word_before_hyphen_suffix(l.to_owned()) &&
  starts_with_lower_ascii(r.to_owned())
}

///|
fn last_char_before_last_opt(text : String) -> Char? {
  let arr = text.to_array()
  if arr.length() < 2 {
    return None
  }
  Some(arr[arr.length() - 2])
}

///|
fn is_sign_prefix_for_number(left : Char, right : Char) -> Bool {
  (left == '+' || left == '-') && (is_ascii_digit(right) || right == '.')
}

///|
fn should_tighten_numeric_separator_boundary(
  left : String,
  right : Char,
) -> Bool {
  if !is_ascii_digit(right) {
    return false
  }

  let arr = left.to_array()
  if arr.length() < 2 {
    return false
  }

  let last = arr[arr.length() - 1]
  let prev = arr[arr.length() - 2]
  (last == ',' || last == ':' || last == '.' || last == '/') &&
  is_ascii_digit(prev)
}

///|
fn should_insert_space_before_open_punct(left : Char, right : Char) -> Bool {
  is_left_open_punct(right) &&
  (
    is_ascii_wordish(left) ||
    is_other_script_word_char(left) ||
    is_cjk_char(left) ||
    is_left_space_worthy_punct(left)
  )
}

///|
fn should_insert_space_after_bullet_marker(
  left : String,
  right : String,
) -> Bool {
  let l = left.trim()
  if l == "" || right == "" {
    return false
  }

  match (last_char_opt(l.to_owned()), first_char_opt(right)) {
    (Some(_), Some(b)) if is_space_like_char(b) => false
    (Some(a), Some(b)) => is_bullet_char(a) && !is_spacing_or_punct(b)
    _ => false
  }
}

///|
fn should_insert_space_after_numbered_marker(
  left : String,
  right : String,
) -> Bool {
  let l = left.trim()
  let r = right.trim()
  if l == "" || r == "" {
    return false
  }

  let arr = l.to_array()
  if arr.length() < 2 {
    return false
  }

  let last = arr[arr.length() - 1]
  let prev = arr[arr.length() - 2]
  if !is_ascii_digit(prev) {
    return false
  }
  if !(last == ')' || last == '、' || last == '）') {
    return false
  }

  match first_char_opt(r.to_owned()) {
    Some(ch) => !is_spacing_or_punct(ch)
    None => false
  }
}

///|
fn should_glue_english_word_piece_with_context(
  left_span : PdfTextSpan,
  right_span : PdfTextSpan,
) -> Bool {
  let l = left_span.text.trim().to_owned()
  let r = right_span.text.trim().to_owned()

  if l == "" || r == "" {
    return false
  }

  let left_word = last_ascii_word(l)
  let right_word = first_ascii_word(r)

  if left_word == "" || right_word == "" {
    return false
  }

  if left_word.length() > 12 || right_word.length() > 12 {
    return false
  }

  if looks_like_et_al_citation_fragment_boundary(left_word, r) {
    return false
  }

  if is_short_upper_acronym(left_word) || !starts_with_lower_ascii(right_word) {
    return false
  }

  if looks_like_wrapped_prefix_continuation_for_word_merge(
      left_span, right_span, left_word, right_word,
    ) {
    return true
  }

  if has_explicit_space_boundary_for_word_merge(left_span, right_span) {
    return false
  }

  if !span_font_compatible_for_word_merge(left_span, right_span) ||
    !span_source_refs_adjacent_for_word_merge(left_span, right_span) {
    return false
  }

  if right_span.break_before {
    return false
  }

  if !span_gap_tight_for_word_merge(left_span, right_span) ||
    !span_baseline_proximate_for_word_merge(left_span, right_span) {
    return false
  }

  if starts_with_ligature_fragment_span(right_span) &&
    left_word.length() >= 2 &&
    right_word.length() <= 3 {
    return true
  }

  if is_small_ligature_fragment_span(left_span) && right_word.length() <= 5 {
    return true
  }

  looks_like_joinable_english_fragment_word(left_word, right_word) ||
  looks_like_tight_short_ascii_fragment_pair(
    left_span, right_span, left_word, right_word,
  )
}

///|
fn last_ascii_word(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return ""
  }

  let mut start = arr.length()
  let mut i = arr.length()

  while i > 0 {
    let ch = arr[i - 1]
    if is_ascii_letter(ch) {
      start = i - 1
      i = i - 1
    } else {
      break
    }
  }

  text[start:arr.length()].to_owned()
}

///|
fn first_ascii_word(text : String) -> String {
  let arr = text.to_array()
  let mut end = 0

  while end < arr.length() {
    let ch = arr[end]
    if is_ascii_letter(ch) {
      end = end + 1
    } else {
      break
    }
  }

  text[:end].to_owned()
}

///|
fn looks_like_et_al_citation_fragment_boundary(
  left_word : String,
  right_text : String,
) -> Bool {
  looks_like_short_capitalized_ascii_surname(left_word) &&
  starts_with_et_al_phrase(right_text)
}

///|
fn looks_like_short_capitalized_ascii_surname(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 2 || t.length() > 4 {
    return false
  }

  let arr = t.to_array()
  if arr.is_empty() || !(arr[0] >= 'A' && arr[0] <= 'Z') {
    return false
  }

  let mut i = 1
  while i < arr.length() {
    let ch = arr[i]
    if !(ch >= 'a' && ch <= 'z') {
      return false
    }
    i = i + 1
  }

  true
}

///|
fn starts_with_et_al_phrase(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_prefix("et al.") || t.has_prefix("et al,")
}

///|
fn looks_like_bound_english_prefix(text : String) -> Bool {
  let t = text.trim().to_lower()
  t == "inter" ||
  t == "multi" ||
  t == "semi" ||
  t == "trans" ||
  t == "micro" ||
  t == "macro" ||
  t == "hyper" ||
  t == "meta" ||
  t == "auto" ||
  t == "uni"
}

///|
fn looks_like_english_suffix_piece(text : String) -> Bool {
  let t = text.trim().to_lower()
  t == "ed" ||
  t == "er" ||
  t == "es" ||
  t == "ly" ||
  t == "ing" ||
  t == "tion" ||
  t == "sion" ||
  t == "ment" ||
  t == "ness" ||
  t == "able" ||
  t == "ible"
}

///|
fn looks_like_joinable_english_fragment_word(
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  let word = left_suffix + right_prefix
  if word.length() < 4 || word.length() > 24 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  let left = left_suffix.to_lower()
  let right = right_prefix.to_lower()

  if has_ligature_fragment_hint(left) {
    return true
  }

  if looks_like_english_suffix_piece(right) && left.length() >= 3 {
    return true
  }

  if looks_like_bound_english_prefix(left) && right.length() >= 4 {
    return true
  }

  false
}

///|
fn looks_like_tight_short_ascii_fragment_pair(
  left_span : PdfTextSpan,
  right_span : PdfTextSpan,
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  let left_len = left_suffix.length()
  let right_len = right_prefix.length()
  let word = left_suffix + right_prefix
  if word.length() < 3 || word.length() > 24 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  if looks_like_common_short_right_word_fragment(right_prefix) {
    return false
  }

  let gap_ok = if left_len <= 2 || right_len <= 2 {
    span_gap_short_fragment_fallback_for_word_merge(left_span, right_span)
  } else {
    span_gap_very_tight_for_word_merge(left_span, right_span)
  }

  if !gap_ok {
    return false
  }

  (left_len >= 3 && right_len <= 3) || (left_len <= 2 && right_len <= 2)
}

///|
fn looks_like_common_short_right_word_fragment(text : String) -> Bool {
  let t = text.trim().to_lower()
  t == "be" ||
  t == "the" ||
  t == "and" ||
  t == "but" ||
  t == "for" ||
  t == "nor" ||
  t == "not" ||
  t == "yet" ||
  t == "are" ||
  t == "was" ||
  t == "were" ||
  t == "has" ||
  t == "had" ||
  t == "have" ||
  t == "can" ||
  t == "may" ||
  t == "will" ||
  t == "with" ||
  t == "from" ||
  t == "that" ||
  t == "this" ||
  t == "then" ||
  t == "than" ||
  t == "them" ||
  t == "they" ||
  t == "their" ||
  t == "there" ||
  t == "here" ||
  t == "your"
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_wordish(ch : Char) -> Bool {
  is_ascii_letter(ch) || is_ascii_digit(ch)
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_other_script_word_char(ch : Char) -> Bool {
  let code = ch.to_int()
  !is_ascii_wordish(ch) &&
  !is_cjk_char(ch) &&
  !is_spacing_or_punct(ch) &&
  (
    (code >= 0x0370 && code <= 0x052F) ||
    (code >= 0x0590 && code <= 0x05FF) ||
    (code >= 0x0600 && code <= 0x08FF) ||
    (code >= 0xFB1D && code <= 0xFDFF) ||
    (code >= 0xFE70 && code <= 0xFEFF)
  )
}

///|
fn is_bullet_char(ch : Char) -> Bool {
  ch == '•' || ch == '-' || ch == '*'
}

///|
fn is_left_open_punct(ch : Char) -> Bool {
  ch == '(' ||
  ch == '[' ||
  ch == '{' ||
  ch == '（' ||
  ch == '【' ||
  ch == '《'
}

///|
/// 右侧若以这些紧贴型标点开头，通常不补空格。
fn is_right_tight_punct(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ':' ||
  ch == ';' ||
  ch == '!' ||
  ch == '?' ||
  ch == ')' ||
  ch == ']' ||
  ch == '}' ||
  ch == '，' ||
  ch == '。' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？' ||
  ch == '）' ||
  ch == '】' ||
  ch == '》'
}

///|
/// 左侧如果以这些字符结束，而右侧是正文，通常要补空格。
fn is_left_space_worthy_punct(ch : Char) -> Bool {
  ch == ')' ||
  ch == ']' ||
  ch == '}' ||
  ch == ':' ||
  ch == ';' ||
  ch == ',' ||
  ch == '.' ||
  ch == '!' ||
  ch == '?'
}

///|
fn is_spacing_or_punct(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  is_right_tight_punct(ch)
}

///|
fn is_space_like_char(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{00A0}' ||
  ch == '\u{2002}' ||
  ch == '\u{2003}' ||
  ch == '\u{2009}' ||
  ch == '　'
}

///|
fn is_short_upper_acronym(text : String) -> Bool {
  let t = text.trim()
  if t.length() == 0 || t.length() > 3 {
    return false
  }
  let mut has_char = false
  for ch in t {
    if !is_ascii_letter(ch) {
      return false
    }
    if !(ch >= 'A' && ch <= 'Z') {
      return false
    }
    has_char = true
  }
  has_char
}

///|
fn starts_with_lower_ascii(text : String) -> Bool {
  match first_char_opt(text) {
    Some(ch) => ch >= 'a' && ch <= 'z'
    None => false
  }
}

///|
fn has_explicit_space_boundary_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  span_has_trailing_space_char(left) || span_has_leading_space_char(right)
}

///|
fn span_has_trailing_space_char(span : PdfTextSpan) -> Bool {
  match last_span_raw_char_opt(span) {
    Some(ch) => is_space_like_char(ch)
    None => false
  }
}

///|
fn span_has_leading_space_char(span : PdfTextSpan) -> Bool {
  match first_span_raw_char_opt(span) {
    Some(ch) => is_space_like_char(ch)
    None => false
  }
}

///|
fn span_has_raw_trailing_hyphen_char(span : PdfTextSpan) -> Bool {
  match last_span_raw_char_opt(span) {
    Some(ch) => is_word_wrap_hyphen_char(ch)
    None => false
  }
}

///|
fn has_word_wrap_hyphen_suffix(text : String) -> Bool {
  text.has_suffix("-") ||
  text.has_suffix("\u{2010}") ||
  text.has_suffix("\u{2011}")
}

///|
fn has_ascii_word_before_hyphen_suffix(text : String) -> Bool {
  if !has_word_wrap_hyphen_suffix(text) {
    return false
  }

  match last_char_before_last_opt(text) {
    Some(ch) => is_ascii_letter(ch)
    None => false
  }
}

///|
fn is_word_wrap_hyphen_char(ch : Char) -> Bool {
  ch == '-' || ch == '\u{2010}' || ch == '\u{2011}'
}

///|
fn starts_with_ligature_fragment_span(span : PdfTextSpan) -> Bool {
  if span.chars.is_empty() {
    return false
  }

  let first = span.chars[0]
  first.is_ligature ||
  first.decoded_text == "\u{FB00}" ||
  first.decoded_text == "\u{FB01}" ||
  first.decoded_text == "\u{FB02}" ||
  first.decoded_text == "\u{FB03}" ||
  first.decoded_text == "\u{FB04}"
}

///|
fn is_small_ligature_fragment_span(span : PdfTextSpan) -> Bool {
  let t = span.text.trim().to_owned().to_lower()
  starts_with_ligature_fragment_span(span) &&
  span.chars.length() == 1 &&
  t != "" &&
  t.length() <= 3 &&
  all_ascii_letters(t)
}

///|
fn looks_like_wrapped_prefix_continuation_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
  left_word : String,
  right_word : String,
) -> Bool {
  if !looks_like_bound_english_prefix(left_word) || right_word.length() < 4 {
    return false
  }

  let ref_size = span_word_merge_ref_size(left, right)
  let baseline_drop = left.origin.y - right.origin.y
  if baseline_drop <= ref_size * 0.7 || baseline_drop > ref_size * 2.4 {
    return false
  }

  // Wrapped continuation should restart near the paragraph left edge rather
  // than continuing horizontally on the same visual line.
  right.bbox.x0 <= left.bbox.x0 + ref_size * 0.8
}

///|
fn looks_like_wrapped_hyphen_continuation_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  if right.break_before {
    return true
  }

  let ref_size = span_word_merge_ref_size(left, right)
  let baseline_drop = left.origin.y - right.origin.y
  if baseline_drop <= ref_size * 0.45 || baseline_drop > ref_size * 2.6 {
    return false
  }

  right.bbox.x0 <= left.bbox.x0 + ref_size * 1.0
}

///|
fn should_drop_wrapped_raw_hyphenated_word_piece(
  left_text : String,
  right_word : String,
) -> Bool {
  let left_fragment = last_ascii_word(left_text.trim().to_owned())
  let right_fragment = first_ascii_word(right_word.trim().to_owned())
  if left_fragment == "" || right_fragment == "" {
    return false
  }

  looks_like_wrapped_hyphen_word_continuation(left_fragment, right_fragment)
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

///|
fn looks_like_hyphen_connector_follow_word(text : String) -> Bool {
  let word = text.trim().to_lower()
  word == "or" || word == "and" || word == "to"
}

///|
fn has_ligature_fragment_hint(text : String) -> Bool {
  text.has_suffix("fi") ||
  text.has_suffix("ff") ||
  text.has_suffix("fl") ||
  text.has_suffix("ffi") ||
  text.has_suffix("ffl")
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
fn span_font_compatible_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  let font_name_ok = match (left.font_name, right.font_name) {
    (Some(a), Some(b)) => a == b
    _ => true
  }

  let font_family_ok = match (left.font_family, right.font_family) {
    (Some(a), Some(b)) => a == b
    _ => true
  }

  let font_size_ok = match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => abs_double_glue(a - b) <= 0.75
    _ => true
  }

  let style_ok = left.is_bold == right.is_bold &&
    left.is_italic == right.is_italic &&
    left.is_monospace == right.is_monospace

  font_name_ok && font_family_ok && font_size_ok && style_ok
}

///|
fn span_gap_tight_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = span_word_merge_ref_size(left, right)
  gap <= ref_size * 0.22 + 1.5
}

///|
fn span_gap_very_tight_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = span_word_merge_ref_size(left, right)
  gap <= ref_size * 0.08 + 0.6
}

///|
fn span_gap_short_fragment_fallback_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = span_word_merge_ref_size(left, right)
  gap <= ref_size * 0.16 + 1.0
}

///|
fn span_baseline_proximate_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  let ref_size = span_word_merge_ref_size(left, right)
  abs_double_glue(left.origin.y - right.origin.y) <= ref_size * 0.35 + 0.75
}

///|
fn span_word_merge_ref_size(left : PdfTextSpan, right : PdfTextSpan) -> Double {
  match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }
}

///|
fn span_source_refs_adjacent_for_word_merge(
  left : PdfTextSpan,
  right : PdfTextSpan,
) -> Bool {
  match
    (
      last_source_ref_opt(left.source_refs),
      first_source_ref_opt(right.source_refs),
    ) {
    (Some(a), Some(b)) => {
      if a.page_index != b.page_index ||
        a.source_stream_index != b.source_stream_index {
        return false
      }

      match (a.content_order_index, b.content_order_index) {
        (Some(x), Some(y)) => if y < x { false } else { y - x <= 2 }
        _ =>
          if b.source_op_index < a.source_op_index {
            false
          } else {
            b.source_op_index - a.source_op_index <= 2
          }
      }
    }
    _ => true
  }
}

///|
fn first_source_ref_opt(refs : Array[PdfSourceRef]) -> PdfSourceRef? {
  if refs.is_empty() {
    None
  } else {
    Some(refs[0])
  }
}

///|
fn last_source_ref_opt(refs : Array[PdfSourceRef]) -> PdfSourceRef? {
  if refs.is_empty() {
    None
  } else {
    Some(refs[refs.length() - 1])
  }
}

///|
fn abs_double_glue(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
fn first_char_opt(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn last_char_opt(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn first_span_raw_char_opt(span : PdfTextSpan) -> Char? {
  for pdf_char in span.chars {
    for ch in pdf_char.decoded_text {
      return Some(ch)
    }
  }
  first_char_opt(span.text)
}

///|
fn last_span_raw_char_opt(span : PdfTextSpan) -> Char? {
  let mut last : Char? = None
  for pdf_char in span.chars {
    for ch in pdf_char.decoded_text {
      last = Some(ch)
    }
  }
  match last {
    Some(_) => last
    None => last_char_opt(span.text)
  }
}
