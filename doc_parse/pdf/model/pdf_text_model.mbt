///|

///|
/// 书写方向。
pub(all) enum PdfWritingDirection {
  LeftToRight
  RightToLeft
  TopToBottom
  BottomToTop
  Unknown
}

///|
/// 文本块弱类型，注意这是 PDF lower-layer parser 内部候选，不是最终 convert 语义。
pub(all) enum PdfTextBlockKind {
  Text
  HeadingCandidate
  ListCandidate
  CaptionCandidate
  HeaderFooterCandidate
  TableCellCandidate
  FormulaCandidate
  Unknown
}

///|
/// 来源追踪信息。
pub(all) struct PdfSourceRef {
  page_index : Int
  source_stream_index : Int
  source_op_index : Int
  text_object_id : Int?
  content_order_index : Int?
  source_object_ref : String?
}

///|
/// 字符级模型。
pub(all) struct PdfChar {
  unicode : String
  raw_bytes : Bytes?
  decoded_text : String
  bbox : PdfRect
  origin : PdfPoint
  quad : PdfQuad?
  advance_width : Double?
  glyph_width : Double?
  font_name : String?
  font_size : Double?
  fill_color : PdfColor?
  rotation : Double?
  is_ligature : Bool
  is_compat_glyph : Bool
  decode_confidence : Double?
  source : PdfSourceRef
  /// 该 char 前是否有显式 break
  break_before : Bool
  /// break 原因
  break_reason : String?
}

///|
/// span 级模型：同一 run / 同一组字体样式下的连续文本。
pub(all) struct PdfTextSpan {
  id : String
  bbox : PdfRect
  origin : PdfPoint
  text : String
  font_name : String?
  font_family : String?
  font_size : Double?
  is_bold : Bool
  is_italic : Bool
  is_monospace : Bool
  fill_color : PdfColor?
  stroke_color : PdfColor?
  char_spacing : Double?
  word_spacing : Double?
  text_rise : Double?
  scale_x : Double?
  writing_direction : PdfWritingDirection
  language_hint : String?
  chars : Array[PdfChar]
  source_refs : Array[PdfSourceRef]
  /// 该 span 前是否有显式 break
  break_before : Bool
  /// break 原因
  break_reason : String?
}

///|
/// line 级模型。
pub(all) struct PdfTextLine {
  id : String
  bbox : PdfRect
  baseline_y : Double?
  ascent : Double?
  descent : Double?
  line_height : Double?
  indent_left : Double?
  indent_right : Double?
  alignment_hint : String?
  line_gap_before : Double?
  line_gap_after : Double?
  spans : Array[PdfTextSpan]
  is_wrapped_candidate : Bool
  is_same_paragraph_with_prev_candidate : Bool
  source_refs : Array[PdfSourceRef]
}

///|
/// block 级模型。
pub(all) struct PdfTextBlock {
  id : String
  bbox : PdfRect
  kind : PdfTextBlockKind
  rotation : Double?
  dominant_font_name : String?
  dominant_font_size : Double?
  dominant_language : String?
  writing_direction : PdfWritingDirection
  z_index : Int?
  lines : Array[PdfTextLine]
  is_heading_candidate : Bool
  is_header_footer_candidate : Bool
  is_page_number_candidate : Bool
  is_table_cell_candidate : Bool
  is_caption_candidate : Bool
  is_artifact_candidate : Bool
  source_refs : Array[PdfSourceRef]
}

///|
/// span 文本聚合。
pub fn span_text(span : PdfTextSpan) -> String {
  span.text
}

///|
/// line 文本聚合。
pub fn line_text(line : PdfTextLine) -> String {
  if line.spans.is_empty() {
    return ""
  }

  let mut buf = line.spans[0].text

  for i = 1; i < line.spans.length(); i = i + 1 {
    let prev = line.spans[i - 1]
    let cur = line.spans[i]
    buf = buf + glue_between_adjacent_spans(buf, prev, cur) + cur.text
  }

  buf
}

///|
fn glue_between_adjacent_spans(
  left_text : String,
  left_span : PdfTextSpan,
  right_span : PdfTextSpan,
) -> String {
  if should_glue_english_word_piece_with_context(left_span, right_span) {
    return ""
  }

  glue_between_spans(left_text, right_span.text)
}

///|
pub fn glue_between_spans(left : String, right : String) -> String {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return ""
  }

  let lc = last_char_opt(l.to_owned())
  let rc = first_char_opt(r.to_owned())

  match (lc, rc) {
    (Some(a), Some(b)) => {
      // 中文连续文本不补空格
      if is_cjk_char(a) && is_cjk_char(b) {
        return ""
      }

      // 断词场景：inter- + national
      if should_merge_hyphenated_word_piece(l.to_owned(), r.to_owned()) {
        return ""
      }

      // 左边是 bullet，右边是正文：补空格
      if should_insert_space_after_bullet_marker(l.to_owned(), r.to_owned()) {
        return " "
      }

      // 左侧编号项（如 2)）后接正文：补空格
      if should_insert_space_after_numbered_marker(l.to_owned(), r.to_owned()) {
        return " "
      }

      // 右边是纯标点开头：一般不补
      if is_right_tight_punct(b) {
        return ""
      }

      // 章节编号：1. + 1 => 1.1，不补空格
      if a == '.' && is_ascii_digit(b) {
        return ""
      }

      // 左边这些结尾后，右边是正文时，补空格
      if is_left_space_worthy_punct(a) && !is_spacing_or_punct(b) {
        return " "
      }

      // ASCII/数字词元之间补空格
      if is_ascii_wordish(a) && is_ascii_wordish(b) {
        return " "
      }

      if is_ascii_wordish(a) && is_other_script_word_char(b) {
        return " "
      }

      if is_other_script_word_char(a) && is_ascii_wordish(b) {
        return " "
      }

      // CJK + ASCII 正文，通常补空格
      if is_cjk_char(a) && is_ascii_wordish(b) {
        return " "
      }

      // ASCII 正文 + CJK，通常补空格
      if is_ascii_wordish(a) && is_cjk_char(b) {
        return " "
      }

      ""
    }
    _ => ""
  }
}

///|
fn should_merge_hyphenated_word_piece(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()
  if l == "" || r == "" {
    return false
  }

  match (last_char_opt(l.to_owned()), first_char_opt(r.to_owned())) {
    (Some(a), Some(b)) => a == '-' && is_ascii_letter(b)
    _ => false
  }
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

  // Wrapped hyphen repair is a PDF-local line/span decision: once the raw span
  // proves it ended with a hyphen and the next span starts with lowercase text,
  // we should not keep the artificial boundary after line merge.
  if span_has_raw_trailing_hyphen_char(left_span) &&
    starts_with_lower_ascii(right_word) {
    return true
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

  let gap_ok = if left_len <= 2 || right_len <= 2 {
    span_gap_short_fragment_fallback_for_word_merge(left_span, right_span)
  } else {
    span_gap_very_tight_for_word_merge(left_span, right_span)
  }

  if !gap_ok {
    return false
  }

  (left_len >= 3 && right_len <= 3) ||
  (left_len <= 2 && right_len <= 2)
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
  ch == '.'
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

///|
/// block 文本聚合，行间默认用换行连接，方便 debug。
pub fn block_text(block : PdfTextBlock) -> String {
  let mut buf = ""
  for i = 0; i < block.lines.length(); i = i + 1 {
    if i > 0 {
      buf = buf + "\n"
    }
    buf = buf + line_text(block.lines[i])
  }
  buf
}

///|
/// 从字符数组生成包围盒。
pub fn chars_bbox(chars : Array[PdfChar]) -> PdfRect? {
  if chars.is_empty() {
    return None
  }
  let mut acc = chars[0].bbox
  for i = 1; i < chars.length(); i = i + 1 {
    acc = union_rect(acc, chars[i].bbox)
  }
  Some(acc)
}

///|
/// 从 span 数组生成包围盒。
pub fn spans_bbox(spans : Array[PdfTextSpan]) -> PdfRect? {
  if spans.is_empty() {
    return None
  }
  let mut acc = spans[0].bbox
  for i = 1; i < spans.length(); i = i + 1 {
    acc = union_rect(acc, spans[i].bbox)
  }
  Some(acc)
}

///|
/// 从 line 数组生成包围盒。
pub fn lines_bbox(lines : Array[PdfTextLine]) -> PdfRect? {
  if lines.is_empty() {
    return None
  }
  let mut acc = lines[0].bbox
  for i = 1; i < lines.length(); i = i + 1 {
    acc = union_rect(acc, lines[i].bbox)
  }
  Some(acc)
}

///|
/// line 内 char 总数。
pub fn line_char_count(line : PdfTextLine) -> Int {
  let mut total = 0
  for span in line.spans {
    total = total + span.chars.length()
  }
  total
}

///|
/// block 内 span 总数。
pub fn block_span_count(block : PdfTextBlock) -> Int {
  let mut total = 0
  for line in block.lines {
    total = total + line.spans.length()
  }
  total
}

///|
/// block 内 char 总数。
pub fn block_char_count(block : PdfTextBlock) -> Int {
  let mut total = 0
  for line in block.lines {
    total = total + line_char_count(line)
  }
  total
}

///|
/// source ref 数量辅助。
pub fn block_source_ref_count(block : PdfTextBlock) -> Int {
  block.source_refs.length()
}

///|
/// source ref 数量辅助。
pub fn line_source_ref_count(line : PdfTextLine) -> Int {
  line.source_refs.length()
}

///|
/// source ref 数量辅助。
pub fn span_source_ref_count(span : PdfTextSpan) -> Int {
  span.source_refs.length()
}

///|
/// source ref 调试字符串。
pub fn source_ref_to_string(source_ref : PdfSourceRef) -> String {
  let text_object = match source_ref.text_object_id {
    Some(v) => v.to_string()
    None => "None"
  }
  let content_order = match source_ref.content_order_index {
    Some(v) => v.to_string()
    None => "None"
  }
  let object_ref = match source_ref.source_object_ref {
    Some(v) => v
    None => "None"
  }

  "page=" +
  source_ref.page_index.to_string() +
  ",stream=" +
  source_ref.source_stream_index.to_string() +
  ",op=" +
  source_ref.source_op_index.to_string() +
  ",text_object=" +
  text_object +
  ",content_order=" +
  content_order +
  ",object_ref=" +
  object_ref
}
