///|
/// 图片对象。
pub(all) struct PdfImageObject {
  id : String
  bbox : PdfRect
  width_px : Int
  height_px : Int
  colorspace : String?
  bits_per_component : Int?
  image_filter : String?
  object_ref : String?
  alt_text : String?
  inline_image : Bool
  source_refs : Array[PdfSourceRef]
}

///|
/// 矢量对象。
pub(all) enum PdfVectorKind {
  Line
  Rect
  Curve
  Path
  Fill
  Stroke
  Unknown
}

///|
pub(all) struct PdfVectorObject {
  id : String
  bbox : PdfRect
  kind : PdfVectorKind
  stroke_color : PdfColor?
  fill_color : PdfColor?
  stroke_width : Double?
  dash_pattern : Array[Int]
  source_refs : Array[PdfSourceRef]
}

///|
/// 注释对象。
pub(all) struct PdfAnnotationObject {
  id : String
  subtype : String
  bbox : PdfRect
  contents : String?
  subject : String?
  uri : String?
  dest : String?
  target_page : Int?
  color : PdfColor?
  object_ref : String?
  source_refs : Array[PdfSourceRef]
}

///|
/// 表单字段对象。
pub(all) struct PdfFormField {
  id : String
  field_type : String
  field_name : String?
  field_value : String?
  bbox : PdfRect?
  page_index : Int
  options : Array[String]
  checked_state : Bool?
  source_refs : Array[PdfSourceRef]
}

///|
/// 页面层模型。
pub(all) struct PdfPageModel {
  page_index : Int
  page_label : String?
  rotation : Int
  user_unit : Double?
  boxes : PdfPageBoxes
  text_blocks : Array[PdfTextBlock]
  images : Array[PdfImageObject]
  vectors : Array[PdfVectorObject]
  annotations : Array[PdfAnnotationObject]
  forms : Array[PdfFormField]
  reading_order_candidates : Array[String]
  artifact_candidates : Array[String]
  raw_content_stream_refs : Array[String]
}

///|
/// 文档元信息。
pub(all) struct PdfDocumentMetadata {
  title : String?
  author : String?
  subject : String?
  keywords : Array[String]
  creator : String?
  producer : String?
  creation_date : String?
  mod_date : String?
}

///|
/// 目录/书签项。
pub(all) struct PdfOutlineItem {
  title : String
  page_index : Int?
  dest : String?
  children : Array[PdfOutlineItem]
}

///|
/// 文档层模型。
pub(all) struct PdfDocumentModel {
  version : String
  page_count : Int
  metadata : PdfDocumentMetadata
  is_encrypted : Bool
  has_xref_stream : Bool
  has_object_stream : Bool
  outlines : Array[PdfOutlineItem]
  pages : Array[PdfPageModel]
}

///|
/// 页面文本块数统计。
pub fn page_text_block_count(page : PdfPageModel) -> Int {
  page.text_blocks.length()
}

///|
/// 页面对象总量统计，方便 debug。
pub fn page_object_count(page : PdfPageModel) -> Int {
  page.text_blocks.length() +
  page.images.length() +
  page.vectors.length() +
  page.annotations.length() +
  page.forms.length()
}
