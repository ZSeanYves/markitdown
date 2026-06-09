///|
test "test_tounicode_fixture_is_kept_as_placeholder_input" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<0102>",
      base_tounicode_cmap_header("<00> <FF>") +
      "2 beginbfchar\n" +
      "<01> <0048>\n" +
      "<02> <0069>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_true(core.version == Some("1.4"))
  assert_eq(core.text_events.length(), 0)
  assert_eq(
    tounicode_placeholder_has_warning_tag(
      core.warnings,
      "mbtpdf_backend_planned",
    ),
    true,
  )
}

///|
test "test_tounicode_missing_fixture_fails_closed_without_fallback" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_tounicode_missing_pdf_bytes())
  assert_eq(core.text_events.length(), 0)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(
    tounicode_placeholder_has_risk_tag(core.risks, "reader_scaffold_only"),
    true,
  )
}

///|
test "test_tounicode_diagnostics_propagate_to_text_reconstruction_placeholder" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(
      pdf_v2_tounicode_pdf_bytes(
        "<01>",
        base_tounicode_cmap_header("<00> <FF>") +
        "1 beginbfchar\n" +
        "<01> <0041>\n" +
        "endbfchar\n" +
        base_tounicode_cmap_footer(),
      ),
    ),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 0)
  assert_eq(
    tounicode_placeholder_has_warning_tag(
      model.warnings,
      "self_written_core_removed",
    ),
    true,
  )
  assert_eq(
    tounicode_placeholder_has_risk_tag(model.risks, "self_written_core_removed"),
    true,
  )
}

///|
fn base_tounicode_cmap_header(codespace : String) -> String {
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
fn base_tounicode_cmap_footer() -> String {
  "endcmap\n" +
  "CMapName currentdict /CMap defineresource pop\n" +
  "end\n" +
  "end\n"
}

///|
fn tounicode_placeholder_has_warning_tag(
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
fn tounicode_placeholder_has_risk_tag(
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
