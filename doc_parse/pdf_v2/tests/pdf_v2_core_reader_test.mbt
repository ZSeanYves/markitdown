///|
test "test_pdf_v2_scaffold_header_probe_is_retained" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  assert_true(core.version == Some("1.4"))
  assert_eq(core.page_count, 0)
  assert_eq(core.objects.length(), 0)
  assert_eq(core.content_streams.length(), 0)
  assert_eq(core.text_events.length(), 0)
}

///|
test "test_pdf_v2_scaffold_emits_removed_base_diagnostic" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(
    core_reader_has_warning_tag(core.warnings, "self_written_core_removed"),
    true,
  )
  assert_eq(
    core_reader_has_risk_tag(core.risks, "self_written_core_removed"),
    true,
  )
  assert_eq(
    core_reader_has_warning_tag(core.warnings, "mbtpdf_backend_planned"),
    true,
  )
  assert_eq(
    core_reader_has_risk_tag(core.risks, "mbtpdf_backend_planned"),
    true,
  )
}

///|
test "test_pdf_v2_scaffold_malformed_header_fails_closed" {
  let core = @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70]))
  assert_true(core.version == None)
  assert_eq(
    core_reader_has_warning_tag(
      core.warnings,
      "pdf_header_missing_or_malformed",
    ),
    true,
  )
  assert_eq(
    core_reader_has_risk_tag(core.risks, "pdf_header_missing_or_malformed"),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_pdf_v2_perf_entry_reads_minimal_text_pdf" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  assert_true(core.version == Some("1.4"))
  assert_eq(core.scanned_once, true)
  assert_eq(core.scan_boundary.one_pass_required, true)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.page_count, 1)
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello PDF v2")
  assert_eq(core.text_events[0].content_order_index, 0)
  assert_eq(core.text_events[0].operator, "Tj")
  assert_eq(core.text_events[0].page_index, 0)
  assert_true(core.text_events[0].stream_index == Some(0))
  assert_true(core.text_events[0].object_ref == Some("4 0 R"))
  assert_true(core.text_events[0].font_name == Some("/F1"))
  assert_true(core.text_events[0].font_size == Some(12.0))
  assert_eq(
    core.text_events[0].reason_tags.contains("mbtpdf_backend_active"),
    true,
  )
  assert_eq(
    core_reader_has_warning_tag(core.warnings, "mbtpdf_backend_active"),
    true,
  )
  assert_eq(core_reader_has_risk_tag(core.risks, "reader_scaffold_only"), false)
}

///|
test "test_pdf_v2_scaffold_does_not_decode_flate_or_tounicode" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_flate_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 0)
  assert_eq(core.text_events.length(), 0)
  assert_eq(core_reader_has_warning_tag(core.warnings, "fail_closed"), true)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_pdf_v2_perf_decodes_flate_content_stream" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_flate_valid_text_pdf_bytes())
  assert_eq(core.page_count, 1)
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].filter_names.contains("/FlateDecode"), true)
  assert_eq(core.content_streams[0].decode_supported, true)
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello Flate v2")
  assert_eq(
    core.text_events[0].reason_tags.contains("lazy_stream_decode"),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_pdf_v2_perf_flate_decode_failure_emits_diagnostic" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_flate_text_pdf_bytes())
  assert_eq(core.page_count, 1)
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].decode_supported, false)
  assert_eq(core.text_events.length(), 0)
  assert_eq(
    core_reader_has_warning_tag(core.warnings, "mbtpdf_stream_decode_failed"),
    true,
  )
  assert_eq(
    core_reader_has_risk_tag(core.risks, "mbtpdf_stream_decode_failed"),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
fn core_reader_has_warning_tag(
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
fn core_reader_has_risk_tag(
  risks : Array[@pdfv2.PdfV2Risk],
  tag : String,
) -> Bool {
  for risk in risks {
    if risk.reason_tags.contains(tag) {
      return true
    }
  }
  false
}
