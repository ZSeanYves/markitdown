///|
pub(all) enum PdfV2SourceEventKind {
  DocumentStart
  PageStart
  ObjectRef
  PageRef
  ResourceRef
  ContentStreamRef
  TextPayload
  Diagnostic
} derive(Eq)

///|
pub(all) struct PdfV2SourceTextPayload {
  text : String
  raw_bytes : Bytes?
  decoded_unicode : String?
  bbox : @pdfv2.PdfV2Rect?
  origin : @pdfv2.PdfV2Point?
  quad : @pdfv2.PdfV2Quad?
  advance_width : Double?
  glyph_width : Double?
  font_name : String?
  font_family : String?
  font_size : Double?
  style_flags : Array[String]
  fill_color : @pdfv2.PdfV2Color?
  stroke_color : @pdfv2.PdfV2Color?
  rotation : Int
  writing_direction : @pdfv2.PdfV2WritingDirection
  content_order_index : Int?
  decode_confidence : Double?
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2SourceEventDiagnostic {
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
}

///|
pub(all) struct PdfV2SourceEvent {
  id : String
  kind : PdfV2SourceEventKind
  capability : @pdfv2.PdfV2CoreCapabilityKind
  source_ref : @pdfv2.PdfV2SourceRef?
  object_ref : String?
  page_index : Int?
  resource_ref : @pdfv2.PdfV2ResourceRef?
  text_payload : PdfV2SourceTextPayload?
  reason_tags : Array[String]
  severity : @pdfv2.PdfV2Severity
  recoverability : @pdfv2.PdfV2Recoverability
  diagnostics : PdfV2SourceEventDiagnostic
}

///|
pub(all) struct PdfV2SourcePage {
  page_index : Int
  page_source_ref : @pdfv2.PdfV2SourceRef
  object_refs : Array[String]
  resource_refs : Array[@pdfv2.PdfV2ResourceRef]
  events : Array[PdfV2SourceEvent]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
}

///|
pub(all) struct PdfV2SourceCapabilityCoverage {
  capability : @pdfv2.PdfV2CoreCapabilityKind
  required : Bool
  observed : Bool
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2SourceSummary {
  bytes_len : Int
  page_count : Int
  event_count : Int
  warning_count : Int
  risk_count : Int
  diagnostic_event_count : Int
  capability_coverage : Array[PdfV2SourceCapabilityCoverage]
  scanned_once : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
}

///|
pub(all) struct PdfV2SourceDocument {
  summary : PdfV2SourceSummary
  pages : Array[PdfV2SourcePage]
  events : Array[PdfV2SourceEvent]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
}
