///|
pub(all) enum PdfV2CapabilityStatus {
  Supported
  MetadataOnly
  Partial
  NotAttempted
  Unsupported
  Capped
  Failed
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2UnsupportedCapabilityReport {
  capability : String
  status : PdfV2CapabilityStatus
  page_index : Int?
  object_ref : String?
  source_ref : PdfV2SourceRef?
  message : String
  reason_tags : Array[String]
  severity : PdfV2Severity
}

///|
pub(all) struct PdfV2PartialFactReport {
  fact_kind : String
  page_index : Int?
  object_ref : String?
  source_ref : PdfV2SourceRef?
  available_fields : Array[String]
  missing_fields : Array[String]
  status : PdfV2CapabilityStatus
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}
