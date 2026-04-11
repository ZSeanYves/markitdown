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
  line_count : Int
  char_count : Int
  is_heading_candidate : Bool
  is_list_candidate : Bool
  is_noise_candidate : Bool
  is_cross_page_continuation_candidate : Bool
}
