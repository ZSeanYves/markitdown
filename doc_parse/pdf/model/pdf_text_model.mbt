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

      if is_sign_prefix_for_number(a, b) {
        return ""
      }

      if should_insert_space_after_existing_hyphen(l.to_owned(), r.to_owned()) {
        return " "
      }

      if should_glue_after_existing_hyphen_without_space(
          l.to_owned(),
          r.to_owned(),
        ) {
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

      if should_insert_space_before_open_punct(a, b) {
        return " "
      }

      // 右边是纯标点开头：一般不补
      if is_right_tight_punct(b) {
        return ""
      }

      if should_tighten_numeric_separator_boundary(l.to_owned(), b) {
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
