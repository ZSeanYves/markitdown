///|
test "test_perf_reader_preserves_simple_text_and_position" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_tm_position_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  let event = core.text_events[0]
  assert_eq(event.text, "Matrix Pos")
  assert_true(event.origin is Some({ x: 100.0, y: 650.0 }))
  assert_eq(event.text_matrix[4], 100.0)
  assert_eq(event.text_matrix[5], 650.0)
  assert_true(event.reason_tags.contains("origin_x"))
  assert_true(event.reason_tags.contains("origin_y"))
  assert_true(event.reason_tags.contains("text_matrix"))
  assert_true(event.reason_tags.contains("char_spacing:1"))
  assert_true(event.reason_tags.contains("word_spacing:2"))
  assert_true(event.reason_tags.contains("horizontal_scaling:95"))
  assert_true(event.reason_tags.contains("rendering_mode:1"))
  assert_true(event.reason_tags.contains("text_rise:3"))
  assert_true(
    mbtpdf_diag_has_warning_tag(
      event.warnings,
      "positioning_detail_unavailable",
    ),
  )
}

///|
test "test_perf_reader_records_resource_inheritance" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_inherited_resources_pdf_bytes(),
  )
  assert_eq(core.text_events.length(), 1)
  assert_eq(core.text_events[0].text, "Inherited Font")
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "resource_inheritance_applied"),
  )
}

///|
test "test_perf_reader_records_missing_resource_ops" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_resource_ops_missing_pdf_bytes(),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "missing_xobject_resource"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "missing_extgstate_resource"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "missing_colorspace_resource"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "unsupported_resource_kind"),
  )
}

///|
test "test_subset_font_records_original_and_base_name" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_subset_font_pdf_bytes())
  assert_eq(core.text_events.length(), 1)
  let tags = core.text_events[0].reason_tags
  assert_true(tags.contains("font_type_simple"))
  assert_true(tags.contains("font_subset_detected"))
  assert_true(tags.contains("font_subset_prefix_removed_or_recorded"))
  assert_true(tags.contains("raw_base_font:/ABCDEE+MyFont"))
  assert_true(tags.contains("normalized_base_font:MyFont"))
}

///|
test "test_type0_or_tounicode_reason_tags_propagate" {
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
  assert_eq(core.text_events.length(), 1)
  let tags = core.text_events[0].reason_tags
  assert_true(tags.contains("tounicode_present"))
  assert_true(tags.contains("decode_source_tounicode"))
  assert_true(tags.contains("cmap_used"))
}

///|
test "test_xref_or_object_stream_limit_is_structured_diagnostic" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_extra_objstm_pdf_bytes())
  assert_true(mbtpdf_diag_has_warning_tag(core.warnings, "xref_table_used"))
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "object_stream_detected"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "object_stream_supported"),
  )
}

///|
test "test_filter_chain_or_decode_params_diagnostic" {
  let core = @pdfv2.open_pdf_core_v2_perf(
    pdf_v2_flate_decode_params_pdf_bytes(),
  )
  assert_eq(core.text_events.length(), 1)
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "filter_flate_decode_used"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "decode_params_present"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "decode_params_ignored"),
  )
}

///|
test "test_flate_stream_lifetime_counts_and_no_raw_bytes" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_flate_valid_text_pdf_bytes())
  assert_eq(core.content_streams.length(), 1)
  assert_true(core.content_streams[0].raw_bytes is None)
  assert_true(core.content_streams[0].decoded_text is None)
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "decoded_stream_count"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "decoded_stream_count:1"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(
      core.warnings,
      "stream_bytes_not_exposed_to_convert",
    ),
  )
}

///|
test "test_malformed_stream_fail_closed_no_fallback" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_flate_text_pdf_bytes())
  assert_eq(core.text_events.length(), 0)
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "stream_decode_failed"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "decode_failure_count:1"),
  )
  assert_true(mbtpdf_diag_has_risk_tag(core.risks, "stream_decode_failed"))
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "test_encrypted_pdf_fail_closed_no_fallback" {
  let core = @pdfv2.open_pdf_core_v2_perf(pdf_v2_encrypted_marker_pdf_bytes())
  assert_eq(core.page_count, 0)
  assert_eq(core.text_events.length(), 0)
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "encrypted_pdf_detected"),
  )
  assert_true(
    mbtpdf_diag_has_warning_tag(core.warnings, "encrypted_pdf_unsupported"),
  )
  assert_true(mbtpdf_diag_has_risk_tag(core.risks, "encrypted_pdf_detected"))
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
fn mbtpdf_diag_has_warning_tag(
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
fn mbtpdf_diag_has_risk_tag(
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
