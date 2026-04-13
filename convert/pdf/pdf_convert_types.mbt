///|
priv struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
}

///|
priv struct PdfConvertLine {
  text : String
  page_index : Int
  line_index : Int
  source_event_start : Int
  source_event_end : Int
  is_paragraph_break : Bool
  strong_break_after : Bool
}

///|
priv enum PdfConvertBlockKind {
  Heading
  Paragraph
} derive(Eq)

///|
priv struct PdfConvertBlock {
  kind : PdfConvertBlockKind
  text : String
  page_index : Int
  line_start : Int
  line_end : Int
  heading_level : Int
}
