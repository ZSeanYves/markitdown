///|
test "source event embeds malformed object diagnostic context" {
  let warning = @pdfv2.warn_malformed_object("21 0 R", Some(se_source_ref(2)))
  let event = @source_event.pdf_v2_event_for_warning(
    "malformed_object",
    @source_event.PdfV2SourceEventKind::Diagnostic,
    warning,
  )
  assert_true(
    event.capability == @pdfv2.PdfV2CoreCapabilityKind::MalformedObject,
  )
  assert_true(event.object_ref == Some("21 0 R"))
  assert_true(event.page_index == Some(2))
  assert_eq(event.reason_tags[0], "malformed_object")
  assert_eq(event.diagnostics.warnings.length(), 1)
}

///|
test "source events preserve filter diagnostic warning and risk" {
  let filter = @pdfv2.warn_rare_filter_unsupported(
    @pdfv2.PdfV2FilterName::JPXDecode,
    "JPXDecode",
    Some(se_source_ref(3)),
    Some("22 0 R"),
  )
  let events = @source_event.pdf_v2_events_for_filter_diagnostic(
    "filter_jpx", filter,
  )
  assert_eq(events.length(), 2)
  assert_true(events[0].object_ref == Some("22 0 R"))
  assert_true(events[0].page_index == Some(3))
  assert_eq(events[0].reason_tags[0], "rare_filter_unsupported")
  assert_eq(events[1].diagnostics.risks.length(), 1)
}

///|
test "source events preserve encryption and permission diagnostics" {
  let encryption : @pdfv2.PdfV2EncryptionState = {
    is_encrypted: true,
    handler_name: Some("UnknownHandler"),
    requires_password: true,
    unsupported_handler: true,
    reason_tags: ["encrypted_document", "unsupported_handler"],
  }
  let events = @source_event.pdf_v2_events_for_security_diagnostic(
    "security",
    @pdfv2.risk_encrypted_document(encryption, Some(se_source_ref(0))),
  )
  assert_eq(events.length(), 2)
  assert_true(
    events[1].capability == @pdfv2.PdfV2CoreCapabilityKind::EncryptionMetadata,
  )
  assert_eq(events[1].reason_tags[0], "encrypted_document")
  assert_true(
    events[1].recoverability == @pdfv2.PdfV2Recoverability::NotRecoverable,
  )
}

///|
test "source event preserves missing resource page and object refs" {
  let resource = @pdfv2.make_resource_ref(
    @pdfv2.PdfV2ResourceKind::Font,
    "F2",
    5,
    Some("31 0 R"),
    Some(se_source_ref(5)),
  )
  let event = @source_event.pdf_v2_event_for_resource_warning(
    "missing_font",
    @pdfv2.warn_missing_font_resource(resource),
  )
  assert_true(
    event.capability == @pdfv2.PdfV2CoreCapabilityKind::FontDictionary,
  )
  match event.resource_ref {
    Some(resource_ref) => assert_eq(resource_ref.name, "F2")
    None => fail("expected source event resource ref")
  }
  assert_true(event.page_index == Some(5))
  assert_true(event.object_ref == Some("31 0 R"))
  assert_eq(event.reason_tags[0], "missing_font_resource")
}

///|
test "source document propagates diagnostics into summary and pages" {
  let core = @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70]))
  let resource = @pdfv2.make_resource_ref(
    @pdfv2.PdfV2ResourceKind::Image,
    "Im2",
    0,
    Some("40 0 R"),
    Some(se_source_ref(0)),
  )
  let event = @source_event.pdf_v2_event_for_resource_warning(
    "missing_image",
    @pdfv2.warn_missing_xobject_resource(resource),
  )
  let doc = @source_event.build_pdf_v2_source_event_document(core, [event])
  assert_eq(doc.summary.scanned_once, true)
  assert_eq(doc.summary.one_pass_required, true)
  assert_eq(doc.summary.legacy_fallback_allowed, false)
  assert_eq(doc.summary.convert_raw_reparse_allowed, false)
  assert_eq(doc.summary.event_count, 2)
  assert_eq(doc.summary.diagnostic_event_count, 2)
  assert_eq(doc.pages[0].resource_refs.length(), 1)
  assert_eq(doc.pages[0].warnings.length(), 1)
}

///|
test "source event coverage records unsupported capability diagnostics" {
  let filter = @pdfv2.warn_unknown_filter(
    "MysteryDecode",
    Some(se_source_ref(0)),
    Some("41 0 R"),
  )
  let events = @source_event.pdf_v2_events_for_filter_diagnostic(
    "unknown_filter", filter,
  )
  let doc = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    events,
  )
  assert_true(
    coverage_has_warning(
      doc.summary.capability_coverage,
      @pdfv2.PdfV2CoreCapabilityKind::RareFilter,
    ),
  )
}

///|
test "source event enforces fallback forbidden as fatal diagnostic" {
  let event = @source_event.pdf_v2_event_for_fallback_forbidden(
    "legacy parser fallback attempted",
  )
  assert_true(event.severity == @pdfv2.PdfV2Severity::Fatal)
  assert_eq(event.reason_tags[0], "fallback_forbidden_violation")
  assert_eq(event.diagnostics.risks.length(), 1)
}

///|
test "source event preserves one-pass violation diagnostic" {
  let event = @source_event.pdf_v2_event_for_one_pass_violation(
    "convert attempted raw reparse",
  )
  assert_true(event.severity == @pdfv2.PdfV2Severity::Fatal)
  assert_eq(event.reason_tags[0], "one_pass_boundary_violation")
  assert_true(
    event.diagnostics.risks[0].kind ==
    @pdfv2.PdfV2RiskKind::OnePassBoundaryViolation,
  )
}

///|
fn se_source_ref(page_index : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index,
    object_ref: Some("7 0 R"),
    stream_index: Some(0),
    op_index: Some(1),
    content_order_index: Some(3),
    text_object_id: None,
  }
}

///|
fn coverage_has_warning(
  coverage : Array[@source_event.PdfV2SourceCapabilityCoverage],
  capability : @pdfv2.PdfV2CoreCapabilityKind,
) -> Bool {
  for item in coverage {
    if item.capability == capability && item.warning_count > 0 {
      return true
    }
  }
  false
}
