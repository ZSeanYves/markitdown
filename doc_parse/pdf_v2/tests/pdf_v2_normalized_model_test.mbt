///|
test "normalized model aggregates source events and text reconstruction output" {
  let source = nm_source_doc("A", 0.98, 12.0)
  let text = nm_text_model(source)
  let model = @normalized_model.build_pdf_v2_document_model(source, text)
  assert_eq(model.pages.length(), 1)
  assert_eq(model.pages[0].text_blocks.length(), 1)
  assert_eq(model.pages[0].text_blocks[0].text, "A")
  assert_eq(model.source_summary.text_block_count, 1)
  assert_eq(model.source_summary.source_event_count, source.summary.event_count)
}

///|
test "normalized model preserves diagnostics and reason tags" {
  let warning = @pdfv2.warn_malformed_object("70 0 R", Some(nm_source_ref(0)))
  let event = @source_event.pdf_v2_event_for_warning(
    "malformed_object",
    @source_event.PdfV2SourceEventKind::Diagnostic,
    warning,
  )
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [event],
  )
  let text = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let model = @normalized_model.build_pdf_v2_document_model(source, text)
  assert_eq(model.warnings.length() > 0, true)
  assert_eq(model.reason_tags[0], "normalized_model_scaffold")
  assert_eq(model.pages[0].warnings[0].reason_tags[0], "malformed_object")
}

///|
test "normalized model preserves source refs object refs page index and content order" {
  let model = @normalized_model.build_pdf_v2_document_model(
    nm_source_doc("B", 0.98, 12.0),
    nm_text_model(nm_source_doc("B", 0.98, 12.0)),
  )
  let block = model.pages[0].text_blocks[0]
  assert_eq(block.page_index, 0)
  assert_eq(block.object_refs[0], "80 0 R")
  assert_true(block.content_order_start == Some(5))
  assert_true(block.source_refs[0].content_order_index == Some(5))
  assert_eq(block.lines[0].spans[0].chars[0].text, "B")
}

///|
test "normalized model keeps candidate facts without final semantic labels" {
  let source = nm_source_doc("-", 0.98, 12.0)
  let model = @normalized_model.build_pdf_v2_document_model(
    source,
    nm_text_model(source),
  )
  let block = model.pages[0].text_blocks[0]
  assert_eq(block.candidate_facts.length(), 1)
  assert_true(
    block.candidate_facts[0].kind ==
    @text_reconstruction.PdfV2TextCandidateFactKind::ListMarkerCandidate,
  )
  assert_eq(block.list_marker_candidates[0].reason_tags[1], "parser_shape_fact")
  assert_eq(block.classifier_ready_features.reason_tags[1], "parser_fact")
}

///|
test "normalized model preserves one pass no fallback and runtime closure risks" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [
      @source_event.pdf_v2_event_for_fallback_forbidden(
        "legacy parser fallback attempted",
      ),
      @source_event.pdf_v2_event_for_risk(
        "runtime_closure",
        @source_event.PdfV2SourceEventKind::Diagnostic,
        @pdfv2.risk_runtime_closure_violation(
          @pdfv2.PdfV2RuntimeClosureCategory::TrainingExport,
        ),
      ),
    ],
  )
  let text = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let model = @normalized_model.build_pdf_v2_document_model(source, text)
  assert_eq(model.source_summary.scanned_once, true)
  assert_eq(model.source_summary.one_pass_required, true)
  assert_eq(model.source_summary.legacy_fallback_allowed, false)
  assert_eq(model.source_summary.convert_raw_reparse_allowed, false)
  assert_eq(has_risk_tag(model.risks, "fallback_forbidden_violation"), true)
  assert_eq(has_risk_tag(model.risks, "runtime_closure_violation"), true)
}

///|
test "normalized model exposes reading order placeholder" {
  let source = nm_source_doc("C", 0.98, 12.0)
  let model = @normalized_model.build_pdf_v2_document_model(
    source,
    nm_text_model(source),
  )
  assert_eq(model.pages[0].reading_order.page_index, 0)
  assert_eq(model.pages[0].reading_order.ordered_block_ids[0], "block_0")
  assert_eq(
    model.pages[0].reading_order.reason_tags[0],
    "source_order_placeholder",
  )
}

///|
test "normalized model document features are classifier ready placeholders" {
  let source = nm_source_doc("D", 0.98, 12.0)
  let model = @normalized_model.build_pdf_v2_document_model(
    source,
    nm_text_model(source),
  )
  assert_eq(
    model.classifier_ready_features.reason_tags[0],
    "document_feature_placeholder",
  )
  assert_eq(
    model.pages[0].text_blocks[0].classifier_ready_features.reason_tags[0],
    "classifier_ready_placeholder",
  )
}

///|
fn nm_text_model(
  source : @source_event.PdfV2SourceDocument,
) -> @text_reconstruction.PdfV2TextModel {
  @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
}

///|
fn nm_source_doc(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @source_event.PdfV2SourceDocument {
  let event = @source_event.pdf_v2_text_payload_event(
    "text_event",
    0,
    Some("80 0 R"),
    nm_source_ref(0),
    nm_payload(text, confidence, font_size),
  )
  @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [event],
  )
}

///|
fn nm_payload(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @source_event.PdfV2SourceTextPayload {
  {
    text,
    raw_bytes: Some(Bytes::from_array([65])),
    decoded_unicode: Some(text),
    bbox: Some({ x0: 11.0, y0: 21.0, x1: 19.0, y1: 33.0 }),
    origin: Some({ x: 11.0, y: 31.0 }),
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
    content_order_index: Some(5),
    decode_confidence: Some(confidence),
    reason_tags: ["normalized_model_test_payload"],
  }
}

///|
fn nm_source_ref(page_index : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index,
    object_ref: Some("80 0 R"),
    stream_index: Some(0),
    op_index: Some(3),
    content_order_index: Some(5),
    text_object_id: Some(1),
  }
}

///|
fn has_risk_tag(risks : Array[@pdfv2.PdfV2Risk], tag : String) -> Bool {
  for risk in risks {
    for reason_tag in risk.reason_tags {
      if reason_tag == tag {
        return true
      }
    }
  }
  false
}
