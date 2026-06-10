///|
pub(all) enum PdfV2WarningKind {
  UnsupportedCapability
  MalformedObject
  DecodeIssue
  EncryptedOrRestricted
  PerformanceCap
  LowSignal
  ModelUnavailable
  InternalInvariant
} derive(Eq)

///|
pub(all) struct PdfV2Warning {
  kind : PdfV2WarningKind
  severity : PdfV2Severity
  message : String
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_warning(
  kind : PdfV2WarningKind,
  severity : PdfV2Severity,
  message : String,
  source_refs : Array[PdfV2SourceRef],
  reason_tags : Array[String],
) -> PdfV2Warning {
  { kind, severity, message, source_refs, reason_tags }
}
