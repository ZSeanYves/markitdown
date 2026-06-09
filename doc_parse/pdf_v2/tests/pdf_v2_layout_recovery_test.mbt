///|
test "test_layout_recovery_consumes_normalized_model_only" {
  let doc = lr_doc_with_events([
    lr_text_event("text_event", 0, "A", 0.98, 12.0, 4),
  ])
  let result = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  assert_eq(result.summary.page_count, doc.pages.length())
  assert_eq(result.summary.input_text_block_count, 1)
  assert_eq(result.summary.scanned_once, true)
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
  assert_eq(result.reason_tags[1], "normalized_model_only")
}

///|
test "test_empty_document_yields_fail_closed_summary" {
  let doc = lr_doc_with_events([])
  let result = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  assert_eq(result.summary.input_text_block_count, 0)
  assert_eq(result.summary.fail_closed, true)
  assert_eq(result.summary.abstain, true)
  assert_eq(
    has_layout_risk(
      result.layout_risks,
      @layout_recovery.PdfV2LayoutRiskKind::LowSignalLayout,
    ),
    true,
  )
  assert_eq(result.regions.length(), 0)
}

///|
test "test_layout_result_propagates_warnings_and_risks" {
  let warning = @pdfv2.warn_malformed_object(
    "70 0 R",
    Some(lr_source_ref(0, 4)),
  )
  let doc = lr_doc_with_events([
    @source_event.pdf_v2_event_for_warning(
      "malformed_object",
      @source_event.PdfV2SourceEventKind::Diagnostic,
      warning,
    ),
  ])
  let result = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  assert_eq(result.summary.propagated_warning_count, doc.warnings.length())
  assert_eq(result.summary.propagated_risk_count, doc.risks.length())
  assert_eq(result.warnings.length() > doc.warnings.length(), true)
  assert_eq(has_warning_tag(result.warnings, "malformed_object"), true)
  assert_eq(
    has_layout_result_risk_tag(result.risks, "low_signal_document"),
    true,
  )
}

///|
test "test_region_candidate_preserves_page_block_line_context" {
  let result = lr_result_for_single_text("B")
  let region = result.regions[0]
  assert_eq(region.page_index, 0)
  assert_eq(
    region.kind == @layout_recovery.PdfV2LayoutRegionKind::Paragraph,
    true,
  )
  assert_eq(region.member_block_ids[0], "block_0")
  assert_eq(region.member_line_ids[0], "line_0")
  assert_eq(region.source_refs[0].page_index, 0)
  assert_eq(region.object_refs[0], "90 0 R")
  assert_eq(region.reason_tags[1], "paragraph_region_candidate")
}

///|
test "test_reading_order_candidate_preserves_block_ids" {
  let result = lr_result_for_single_text("C")
  let order = result.reading_orders[0]
  assert_eq(order.page_index, 0)
  assert_eq(order.selected_candidate_index == Some(0), true)
  assert_eq(order.candidates[0].ordered_block_ids[0], "block_0")
  assert_eq(
    order.candidates[0].source ==
    @layout_recovery.PdfV2ReadingOrderSource::SourceOrder,
    true,
  )
  assert_eq(order.candidates[0].reason_tags[1], "reading_order_candidate")
}

///|
test "test_cross_page_boundary_candidate_preserves_pages_and_blocks" {
  let doc = lr_two_page_doc()
  let result = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  let boundary = result.cross_page_boundaries[0]
  assert_eq(boundary.from_page_index, 0)
  assert_eq(boundary.to_page_index, 1)
  assert_eq(boundary.from_block_id == Some("block_0"), true)
  assert_eq(boundary.to_block_id == Some("block_0"), true)
  assert_eq(
    boundary.kind == @layout_recovery.PdfV2CrossPageBoundaryKind::Uncertain,
    true,
  )
  assert_eq(boundary.reason_tags[2], "no_merge_without_evidence")
}

///|
test "test_layout_decision_trace_has_scores_and_reason_tags" {
  let result = lr_result_for_single_text("D")
  let trace = result.regions[0].decision_trace
  assert_eq(trace.deterministic_constraint_score > 0.0, true)
  assert_eq(trace.model_confidence, 0.0)
  assert_eq(trace.feature_support_score > 0.0, true)
  assert_eq(trace.final_confidence > 0.0, true)
  assert_eq(
    trace.decision_source ==
    @layout_recovery.PdfV2LayoutDecisionSource::DeterministicRule,
    true,
  )
  assert_eq(trace.reason_tags[2], "parser_owned_fact")
}

///|
test "test_low_signal_layout_triggers_abstain_or_low_confidence" {
  let result = lr_result_for_empty_doc()
  assert_eq(result.summary.abstain, true)
  assert_eq(result.reading_orders[0].selected_candidate_index == None, true)
  assert_eq(result.reading_orders[0].candidates[0].decision_trace.abstain, true)
  assert_eq(
    has_layout_risk(
      result.layout_risks,
      @layout_recovery.PdfV2LayoutRiskKind::LowSignalLayout,
    ),
    true,
  )
}

///|
test "test_ocr_recommended_is_risk_not_fallback" {
  let result = lr_result_for_empty_doc()
  assert_eq(
    has_layout_risk(
      result.layout_risks,
      @layout_recovery.PdfV2LayoutRiskKind::OcrRecommendedButNotFallback,
    ),
    true,
  )
  assert_eq(
    has_layout_result_risk_tag(result.risks, "ocr_recommended_but_not_fallback"),
    true,
  )
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.reason_tags[5], "no_ocr_fallback")
}

///|
test "test_model_hint_conflict_is_reasoned_not_override" {
  let options = @layout_recovery.default_pdf_v2_layout_recovery_options()
  let hint = @layout_recovery.pdf_v2_layout_hint(
    "hint_region",
    @layout_recovery.PdfV2LayoutHintTargetKind::Region,
    Some(0),
    Some("block_0"),
    Some(@layout_recovery.PdfV2LayoutRegionKind::Table),
    None,
    0.99,
    0.90,
    ["synthetic_model_hint"],
  )
  let result = @layout_recovery.recover_pdf_v2_layout(
    lr_doc_with_events([lr_text_event("text_event", 0, "E", 0.98, 12.0, 4)]),
    { ..options, model_hints_enabled: false, hints: [hint] },
  )
  assert_eq(result.summary.model_hint_count, 1)
  assert_eq(result.summary.accepted_model_hint_count, 0)
  assert_eq(result.summary.conflict_model_hint_count, 1)
  assert_eq(
    has_layout_risk(
      result.layout_risks,
      @layout_recovery.PdfV2LayoutRiskKind::ModelHintConflict,
    ),
    true,
  )
  assert_eq(
    has_layout_result_risk_tag(result.risks, "model_hint_conflict"),
    true,
  )
  assert_eq(
    result.regions[0].kind == @layout_recovery.PdfV2LayoutRegionKind::Paragraph,
    true,
  )
}

///|
test "test_layout_recovery_does_not_emit_final_semantic_labels" {
  let result = lr_result_for_single_text("Figure 1")
  assert_eq(result.reason_tags[3], "no_final_semantic_labels")
  assert_eq(
    result.regions[0].kind == @layout_recovery.PdfV2LayoutRegionKind::Paragraph,
    true,
  )
  assert_eq(
    !has_reason_tag(result.regions[0].reason_tags, "final_caption"),
    true,
  )
  assert_eq(
    !has_reason_tag(result.regions[0].reason_tags, "markdown_table"),
    true,
  )
}

///|
test "test_one_pass_no_fallback_policy_preserved" {
  let result = lr_result_for_single_text("F")
  assert_eq(result.summary.scanned_once, true)
  assert_eq(result.summary.one_pass_required, true)
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
  assert_eq(result.reason_tags[4], "no_pdf_reparse")
}

///|
fn lr_result_for_single_text(
  text : String,
) -> @layout_recovery.PdfV2LayoutRecoveryResult {
  @layout_recovery.recover_pdf_v2_layout(
    lr_doc_with_events([lr_text_event("text_event", 0, text, 0.98, 12.0, 4)]),
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
}

///|
fn lr_result_for_empty_doc() -> @layout_recovery.PdfV2LayoutRecoveryResult {
  @layout_recovery.recover_pdf_v2_layout(
    lr_doc_with_events([]),
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
}

///|
fn lr_doc_with_events(
  events : Array[@source_event.PdfV2SourceEvent],
) -> @normalized_model.PdfV2DocumentModel {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    events,
  )
  let text = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  @normalized_model.build_pdf_v2_document_model(source, text)
}

///|
fn lr_two_page_doc() -> @normalized_model.PdfV2DocumentModel {
  let base = lr_doc_with_events([
    lr_text_event("left_text", 0, "Left", 0.98, 12.0, 4),
  ])
  let right_base = lr_doc_with_events([
    lr_text_event("right_text", 0, "Right", 0.98, 12.0, 7),
  ])
  let left_page = base.pages[0]
  let right_page = lr_page_with_index(right_base.pages[0], 1)
  {
    source_summary: {
      bytes_len: base.source_summary.bytes_len,
      page_count: 2,
      source_event_count: base.source_summary.source_event_count +
      right_base.source_summary.source_event_count,
      text_block_count: 2,
      warning_count: base.source_summary.warning_count +
      right_base.source_summary.warning_count,
      risk_count: base.source_summary.risk_count +
      right_base.source_summary.risk_count,
      scanned_once: base.source_summary.scanned_once,
      one_pass_required: base.source_summary.one_pass_required,
      legacy_fallback_allowed: base.source_summary.legacy_fallback_allowed,
      convert_raw_reparse_allowed: base.source_summary.convert_raw_reparse_allowed,
    },
    pages: [left_page, right_page],
    outlines: [],
    destinations: [],
    cross_page_boundaries: [],
    warnings: base.warnings + right_base.warnings,
    risks: base.risks + right_base.risks,
    classifier_ready_features: base.classifier_ready_features,
    reason_tags: base.reason_tags,
  }
}

///|
fn lr_page_with_index(
  page : @normalized_model.PdfV2Page,
  page_index : Int,
) -> @normalized_model.PdfV2Page {
  let blocks : Array[@normalized_model.PdfV2TextBlock] = []
  for block in page.text_blocks {
    blocks.push(lr_block_with_index(block, page_index))
  }
  {
    page_index,
    text_blocks: blocks,
    images: page.images,
    vectors: page.vectors,
    annotations: page.annotations,
    forms: page.forms,
    layout_regions: page.layout_regions,
    reading_order: {
      page_index,
      ordered_block_ids: page.reading_order.ordered_block_ids,
      confidence: page.reading_order.confidence,
      reason_tags: page.reading_order.reason_tags,
    },
    source_refs: [lr_source_ref(page_index, 7)],
    object_refs: page.object_refs,
    warnings: page.warnings,
    risks: page.risks,
  }
}

///|
fn lr_block_with_index(
  block : @normalized_model.PdfV2TextBlock,
  page_index : Int,
) -> @normalized_model.PdfV2TextBlock {
  let lines : Array[@normalized_model.PdfV2Line] = []
  for line in block.lines {
    lines.push(lr_line_with_index(line, page_index))
  }
  {
    id: block.id,
    text: block.text,
    bbox: block.bbox,
    lines,
    dominant_font: block.dominant_font,
    dominant_font_size: block.dominant_font_size,
    writing_direction: block.writing_direction,
    page_index,
    source_refs: [lr_source_ref(page_index, 7)],
    object_refs: block.object_refs,
    content_order_start: block.content_order_start,
    content_order_end: block.content_order_end,
    decode_confidence: block.decode_confidence,
    candidate_facts: block.candidate_facts,
    list_marker_candidates: block.list_marker_candidates,
    caption_prefix_candidates: block.caption_prefix_candidates,
    heading_shape_candidates: block.heading_shape_candidates,
    classifier_ready_features: block.classifier_ready_features,
    warnings: block.warnings,
    risks: block.risks,
    reason_tags: block.reason_tags,
  }
}

///|
fn lr_line_with_index(
  line : @normalized_model.PdfV2Line,
  page_index : Int,
) -> @normalized_model.PdfV2Line {
  {
    id: line.id,
    text: line.text,
    bbox: line.bbox,
    spans: line.spans,
    baseline_y: line.baseline_y,
    line_height: line.line_height,
    writing_direction: line.writing_direction,
    source_refs: [lr_source_ref(page_index, 7)],
    object_refs: line.object_refs,
    page_index,
    content_order_start: line.content_order_start,
    content_order_end: line.content_order_end,
    decode_confidence: line.decode_confidence,
    warnings: line.warnings,
    risks: line.risks,
  }
}

///|
fn lr_text_event(
  id : String,
  page_index : Int,
  text : String,
  confidence : Double,
  font_size : Double,
  content_order_index : Int,
) -> @source_event.PdfV2SourceEvent {
  @source_event.pdf_v2_text_payload_event(
    id,
    page_index,
    Some("90 0 R"),
    lr_source_ref(page_index, content_order_index),
    lr_payload(text, confidence, font_size, content_order_index),
  )
}

///|
fn lr_payload(
  text : String,
  confidence : Double,
  font_size : Double,
  content_order_index : Int,
) -> @source_event.PdfV2SourceTextPayload {
  {
    text,
    raw_bytes: Some(Bytes::from_array([65])),
    decoded_unicode: Some(text),
    bbox: Some({ x0: 12.0, y0: 22.0, x1: 72.0, y1: 36.0 }),
    origin: Some({ x: 12.0, y: 34.0 }),
    quad: None,
    advance_width: Some(8.0),
    glyph_width: Some(7.0),
    font_name: Some("F1"),
    font_family: Some("TestFont"),
    font_size: Some(font_size),
    style_flags: ["regular"],
    fill_color: None,
    stroke_color: None,
    rotation: 0,
    writing_direction: @pdfv2.PdfV2WritingDirection::LeftToRight,
    content_order_index: Some(content_order_index),
    decode_confidence: Some(confidence),
    reason_tags: ["layout_recovery_test_payload"],
  }
}

///|
fn lr_source_ref(
  page_index : Int,
  content_order_index : Int,
) -> @pdfv2.PdfV2SourceRef {
  {
    page_index,
    object_ref: Some("90 0 R"),
    stream_index: Some(0),
    op_index: Some(2),
    content_order_index: Some(content_order_index),
    text_object_id: Some(1),
  }
}

///|
fn has_layout_risk(
  risks : Array[@layout_recovery.PdfV2LayoutRisk],
  kind : @layout_recovery.PdfV2LayoutRiskKind,
) -> Bool {
  for risk in risks {
    if risk.kind == kind {
      return true
    }
  }
  false
}

///|
fn has_warning_tag(warnings : Array[@pdfv2.PdfV2Warning], tag : String) -> Bool {
  for warning in warnings {
    if has_reason_tag(warning.reason_tags, tag) {
      return true
    }
  }
  false
}

///|
fn has_layout_result_risk_tag(
  risks : Array[@pdfv2.PdfV2Risk],
  tag : String,
) -> Bool {
  for risk in risks {
    if has_reason_tag(risk.reason_tags, tag) {
      return true
    }
  }
  false
}

///|
fn has_reason_tag(tags : Array[String], tag : String) -> Bool {
  for reason_tag in tags {
    if reason_tag == tag {
      return true
    }
  }
  false
}
