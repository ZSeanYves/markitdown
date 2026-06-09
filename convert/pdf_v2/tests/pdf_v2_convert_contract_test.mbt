///|
test "pdf v2 entry fail closed without legacy fallback" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    Bytes::from_array([37, 80, 68, 70]),
    "synthetic.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.document.blocks.val.length(), 1)
  match result.document.blocks.val[0] {
    @cor.Block::Paragraph(text) => {
      assert_eq(text.contains("PDF v2 experimental route"), true)
      assert_eq(text.contains("without legacy fallback"), true)
    }
    _ => fail("expected fail-closed diagnostic paragraph")
  }
  assert_eq(@pdfv2convert.pdf_v2_pipeline_preserves_no_fallback(result), true)
}

///|
test "pdf v2 pipeline preserves no fallback summary" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    Bytes::from_array([37, 80, 68, 70]),
    "summary.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.core.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(result.core.scan_boundary.convert_raw_reparse_allowed, false)
  assert_eq(result.source.summary.legacy_fallback_allowed, false)
  assert_eq(result.model.source_summary.legacy_fallback_allowed, false)
  assert_eq(result.features.summary.legacy_fallback_allowed, false)
  assert_eq(result.lowering.summary.legacy_fallback_allowed, false)
  assert_eq(result.reason_tags.contains("no_old_convert_pdf"), true)
}

///|
test "pdf v2 empty reader returns valid core document" {
  let result = @pdfv2convert.parse_pdf_v2_bytes_with_options(
    Bytes::from_array([37, 80, 68, 70]),
    "empty-reader.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(result.core.scanned_once, true)
  assert_eq(result.text_model.summary.block_count, 0)
  assert_eq(result.lowering.summary.lowered_block_count, 0)
  assert_eq(result.document.blocks.val.is_empty(), false)
}

///|
test "pdf v2 core adapter maps lowered blocks conservatively" {
  let lowered : @lowering.PdfV2LoweringResult = {
    blocks: [
      lowered_block("b0", @lowering.PdfV2LoweredBlockKind::Heading, "Title"),
      lowered_block("b1", @lowering.PdfV2LoweredBlockKind::ListItem, "Item"),
      lowered_block(
        "b2",
        @lowering.PdfV2LoweredBlockKind::CaptionText,
        "Caption",
      ),
    ],
    asset_refs: [],
    warnings: [],
    parser_warnings: [],
    parser_risks: [],
    decision_traces: [],
    summary: lowered_summary(3),
    policy: @lowering.pdf_v2_lowering_policy(
      @lowering.default_pdf_v2_lowering_options(),
    ),
    reason_tags: ["test_lowering"],
  }
  let doc = @pdfv2convert.lower_pdf_v2_result_to_core_document(
    lowered,
    "adapter.pdf",
    @pdfv2convert.default_pdf_v2_convert_options(),
  )
  assert_eq(doc.blocks.val.length(), 3)
  match doc.blocks.val[0] {
    @cor.Block::Heading(_, text) => assert_eq(text, "Title")
    _ => fail("expected heading")
  }
  match doc.blocks.val[1] {
    @cor.Block::ListItem(_, _, text) => assert_eq(text, "Item")
    _ => fail("expected list item")
  }
  match doc.blocks.val[2] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Caption")
    _ => fail("expected paragraph for caption text")
  }
}

///|
test "pdf v2 convert report placeholders require reason tags" {
  let templates = @pdfv2convert.pdf_v2_convert_report_templates()
  assert_eq(templates.length(), 4)
  assert_eq(templates[0].reason_tags_required, true)
  assert_eq(templates[3].name, "dispatcher_experimental_route")
}

///|
fn lowered_block(
  block_id : String,
  kind : @lowering.PdfV2LoweredBlockKind,
  text : String,
) -> @lowering.PdfV2LoweredBlock {
  {
    id: block_id,
    kind,
    text,
    page_index: 0,
    bbox: Some(@pdfv2.pdf_v2_default_rect()),
    origin: {
      page_index: 0,
      block_id: Some(block_id),
      line_ids: [],
      source_refs: [@pdfv2.pdf_v2_source_ref_for_page(0)],
      object_refs: [],
      feature_record_id: None,
      decision_id: None,
      parser_warning_count: 0,
      parser_risk_count: 0,
      reason_tags: ["test_origin"],
    },
    decision_trace: None,
    asset_ref: None,
    warnings: [],
    parser_warnings: [],
    parser_risks: [],
    reason_tags: ["test_block"],
  }
}

///|
fn lowered_summary(count : Int) -> @lowering.PdfV2LoweringSummary {
  {
    input_page_count: 1,
    input_text_block_count: count,
    feature_record_count: count,
    decision_count: count,
    lowered_block_count: count,
    text_count: 0,
    paragraph_count: 0,
    heading_count: 1,
    list_item_count: 1,
    caption_text_count: 1,
    table_like_text_count: 0,
    image_placeholder_count: 0,
    form_note_count: 0,
    annotation_note_count: 0,
    noise_suppressed_count: 0,
    unsupported_count: 0,
    uncertain_count: 0,
    missing_feature_count: 0,
    missing_decision_count: 0,
    abstain_count: 0,
    low_confidence_count: 0,
    high_risk_count: 0,
    warning_count: 0,
    parser_warning_count: 0,
    parser_risk_count: 0,
    decision_trace_count: 0,
    fail_closed: true,
    one_pass_required: true,
    legacy_fallback_allowed: false,
    convert_raw_reparse_allowed: false,
    reason_tags: ["test_summary"],
  }
}
