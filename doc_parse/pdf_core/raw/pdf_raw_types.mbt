///|
/// 底层 PDF 对象引用。
pub(all) struct RawPdfRef {
  obj_num : Int
  gen_num : Int
}

///|
/// 原始来源引用。
pub struct RawSourceRef {
  page_index : Int
  source_stream_index : Int
  source_op_index : Int
  text_object_id : Int?
  content_order_index : Int?
  source_object_ref : RawPdfRef?
}

///|
/// 原始字体信息。
pub struct RawFontInfo {
  font_name : String?
  font_family : String?
  font_size : Double?
  is_bold : Bool
  is_italic : Bool
  is_monospace : Bool
  fill_color : @model.PdfColor?
  stroke_color : @model.PdfColor?
  char_spacing : Double?
  word_spacing : Double?
  text_rise : Double?
  scale_x : Double?
}

///|
/// 原始解码 glyph。
pub struct RawDecodedGlyph {
  unicode : String
  raw_bytes : Bytes?
  decoded_text : String
  origin : @model.PdfPoint?
  bbox : @model.PdfRect?
  advance_width : Double?
  glyph_width : Double?
  font_name : String?
  font_size : Double?
  fill_color : @model.PdfColor?
  rotation : Double?
  is_ligature : Bool
  is_compat_glyph : Bool
  decode_confidence : Double?
  source : RawSourceRef
}

///|
/// 原始文本操作类型。
pub(all) enum RawTextOpKind {
  ShowText // Tj
  ShowTextArray // TJ
  MoveText // Td / TD
  NextLine // T*
  Quote // '
  DoubleQuote // "
  BeginText // BT
  EndText // ET
  SetFont // Tf
  FormXObjectText // 递归 form xobject 时生成
  Unknown
}

///|

///|
/// 原始文本操作。
pub struct RawTextOp {
  kind : RawTextOpKind
  page_index : Int
  source_stream_index : Int
  source_op_index : Int
  text_object_id : Int?
  content_order_index : Int?
  raw_text : String?
  glyphs : Array[RawDecodedGlyph]
  origin : @model.PdfPoint?
  bbox : @model.PdfRect?
  font : RawFontInfo?
  /// 该文本 op 前是否存在显式断行/换段信号
  break_before : Bool
  /// 断行原因，来自 adapter 内部状态
  break_reason : String?
}

///|
/// 原始图片负载类型。

///|
/// 原始图片负载类型。
pub(all) enum RawImagePayload {
  Jpeg(Array[Byte])
  Jpeg2000(Array[Byte])
  Jbig2(Array[Byte], Int?)
  RawRgb24(Array[Byte])
}

///|
/// 原始图片信息。
pub(all) struct RawImageInfo {
  id : String
  page_index : Int
  object_ref : RawPdfRef?
  bbox : @model.PdfRect?
  width_px : Int
  height_px : Int
  colorspace : String?
  bits_per_component : Int?
  image_filter : String?
  alt_text : String?
  inline_image : Bool
  payload : RawImagePayload?
  source_refs : Array[RawSourceRef]
}

///|
/// 原始注释信息。
pub(all) struct RawAnnotationInfo {
  id : String
  page_index : Int
  object_ref : RawPdfRef?
  subtype : String
  bbox : @model.PdfRect?
  contents : String?
  subject : String?
  uri : String?
  dest : String?
  target_page : Int?
  color : @model.PdfColor?
  source_refs : Array[RawSourceRef]
}

///|
/// 原始页面结果：这是 adapter 层吐给 text/image/annot build 层的统一页内原始容器。
pub struct RawPdfPageExtract {
  page_index : Int
  raw_page_ref : RawPdfRef?
  text_ops : Array[RawTextOp]
  images : Array[RawImageInfo]
  annotations : Array[RawAnnotationInfo]
  raw_content_stream_refs : Array[String]
}

///|
/// 原始文档结果。
pub struct RawPdfDocumentExtract {
  version : String
  page_count : Int
  is_encrypted : Bool
  has_xref_stream : Bool
  has_object_stream : Bool
  metadata_title : String?
  metadata_author : String?
  metadata_subject : String?
  metadata_keywords : Array[String]
  metadata_creator : String?
  metadata_producer : String?
  metadata_creation_date : String?
  metadata_mod_date : String?
  pages : Array[RawPdfPageExtract]
}
