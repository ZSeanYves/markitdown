///|
test "test_scaffold_pdf_bytes_produce_diagnostic_source_document" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes()),
    [],
  )
  assert_eq(source.summary.page_count, 1)
  assert_eq(source.summary.event_count, 1)
  assert_eq(source_text_event_count(source.events), 0)
  assert_eq(source.summary.warning_count > 0, true)
  assert_eq(source.summary.risk_count > 0, true)
}

///|
test "test_text_reconstruction_fail_closes_without_scaffold_text_payloads" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes()),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 0)
  assert_eq(model.summary.warning_count > 0, true)
  assert_eq(model.summary.risk_count > 0, true)
  assert_eq(model.summary.legacy_fallback_allowed, false)
  assert_eq(model.summary.convert_raw_reparse_allowed, false)
}

///|
test "test_scaffold_keeps_reader_diagnostics_for_text_reconstruction" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_missing_font_pdf_bytes()),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.pages[0].blocks.length(), 0)
  assert_eq(
    text_pdf_has_warning_tag(model.warnings, "self_written_core_removed"),
    true,
  )
  assert_eq(
    text_pdf_has_risk_tag(model.risks, "self_written_core_removed"),
    true,
  )
}

///|
test "test_perf_reader_text_payload_reconstructs_block" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  let source = @source_event.build_pdf_v2_source_event_document(core, [])
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(source_text_event_count(source.events), 1)
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "Hello PDF v2")
  assert_eq(model.summary.legacy_fallback_allowed, false)
  assert_eq(model.summary.convert_raw_reparse_allowed, false)
}

///|
test "test_perf_reader_missing_font_retains_low_confidence_text" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_missing_font_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Missing Font")
  assert_true(core.text_events[0].decode_confidence < 0.60)
  assert_eq(
    text_pdf_has_warning_tag(
      core.text_events[0].warnings,
      "missing_font_resource",
    ),
    true,
  )
  assert_eq(
    text_pdf_has_risk_tag(
      core.text_events[0].risks,
      "glyph_decode_low_confidence",
    ),
    true,
  )
}

///|
fn source_text_event_count(
  events : Array[@source_event.PdfV2SourceEvent],
) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == @source_event.PdfV2SourceEventKind::TextPayload {
      count = count + 1
    }
  }
  count
}

///|
fn text_pdf_has_warning_tag(
  warnings : Array[@pdfv2.PdfV2Warning],
  tag : String,
) -> Bool {
  for warning in warnings {
    if warning.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn text_pdf_has_risk_tag(risks : Array[@pdfv2.PdfV2Risk], tag : String) -> Bool {
  for risk in risks {
    if risk.reason_tags.contains(tag) {
      return true
    }
  }
  false
}
