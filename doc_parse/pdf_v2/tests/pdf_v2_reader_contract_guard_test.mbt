///|
test "test_open_pdf_core_v2_remains_scaffold_only" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(@pdfv2.pdf_v2_default_reader_entry_contract, "scaffold-only")
  assert_true(core.version == Some("1.4"))
  assert_eq(core.page_count, 0)
  assert_eq(core.pages.length(), 0)
  assert_eq(core.objects.length(), 0)
  assert_eq(core.content_streams.length(), 0)
  assert_eq(core.text_events.length(), 0)
  assert_true(
    reader_contract_warning_tag(core.warnings, "self_written_core_removed"),
  )
  assert_true(
    reader_contract_warning_tag(core.warnings, "mbtpdf_backend_planned"),
  )
  assert_true(reader_contract_risk_tag(core.risks, "reader_scaffold_only"))
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_open_pdf_core_v2_perf_is_real_reader_path" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(
    @pdfv2.pdf_v2_perf_reader_entry_contract, "authorized-mbtpdf-reader",
  )
  assert_eq(core.page_count, 1)
  assert_eq(core.pages.length(), 1)
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello PDF v2")
  assert_true(reader_contract_warning_tag(core.warnings, "mbtpdf_backend_used"))
  assert_true(
    reader_contract_warning_tag(core.warnings, "v2_adapter_diagnostics_only"),
  )
  assert_true(core.text_events[0].reason_tags.contains("mbtpdf_backend_active"))
}

///|
test "test_reader_contract_declares_mbtpdf_backend" {
  assert_eq(@pdfv2.pdf_v2_reader_backend_contract, "mbtpdf-backed")
  assert_eq(@pdfv2.pdf_v2_low_level_parser_owner, "vendor/mbtpdf")
  assert_eq(@pdfv2.pdf_v2_self_written_core_allowed, false)
}

///|
test "test_no_legacy_fallback_reason_tags" {
  let scaffold = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  let perf = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(scaffold.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(scaffold.fallback_policy.external_tool_fallback_allowed, false)
  assert_eq(scaffold.fallback_policy.silent_loss_allowed, false)
  assert_eq(perf.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(perf.fallback_policy.external_tool_fallback_allowed, false)
  assert_eq(perf.fallback_policy.silent_loss_allowed, false)
  assert_true(reader_contract_warning_tag(scaffold.warnings, "no_fallback"))
  assert_true(reader_contract_warning_tag(perf.warnings, "no_fallback"))
}

///|
test "test_bad_tounicode_goes_through_tolerant_adapter" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21>",
      reader_contract_tounicode_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <D800>\n" +
      "endbfchar\n" +
      reader_contract_tounicode_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "!")
  assert_true(core.text_events[0].decode_confidence < 0.90)
  assert_true(
    core.text_events[0].reason_tags.contains("decode_source_tounicode"),
  )
  assert_true(
    core.text_events[0].reason_tags.contains("tonyfettes_unicode_helper"),
  )
  assert_true(core.text_events[0].reason_tags.contains("bad_tounicode_handled"))
  assert_true(
    reader_contract_warning_tag(
      core.text_events[0].warnings,
      "tounicode_malformed",
    ),
  )
}

///|
test "test_malformed_cmap_fail_closed_no_fallback" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21>",
      reader_contract_tounicode_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21>\n" +
      "endbfchar\n" +
      reader_contract_tounicode_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "!")
  assert_true(core.text_events[0].decode_confidence < 0.90)
  assert_true(core.text_events[0].reason_tags.contains("text_retained"))
  assert_true(core.text_events[0].reason_tags.contains("bad_tounicode_handled"))
  assert_true(
    reader_contract_warning_tag(
      core.text_events[0].warnings,
      "tounicode_malformed",
    ),
  )
  assert_true(
    reader_contract_risk_tag(
      core.text_events[0].risks,
      "glyph_decode_low_confidence",
    ),
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.scan_boundary.convert_raw_reparse_allowed, false)
}

///|
test "test_convert_raw_reparse_forbidden_in_source_summary" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(core.source_summary.scanned_once, true)
  assert_eq(core.source_summary.one_pass_required, true)
  assert_eq(core.source_summary.legacy_fallback_allowed, false)
  assert_eq(core.source_summary.convert_raw_reparse_allowed, false)
  assert_eq(core.source_summary.external_model_file_allowed, false)
  assert_eq(core.source_summary.quality_lab_runtime_dependency_allowed, false)
}

///|
fn reader_contract_tounicode_header(codespace : String) -> String {
  "/CIDInit /ProcSet findresource begin\n" +
  "12 dict begin\n" +
  "begincmap\n" +
  "/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n" +
  "/CMapName /Adobe-Identity-UCS def\n" +
  "/CMapType 2 def\n" +
  "1 begincodespacerange\n" +
  codespace +
  "\nendcodespacerange\n"
}

///|
fn reader_contract_tounicode_footer() -> String {
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn reader_contract_warning_tag(
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
fn reader_contract_risk_tag(
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
