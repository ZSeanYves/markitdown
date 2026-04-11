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
}

///|
priv enum PdfConvertBlockKind {
  Heading
  ListItem
  Paragraph
} derive(Eq)

///|
priv struct PdfConvertBlock {
  kind : PdfConvertBlockKind
  text : String
  page_index : Int
  line_start : Int
  line_end : Int
  is_noise : Bool
  noise_reason : String?
  is_cross_page_continuation_candidate : Bool

  list_ordered : Bool
  list_level : Int

  heading_level : Int
}