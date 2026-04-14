///|
pub(all) enum PdfConvertBlockKind {
  Heading
  Paragraph
  Noise
}

///|
pub(all) struct PdfConvertLine {
  page_index : Int
  text : String
  is_heading_candidate : Bool
  is_page_number_candidate : Bool
}

///|
pub(all) struct PdfConvertBlock {
  page_index : Int
  kind : PdfConvertBlockKind
  text : String
  heading_level : Int
  line_count : Int
}

///|
pub(all) struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
  blocks : Array[PdfConvertBlock]
}

///|
pub(all) struct PdfConvertDocument {
  pages : Array[PdfConvertPage]
  blocks : Array[PdfConvertBlock]
}
