///|
test "test_minimal_pdf_header_is_recognized" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  assert_true(core.version == Some("1.4"))
  assert_eq(core.page_count, 1)
  assert_true(core.pages[0].object_ref == Some("3 0 R"))
}

///|
test "test_malformed_header_emits_structured_diagnostic" {
  let core = @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70]))
  assert_true(core.version == None)
  assert_eq(
    core_reader_has_warning_tag(core.warnings, "malformed_pdf_header"),
    true,
  )
  assert_eq(core_reader_has_risk_tag(core.risks, "malformed_pdf_header"), true)
}

///|
test "test_uncompressed_single_page_text_pdf_produces_core_text_event" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].decode_supported, true)
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello PDF v2")
}

///|
test "test_text_event_preserves_page_object_content_order" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes())
  let event = core.text_events[0]
  assert_eq(event.page_index, 0)
  assert_true(event.object_ref == Some("4 0 R"))
  assert_true(event.stream_ref == Some("4 0 R#stream:0"))
  assert_eq(event.content_order_index, 0)
  assert_true(event.source_ref.content_order_index == Some(0))
  assert_eq(event.operator, "Tj")
}

///|
test "test_flate_stream_decode_failure_emits_warning_not_fallback" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_flate_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].decode_supported, false)
  assert_eq(core.text_events.length(), 0)
  assert_eq(
    core_reader_has_warning_tag(
      core.warnings,
      "compressed_stream_decode_failure",
    ),
    true,
  )
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_flate_stream_decodes_to_core_text_event" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_flate_valid_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].decode_supported, true)
  assert_true(core.content_streams[0].filter_names.contains("FlateDecode"))
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello Flate v2")
  assert_eq(core.text_events[0].operator, "Tj")
  assert_true(core.text_events[0].decode_confidence > 0.0)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_flate_array_filter_decodes_to_core_text_event" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_flate_array_valid_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 1)
  assert_eq(core.content_streams[0].decode_supported, true)
  assert_eq(core.content_streams[0].filter_names.length(), 1)
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Hello Flate Array v2")
}

///|
test "test_missing_font_or_tounicode_emits_decode_warning" {
  let core = @pdfv2.open_pdf_core_v2(pdf_v2_missing_font_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  assert_eq(
    core_reader_has_warning_tag(
      core.text_events[0].warnings,
      "missing_font_resource",
    ),
    true,
  )
  assert_eq(
    core_reader_has_risk_tag(
      core.text_events[0].risks,
      "glyph_decode_low_confidence",
    ),
    true,
  )
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
