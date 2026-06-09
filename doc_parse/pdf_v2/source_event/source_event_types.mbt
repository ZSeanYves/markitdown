///|
pub(all) enum PdfV2SourceEventKind {
  DocumentStart
  PageStart
  ObjectRef
  PageRef
  ResourceRef
  ContentStreamRef
  Diagnostic
} derive(Eq)

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
