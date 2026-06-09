///|
test "test_text_model_consumes_source_document_only" {
  let source = source_doc_with_text("A", 0.98, 12.0)
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.source_event_count, source.summary.event_count)
  assert_eq(model.summary.scanned_once, true)
  assert_eq(model.summary.legacy_fallback_allowed, false)
}

///|
test "test_empty_source_produces_summary_not_silent_loss" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 0)
  assert_eq(model.summary.warning_count > 0, true)
  assert_eq(model.summary.risk_count > 0, true)
  assert_eq(model.summary.reason_tags[2], "fail_closed")
}

///|
test "test_source_diagnostics_propagate_to_text_summary" {
  let warning = @pdfv2.warn_malformed_object("50 0 R", Some(tr_source_ref(0)))
  let event = @source_event.pdf_v2_event_for_warning(
    "malformed_object",
    @source_event.PdfV2SourceEventKind::Diagnostic,
    warning,
  )
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [event],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.source_diagnostic_event_count, 2)
  assert_eq(model.summary.warning_count >= 1, true)
}

///|
test "test_synthetic_text_event_builds_char_span_line_block" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("A", 0.98, 12.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.glyph_count, 1)
  assert_eq(model.summary.char_count, 1)
  assert_eq(model.summary.span_count, 1)
  assert_eq(model.summary.line_count, 1)
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "A")
}

///|
test "test_char_span_line_block_preserve_source_object_page_context" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("B", 0.98, 12.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let block = model.pages[0].blocks[0]
  assert_eq(block.page_index, 0)
  assert_eq(block.object_refs[0], "60 0 R")
  assert_true(block.content_order_start == Some(4))
  assert_true(block.source_refs[0].content_order_index == Some(4))
  assert_true(block.lines[0].spans[0].chars[0].object_ref == Some("60 0 R"))
}

///|
test "test_decode_confidence_rolls_up_to_summary" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("C", 0.20, 12.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.low_confidence_count, 1)
  assert_eq(model.summary.failed_decode_count, 0)
  assert_true(
    model.pages[0].blocks[0].decode_confidence ==
    @text_reconstruction.PdfV2DecodeConfidence::Low,
  )
}

///|
test "test_low_confidence_decode_keeps_text_with_risk" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("D", 0.20, 12.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let block = model.pages[0].blocks[0]
  assert_eq(block.text, "D")
  assert_eq(block.risks.length() > 0, true)
  assert_eq(block.warnings.length() > 0, true)
  assert_eq(block.reason_tags[0], "synthetic_text_payload")
}

///|
test "test_candidate_facts_are_not_final_semantic_labels" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("-", 0.98, 12.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let block = model.pages[0].blocks[0]
  assert_eq(block.candidate_facts.length(), 1)
  assert_true(
    block.candidate_facts[0].kind ==
    @text_reconstruction.PdfV2TextCandidateFactKind::ListMarkerCandidate,
  )
  assert_eq(block.candidate_facts[0].reason_tags[1], "parser_shape_fact")
}

///|
test "test_list_marker_candidate_has_reason_tags" {
  let candidate = @text_reconstruction.list_marker_candidate("1.", 0.82, [
    tr_source_ref(0),
  ])
  assert_eq(candidate.marker_text, "1.")
  assert_eq(candidate.reason_tags[0], "list_marker_candidate")
}

///|
test "test_caption_prefix_candidate_has_reason_tags" {
  let candidate = @text_reconstruction.caption_prefix_candidate(
    "Figure",
    0.77,
    [tr_source_ref(0)],
  )
  assert_eq(candidate.prefix_text, "Figure")
  assert_eq(candidate.reason_tags[0], "caption_prefix_candidate")
}

///|
test "test_heading_shape_candidate_has_reason_tags" {
  let candidate = @text_reconstruction.heading_shape_candidate(
    "Introduction",
    Some(6.0),
    0.66,
    [tr_source_ref(0)],
  )
  assert_eq(candidate.text, "Introduction")
  assert_eq(candidate.reason_tags[0], "heading_shape_candidate")
}

///|
test "test_text_model_keeps_one_pass_no_fallback_policy" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("E", 0.98, 18.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.scanned_once, true)
  assert_eq(model.summary.one_pass_required, true)
  assert_eq(model.summary.legacy_fallback_allowed, false)
  assert_eq(model.summary.convert_raw_reparse_allowed, false)
}

///|
test "test_heading_shape_is_candidate_only" {
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source_doc_with_text("Title", 0.98, 18.0),
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let block = model.pages[0].blocks[0]
  assert_eq(block.heading_shape_candidates.length(), 1)
  assert_eq(
    block.heading_shape_candidates[0].reason_tags[1],
    "parser_shape_fact",
  )
}

///|
fn source_doc_with_text(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @source_event.PdfV2SourceDocument {
  let event = @source_event.pdf_v2_text_payload_event(
    "text_event",
    0,
    Some("60 0 R"),
    tr_source_ref(0),
    synthetic_payload(text, confidence, font_size),
  )
  @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [event],
  )
}

///|
fn synthetic_payload(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @source_event.PdfV2SourceTextPayload {
  {
    text,
    raw_bytes: Some(Bytes::from_array([65])),
    decoded_unicode: Some(text),
    bbox: Some({ x0: 10.0, y0: 20.0, x1: 18.0, y1: 32.0 }),
    origin: Some({ x: 10.0, y: 30.0 }),
    quad: None,
    advance_width: Some(8.0),
    glyph_width: Some(7.5),
    font_name: Some("F1"),
    font_family: Some("TestFont"),
    font_size: Some(font_size),
    style_flags: ["regular"],
    fill_color: None,
    stroke_color: None,
    rotation: 0,
    writing_direction: @pdfv2.PdfV2WritingDirection::LeftToRight,
    content_order_index: Some(4),
    decode_confidence: Some(confidence),
    reason_tags: ["synthetic_text_payload"],
  }
}

///|
fn tr_source_ref(page_index : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index,
    object_ref: Some("60 0 R"),
    stream_index: Some(0),
    op_index: Some(2),
    content_order_index: Some(4),
    text_object_id: Some(1),
  }
}
