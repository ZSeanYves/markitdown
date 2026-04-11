///|
priv struct PdfExtractResult {
  _backend_name : String
  text : String
  quality_accepted : Bool
  _native_stats : @pdfc.PdfNativeDocumentResult?
}

///|
priv struct PdfConvertLine {
  text : String
  page_index : Int
  line_index : Int
  source_event_start : Int
  source_event_end : Int
  is_explicit_break : Bool
}

///|
priv struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
}

///|
priv enum PdfConvertBlockKind {
  Heading
  Paragraph
}

///|
priv struct PdfConvertBlock {
  kind : PdfConvertBlockKind
  text : String
  page_index : Int
  line_start : Int
  line_end : Int
  char_count : Int
  is_noise : Bool
  is_cross_page_continuation_candidate : Bool
}
