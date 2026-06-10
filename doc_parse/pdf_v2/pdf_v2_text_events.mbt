///|
pub(all) enum PdfV2TextDecodeConfidence {
  High
  Medium
  Low
  Unknown
  Failed
} derive(Eq)

///|
pub(all) enum PdfV2TextShowOperatorKind {
  Tj
  TJ
  SingleQuote
  DoubleQuote
  UnknownTextShow
} derive(Eq)

///|
pub(all) struct PdfV2TextMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
pub(all) struct PdfV2TextStateFact {
  font_name_or_ref : String?
  font_size : Double?
  text_matrix : PdfV2TextMatrix?
  line_matrix : PdfV2TextMatrix?
  text_rendering_mode : Int?
  char_spacing : Double?
  word_spacing : Double?
  horizontal_scaling : Double?
  leading : Double?
  rise : Double?
  source_ref : PdfV2SourceRef
  confidence : PdfV2TextDecodeConfidence
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2TextShowFact {
  raw_operator_kind : PdfV2TextShowOperatorKind
  raw_bytes_or_string : String
  decoded_text : String?
  font_ref : String?
  font_size : Double?
  text_matrix_snapshot : PdfV2TextMatrix?
  source_ref : PdfV2SourceRef
  decode_confidence : PdfV2TextDecodeConfidence
  warnings : Array[PdfV2Warning]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2GlyphCandidateFact {
  raw_code : Int?
  raw_bytes : String
  unicode_candidate : String?
  glyph_name : String?
  font_ref : String?
  advance_width : Double?
  text_position : PdfV2TextMatrix?
  bbox : PdfV2BBox?
  decode_confidence : PdfV2TextDecodeConfidence
  source_ref : PdfV2SourceRef
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_identity_text_matrix() -> PdfV2TextMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}
