///|
pub(all) struct PdfV2Image {
  id : String
  page_index : Int
  bbox : PdfV2Rect
  width_px : Int?
  height_px : Int?
  colorspace : String?
  filter : String?
  object_ref : String?
  alt_text : String?
  inline_image : Bool
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2Vector {
  id : String
  page_index : Int
  bbox : PdfV2Rect
  kind : String
  stroke_color : PdfV2Color?
  fill_color : PdfV2Color?
  stroke_width : Double?
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2Annotation {
  id : String
  page_index : Int
  subtype : String
  flags : Int
  bbox : PdfV2Rect
  contents : String?
  uri : String?
  dest : String?
  target_page : Int?
  object_ref : String?
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2Form {
  id : String
  page_index : Int
  field_type : String
  flags : Int
  field_name : String?
  field_value : String?
  bbox : PdfV2Rect?
  options : Array[String]
  checked_state : Bool?
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2OutlineItem {
  title : String
  page_index : Int?
  dest : String?
  children : Array[PdfV2OutlineItem]
}

///|
pub(all) struct PdfV2Destination {
  id : String
  page_index : Int?
  object_ref : String?
  source_refs : Array[PdfV2SourceRef]
}
