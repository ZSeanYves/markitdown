///|
priv struct PdfConvertLine {
  _page_index : Int
  line_index : Int
  text : String
  _source_block_index : Int
  is_heading_candidate : Bool
  is_page_number_candidate : Bool

  // 版面信号
  _bbox : @model.PdfRect
  font_size : Double?
  font_name : String?
  indent_left : Double?
  line_gap_before : Double?
  _line_gap_after : Double?
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
  is_heading_candidate : Bool
  is_noise_candidate : Bool

  // 块级版面信号
  _bbox : @model.PdfRect
  dominant_font_size : Double?
  dominant_font_name : String?
  top_y : Double
  left_x : Double
  line_count : Int
}

///|
priv struct PdfConvertImage {
  _page_index : Int
  _image_index : Int
  path : String
  alt_text : String?
  caption : String?
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
  lines : Array[PdfConvertLine]
  blocks : Array[PdfConvertBlock]
  images : Array[PdfConvertImage]
  objects : Array[PdfConvertPageObject]
}

///|
priv struct PdfConvertDocument {
  pages : Array[PdfConvertPage]
}
