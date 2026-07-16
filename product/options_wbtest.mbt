///|
test "product accurate feature registry covers every feature and format" {
  let features : Array[(AccurateFeature, String)] = [
    (PdfPageAppendix, "pdf_page_appendix"),
    (PdfWindowedAssembly, "pdf_windowed_assembly"),
    (DocxTextboxInline, "docx_textbox_inline"),
    (DocxAlternateContentRestore, "docx_alternate_content_restore"),
    (DocxNotesAppendix, "docx_notes_appendix"),
    (XlsxHiddenSheets, "xlsx_hidden_sheets"),
    (XlsxHiddenRows, "xlsx_hidden_rows"),
    (XlsxMergedSpans, "xlsx_merged_spans"),
    (PptxReadingOrder, "pptx_reading_order"),
    (PptxGroupSummary, "pptx_group_summary"),
    (PptxHiddenSlideSemantics, "pptx_hidden_slide_semantics"),
    (PptxNotesAppendix, "pptx_notes_appendix"),
    (OdtRichNotes, "odt_rich_notes"),
    (OdtCommentsAppendix, "odt_comments_appendix"),
    (OdsHiddenSheets, "ods_hidden_sheets"),
    (OdsHiddenRows, "ods_hidden_rows"),
    (OdsCoveredCellSpans, "ods_covered_cell_spans"),
    (OdpNotesAppendix, "odp_notes_appendix"),
    (OdpSlideSummary, "odp_slide_summary"),
  ]
  let profile = make_accurate_feature_profile(features.map(entry => entry.0))
  assert_eq(accurate_feature_profile_names(profile).length(), features.length())
  for entry in features {
    assert_eq(accurate_feature_name(entry.0), entry.1)
    assert_true(accurate_feature_enabled(profile, entry.0))
  }
  assert_eq(empty_accurate_feature_profile().features.length(), 0)
  let expected_counts : Array[(@input.DetectedFormat, Int)] = [
    (Pdf, 2),
    (Docx, 3),
    (Xlsx, 3),
    (Pptx, 4),
    (Odt, 2),
    (Ods, 3),
    (Odp, 2),
    (Txt, 0),
  ]
  for entry in expected_counts {
    assert_eq(accurate_features_for_detected_format(entry.0).length(), entry.1)
  }
}

///|
test "product option defaults and mode derivation remain stable" {
  let limits = default_resource_limits()
  assert_eq(limits.max_rows, 2000)
  assert_eq(limits.max_cols, 50)
  assert_eq(limits.max_cells, 100000)
  assert_eq(limits.max_line_chars, 4000)
  assert_eq(limits.max_input_bytes, 536870912L)
  assert_eq(limits.max_asset_bytes, 33554432L)
  assert_eq(limits.max_total_asset_bytes, 134217728L)
  assert_eq(limits.external_command_timeout_ms, 300000)
  assert_eq(limits.max_external_output_bytes, 8388608L)
  let custom = make_resource_limits(1, 2, 3, max_line_chars=4)
  let options = make_product_options(
    Accurate,
    custom,
    output_mode=Rag,
    stream_requested=true,
  )
  assert_true(options.mode == Accurate)
  assert_true(options.fidelity_mode == Accurate)
  assert_true(options.output_mode == Rag)
  assert_true(options.stream_requested)
  assert_eq(options.limits.max_line_chars, 4)
  let defaults = default_product_options()
  assert_true(defaults.mode == Balanced)
  assert_true(defaults.output_mode == Markdown)
  assert_true(!defaults.stream_requested)
  assert_true(fidelity_mode_for_convert_mode(Accurate) == Accurate)
  assert_true(fidelity_mode_for_convert_mode(Stream) == Balanced)
  assert_true(output_mode_for_convert_mode(Accurate) == Markdown)
  assert_true(convert_mode_from_modes(Balanced, true) == Stream)
  assert_true(convert_mode_from_modes(Accurate, false) == Accurate)
  assert_true(convert_mode_from_modes(Balanced, false) == Balanced)
}

///|
test "product profile names cover every public enum variant" {
  assert_eq(convert_mode_name(Balanced), "balanced")
  assert_eq(convert_mode_name(Accurate), "accurate")
  assert_eq(convert_mode_name(Stream), "stream")
  assert_eq(fidelity_mode_name(Balanced), "balanced")
  assert_eq(fidelity_mode_name(Accurate), "accurate")
  assert_eq(output_mode_name(Markdown), "markdown")
  assert_eq(output_mode_name(Debug), "debug")
  assert_eq(output_mode_name(Rag), "rag")
  assert_eq(execution_profile_name(Standard), "standard")
  assert_eq(execution_profile_name(MediumAdaptive), "medium_adaptive")
  assert_eq(execution_profile_name(LargeAdaptive), "large_adaptive")
  assert_eq(lowering_profile_name(Canonical), "canonical")
  assert_eq(lowering_profile_name(AccurateSemantic), "accurate_semantic")
  assert_eq(lowering_profile_name(StreamCanonical), "stream_canonical")
  assert_eq(lowering_profile_name(LargeAdaptive), "large_adaptive")
  let render_profiles : Array[(RenderProfile, String)] = [
    (DefaultMarkdown, "default_markdown"),
    (SectionFlushMarkdown, "section_flush_markdown"),
    (SparseTableMarkdown, "sparse_table_markdown"),
    (NotesAppendixFirst, "notes_appendix_first"),
    (AssetManifestFirst, "asset_manifest_first"),
    (PageWindowMarkdown, "page_window_markdown"),
    (RecordBatchMarkdown, "record_batch_markdown"),
  ]
  for entry in render_profiles {
    assert_eq(render_profile_name(entry.0), entry.1)
  }
  assert_true(debug_output_mode(Debug))
  assert_true(!debug_output_mode(Markdown))
}
