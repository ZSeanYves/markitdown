///|
pub struct PdfConvertLine {
  _page_index : Int
  line_index : Int
  text : String
  _source_block_index : Int
  source_block_line_count : Int
  source_block_kind : @model.PdfTextBlockKind
  source_block_bbox : @model.PdfRect
  source_block_dominant_font_size : Double?
  source_block_dominant_font_name : String?
  is_heading_candidate : Bool
  is_page_number_candidate : Bool
  is_header_footer_candidate : Bool
  is_artifact_candidate : Bool
  is_caption_candidate : Bool
  is_table_cell_candidate : Bool
  dominant_language : String?
  writing_direction : @model.PdfWritingDirection

  // 版面信号
  _bbox : @model.PdfRect
  font_size : Double?
  font_name : String?
  indent_left : Double?
  indent_right : Double?
  alignment_hint : String?
  line_gap_before : Double?
  _line_gap_after : Double?
  line_height : Double?
  baseline_y : Double?
  is_wrapped_candidate : Bool
  is_same_paragraph_with_prev_candidate : Bool
}

///|
pub enum PdfConvertBlockKind {
  Heading
  Paragraph
  Noise
} derive(Eq)

///|
pub struct PdfConvertBlock {
  _page_index : Int
  block_index : Int
  kind : PdfConvertBlockKind
  text : String
  rich_inlines : Array[@cor.Inline]?
  line_start : Int
  line_end : Int
  source_block_index : Int
  source_block_line_count : Int
  source_block_kind : @model.PdfTextBlockKind
  source_block_bbox : @model.PdfRect
  source_block_dominant_font_size : Double?
  source_block_dominant_font_name : String?
  is_heading_candidate : Bool
  is_noise_candidate : Bool
  is_header_footer_candidate : Bool
  is_artifact_candidate : Bool
  is_caption_candidate : Bool
  is_table_cell_candidate : Bool
  dominant_language : String?
  writing_direction : @model.PdfWritingDirection

  // 块级版面信号
  _bbox : @model.PdfRect
  dominant_font_size : Double?
  dominant_font_name : String?
  top_y : Double
  left_x : Double
  line_count : Int
  first_indent_left : Double?
  last_indent_left : Double?
  first_indent_right : Double?
  last_indent_right : Double?
  first_alignment_hint : String?
  last_alignment_hint : String?
  first_line_gap_before : Double?
  last_line_gap_after : Double?
  first_line_height : Double?
  last_line_height : Double?
  first_baseline_y : Double?
  last_baseline_y : Double?
  first_is_wrapped_candidate : Bool
  last_is_wrapped_candidate : Bool
  first_is_same_paragraph_with_prev_candidate : Bool
  last_is_same_paragraph_with_prev_candidate : Bool
}

///|
pub struct PdfConvertImage {
  _page_index : Int
  _image_index : Int
  path : String
  alt_text : String?
  _caption : String?
  _bbox : @model.PdfRect
  top_y : Double
  left_x : Double
  _width_px : Int
  _height_px : Int
  colorspace : String?
  bits_per_component : Int?
  image_filter : String?
  object_ref : String?
  inline_image : Bool
  source_refs_count : Int
  source_image_id : String
}

///|
pub struct PdfConvertColor {
  r : Int
  g : Int
  b : Int
}

///|
pub struct PdfConvertAnnotation {
  _page_index : Int
  _annotation_index : Int
  subtype : String
  flags : Int
  _bbox : @model.PdfRect
  uri : String?
  dest : String?
  target_page : Int?
  object_ref : String?
  contents : String?
  subject : String?
  color : PdfConvertColor?
}

///|
pub struct PdfConvertFormField {
  _page_index : Int
  _form_index : Int
  field_type : String
  flags : Int
  field_name : String?
  field_value : String?
  options : Array[String]
  checked_state : Bool?
  _bbox : @model.PdfRect?
}

///|
pub enum PdfConvertPageObject {
  TextBlock(PdfConvertBlock)
  Image(PdfConvertImage)
}

///|
pub struct PdfConvertPage {
  _page_index : Int
  media_box : @model.PdfRect?
  crop_box : @model.PdfRect?
  lines : Array[PdfConvertLine]
  blocks : Array[PdfConvertBlock]
  images : Array[PdfConvertImage]
  annotations : Array[PdfConvertAnnotation]
  forms : Array[PdfConvertFormField]
  objects : Array[PdfConvertPageObject]
}

///|
pub struct PdfConvertDocument {
  pages : Array[PdfConvertPage]
}
