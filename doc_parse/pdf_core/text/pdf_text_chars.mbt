///|
/// 页级字符结果。
pub struct PdfPageChars {
  page_index : Int
  chars : Array[@model.PdfChar]
}

///|
/// 文档级字符结果。
pub struct PdfDocumentChars {
  pages : Array[PdfPageChars]
}

///|
/// 从 raw 文档抽取字符层。
pub fn build_document_chars(
  raw : @raw.RawPdfDocumentExtract,
) -> PdfDocumentChars {
  let pages = Array::new()
  for page in raw.pages {
    pages.push(build_page_chars(page))
  }
  { pages, }
}

///|
/// 从单页 raw 结果抽取字符层。
pub fn build_page_chars(raw_page : @raw.RawPdfPageExtract) -> PdfPageChars {
  let chars = Array::new()
  for op in raw_page.text_ops {
    let op_chars = build_chars_from_text_op(op)
    chars.append(op_chars)
  }
  { page_index: raw_page.page_index, chars }
}

///|
/// 从单个 RawTextOp 抽字符。
///
/// 规则：
/// - 第一个 glyph 继承 op.break_before / op.break_reason
/// - 后续 glyph 一律不带 break
pub fn build_chars_from_text_op(op : @raw.RawTextOp) -> Array[@model.PdfChar] {
  let out = Array::new()

  for i = 0; i < op.glyphs.length(); i = i + 1 {
    let glyph = op.glyphs[i]
    let break_before = if i == 0 { op.break_before } else { false }
    let break_reason = if i == 0 { op.break_reason } else { None }

    out.push(build_char_from_glyph(glyph, break_before, break_reason))
  }

  out
}

///|
/// 从 RawDecodedGlyph 映射到 PdfChar。
pub fn build_char_from_glyph(
  glyph : @raw.RawDecodedGlyph,
  break_before : Bool,
  break_reason : String?,
) -> @model.PdfChar {
  {
    unicode: glyph.unicode,
    raw_bytes: glyph.raw_bytes,
    decoded_text: glyph.decoded_text,
    bbox: glyph.bbox.unwrap_or(default_rect()),
    origin: glyph.origin.unwrap_or(default_point()),
    quad: None,
    advance_width: glyph.advance_width,
    glyph_width: glyph.glyph_width,
    font_name: glyph.font_name,
    font_size: glyph.font_size,
    fill_color: glyph.fill_color,
    rotation: glyph.rotation,
    is_ligature: glyph.is_ligature,
    is_compat_glyph: glyph.is_compat_glyph,
    decode_confidence: glyph.decode_confidence,
    source: map_source_ref(glyph.source),
    break_before,
    break_reason,
  }
}

///|
/// RawSourceRef -> PdfSourceRef
fn map_source_ref(source : @raw.RawSourceRef) -> @model.PdfSourceRef {
  {
    page_index: source.page_index,
    source_stream_index: source.source_stream_index,
    source_op_index: source.source_op_index,
    text_object_id: source.text_object_id,
    content_order_index: source.content_order_index,
    source_object_ref: map_raw_ref(source.source_object_ref),
  }
}

///|
fn map_raw_ref(raw_ref : @raw.RawPdfRef?) -> String? {
  match raw_ref {
    Some(r) => Some(r.obj_num.to_string() + " " + r.gen_num.to_string() + " R")
    None => None
  }
}

///|
fn default_point() -> @model.PdfPoint {
  { x: 0.0, y: 0.0 }
}

///|
fn default_rect() -> @model.PdfRect {
  { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
}
