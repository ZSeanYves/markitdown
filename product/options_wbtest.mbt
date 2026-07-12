///|
test "product accurate feature registry covers every feature and format" {
  let features : Array[(AccurateFeature, String)] = [
    (AccurateFeature::PdfPageAppendix, "pdf_page_appendix"),
    (AccurateFeature::PdfWindowedAssembly, "pdf_windowed_assembly"),
    (AccurateFeature::DocxTextboxInline, "docx_textbox_inline"),
    (
      AccurateFeature::DocxAlternateContentRestore,
      "docx_alternate_content_restore",
    ),
    (AccurateFeature::DocxNotesAppendix, "docx_notes_appendix"),
    (AccurateFeature::XlsxHiddenSheets, "xlsx_hidden_sheets"),
    (AccurateFeature::XlsxHiddenRows, "xlsx_hidden_rows"),
    (AccurateFeature::XlsxMergedSpans, "xlsx_merged_spans"),
    (AccurateFeature::PptxReadingOrder, "pptx_reading_order"),
    (AccurateFeature::PptxGroupSummary, "pptx_group_summary"),
    (AccurateFeature::PptxHiddenSlideSemantics, "pptx_hidden_slide_semantics"),
    (AccurateFeature::PptxNotesAppendix, "pptx_notes_appendix"),
    (AccurateFeature::OdtRichNotes, "odt_rich_notes"),
    (AccurateFeature::OdtCommentsAppendix, "odt_comments_appendix"),
    (AccurateFeature::OdsHiddenSheets, "ods_hidden_sheets"),
    (AccurateFeature::OdsHiddenRows, "ods_hidden_rows"),
    (AccurateFeature::OdsCoveredCellSpans, "ods_covered_cell_spans"),
    (AccurateFeature::OdpNotesAppendix, "odp_notes_appendix"),
    (AccurateFeature::OdpSlideSummary, "odp_slide_summary"),
  ]
  let profile = make_accurate_feature_profile(features.map(entry => entry.0))
  assert_eq(accurate_feature_profile_names(profile).length(), features.length())
  for entry in features {
    assert_eq(accurate_feature_name(entry.0), entry.1)
    assert_true(accurate_feature_enabled(profile, entry.0))
  }
  assert_eq(empty_accurate_feature_profile().features.length(), 0)
  let expected_counts : Array[(@input.DetectedFormat, Int)] = [
    (@input.DetectedFormat::Pdf, 2),
    (@input.DetectedFormat::Docx, 3),
    (@input.DetectedFormat::Xlsx, 3),
    (@input.DetectedFormat::Pptx, 4),
    (@input.DetectedFormat::Odt, 2),
    (@input.DetectedFormat::Ods, 3),
    (@input.DetectedFormat::Odp, 2),
    (@input.DetectedFormat::Txt, 0),
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
  let custom = make_resource_limits(1, 2, 3, max_line_chars=4)
  let options = make_product_options(
    ConvertMode::Accurate,
    custom,
    output_mode=OutputMode::Rag,
    stream_requested=true,
  )
  assert_true(options.mode == ConvertMode::Accurate)
  assert_true(options.fidelity_mode == FidelityMode::Accurate)
  assert_true(options.output_mode == OutputMode::Rag)
  assert_true(options.stream_requested)
  assert_eq(options.limits.max_line_chars, 4)
  let defaults = default_product_options()
  assert_true(defaults.mode == ConvertMode::Balanced)
  assert_true(defaults.output_mode == OutputMode::Markdown)
  assert_true(!defaults.stream_requested)
  assert_true(
    fidelity_mode_for_convert_mode(ConvertMode::Accurate) ==
    FidelityMode::Accurate,
  )
  assert_true(
    fidelity_mode_for_convert_mode(ConvertMode::Stream) ==
    FidelityMode::Balanced,
  )
  assert_true(
    output_mode_for_convert_mode(ConvertMode::Accurate) == OutputMode::Markdown,
  )
  assert_true(
    convert_mode_from_modes(FidelityMode::Balanced, true) == ConvertMode::Stream,
  )
  assert_true(
    convert_mode_from_modes(FidelityMode::Accurate, false) ==
    ConvertMode::Accurate,
  )
  assert_true(
    convert_mode_from_modes(FidelityMode::Balanced, false) ==
    ConvertMode::Balanced,
  )
}

///|
test "product profile names cover every public enum variant" {
  assert_eq(convert_mode_name(ConvertMode::Balanced), "balanced")
  assert_eq(convert_mode_name(ConvertMode::Accurate), "accurate")
  assert_eq(convert_mode_name(ConvertMode::Stream), "stream")
  assert_eq(fidelity_mode_name(FidelityMode::Balanced), "balanced")
  assert_eq(fidelity_mode_name(FidelityMode::Accurate), "accurate")
  assert_eq(output_mode_name(OutputMode::Markdown), "markdown")
  assert_eq(output_mode_name(OutputMode::Debug), "debug")
  assert_eq(output_mode_name(OutputMode::Rag), "rag")
  assert_eq(execution_profile_name(ExecutionProfile::Standard), "standard")
  assert_eq(
    execution_profile_name(ExecutionProfile::MediumAdaptive),
    "medium_adaptive",
  )
  assert_eq(
    execution_profile_name(ExecutionProfile::LargeAdaptive),
    "large_adaptive",
  )
  assert_eq(lowering_profile_name(LoweringProfile::Canonical), "canonical")
  assert_eq(
    lowering_profile_name(LoweringProfile::AccurateSemantic),
    "accurate_semantic",
  )
  assert_eq(
    lowering_profile_name(LoweringProfile::StreamCanonical),
    "stream_canonical",
  )
  assert_eq(
    lowering_profile_name(LoweringProfile::LargeAdaptive),
    "large_adaptive",
  )
  let render_profiles : Array[(RenderProfile, String)] = [
    (RenderProfile::DefaultMarkdown, "default_markdown"),
    (RenderProfile::SectionFlushMarkdown, "section_flush_markdown"),
    (RenderProfile::SparseTableMarkdown, "sparse_table_markdown"),
    (RenderProfile::NotesAppendixFirst, "notes_appendix_first"),
    (RenderProfile::AssetManifestFirst, "asset_manifest_first"),
    (RenderProfile::PageWindowMarkdown, "page_window_markdown"),
    (RenderProfile::RecordBatchMarkdown, "record_batch_markdown"),
  ]
  for entry in render_profiles {
    assert_eq(render_profile_name(entry.0), entry.1)
  }
  assert_true(debug_output_mode(OutputMode::Debug))
  assert_true(!debug_output_mode(OutputMode::Markdown))
}
