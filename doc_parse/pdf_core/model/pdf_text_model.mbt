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
  let mut buf = ""
  for i = 0; i < line.spans.length(); i = i + 1 {
    buf = buf + line.spans[i].text
  }
  buf
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
