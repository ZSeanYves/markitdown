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
test "test_perf_reader_decodes_basic_tounicode_bfchar" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<2122>",
      base_tounicode_cmap_header("<00> <FF>") +
      "2 beginbfchar\n" +
      "<21> <0048>\n" +
      "<22> <0069>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hi")
  assert_true(core.text_events[0].decode_confidence >= 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("batch_glyph_decode"),
    true,
  )
  assert_eq(
    core.text_events[0].reason_tags.contains("decode_source_tounicode"),
    true,
  )
  assert_eq(
    core.text_events[0].reason_tags.contains("tounicode_bfchar_applied"),
    true,
  )
  assert_eq(
    core.text_events[0].reason_tags.contains("tonyfettes_unicode_helper"),
    true,
  )
}

///|
test "test_perf_reader_decodes_flate_tounicode_cmap" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_flate_cmap_pdf_bytes(
      "<21>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "A")
  assert_true(core.text_events[0].decode_confidence >= 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("decode_source_tounicode"),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.scan_boundary.convert_raw_reparse_allowed, false)
}

///|
test "test_perf_reader_decodes_tounicode_bfrange" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<212223>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfrange\n" +
      "<21> <23> <0041>\n" +
      "endbfrange\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "ABC")
  assert_true(core.text_events[0].decode_confidence >= 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("tounicode_bfrange_applied"),
    true,
  )
}

///|
test "test_perf_reader_decodes_multibyte_codespacerange" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<00010002>",
      base_tounicode_cmap_header("<0000> <FFFF>") +
      "2 beginbfchar\n" +
      "<0001> <0041>\n" +
      "<0002> <0042>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "AB")
  assert_true(core.text_events[0].decode_confidence >= 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("tounicode_bfchar_applied"),
    true,
  )
}

///|
test "test_perf_reader_decodes_surrogate_pair_tounicode_target" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <D83DDE00>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text.length() > 0, true)
  assert_eq(core.text_events[0].text == "!", false)
  assert_true(core.text_events[0].decode_confidence >= 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("tonyfettes_unicode_helper"),
    true,
  )
}

///|
test "test_perf_reader_retains_low_confidence_text_for_unmapped_tounicode_code" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21FF>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text.length() >= 2, true)
  assert_true(core.text_events[0].decode_confidence < 0.90)
  assert_eq(
    tounicode_placeholder_has_warning_tag(
      core.text_events[0].warnings,
      "tounicode_unmapped_code",
    ),
    true,
  )
  assert_eq(
    tounicode_placeholder_has_risk_tag(
      core.text_events[0].risks,
      "glyph_decode_low_confidence",
    ),
    true,
  )
}

///|
test "test_perf_reader_handles_bad_tounicode_without_fallback" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <D800>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "!")
  assert_true(core.text_events[0].decode_confidence < 0.90)
  assert_eq(
    core.text_events[0].reason_tags.contains("bad_tounicode_handled"),
    true,
  )
  assert_eq(
    tounicode_placeholder_has_warning_tag(
      core.text_events[0].warnings,
      "tounicode_malformed",
    ),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.scan_boundary.convert_raw_reparse_allowed, false)
}

///|
test "test_tounicode_source_text_pipeline_consumes_perf_reader_events" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<21>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<21> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  let source = @source_event.build_pdf_v2_source_event_document(core, [])
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "A")
}

///|
test "test_perf_reader_missing_tounicode_warns_and_retains_text" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_tounicode_missing_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "ABC")
  assert_eq(
    tounicode_placeholder_has_warning_tag(
      core.text_events[0].warnings,
      "to_unicode_missing_or_malformed",
    ),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_reset17_type0_cid_subset_font_diagnostics_propagate" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_type0_cid_tounicode_pdf_bytes(
      "<00010002>",
      base_tounicode_cmap_header("<0000> <FFFF>") +
      "2 beginbfchar\n" +
      "<0001> <0041>\n" +
      "<0002> <0042>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  let event = core.text_events[0]
  assert_eq(event.text, "AB")
  assert_true(event.decode_confidence >= 0.90)
  assert_true(event.reason_tags.contains("font_type_type0"))
  assert_true(event.reason_tags.contains("font_type_cid"))
  assert_true(event.reason_tags.contains("cid_font_type2"))
  assert_true(event.reason_tags.contains("descendant_font_present"))
  assert_true(event.reason_tags.contains("cid_system_info_present"))
  assert_true(event.reason_tags.contains("cid_registry:Adobe"))
  assert_true(event.reason_tags.contains("cid_ordering:Identity"))
  assert_true(event.reason_tags.contains("cid_supplement:0"))
  assert_true(event.reason_tags.contains("font_subset_detected"))
  assert_true(event.reason_tags.contains("normalized_base_font:StageTwoCID"))
  assert_true(event.reason_tags.contains("embedded_font_present"))
  assert_true(event.reason_tags.contains("tounicode_codespace_multibyte"))
  assert_true(event.reason_tags.contains("tounicode_source_multibyte"))
  assert_true(event.reason_tags.contains("decode_source_tounicode"))
}

///|
test "test_reset17_bfrange_array_and_multibyte_codespace_decode" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<000100020003>",
      base_tounicode_cmap_header("<0000> <FFFF>") +
      "1 beginbfrange\n" +
      "<0001> <0003> [<0041> <0042> <0043>]\n" +
      "endbfrange\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  let event = core.text_events[0]
  assert_eq(event.text, "ABC")
  assert_true(event.decode_confidence >= 0.90)
  assert_true(event.reason_tags.contains("tounicode_bfrange_applied"))
  assert_true(event.reason_tags.contains("tounicode_bfrange_array"))
  assert_true(event.reason_tags.contains("tounicode_codespace_multibyte"))
  assert_true(event.reason_tags.contains("tounicode_source_2byte"))
}

///|
test "test_reset17_variable_codespace_prefers_longest_match" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<010002>",
      "/CIDInit /ProcSet findresource begin\n" +
      "12 dict begin\n" +
      "begincmap\n" +
      "/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n" +
      "/CMapName /Adobe-Identity-UCS def\n" +
      "/CMapType 2 def\n" +
      "2 begincodespacerange\n" +
      "<00> <FF>\n" +
      "<0000> <FFFF>\n" +
      "endcodespacerange\n" +
      "2 beginbfchar\n" +
      "<01> <0058>\n" +
      "<0002> <0059>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  let event = core.text_events[0]
  assert_eq(event.text, "XY")
  assert_true(event.decode_confidence >= 0.90)
  assert_true(event.reason_tags.contains("tounicode_codespace_applied"))
  assert_true(event.reason_tags.contains("tounicode_codespace_multibyte"))
  assert_true(event.reason_tags.contains("tounicode_source_2byte"))
}

///|
test "test_reset17_malformed_partial_cmap_emits_warning_and_retains_text" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_tounicode_pdf_bytes(
      "<2122>",
      base_tounicode_cmap_header("<00> <FF>") +
      "2 beginbfchar\n" +
      "<21> <0041>\n" +
      "<22> <D800>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  let event = core.text_events[0]
  assert_eq(event.text.length() >= 2, true)
  assert_true(event.decode_confidence < 0.90)
  assert_true(event.reason_tags.contains("bad_tounicode_handled"))
  assert_true(event.reason_tags.contains("tounicode_target_malformed"))
  assert_true(event.reason_tags.contains("text_retained"))
  assert_eq(
    tounicode_placeholder_has_warning_tag(event.warnings, "tounicode_malformed"),
    true,
  )
  assert_eq(
    tounicode_placeholder_has_risk_tag(
      event.risks,
      "glyph_decode_low_confidence",
    ),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(core.scan_boundary.convert_raw_reparse_allowed, false)
}

///|
test "test_reset17_source_text_pipeline_preserves_cmap_reason_tags" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_type0_cid_tounicode_pdf_bytes(
      "<0001>",
      base_tounicode_cmap_header("<0000> <FFFF>") +
      "1 beginbfchar\n" +
      "<0001> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  let source = @source_event.build_pdf_v2_source_event_document(core, [])
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "A")
  let block_tags = model.pages[0].blocks[0].reason_tags
  assert_true(block_tags.contains("decode_source_tounicode"))
  assert_true(block_tags.contains("font_type_cid"))
  assert_true(block_tags.contains("font_subset_detected"))
  assert_true(block_tags.contains("tounicode_source_multibyte"))
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
