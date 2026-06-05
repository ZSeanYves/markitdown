///|
test "pdf error classifier maps detail kinds" {
  let encrypted = classify_pdf_error(
    @api.make_pdf_adapter_failed_error("open failed: encrypted document"),
  )
  match encrypted.kind {
    PdfErrorKind::Encrypted => ()
    _ => fail("expected encrypted classifier kind")
  }
  match encrypted.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected encrypted mapping to be best-effort message")
  }
  assert_eq(encrypted.message, "AdapterFailed: open failed: encrypted document")

  let partial = classify_pdf_error(
    @api.make_pdf_build_failed_error("raw pages length != block pages length"),
  )
  match partial.kind {
    PdfErrorKind::PartialPageFailure => ()
    _ => fail("expected partial page failure classifier kind")
  }
  match partial.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected partial mapping to be best-effort message")
  }

  let object_stream = classify_pdf_error(
    @api.make_pdf_unsupported_error("object stream not supported"),
  )
  match object_stream.kind {
    PdfErrorKind::UnsupportedObjectStream => ()
    _ => fail("expected unsupported object stream classifier kind")
  }
  match object_stream.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected object stream mapping to be best-effort message")
  }

  let filter = classify_pdf_error(
    @api.make_pdf_unsupported_error("unsupported filter /LZWDecode"),
  )
  match filter.kind {
    PdfErrorKind::UnsupportedFilter => ()
    _ => fail("expected unsupported filter classifier kind")
  }
  match filter.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected filter mapping to be best-effort message")
  }

  let malformed = classify_pdf_error(
    @api.make_pdf_adapter_failed_error("malformed content stream"),
  )
  match malformed.kind {
    PdfErrorKind::MalformedContentStream => ()
    _ => fail("expected malformed content stream classifier kind")
  }
  match malformed.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ =>
      fail(
        "expected malformed content stream mapping to be best-effort message",
      )
  }

  let font_encoding = classify_pdf_error(
    @api.make_pdf_unsupported_error("missing font encoding"),
  )
  match font_encoding.kind {
    PdfErrorKind::MissingFontEncoding => ()
    _ => fail("expected missing font encoding classifier kind")
  }
  match font_encoding.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected font encoding mapping to be best-effort message")
  }

  let to_unicode = classify_pdf_error(
    @api.make_pdf_unsupported_error("bad ToUnicode map"),
  )
  match to_unicode.kind {
    PdfErrorKind::BadToUnicode => ()
    _ => fail("expected bad ToUnicode classifier kind")
  }
  match to_unicode.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected ToUnicode mapping to be best-effort message")
  }

  let low_signal = classify_pdf_error(
    @api.make_pdf_unsupported_error("low signal extraction"),
  )
  match low_signal.kind {
    PdfErrorKind::LowSignalExtraction => ()
    _ => fail("expected low signal classifier kind")
  }
  match low_signal.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected low signal mapping to be best-effort message")
  }

  let adapter = classify_pdf_error(
    @api.make_pdf_adapter_failed_error("open failed: missing file"),
  )
  match adapter.kind {
    PdfErrorKind::AdapterFailed => ()
    _ => fail("expected adapter failed classifier kind")
  }
  match adapter.mapping {
    PdfErrorMappingKind::DirectVariant => ()
    _ => fail("expected adapter failure to keep direct variant mapping")
  }

  let unsupported = classify_pdf_error(
    @api.make_pdf_unsupported_error("some unsupported detail"),
  )
  match unsupported.kind {
    PdfErrorKind::Unsupported => ()
    _ => fail("expected unsupported classifier kind")
  }
  match unsupported.mapping {
    PdfErrorMappingKind::DirectVariant => ()
    _ => fail("expected unsupported fallback to keep direct variant mapping")
  }
}

///|
test "pdf error classifier avoids over-reporting reserved kinds" {
  let malformed = classify_pdf_error(
    @api.make_pdf_adapter_failed_error("invalid pdf trailer"),
  )
  match malformed.kind {
    PdfErrorKind::Malformed => ()
    _ => fail("expected malformed classifier kind")
  }
  match malformed.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ => fail("expected malformed mapping to be best-effort message")
  }

  let generic_build = classify_pdf_error(
    @api.make_pdf_build_failed_error("unexpected internal build failure"),
  )
  match generic_build.kind {
    PdfErrorKind::BuildFailed => ()
    _ => fail("generic build errors should remain build failed")
  }
  match generic_build.mapping {
    PdfErrorMappingKind::DirectVariant => ()
    _ => fail("generic build errors should keep direct variant mapping")
  }

  let generic_unsupported = classify_pdf_error(
    @api.make_pdf_unsupported_error("unsupported annotation subtype"),
  )
  match generic_unsupported.kind {
    PdfErrorKind::Unsupported => ()
    _ => fail("generic unsupported errors should remain unsupported")
  }
  match generic_unsupported.mapping {
    PdfErrorMappingKind::DirectVariant => ()
    _ => fail("generic unsupported errors should keep direct variant mapping")
  }
}

///|
test "pdf typed issue classifier helpers prefer inspect issues" {
  let issue = {
    kind: PdfInspectIssueKind::PartialPageFailure,
    severity: PdfInspectSeverity::Error,
    source: PdfInspectIssueSource::Model,
    page_index: None,
    object_ref: None,
    source_ref: None,
    message: "document model exposes fewer pages than declared page_count",
  }

  let info = match classify_pdf_inspect_issue(issue) {
    Some(v) => v
    None => fail("partial page failure issue should classify")
  }
  match info.kind {
    PdfErrorKind::PartialPageFailure => ()
    _ => fail("typed inspect issue should classify to partial page failure")
  }
  match info.mapping {
    PdfErrorMappingKind::TypedIssue => ()
    _ => fail("typed inspect issue should use typed issue mapping")
  }

  let err = classify_pdf_error_with_issues(
    @api.make_pdf_build_failed_error("generic build failure"),
    [issue],
  )
  match err.kind {
    PdfErrorKind::PartialPageFailure => ()
    _ => fail("typed issue classifier should override generic build failure")
  }
  match err.mapping {
    PdfErrorMappingKind::TypedIssue => ()
    _ => fail("typed issue classifier should mark typed issue mapping")
  }
}

///|
test "pdf raw warning issues do not over-promote reserved kinds" {
  let raw_warning = {
    kind: PdfInspectIssueKind::AnnotationParseWarning,
    severity: PdfInspectSeverity::Warning,
    source: PdfInspectIssueSource::Raw,
    page_index: Some(0),
    object_ref: Some("12 0 R"),
    source_ref: None,
    message: "annotation missing or malformed /Rect bbox",
  }

  match classify_pdf_inspect_issue(raw_warning) {
    Some(_) =>
      fail("annotation parse warnings should remain inspect-only findings")
    None => ()
  }

  let info = classify_pdf_error_with_issues(
    @api.make_pdf_unsupported_error("unsupported filter /LZWDecode"),
    [raw_warning],
  )
  match info.kind {
    PdfErrorKind::UnsupportedFilter => ()
    _ =>
      fail(
        "reserved unsupported filter kind should still come from message mapping",
      )
  }
  match info.mapping {
    PdfErrorMappingKind::BestEffortMessage => ()
    _ =>
      fail(
        "non-classifying raw warnings should not upgrade reserved kinds to typed issue mapping",
      )
  }
}
