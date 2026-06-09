///|
test "test_tounicode_bfchar_decodes_ascii" {
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
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hi")
  assert_true(
    core.text_events[0].reason_tags.contains("decode_source_tounicode"),
  )
  assert_true(
    core.text_events[0].reason_tags.contains("tounicode_bfchar_applied"),
  )
  assert_true(core.text_events[0].decode_confidence > 0.95)
}

///|
test "test_tounicode_bfchar_decodes_cjk" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<01>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<01> <4E2D>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "中")
}

///|
test "test_tounicode_bfrange_sequential_decodes_text" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<101112>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfrange\n" +
      "<10> <12> <0061>\n" +
      "endbfrange\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "abc")
  assert_true(
    core.text_events[0].reason_tags.contains("tounicode_bfrange_applied"),
  )
}

///|
test "test_tounicode_bfrange_array_decodes_text" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<202122>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfrange\n" +
      "<20> <22> [<0064> <0065> <0066>]\n" +
      "endbfrange\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "def")
}

///|
test "test_flate_tounicode_stream_decodes_text" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_flate_cmap_pdf_bytes(
      "<01>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<01> <03A9>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Ω")
  assert_true(
    core.text_events[0].reason_tags.contains("tounicode_stream_decoded"),
  )
}

///|
test "test_tounicode_missing_keeps_best_effort_with_warning" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_tounicode_missing_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "ABC")
  assert_true(
    has_tounicode_warning_tag(
      core.text_events[0].warnings,
      "to_unicode_missing_or_malformed",
    ),
  )
  assert_true(core.text_events[0].reason_tags.contains("tounicode_missing"))
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_tounicode_malformed_emits_warning_and_keeps_text" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<41>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<41>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "A")
  assert_true(core.text_events[0].reason_tags.contains("tounicode_malformed"))
  assert_true(
    has_tounicode_warning_tag(
      core.text_events[0].warnings,
      "to_unicode_missing_or_malformed",
    ),
  )
}

///|
test "test_unmapped_code_keeps_raw_or_best_effort_with_low_confidence" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<0142>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<01> <0041>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "AB")
  assert_true(core.text_events[0].decode_confidence < 0.7)
  assert_true(
    core.text_events[0].reason_tags.contains("tounicode_code_unmapped"),
  )
  assert_true(core.text_events[0].reason_tags.contains("text_retained"))
}

///|
test "test_tounicode_decode_source_and_reason_tags_propagate" {
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
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "A")
  assert_true(
    model.pages[0].blocks[0].reason_tags.contains("decode_source_tounicode"),
  )
}

///|
test "test_no_legacy_fallback_on_tounicode_failure" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes("<41>", "not a cmap"),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "A")
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
  assert_true(core.text_events[0].risks.length() > 0)
}

///|
test "test_tounicode_utf16_surrogate_pair_decodes" {
  let core = @pdfv2.open_pdf_core_v2(
    pdf_v2_tounicode_pdf_bytes(
      "<01>",
      base_tounicode_cmap_header("<00> <FF>") +
      "1 beginbfchar\n" +
      "<01> <D83DDE00>\n" +
      "endbfchar\n" +
      base_tounicode_cmap_footer(),
    ),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "😀")
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
fn has_tounicode_warning_tag(
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
