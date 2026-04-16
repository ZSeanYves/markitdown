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
/// 文本块弱类型，注意这是 pdf_core 内部候选，不是最终 convert 语义。
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
    let cur = line.spans[i].text
    buf = buf + glue_between_spans(buf, cur) + cur
  }

  buf
}

///|
pub fn glue_between_spans(left : String, right : String) -> String {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return ""
  }

  let lc = last_char_opt(l.to_string())
  let rc = first_char_opt(r.to_string())

  match (lc, rc) {
    (Some(a), Some(b)) => {
      // 中文连续文本不补空格
      if is_cjk_char(a) && is_cjk_char(b) {
        return ""
      }

      // 断词场景：inter- + national
      if should_merge_hyphenated_word_piece(l.to_string(), r.to_string()) {
        return ""
      }

      // 新增：明显像英文词内续接，不补空格
      if should_glue_english_word_piece(l.to_string(), r.to_string()) {
        return ""
      }

      // 左边是 bullet，右边是正文：补空格
      if should_insert_space_after_bullet_marker(l.to_string(), r.to_string()) {
        return " "
      }

      // 左侧编号项（如 2)）后接正文：补空格
      if should_insert_space_after_numbered_marker(l.to_string(), r.to_string()) {
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

  match (last_char_opt(l.to_string()), first_char_opt(r.to_string())) {
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

  match (last_char_opt(l.to_string()), first_char_opt(right.to_string())) {
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

  match first_char_opt(r.to_string()) {
    Some(ch) => !is_spacing_or_punct(ch)
    None => false
  }
}

///|
fn should_glue_english_word_piece(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return false
  }

  let lc = last_char_opt(l.to_string())
  let rc = first_char_opt(r.to_string())

  match (lc, rc) {
    (Some(a), Some(b)) => {
      if is_common_standalone_english_word(last_ascii_word(l.to_string())) &&
        is_common_standalone_english_word(first_ascii_word(r.to_string())) {
        return false
      }
      if is_common_standalone_english_word(last_ascii_word(l.to_string())) {
        return false
      }
      if is_short_upper_acronym(last_ascii_word(l.to_string())) {
        return false
      }
      if !is_ascii_letter(a) || !is_ascii_letter(b) {
        return false
      }

      let left_word = last_ascii_word(l.to_string())
      let right_word = first_ascii_word(r.to_string())

      if is_common_english_suffix_piece(right_word) &&
        last_ascii_word_len(l.to_string()) >= 3 {
        return true
      }
      if right_word == "rm" && left_word.has_suffix("fi") {
        return true
      }
      if is_common_bound_english_prefix(left_word) &&
        first_ascii_word_len(r.to_string()) >= 4 {
        return true
      }

      let left_len = last_ascii_word_len(l.to_string())
      let right_len = first_ascii_word_len(r.to_string())

      // 左右都很短：高概率是 ligature / 词内碎片
      // fi + rst, con + firm, uni + fied
      if left_len <= 3 && right_len <= 4 {
        return true
      }

      // 左边极短且右边不是常见独立短词：也倾向词内续接
      if left_len <= 2 && !is_common_short_english_word_start(r.to_string()) {
        return true
      }

      false
    }
    _ => false
  }
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

  text[start:arr.length()].to_string()
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

  text[:end].to_string()
}

///|
fn is_common_bound_english_prefix(text : String) -> Bool {
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
fn is_common_short_english_word_start(text : String) -> Bool {
  let t = text.trim().to_lower()

  t.has_prefix("a") ||
  t.has_prefix("an") ||
  t.has_prefix("as") ||
  t.has_prefix("at") ||
  t.has_prefix("be") ||
  t.has_prefix("by") ||
  t.has_prefix("do") ||
  t.has_prefix("go") ||
  t.has_prefix("he") ||
  t.has_prefix("if") ||
  t.has_prefix("in") ||
  t.has_prefix("is") ||
  t.has_prefix("it") ||
  t.has_prefix("me") ||
  t.has_prefix("my") ||
  t.has_prefix("no") ||
  t.has_prefix("of") ||
  t.has_prefix("on") ||
  t.has_prefix("or") ||
  t.has_prefix("so") ||
  t.has_prefix("to") ||
  t.has_prefix("up") ||
  t.has_prefix("us") ||
  t.has_prefix("we") ||
  t.has_prefix("yet")
}

///|
fn is_common_standalone_english_word(text : String) -> Bool {
  let t = text.trim().to_lower()
  t == "a" ||
  t == "an" ||
  t == "and" ||
  t == "as" ||
  t == "at" ||
  t == "be" ||
  t == "by" ||
  t == "for" ||
  t == "from" ||
  t == "in" ||
  t == "into" ||
  t == "is" ||
  t == "it" ||
  t == "not" ||
  t == "of" ||
  t == "on" ||
  t == "or" ||
  t == "the" ||
  t == "to" ||
  t == "with" ||
  t == "yet"
}

///|
fn is_common_english_suffix_piece(text : String) -> Bool {
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
fn last_ascii_word_len(text : String) -> Int {
  let mut n = 0
  let arr = text.to_array()
  let mut i = arr.length() - 1

  while i >= 0 {
    let ch = arr[i]
    if is_ascii_letter(ch) {
      n = n + 1
      if i == 0 {
        break
      }
      i = i - 1
    } else {
      break
    }
  }

  n
}

///|
fn first_ascii_word_len(text : String) -> Int {
  let mut n = 0
  for ch in text {
    if is_ascii_letter(ch) {
      n = n + 1
    } else {
      break
    }
  }
  n
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
