///|
pub struct PdfConvertLine {
  page_index : Int
  line_index : Int
  text : String
  source_block_index : Int
  is_heading_candidate : Bool
  is_page_number_candidate : Bool

  // 新增：版面信号
  bbox : @model.PdfRect
  font_size : Double?
  font_name : String?
  indent_left : Double?
  line_gap_before : Double?
  line_gap_after : Double?
}

///|
pub enum PdfConvertBlockKind {
  Heading
  Paragraph
  Noise
} derive(Eq)

///|
pub struct PdfConvertBlock {
  page_index : Int
  block_index : Int
  kind : PdfConvertBlockKind
  text : String
  line_start : Int
  line_end : Int
  is_heading_candidate : Bool
  is_noise_candidate : Bool

  // 新增：块级版面信号
  bbox : @model.PdfRect
  dominant_font_size : Double?
  dominant_font_name : String?
  top_y : Double
  left_x : Double
  line_count : Int
}

///|
pub struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
  blocks : Array[PdfConvertBlock]
}

///|
pub struct PdfConvertDocument {
  pages : Array[PdfConvertPage]
}
