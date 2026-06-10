///|
pub(all) enum PdfV2WritingDirection {
  LeftToRight
  RightToLeft
  TopToBottom
  BottomToTop
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2TextStyleFlags {
  bold : Bool
  italic : Bool
  monospace : Bool
  serif : Bool
}

///|
pub(all) struct PdfV2Glyph {
  text : String
  bbox : PdfV2BBox
  source_ref : PdfV2SourceRef
  font_name : String?
  font_size : Double?
  style_flags : PdfV2TextStyleFlags
  writing_direction : PdfV2WritingDirection
  rotation_degrees : Double
  decode_confidence : Double
}

///|
pub(all) struct PdfV2Char {
  text : String
  bbox : PdfV2BBox
  source_refs : Array[PdfV2SourceRef]
  decode_confidence : Double
}

///|
pub(all) struct PdfV2Span {
  text : String
  bbox : PdfV2BBox
  source_refs : Array[PdfV2SourceRef]
  font_name : String?
  font_size : Double?
  style_flags : PdfV2TextStyleFlags
  writing_direction : PdfV2WritingDirection
  rotation_degrees : Double
  decode_confidence : Double
}

///|
pub(all) struct PdfV2Line {
  text : String
  bbox : PdfV2BBox
  source_refs : Array[PdfV2SourceRef]
  spans : Array[PdfV2Span]
  line_gap_before : Double?
  line_gap_after : Double?
  indent : Double?
  writing_direction : PdfV2WritingDirection
  rotation_degrees : Double
  decode_confidence : Double
}

///|
pub(all) struct PdfV2TextShapeFeatures {
  has_list_marker : Bool
  list_marker_text : String?
  has_caption_prefix : Bool
  caption_prefix_text : String?
  heading_shape_score : Double
  body_density_guard_score : Double
}

///|
pub(all) struct PdfV2GeometryFeatures {
  bbox : PdfV2BBox
  line_gap_before : Double?
  line_gap_after : Double?
  indent : Double?
  relative_x0 : Double
  relative_y0 : Double
  relative_width : Double
  relative_height : Double
}

///|
pub(all) struct PdfV2ClassifierReadyFeatures {
  text_preview : String
  geometry : PdfV2GeometryFeatures
  text_shape : PdfV2TextShapeFeatures
  source_refs : Array[PdfV2SourceRef]
  risk_tags : Array[String]
}

///|
pub(all) struct PdfV2TextBlock {
  text : String
  bbox : PdfV2BBox
  source_refs : Array[PdfV2SourceRef]
  lines : Array[PdfV2Line]
  font_name : String?
  font_size : Double?
  style_flags : PdfV2TextStyleFlags
  writing_direction : PdfV2WritingDirection
  rotation_degrees : Double
  decode_confidence : Double
  shape_features : PdfV2TextShapeFeatures
  geometry_features : PdfV2GeometryFeatures
  classifier_features : PdfV2ClassifierReadyFeatures
}

///|
pub fn pdf_v2_plain_text_style_flags() -> PdfV2TextStyleFlags {
  { bold: false, italic: false, monospace: false, serif: false }
}

///|
pub fn pdf_v2_empty_text_shape_features() -> PdfV2TextShapeFeatures {
  {
    has_list_marker: false,
    list_marker_text: None,
    has_caption_prefix: false,
    caption_prefix_text: None,
    heading_shape_score: 0.0,
    body_density_guard_score: 0.0,
  }
}

///|
pub fn pdf_v2_empty_geometry_features() -> PdfV2GeometryFeatures {
  {
    bbox: pdf_v2_empty_bbox(),
    line_gap_before: None,
    line_gap_after: None,
    indent: None,
    relative_x0: 0.0,
    relative_y0: 0.0,
    relative_width: 0.0,
    relative_height: 0.0,
  }
}

///|
pub fn pdf_v2_empty_classifier_ready_features() -> PdfV2ClassifierReadyFeatures {
  {
    text_preview: "",
    geometry: pdf_v2_empty_geometry_features(),
    text_shape: pdf_v2_empty_text_shape_features(),
    source_refs: [],
    risk_tags: [],
  }
}
