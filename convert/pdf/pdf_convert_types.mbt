///|
priv struct PdfConvertLine {
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
priv enum PdfConvertBlockKind {
  Heading
  Paragraph
  Noise
} derive(Eq)

///|
priv struct PdfConvertBlock {
  _page_index : Int
  block_index : Int
  kind : PdfConvertBlockKind
  text : String
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
priv struct PdfConvertImage {
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
  source_image_id : String
}

///|
priv enum PdfConvertPageObject {
  TextBlock(PdfConvertBlock)
  Image(PdfConvertImage)
}

///|
priv struct PdfConvertPage {
  _page_index : Int
  media_box : @model.PdfRect?
  crop_box : @model.PdfRect?
  lines : Array[PdfConvertLine]
  blocks : Array[PdfConvertBlock]
  images : Array[PdfConvertImage]
  objects : Array[PdfConvertPageObject]
}

///|
priv struct PdfConvertDocument {
  pages : Array[PdfConvertPage]
}
