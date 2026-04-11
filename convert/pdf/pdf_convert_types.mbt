///|
priv struct PdfConvertLine {
  text : String
  source_event_start : Int
  source_event_end : Int
  font_name : String?
  font_size : Double?
  is_explicit_break : Bool
}

///|
priv struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
}

///|
priv enum PdfConvertBlockKind {
  StandaloneLine
  Paragraph
}

///|
priv struct PdfConvertBlock {
  kind : PdfConvertBlockKind
  text : String
  page_index : Int
  line_start : Int
  line_end : Int
}
