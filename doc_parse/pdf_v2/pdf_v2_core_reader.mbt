///|
fn open_pdf_core_v2_scaffold_reader(
  bytes : Bytes,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreDocument {
  let version = pdf_v2_probe_header_version(bytes)
  let source_ref = pdf_v2_source_ref_for_page(0)
  let warnings : Array[PdfV2Warning] = [
    pdf_v2_reader_base_removed_warning(version, source_ref),
  ]
  let risks : Array[PdfV2Risk] = [
    pdf_v2_reader_base_removed_risk(version, source_ref),
  ]
  let summary = pdf_v2_core_source_summary(bytes.length(), 0, true, options)
  {
    bytes_len: bytes.length(),
    version,
    page_count: 0,
    pages: [],
    objects: [],
    content_streams: [],
    text_events: [],
    capabilities: pdf_v2_core_capability_matrix(),
    warnings,
    risks,
    scanned_once: true,
    scan_boundary: options.scan_boundary,
    fallback_policy: options.fallback_policy,
    runtime_closure_policy: options.runtime_closure_policy,
    source_summary: summary,
  }
}

///|
fn pdf_v2_probe_header_version(bytes : Bytes) -> String? {
  let prefix = [0x25, 0x50, 0x44, 0x46, 0x2D] // %PDF-
  if bytes.length() < prefix.length() {
    return None
  }
  for i in 0..<prefix.length() {
    if bytes[i].to_int() != prefix[i] {
      return None
    }
  }
  let chars : Array[Char] = []
  let mut i = prefix.length()
  while i < bytes.length() {
    let value = bytes[i].to_int()
    if value == 0x0A || value == 0x0D || value == 0x20 || value == 0x09 {
      break
    }
    if !((value >= 0x30 && value <= 0x39) || value == 0x2E) {
      break
    }
    chars.push(bytes[i].to_char())
    i = i + 1
  }
  if chars.is_empty() {
    None
  } else {
    Some(String::from_array(chars))
  }
}

///|
fn pdf_v2_reader_base_removed_warning(
  version : String?,
  source_ref : PdfV2SourceRef,
) -> PdfV2Warning {
  let header_tag = match version {
    Some(_) => "pdf_header_recognized"
    None => "pdf_header_missing_or_malformed"
  }
  pdf_v2_warning_for_context(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      Some(source_ref),
      None,
      Some(0),
      [],
    ),
    "PDF v2 self-written core reader base has been removed; mbtpdf-backed base is planned",
    [
      "self_written_core_removed", "mbtpdf_backend_planned", "reader_scaffold_only",
      header_tag, "fail_closed", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
fn pdf_v2_reader_base_removed_risk(
  version : String?,
  source_ref : PdfV2SourceRef,
) -> PdfV2Risk {
  let header_tag = match version {
    Some(_) => "pdf_header_recognized"
    None => "pdf_header_missing_or_malformed"
  }
  pdf_v2_risk_for_context(
    PdfV2RiskKind::PartialCapability,
    PdfV2RiskSeverity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      Some(source_ref),
      None,
      Some(0),
      [],
    ),
    "PDF v2 core reader is scaffold-only until the mbtpdf-backed performance base is integrated",
    [
      "self_written_core_removed", "mbtpdf_backend_planned", "reader_scaffold_only",
      header_tag, "abstain_candidate", "no_fallback",
    ],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}
