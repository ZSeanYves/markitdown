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
test "test_pdf_v2_perf_entry_is_currently_scaffold_compatible" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  assert_true(core.version == Some("1.4"))
  assert_eq(core.scanned_once, true)
  assert_eq(core.scan_boundary.one_pass_required, true)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.text_events.length(), 0)
  assert_eq(core_reader_has_risk_tag(core.risks, "reader_scaffold_only"), true)
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
