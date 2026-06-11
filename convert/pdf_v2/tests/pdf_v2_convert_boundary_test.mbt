///|
fn phase14_pad_xref_offset(value : Int) -> String {
  let mut out = value.to_string()
  while out.length() < 10 {
    out = "0" + out
  }
  out
}

///|
fn phase14_pdf_object(number : Int, body : String) -> String {
  "\{number} 0 obj\n" + body + "\nendobj\n"
}

///|
fn phase14_stream_object(content : String) -> String {
  "<< /Length " +
  content.length().to_string() +
  " >>\nstream\n" +
  content +
  "endstream"
}

///|
fn phase14_pdf_from_objects(objects : Array[(Int, String)]) -> String {
  let header = "%PDF-1.4\n"
  let pieces : Array[String] = [header]
  let offsets : Array[Int] = []
  let mut offset = header.length()
  for pair in objects {
    let object_text = phase14_pdf_object(pair.0, pair.1)
    offsets.push(offset)
    pieces.push(object_text)
    offset = offset + object_text.length()
  }
  let xref_offset = offset
  let size = objects.length() + 1
  let xref_entries : Array[String] = [
    "xref\n0 \{size}\n",
    "0000000000 65535 f \n",
  ]
  for object_offset in offsets {
    xref_entries.push(phase14_pad_xref_offset(object_offset) + " 00000 n \n")
  }
  xref_entries.push(
    "trailer\n<< /Root 1 0 R /Size \{size} >>\nstartxref\n\{xref_offset}\n%%EOF\n",
  )
  pieces.push(xref_entries.join(""))
  pieces.join("")
}

///|
fn phase14_text_pdf(content : String) -> String {
  phase14_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    ),
    (4, phase14_stream_object(content)),
    (5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
  ])
}

///|
fn phase14_simple_text_pdf() -> String {
  phase14_text_pdf("BT\n/F1 12 Tf\n72 720 Td\n(Hello) Tj\nET\n")
}

///|
fn phase17_two_image_text_pdf() -> String {
  let content = "BT\n/F1 12 Tf\n72 720 Td\n(Hello) Tj\nET\nq\n/Im1 Do\n/Im2 Do\nQ\n"
  phase14_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 7 0 R >> /XObject << /Im1 5 0 R /Im2 6 0 R >> >> /Contents 4 0 R >>",
    ),
    (4, phase14_stream_object(content)),
    (
      5, "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length 3 >>\nstream\nabcendstream",
    ),
    (
      6, "<< /Type /XObject /Subtype /Image /Width 3 /Height 2 /ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /DCTDecode /Length 3 >>\nstream\nxyzendstream",
    ),
    (7, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
  ])
}

///|
fn phase14_write_fixture(path : String, body : String) -> Unit raise {
  @fs.write_string_to_file(path, body, encoding="utf8") catch {
    err => fail("write fixture failed: " + err.to_string())
  }
}

///|
fn phase14_cleanup_fixture(path : String) -> Unit {
  if @fs.path_exists(path) {
    let _ = @fs.remove_file(path) catch { _ => () }
  }
}

///|
fn phase14_page_ref() -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(0),
    object_id: Some("3 0 R"),
    stream_index: None,
    op_index: None,
    content_order_index: None,
    kind: @pdfv2.PdfV2SourceKind::Page,
  }
}

///|
fn phase14_text_ref(order : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(0),
    object_id: Some("4 0 R"),
    stream_index: Some(0),
    op_index: Some(order),
    content_order_index: Some(order),
    kind: @pdfv2.PdfV2SourceKind::TextOp,
  }
}

///|
fn phase14_image_ref() -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(0),
    object_id: Some("5 0 R"),
    stream_index: None,
    op_index: None,
    content_order_index: None,
    kind: @pdfv2.PdfV2SourceKind::Image,
  }
}

///|
fn phase14_page() -> @pdfv2.PdfV2PageModel {
  let page_ref = phase14_page_ref()
  let bbox : @pdfv2.PdfV2BBox = { x0: 0.0, y0: 0.0, x1: 612.0, y1: 792.0 }
  {
    page_index: 0,
    page_label: None,
    media_box: bbox,
    crop_box: None,
    rotate: 0,
    user_unit: None,
    resources_present: false,
    source_ref: page_ref,
    blocks: [],
    lines: [],
    spans: [],
    chars: [],
    images: [],
    inline_images: [],
    annotations: [],
    links: [],
    forms: [],
    resources: [],
    metadata_refs: [],
    page_warnings: [],
    page_risks: [],
    text_blocks: [],
    layout_regions: [],
  }
}

///|
fn phase14_line(
  line_index : Int,
  text : String,
  source_ref : @pdfv2.PdfV2SourceRef,
) -> @pdfv2.PdfV2LineCandidate {
  {
    page_index: Some(0),
    line_index,
    text,
    spans: [],
    source_refs: [source_ref],
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Unknown,
    warnings: [],
    reason_tags: ["line_candidate"],
    merge_reason_tags: [],
    break_reason_tags: [],
    text_signal: @pdfv2.pdf_v2_build_line_text_signal(
      text,
      @pdfv2.PdfV2TextDecodeConfidence::High,
      [source_ref],
      ["line_candidate"],
    ),
    bbox: None,
    baseline: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
  }
}

///|
fn phase14_block(
  block_index : Int,
  text : String,
  lines : Array[@pdfv2.PdfV2LineCandidate],
  decode_confidence : @pdfv2.PdfV2TextDecodeConfidence,
) -> @pdfv2.PdfV2BlockCandidate {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  for line in lines {
    refs.append(line.source_refs)
  }
  if refs.length() == 0 {
    refs.push(phase14_text_ref(block_index))
  }
  {
    page_index: Some(0),
    block_index,
    text,
    lines,
    source_refs: refs,
    decode_confidence,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Unknown,
    warnings: [],
    reason_tags: ["block_candidate"],
    merge_reason_tags: [],
    break_reason_tags: [],
    boundary_signal: @pdfv2.pdf_v2_build_block_boundary_signal(
      lines,
      ["block_candidate"],
      None,
    ),
    bbox: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
    block_kind_hint: if decode_confidence ==
      @pdfv2.PdfV2TextDecodeConfidence::High {
      @pdfv2.PdfV2BlockKindHint::TextLike
    } else {
      @pdfv2.PdfV2BlockKindHint::LowSignal
    },
  }
}

///|
fn phase14_model(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
) -> @pdfv2.PdfV2DocumentModel {
  let page_ref = phase14_page_ref()
  let page = { ..phase14_page(), blocks, }
  {
    document_id: None,
    page_count: 1,
    metadata: {
      title: None,
      author: None,
      subject: None,
      creator: None,
      producer: None,
      keywords: None,
      created: None,
      modified: None,
      source_refs: [page_ref],
    },
    pages: [page],
    source_events: [],
    outlines: [],
    destinations: [],
    metadata_candidates: [],
    unsupported_capabilities: [],
    partial_fact_reports: [],
    object_summary: @pdfv2.pdf_v2_empty_object_summary(),
    layout: @pdfv2.recover_pdf_v2_layout_noop([page_ref]),
    warnings: [],
    risks: [],
    source_summary: @pdfv2.pdf_v2_source_summary(0, 1, 0, 0),
    reconstruction_summary: @pdfv2.pdf_v2_empty_reconstruction_summary(),
    capabilities: @pdfv2.pdf_v2_core_supported_capabilities(),
    one_pass: true,
    no_fallback: true,
    model_version: "pdf-v2-phase14-test",
  }
}

///|
fn phase14_feature_set(
  model : @pdfv2.PdfV2DocumentModel,
) -> @pdfv2.PdfV2FeatureSet {
  @pdfv2.pdf_v2_features_from_model_and_layout(
    model,
    @pdfv2.pdf_v2_layout_facts_from_model(model),
  )
}

///|
fn phase14_default_input(
  model : @pdfv2.PdfV2DocumentModel,
  features : @pdfv2.PdfV2FeatureSet?,
) -> @pdfv2conv.PdfV2FactLoweringInput {
  @pdfv2conv.pdf_v2_fact_lowering_input(
    model,
    features,
    @pdfv2conv.default_pdf_v2_fact_lowering_options(),
  )
}

///|
fn phase14_has_fragment_kind(
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
  kind : @pdfv2conv.PdfV2FactFragmentKind,
) -> Bool {
  for fragment in fragments {
    if fragment.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase14_has_warning_tag(
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
fn phase14_has_fragment_tag(
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
  tag : String,
) -> Bool {
  for fragment in fragments {
    if fragment.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase14_fragments_have_semantic_markdown(
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
) -> Bool {
  for fragment in fragments {
    if phase14_text_contains_semantic_markdown(fragment.text) {
      return true
    }
  }
  false
}

///|
fn phase14_has_risk_tag(risks : Array[@pdfv2.PdfV2Risk], tag : String) -> Bool {
  for risk in risks {
    if risk.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn phase14_has_warning_kind(
  warnings : Array[@pdfv2.PdfV2Warning],
  kind : @pdfv2.PdfV2WarningKind,
) -> Bool {
  for warning in warnings {
    if warning.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase14_has_risk_kind(
  risks : Array[@pdfv2.PdfV2Risk],
  kind : @pdfv2.PdfV2RiskKind,
) -> Bool {
  for risk in risks {
    if risk.kind == kind {
      return true
    }
  }
  false
}

///|
fn phase14_plain_text_fragment_count(
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
) -> Int {
  let mut count = 0
  for fragment in fragments {
    if fragment.kind == @pdfv2conv.PdfV2FactFragmentKind::PlainText {
      count = count + 1
    }
  }
  count
}

///|
fn phase14_find_fragment_kind(
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
  kind : @pdfv2conv.PdfV2FactFragmentKind,
) -> @pdfv2conv.PdfV2FactFragment? {
  for fragment in fragments {
    if fragment.kind == kind {
      return Some(fragment)
    }
  }
  None
}

///|
fn phase14_text_contains_semantic_markdown(text : String) -> Bool {
  text.contains("# ") ||
  text.contains("![") ||
  text.contains("](") ||
  text.contains("|---") ||
  text.contains("<table")
}

///|
fn phase16_gate_decision(
  kind : @pdfv2conv.PdfV2BlockDecisionKind,
  block_index : Int,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  tags : Array[String],
) -> @pdfv2conv.PdfV2BlockGateDecision {
  {
    page_index: Some(0),
    block_index,
    decision_kind: kind,
    confidence: if kind == @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate {
      0.55
    } else {
      0.0
    },
    risk_score: if kind == @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate {
      0.1
    } else {
      0.8
    },
    abstain_reason_tags: tags,
    source_refs,
    warning_count: 0,
    risk_count: 0,
    feature_summary: "phase16-test",
    decision_source: @pdfv2conv.PdfV2NoModelDecisionSource::NoModelGate,
  }
}

///|
fn phase16_gate_result(
  decisions : Array[@pdfv2conv.PdfV2BlockGateDecision],
) -> @pdfv2conv.PdfV2GateResult {
  let mut plain_text_candidate_count = 0
  let mut abstain_count = 0
  let mut unknown_count = 0
  for decision in decisions {
    match decision.decision_kind {
      @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate =>
        plain_text_candidate_count = plain_text_candidate_count + 1
      @pdfv2conv.PdfV2BlockDecisionKind::Abstain =>
        abstain_count = abstain_count + 1
      @pdfv2conv.PdfV2BlockDecisionKind::Unknown =>
        unknown_count = unknown_count + 1
    }
  }
  {
    decisions,
    warnings: [],
    risks: [],
    summary: {
      block_count: decisions.length(),
      plain_text_candidate_count,
      abstain_count,
      unknown_count,
      risk_guard_count: 0,
      cap_guard_count: 0,
      unsupported_guard_count: 0,
      missing_geometry_guard_count: 0,
      warning_count: 0,
      risk_count: 0,
    },
    one_pass: true,
    no_fallback: true,
  }
}

///|
fn phase16_input(
  model : @pdfv2.PdfV2DocumentModel,
  gate_result : @pdfv2conv.PdfV2GateResult,
  options : @pdfv2conv.PdfV2FactLoweringOptions,
) -> @pdfv2conv.PdfV2FactLoweringInput {
  @pdfv2conv.pdf_v2_fact_lowering_input_with_gate(
    model,
    None,
    Some(gate_result),
    options,
  )
}

///|
fn phase20_fragment(
  kind : @pdfv2conv.PdfV2FactFragmentKind,
  text : String,
  page_index : Int?,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> @pdfv2conv.PdfV2FactFragment {
  {
    kind,
    text,
    page_index,
    block_index: None,
    line_count: if kind == @pdfv2conv.PdfV2FactFragmentKind::PlainText {
      1
    } else {
      0
    },
    source_refs,
    reason_tags: ["phase20_bridge_test"],
  }
}

///|
fn phase20_fragment_with_line_count(
  kind : @pdfv2conv.PdfV2FactFragmentKind,
  text : String,
  page_index : Int?,
  line_count : Int,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> @pdfv2conv.PdfV2FactFragment {
  {
    kind,
    text,
    page_index,
    block_index: None,
    line_count,
    source_refs,
    reason_tags: ["phase20_bridge_test"],
  }
}

///|
fn phase20_model_summary(
  page_count : Int,
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
) -> @pdfv2conv.PdfV2ConvertModelSummary {
  {
    page_count,
    source_event_count: 0,
    block_count: fragments.length(),
    line_count: 0,
    span_count: 0,
    char_count: 0,
    unsupported_capability_count: 0,
    partial_fact_count: 0,
    warning_count: 0,
    risk_count: 0,
  }
}

///|
fn phase20_layout_summary(page_count : Int) -> @pdfv2.PdfV2LayoutFactSummary {
  {
    page_count,
    pages_with_text_candidates: 0,
    pages_with_block_candidates: 0,
    pages_with_missing_geometry: 0,
    pages_source_order_only: 0,
    pages_with_layout_not_attempted: 0,
    unsupported_capability_count: 0,
    partial_fact_count: 0,
    capped_object_count: 0,
    metadata_only_count: 0,
    warning_count: 0,
    risk_count: 0,
  }
}

///|
fn phase20_feature_summary() -> @pdfv2.PdfV2FeatureSummary {
  {
    document_feature_count: 0,
    page_feature_count: 0,
    block_feature_count: 0,
    object_feature_count: 0,
    low_signal_block_count: 0,
    missing_geometry_block_count: 0,
    unsupported_object_count: 0,
    partial_object_count: 0,
    capped_object_count: 0,
    warning_count: 0,
    risk_count: 0,
  }
}

///|
fn phase20_lowering_summary(
  page_count : Int,
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
) -> @pdfv2conv.PdfV2FactLoweringSummary {
  let mut plain_text_fragment_count = 0
  let mut object_placeholder_count = 0
  let mut low_confidence_note_count = 0
  for fragment in fragments {
    match fragment.kind {
      @pdfv2conv.PdfV2FactFragmentKind::PlainText =>
        plain_text_fragment_count = plain_text_fragment_count + 1
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote =>
        object_placeholder_count = object_placeholder_count + 1
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote =>
        low_confidence_note_count = low_confidence_note_count + 1
      @pdfv2conv.PdfV2FactFragmentKind::PageBreak => ()
    }
  }
  {
    page_count,
    block_count: fragments.length(),
    line_count: 0,
    plain_text_fragment_count,
    object_placeholder_count,
    low_confidence_note_count,
    gate_note_count: 0,
    gate_plain_text_candidate_count: 0,
    gate_abstain_count: 0,
    gate_unknown_count: 0,
    gate_missing_decision_count: 0,
    gate_skipped_plain_text_count: 0,
    warning_count: 0,
    risk_count: 0,
    capped_output: false,
  }
}

///|
fn phase20_pipeline_ok(
  page_count : Int,
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
) -> @pdfv2conv.PdfV2ConvertPipelineResult {
  phase20_pipeline_ok_with_candidates(page_count, fragments, [])
}

///|
fn phase20_pipeline_ok_with_candidates(
  page_count : Int,
  fragments : Array[@pdfv2conv.PdfV2FactFragment],
  text_flow_candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> @pdfv2conv.PdfV2ConvertPipelineResult {
  @pdfv2conv.PdfV2ConvertPipelineResult::ConvertPipelineOk({
    source_summary: @pdfv2.pdf_v2_source_summary(0, page_count, 0, 0),
    model_summary: phase20_model_summary(page_count, fragments),
    document_properties: None,
    layout_summary: phase20_layout_summary(page_count),
    feature_summary: phase20_feature_summary(),
    gate_summary: None,
    lowering_summary: phase20_lowering_summary(page_count, fragments),
    fragments,
    text_flow_candidates,
    warnings: [],
    risks: [],
    one_pass: true,
    no_fallback: true,
  })
}

///|
fn phase20_pipeline_err(
  stage : String,
  message : String,
) -> @pdfv2conv.PdfV2ConvertPipelineResult {
  @pdfv2conv.PdfV2ConvertPipelineResult::ConvertPipelineErr({
    stage,
    message,
    fragments: [],
    warnings: [],
    risks: [],
    one_pass: true,
    no_fallback: true,
  })
}

///|
fn phase20_bridge_document(
  result : @pdfv2conv.PdfV2ConvertPipelineResult,
  options : @pdfv2conv.PdfV2ProductBridgeOptions,
) -> @cor.Document raise {
  match @pdfv2conv.pdf_v2_pipeline_result_to_document(result, options) {
    Ok(doc) => doc
    Err(err) => fail("expected product bridge success: " + err.to_string())
  }
}

///|
fn phase20_assert_text_bridge_blocks(doc : @cor.Document) -> Unit raise {
  for block in doc.blocks.val {
    match block {
      @cor.Block::Heading(_, text) =>
        assert_true(!phase14_text_contains_semantic_markdown(text))
      @cor.Block::Paragraph(text) =>
        assert_true(!phase14_text_contains_semantic_markdown(text))
      @cor.Block::ListItem(_, _, text) =>
        assert_true(!phase14_text_contains_semantic_markdown(text))
      @cor.Block::BlankLine => ()
      _ => fail("unexpected product bridge block")
    }
  }
}

///|
test "pdf v2 lowering scaffold consumes parser model without raw scan fallback" {
  let model = @pdfv2.build_empty_pdf_v2_document()
  let lowered = @pdfv2conv.lower_pdf_v2_document_scaffold(model)

  assert_true(lowered.fragments.length() == 0)
  assert_true(!lowered.fallback_used)
  assert_true(!lowered.raw_pdf_scanned_by_convert)
  assert_true(lowered.risks.length() == model.risks.length())
}

///|
test "pdf v2 markdown policy defaults to preserving uncertain text" {
  let policy = @pdfv2conv.default_pdf_v2_markdown_policy()
  assert_true(@pdfv2conv.pdf_v2_policy_keeps_uncertain_text(policy))
}

///|
test "pdf v2 fact lowerer emits minimal model plain text only" {
  let line = phase14_line(0, "Hello", phase14_text_ref(0))
  let block = phase14_block(
    0,
    "Hello",
    [line],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )

  assert_true(lowered.fragments.length() == 1)
  assert_true(
    lowered.fragments[0].kind == @pdfv2conv.PdfV2FactFragmentKind::PlainText,
  )
  assert_true(lowered.fragments[0].text == "Hello")
  assert_true(lowered.summary.plain_text_fragment_count == 1)
  assert_true(
    !phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
    ),
  )
  assert_true(lowered.one_pass)
  assert_true(lowered.no_fallback)
}

///|
test "pdf v2 fact lowerer gate plain text candidate outputs text" {
  let source_ref = phase14_text_ref(0)
  let line = phase14_line(0, "Gate text", source_ref)
  let block = phase14_block(
    0,
    "Gate text",
    [line],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
      0,
      [source_ref],
      ["plain_text_candidate"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(
      model,
      gate,
      @pdfv2conv.default_pdf_v2_fact_lowering_options(),
    ),
  )

  assert_true(lowered.fragments.length() == 1)
  assert_true(
    lowered.fragments[0].kind == @pdfv2conv.PdfV2FactFragmentKind::PlainText,
  )
  assert_true(lowered.fragments[0].text == "Gate text")
  assert_true(lowered.fragments[0].source_refs.length() == 1)
  assert_true(lowered.fragments[0].source_refs[0].object_id == Some("4 0 R"))
  assert_true(
    lowered.fragments[0].reason_tags.contains("gate_plain_text_candidate"),
  )
  assert_true(lowered.summary.gate_plain_text_candidate_count == 1)
  assert_true(
    !phase14_text_contains_semantic_markdown(lowered.fragments[0].text),
  )
}

///|
test "pdf v2 fact lowerer gate abstain skips text by default" {
  let source_ref = phase14_text_ref(0)
  let block = phase14_block(
    0,
    "Unsafe",
    [phase14_line(0, "Unsafe", source_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
      0,
      [source_ref],
      ["unsupported_guard"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(
      model,
      gate,
      @pdfv2conv.default_pdf_v2_fact_lowering_options(),
    ),
  )

  assert_true(
    !phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
    ),
  )
  assert_true(lowered.summary.gate_abstain_count == 1)
  assert_true(lowered.summary.gate_skipped_plain_text_count == 1)
  assert_true(lowered.no_fallback)
}

///|
test "pdf v2 fact lowerer gate abstain note is conservative" {
  let source_ref = phase14_text_ref(0)
  let block = phase14_block(
    0,
    "Maybe",
    [phase14_line(0, "Maybe", source_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
      0,
      [source_ref],
      ["cap_guard"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(model, gate, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      emit_abstain_notes: true,
    }),
  )

  assert_true(phase14_plain_text_fragment_count(lowered.fragments) == 0)
  assert_true(lowered.summary.gate_note_count == 1)
  match
    phase14_find_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
    ) {
    Some(note) => {
      assert_true(note.text.contains("gate abstained"))
      assert_true(note.reason_tags.contains("gate_abstain"))
      assert_true(note.reason_tags.contains("cap_guard"))
      assert_true(note.source_refs.length() == 1)
      assert_true(note.source_refs[0].object_id == Some("4 0 R"))
    }
    None => fail("expected abstain note")
  }

  let allow_lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(model, gate, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      allow_abstain_plain_text: true,
    }),
  )
  assert_true(phase14_plain_text_fragment_count(allow_lowered.fragments) == 1)
  assert_true(allow_lowered.summary.gate_note_count == 1)
  assert_true(
    phase14_has_risk_tag(allow_lowered.risks, "allow_abstain_plain_text"),
  )
}

///|
test "pdf v2 fact lowerer gate unknown stays option controlled" {
  let source_ref = phase14_text_ref(0)
  let block = phase14_block(
    0,
    "Unknown text",
    [phase14_line(0, "Unknown text", source_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::Unknown,
      0,
      [source_ref],
      ["unknown_fail_closed"],
    ),
  ])
  let default_lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(
      model,
      gate,
      @pdfv2conv.default_pdf_v2_fact_lowering_options(),
    ),
  )
  assert_true(phase14_plain_text_fragment_count(default_lowered.fragments) == 1)
  assert_true(default_lowered.fragments[0].reason_tags.contains("gate_unknown"))
  assert_true(default_lowered.summary.gate_unknown_count == 1)

  let skip_lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(model, gate, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      allow_unknown_plain_text: false,
      emit_unknown_notes: true,
    }),
  )
  assert_true(phase14_plain_text_fragment_count(skip_lowered.fragments) == 0)
  assert_true(
    phase14_has_fragment_kind(
      skip_lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
    ),
  )
  assert_true(skip_lowered.summary.gate_skipped_plain_text_count == 1)
}

///|
test "pdf v2 fact lowerer missing gate decision is unknown" {
  let first_ref = phase14_text_ref(0)
  let second_ref = phase14_text_ref(1)
  let first = phase14_block(
    0,
    "Known",
    [phase14_line(0, "Known", first_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let second = phase14_block(
    1,
    "Missing",
    [phase14_line(1, "Missing", second_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([first, second])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
      0,
      [first_ref],
      ["plain_text_candidate"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(
      model,
      gate,
      @pdfv2conv.default_pdf_v2_fact_lowering_options(),
    ),
  )

  assert_true(phase14_plain_text_fragment_count(lowered.fragments) == 2)
  assert_true(lowered.summary.gate_missing_decision_count == 1)
  assert_true(lowered.summary.gate_unknown_count == 1)
  assert_true(
    phase14_has_fragment_tag(lowered.fragments, "missing_gate_decision"),
  )
}

///|
test "pdf v2 fact lowerer uses line text when block text is empty" {
  let first = phase14_line(0, "Hello", phase14_text_ref(0))
  let second = phase14_line(1, "World", phase14_text_ref(1))
  let block = phase14_block(
    0,
    "",
    [first, second],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )

  assert_true(lowered.fragments.length() == 1)
  assert_true(lowered.fragments[0].text == "Hello\nWorld")
  assert_true(
    lowered.fragments[0].reason_tags.contains(
      "fact_lowering_block_text_from_lines",
    ),
  )
}

///|
test "pdf v2 fact lowerer orders page blocks and fallback lines by candidate index" {
  let second_line = phase14_line(1, "Line two", phase14_text_ref(1))
  let first_line = phase14_line(0, "Line one", phase14_text_ref(0))
  let later = phase14_block(
    1,
    "Second block",
    [phase14_line(0, "Second block", phase14_text_ref(2))],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let earlier = phase14_block(
    0,
    "",
    [second_line, first_line],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([later, earlier])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )

  assert_true(lowered.fragments.length() == 2)
  assert_true(lowered.fragments[0].text == "Line one\nLine two")
  assert_true(lowered.fragments[1].text == "Second block")
}

///|
test "pdf v2 fact lowerer consumes real parser model smoke without path input" {
  let path = "/tmp/markitdown-pdf-v2-phase14-real-parser-smoke.pdf"
  phase14_write_fixture(path, phase14_simple_text_pdf())
  defer phase14_cleanup_fixture(path)

  match
    @pdfv2.parse_pdf_v2_model_from_path(
      path,
      @pdfv2.default_pdf_v2_core_open_options(),
    ) {
    ModelAssemblyOk(model) => {
      let features = phase14_feature_set(model)
      let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
        phase14_default_input(model, Some(features)),
      )
      assert_true(
        phase14_has_fragment_kind(
          lowered.fragments,
          @pdfv2conv.PdfV2FactFragmentKind::PlainText,
        ),
      )
      assert_true(lowered.summary.plain_text_fragment_count >= 1)
      assert_true(lowered.one_pass)
      assert_true(lowered.no_fallback)
    }
    ModelAssemblyErr(_, _, message) =>
      fail("expected Phase 14 parser model smoke: " + message)
  }
}

///|
test "pdf v2 experimental pipeline smokes minimal real pdf" {
  let path = "/tmp/markitdown-pdf-v2-phase17-pipeline-smoke.pdf"
  phase14_write_fixture(path, phase14_simple_text_pdf())
  defer phase14_cleanup_fixture(path)

  let result = @pdfv2conv.convert_pdf_v2_experimental_from_path(
    path,
    @pdfv2conv.default_pdf_v2_convert_pipeline_options(),
  )
  match result {
    ConvertPipelineOk(output) => {
      assert_true(output.fragments.length() > 0)
      assert_true(
        phase14_has_fragment_kind(
          output.fragments,
          @pdfv2conv.PdfV2FactFragmentKind::PlainText,
        ),
      )
      assert_true(output.fragments[0].text.contains("Hello"))
      assert_true(output.source_summary.page_count == 1)
      assert_true(output.model_summary.page_count == 1)
      assert_true(output.layout_summary.page_count == 1)
      assert_true(output.feature_summary.block_feature_count >= 1)
      assert_true(output.lowering_summary.plain_text_fragment_count >= 1)
      match output.gate_summary {
        Some(gate) => assert_true(gate.block_count >= 1)
        None => fail("expected default pipeline gate summary")
      }
      assert_true(output.one_pass)
      assert_true(output.no_fallback)
      assert_true(!phase14_fragments_have_semantic_markdown(output.fragments))
    }
    ConvertPipelineErr(failure) =>
      fail("expected Phase 17 pipeline success: " + failure.message)
  }
}

///|
test "pdf v2 experimental pipeline can disable gate" {
  let path = "/tmp/markitdown-pdf-v2-phase17-no-gate.pdf"
  phase14_write_fixture(path, phase14_simple_text_pdf())
  defer phase14_cleanup_fixture(path)

  let result = @pdfv2conv.convert_pdf_v2_experimental_from_path(path, {
    ..@pdfv2conv.default_pdf_v2_convert_pipeline_options(),
    run_gate: false,
  })
  match result {
    ConvertPipelineOk(output) => {
      assert_true(output.gate_summary is None)
      assert_true(output.lowering_summary.plain_text_fragment_count >= 1)
      assert_true(output.lowering_summary.gate_abstain_count == 0)
      assert_true(output.no_fallback)
    }
    ConvertPipelineErr(failure) =>
      fail("expected Phase 17 no-gate pipeline success: " + failure.message)
  }
}

///|
test "pdf v2 experimental pipeline respects abstain gate behavior" {
  let path = "/tmp/markitdown-pdf-v2-phase17-abstain.pdf"
  phase14_write_fixture(path, phase17_two_image_text_pdf())
  defer phase14_cleanup_fixture(path)
  let options = {
    ..@pdfv2conv.default_pdf_v2_convert_pipeline_options(),
    parser_options: {
      ..@pdfv2.default_pdf_v2_core_open_options(),
      object_caps: {
        ..@pdfv2.pdf_v2_default_object_cap_options(),
        max_images: Some(1),
      },
    },
  }

  let result = @pdfv2conv.convert_pdf_v2_experimental_from_path(path, options)
  match result {
    ConvertPipelineOk(output) => {
      match output.gate_summary {
        Some(gate) => assert_true(gate.abstain_count > 0)
        None => fail("expected gate summary")
      }
      assert_true(output.lowering_summary.gate_abstain_count > 0)
      assert_true(output.lowering_summary.gate_skipped_plain_text_count > 0)
      assert_true(output.lowering_summary.plain_text_fragment_count == 0)
      assert_true(output.no_fallback)
      assert_true(!phase14_fragments_have_semantic_markdown(output.fragments))
    }
    ConvertPipelineErr(failure) =>
      fail("expected Phase 17 abstain pipeline success: " + failure.message)
  }
}

///|
test "pdf v2 experimental pipeline fails closed on malformed pdf" {
  let path = "/tmp/markitdown-pdf-v2-phase17-malformed.pdf"
  phase14_write_fixture(path, "%PDF-1.4\nnot a valid body\n%%EOF\n")
  defer phase14_cleanup_fixture(path)

  let result = @pdfv2conv.convert_pdf_v2_experimental_from_path(
    path,
    @pdfv2conv.default_pdf_v2_convert_pipeline_options(),
  )
  match result {
    ConvertPipelineOk(_) => fail("expected malformed pipeline failure")
    ConvertPipelineErr(failure) => {
      assert_true(failure.stage == "parse_pdf_v2_model_from_path")
      assert_true(failure.fragments.length() == 0)
      assert_true(failure.warnings.length() > 0 || failure.risks.length() > 0)
      assert_true(failure.one_pass)
      assert_true(failure.no_fallback)
    }
  }
}

///|
test "pdf v2 experimental pipeline propagates caps" {
  let path = "/tmp/markitdown-pdf-v2-phase17-caps.pdf"
  phase14_write_fixture(path, phase14_simple_text_pdf())
  defer phase14_cleanup_fixture(path)
  let result = @pdfv2conv.convert_pdf_v2_experimental_from_path(path, {
    ..@pdfv2conv.default_pdf_v2_convert_pipeline_options(),
    lowering_options: {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      max_chars: 3,
    },
  })

  match result {
    ConvertPipelineOk(output) => {
      assert_true(output.lowering_summary.capped_output)
      assert_true(output.lowering_summary.plain_text_fragment_count == 0)
      assert_true(
        phase14_has_warning_kind(
          output.warnings,
          @pdfv2.PdfV2WarningKind::PerformanceCap,
        ),
      )
      assert_true(
        phase14_has_risk_kind(
          output.risks,
          @pdfv2.PdfV2RiskKind::PerformanceCapReached,
        ),
      )
      assert_true(output.no_fallback)
    }
    ConvertPipelineErr(failure) =>
      fail("expected Phase 17 caps pipeline success: " + failure.message)
  }
}

///|
test "pdf v2 fact lowerer does not emit object placeholders by default" {
  let image_ref = phase14_image_ref()
  let report : @pdfv2.PdfV2UnsupportedCapabilityReport = {
    capability: "image_decode",
    status: @pdfv2.PdfV2CapabilityStatus::MetadataOnly,
    page_index: Some(0),
    object_ref: Some("5 0 R"),
    source_ref: Some(image_ref),
    message: "metadata only image",
    reason_tags: ["metadata_only_image"],
    severity: @pdfv2.PdfV2Severity::Info,
  }
  let model = {
    ..phase14_model([]),
    unsupported_capabilities: [report],
    object_summary: {
      ..@pdfv2.pdf_v2_empty_object_summary(),
      image_count: 1,
      unsupported_capability_count: 1,
      metadata_only_count: 1,
    },
  }
  let features = phase14_feature_set(model)
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, Some(features)),
  )

  assert_true(lowered.fragments.length() == 0)
  assert_true(lowered.summary.object_placeholder_count == 0)
  assert_true(
    !phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
    ),
  )
}

///|
test "pdf v2 fact lowerer emits conservative object placeholders when enabled" {
  let image_ref = phase14_image_ref()
  let report : @pdfv2.PdfV2UnsupportedCapabilityReport = {
    capability: "image_decode",
    status: @pdfv2.PdfV2CapabilityStatus::MetadataOnly,
    page_index: Some(0),
    object_ref: Some("5 0 R"),
    source_ref: Some(image_ref),
    message: "metadata only image",
    reason_tags: ["metadata_only_image"],
    severity: @pdfv2.PdfV2Severity::Info,
  }
  let model = {
    ..phase14_model([]),
    unsupported_capabilities: [report],
    object_summary: {
      ..@pdfv2.pdf_v2_empty_object_summary(),
      image_count: 1,
      unsupported_capability_count: 1,
      metadata_only_count: 1,
    },
  }
  let options = {
    ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
    emit_object_placeholders: true,
  }
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    @pdfv2conv.pdf_v2_fact_lowering_input(model, None, options),
  )

  assert_true(lowered.fragments.length() == 1)
  assert_true(
    lowered.fragments[0].kind ==
    @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
  )
  assert_true(lowered.fragments[0].text.contains("image_decode"))
  assert_true(!lowered.fragments[0].text.contains("!["))
  assert_true(!lowered.fragments[0].text.contains("]("))
  assert_true(lowered.summary.object_placeholder_count == 1)
}

///|
test "pdf v2 fact lowerer object placeholders are unaffected by gate" {
  let image_ref = phase14_image_ref()
  let report : @pdfv2.PdfV2UnsupportedCapabilityReport = {
    capability: "image_decode",
    status: @pdfv2.PdfV2CapabilityStatus::MetadataOnly,
    page_index: Some(0),
    object_ref: Some("5 0 R"),
    source_ref: Some(image_ref),
    message: "metadata only image",
    reason_tags: ["metadata_only_image"],
    severity: @pdfv2.PdfV2Severity::Info,
  }
  let block = phase14_block(
    0,
    "Skipped",
    [phase14_line(0, "Skipped", phase14_text_ref(0))],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = {
    ..phase14_model([block]),
    unsupported_capabilities: [report],
    object_summary: {
      ..@pdfv2.pdf_v2_empty_object_summary(),
      image_count: 1,
      unsupported_capability_count: 1,
      metadata_only_count: 1,
    },
  }
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
      0,
      [phase14_text_ref(0)],
      ["unsupported_guard"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(model, gate, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      emit_object_placeholders: true,
    }),
  )

  assert_true(phase14_plain_text_fragment_count(lowered.fragments) == 0)
  assert_true(lowered.summary.gate_skipped_plain_text_count == 1)
  assert_true(lowered.summary.object_placeholder_count == 1)
  assert_true(
    phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
    ),
  )
}

///|
test "pdf v2 fact lowerer low confidence notes are option gated" {
  let line = phase14_line(0, "Faint", phase14_text_ref(0))
  let block = phase14_block(
    0,
    "Faint",
    [line],
    @pdfv2.PdfV2TextDecodeConfidence::Unknown,
  )
  let model = phase14_model([block])
  let features = phase14_feature_set(model)
  let default_lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, Some(features)),
  )

  assert_true(
    !phase14_has_fragment_kind(
      default_lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
    ),
  )

  let options = {
    ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
    emit_low_confidence_notes: true,
  }
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    @pdfv2conv.pdf_v2_fact_lowering_input(model, Some(features), options),
  )

  assert_true(
    phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
    ),
  )
  assert_true(
    phase14_has_fragment_kind(
      lowered.fragments,
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
    ),
  )
  assert_true(lowered.summary.low_confidence_note_count == 1)
}

///|
test "pdf v2 fact lowerer output caps warn risk and stop conservatively" {
  let first = phase14_block(
    0,
    "Alpha",
    [phase14_line(0, "Alpha", phase14_text_ref(0))],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let second = phase14_block(
    1,
    "Beta",
    [phase14_line(1, "Beta", phase14_text_ref(1))],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([first, second])
  let capped_blocks = @pdfv2conv.pdf_v2_lower_fact_model(
    @pdfv2conv.pdf_v2_fact_lowering_input(model, None, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      max_blocks: 1,
    }),
  )

  assert_true(capped_blocks.summary.capped_output)
  assert_true(capped_blocks.summary.block_count == 1)
  assert_true(phase14_has_warning_tag(capped_blocks.warnings, "max_blocks_cap"))
  assert_true(phase14_has_risk_tag(capped_blocks.risks, "max_blocks_cap"))

  let capped_chars = @pdfv2conv.pdf_v2_lower_fact_model(
    @pdfv2conv.pdf_v2_fact_lowering_input(model, None, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      max_chars: 3,
    }),
  )
  assert_true(capped_chars.summary.capped_output)
  assert_true(capped_chars.summary.plain_text_fragment_count == 0)
  assert_true(phase14_has_warning_tag(capped_chars.warnings, "max_chars_cap"))

  let capped_lines = @pdfv2conv.pdf_v2_lower_fact_model(
    @pdfv2conv.pdf_v2_fact_lowering_input(model, None, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      max_lines: 0,
    }),
  )
  assert_true(capped_lines.summary.capped_output)
  assert_true(phase14_has_warning_tag(capped_lines.warnings, "max_lines_cap"))
}

///|
test "pdf v2 fact lowerer caps still apply with gate" {
  let first_ref = phase14_text_ref(0)
  let second_ref = phase14_text_ref(1)
  let first = phase14_block(
    0,
    "Alpha",
    [phase14_line(0, "Alpha", first_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let second = phase14_block(
    1,
    "Beta",
    [phase14_line(1, "Beta", second_ref)],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([first, second])
  let gate = phase16_gate_result([
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
      0,
      [first_ref],
      ["plain_text_candidate"],
    ),
    phase16_gate_decision(
      @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
      1,
      [second_ref],
      ["plain_text_candidate"],
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase16_input(model, gate, {
      ..@pdfv2conv.default_pdf_v2_fact_lowering_options(),
      max_blocks: 1,
    }),
  )

  assert_true(lowered.summary.capped_output)
  assert_true(lowered.summary.plain_text_fragment_count == 1)
  assert_true(lowered.summary.gate_plain_text_candidate_count == 2)
  assert_true(phase14_has_warning_tag(lowered.warnings, "max_blocks_cap"))
  assert_true(phase14_has_risk_tag(lowered.risks, "max_blocks_cap"))
}

///|
test "pdf v2 fact lowerer keeps semantic markdown out" {
  let line = phase14_line(0, "Figure 1. Plain fact text", phase14_text_ref(0))
  let block = phase14_block(
    0,
    "Figure 1. Plain fact text",
    [line],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([block])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )

  for fragment in lowered.fragments {
    assert_true(
      fragment.kind == @pdfv2conv.PdfV2FactFragmentKind::PlainText ||
      fragment.kind == @pdfv2conv.PdfV2FactFragmentKind::PageBreak ||
      fragment.kind == @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote ||
      fragment.kind == @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
    )
    assert_true(!phase14_text_contains_semantic_markdown(fragment.text))
  }
}

///|
test "pdf v2 product bridge emits plain text document" {
  let fragment = phase20_fragment(
    @pdfv2conv.PdfV2FactFragmentKind::PlainText,
    "Hello product bridge",
    Some(0),
    [phase14_text_ref(0)],
  )
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, [fragment]),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 1)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) => assert_true(text == "Hello product bridge")
    _ => fail("expected product bridge paragraph")
  }
  assert_true(markdown.contains("Hello product bridge"))
  assert_true(!markdown.contains("PDF_V2_PIPELINE_DIAGNOSTICS"))
  assert_true(!phase14_text_contains_semantic_markdown(markdown))
  phase20_assert_text_bridge_blocks(doc)
}

///|
test "pdf v2 metadata document properties map model metadata to core sidecar" {
  let model = {
    ..phase14_model([]),
    page_count: 3,
    metadata: {
      title: Some("Quarterly Report"),
      author: Some("Ada"),
      subject: Some("Status"),
      creator: None,
      producer: Some("ReportLab"),
      keywords: Some("pdf,semantic"),
      created: Some("D:20260401000000+00'00'"),
      modified: Some("D:20260402000000+00'00'"),
      source_refs: [phase14_page_ref()],
    },
  }
  match @pdfv2conv.pdf_v2_metadata_document_properties(model) {
    Some(props) => {
      assert_true(props.title == Some("Quarterly Report"))
      assert_true(props.subject == Some("Status"))
      assert_true(props.creator == Some("Ada"))
      assert_true(props.keywords == Some("pdf,semantic"))
      assert_true(props.created == Some("D:20260401000000+00'00'"))
      assert_true(props.modified == Some("D:20260402000000+00'00'"))
      assert_true(props.application == Some("ReportLab"))
      assert_true(props.pages == Some("3"))
    }
    None => fail("expected pdf v2 document properties")
  }
}

///|
test "pdf v2 metadata sidecar path adds document properties without diagnostics" {
  let fragment = phase20_fragment(
    @pdfv2conv.PdfV2FactFragmentKind::PlainText,
    "Body text",
    Some(0),
    [phase14_text_ref(0)],
  )
  let document_properties = @cor.metadata_document_properties(
    Some("Doc Title"),
    None,
    Some("Doc Creator"),
    None,
    None,
    None,
    None,
    Some("PDF Producer"),
    Some("2"),
    None,
    None,
    None,
  )
  let pipeline = @pdfv2conv.PdfV2ConvertPipelineResult::ConvertPipelineOk({
    source_summary: @pdfv2.pdf_v2_source_summary(0, 2, 0, 0),
    model_summary: phase20_model_summary(2, [fragment]),
    document_properties: Some(document_properties),
    layout_summary: phase20_layout_summary(2),
    feature_summary: phase20_feature_summary(),
    gate_summary: None,
    lowering_summary: phase20_lowering_summary(2, [fragment]),
    fragments: [fragment],
    text_flow_candidates: [],
    warnings: [],
    risks: [],
    one_pass: true,
    no_fallback: true,
  })
  let doc = phase20_bridge_document(pipeline, {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    source_name: Some("metadata.pdf"),
  })
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Body text"))
  assert_true(!markdown.contains("PDF v2"))
  let json = @cor.emit_metadata_json_with_document_properties(
    doc,
    "metadata.pdf",
    "pdf",
    "metadata.md",
    Some(document_properties),
  )
  assert_true(json.contains("\"document\": {"))
  assert_true(json.contains("\"title\": \"Doc Title\""))
  assert_true(json.contains("\"creator\": \"Doc Creator\""))
  assert_true(json.contains("\"application\": \"PDF Producer\""))
  assert_true(json.contains("\"pages\": \"2\""))
  assert_true(!json.contains("PDF v2"))
}

///|
test "pdf v2 product bridge emits minimal heading by default" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Document Conversion Pipeline",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "This project aims to build a unified document conversion pipeline.",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 2)
  match doc.blocks.val[0] {
    @cor.Block::Heading(level, text) => {
      assert_true(level == 1)
      assert_true(text == "Document Conversion Pipeline")
    }
    _ => fail("expected minimal heading")
  }
  match doc.blocks.val[1] {
    @cor.Block::Paragraph(text) =>
      assert_true(
        text ==
        "This project aims to build a unified document conversion pipeline.",
      )
    _ => fail("expected following body paragraph")
  }
  assert_true(markdown.has_prefix("# Document Conversion Pipeline\n\n"))
  phase20_assert_text_bridge_blocks(doc)
}

///|
test "pdf v2 product bridge heading rules can be disabled" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Hard Wrap Test",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "This is a line that is hard wrapped.",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(phase20_pipeline_ok(1, fragments), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    enable_heading_rules: false,
  })

  assert_true(doc.blocks.val.length() == 2)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) => assert_true(text == "Hard Wrap Test")
    _ => fail("expected heading rules disabled paragraph")
  }
}

///|
test "pdf v2 product bridge semantic rules disabled keeps plain paragraphs" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Document Conversion Pipeline",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "- item",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(phase20_pipeline_ok(1, fragments), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    enable_semantic_rules: false,
  })

  assert_true(doc.blocks.val.length() == 2)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      assert_true(text == "Document Conversion Pipeline")
    _ => fail("expected semantic-disabled title paragraph")
  }
  match doc.blocks.val[1] {
    @cor.Block::Paragraph(text) => assert_true(text == "- item")
    _ => fail("expected semantic-disabled list marker paragraph")
  }
}

///|
test "pdf v2 product bridge emits semantic list items" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "- First item",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "1. Ordered item",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 2)
  match doc.blocks.val[0] {
    @cor.Block::ListItem(false, 0, text) => assert_true(text == "First item")
    _ => fail("expected unordered list item")
  }
  match doc.blocks.val[1] {
    @cor.Block::ListItem(true, 0, text) => assert_true(text == "Ordered item")
    _ => fail("expected ordered list item")
  }
  assert_true(markdown.contains("- First item"))
  assert_true(markdown.contains("1. Ordered item"))
}

///|
test "pdf v2 product bridge rejects heading false positives" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "OK",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "ALL CAPS SENTENCE BUT ACTUALLY BODY TEXT, NOT A TITLE.",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "1",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "This is a short sentence.",
      Some(0),
      [phase14_text_ref(3)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )

  assert_true(doc.blocks.val.length() == 2)
  for block in doc.blocks.val {
    match block {
      @cor.Block::Paragraph(_) => ()
      _ => fail("expected false-positive heading candidates to stay paragraph")
    }
  }
}

///|
test "pdf v2 product bridge keeps multiline paragraph out of minimal heading" {
  let fragments = [
    phase20_fragment_with_line_count(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Document conversion pipeline\ncontinues here.",
      Some(0),
      2,
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "This project aims to build a unified document conversion pipeline.",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )

  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      assert_true(text == "Document conversion pipeline continues here.")
    _ => fail("expected multiline emitted paragraph to stay paragraph")
  }
}

///|
test "pdf v2 product bridge emits CJK minimal heading and joins body fragments" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "研究内容",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "本项目",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "主要研究",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "多格式文档到 Markdown 的",
      Some(0),
      [phase14_text_ref(3)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "统一转换问题。",
      Some(0),
      [phase14_text_ref(4)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "技术路线",
      Some(0),
      [phase14_text_ref(5)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "首先完成统",
      Some(0),
      [phase14_text_ref(6)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "一 IR，然后逐步",
      Some(0),
      [phase14_text_ref(7)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "支持 docx、pdf、xlsx、pptx 和 html。",
      Some(0),
      [phase14_text_ref(8)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# 研究内容"))
  assert_true(
    markdown.contains(
      "本项目主要研究多格式文档到 Markdown 的统一转换问题。",
    ),
  )
  assert_true(markdown.contains("# 技术路线"))
  assert_true(
    markdown.contains(
      "首先完成统一 IR，然后逐步支持 docx、pdf、xlsx、pptx 和 html。",
    ),
  )
  assert_true(!markdown.contains("本项目\n\n"))
  phase20_assert_text_bridge_blocks(doc)
}

///|
test "pdf v2 product bridge normalizes hardwrap and ligature text" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Document Conversion Pipeline",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "This project aims to build a uni",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "ﬁ",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "ed document",
      Some(0),
      [phase14_text_ref(3)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "conversion pipeline for docx, pdf, xlsx, pptx, and html.",
      Some(0),
      [phase14_text_ref(4)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "The parser should support inter-",
      Some(0),
      [phase14_text_ref(5)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "national text processing.",
      Some(0),
      [phase14_text_ref(6)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Document Conversion Pipeline"))
  assert_true(markdown.contains("unified document conversion pipeline"))
  assert_true(markdown.contains("international text processing."))
  assert_true(!markdown.contains("<br>"))
  assert_true(!markdown.contains("ﬁ"))
  phase20_assert_text_bridge_blocks(doc)
}

///|
test "pdf v2 product bridge preserves CJK while joining split lines" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Hard Wrap Test",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "下一段：",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "中",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "⽂",
      Some(0),
      [phase14_text_ref(3)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "也可能被硬换⾏拆开。",
      Some(0),
      [phase14_text_ref(4)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Hard Wrap Test"))
  assert_true(
    markdown.contains("下一段：中文也可能被硬换行拆开。"),
  )
  assert_true(!markdown.contains("⽂"))
  assert_true(!markdown.contains("⾏"))
  assert_true(!markdown.contains("<br>"))
}

///|
test "pdf v2 product bridge suppresses page-number-like noise by default" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "第",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "⻚",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "1",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "- 2 -",
      Some(0),
      [phase14_text_ref(3)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "3/10",
      Some(0),
      [phase14_text_ref(4)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "第",
      Some(0),
      [phase14_text_ref(40)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "页",
      Some(0),
      [phase14_text_ref(41)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "3/1",
      Some(0),
      [phase14_text_ref(42)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Alpha page content.",
      Some(0),
      [phase14_text_ref(5)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "第",
      Some(1),
      [phase14_text_ref(6)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "页 Beta page content.",
      Some(1),
      [phase14_text_ref(7)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "第页 Gamma page content.",
      Some(2),
      [phase14_text_ref(8)],
    ),
  ]
  let default_doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let default_markdown = @cor.emit_markdown(default_doc)

  assert_true(default_markdown.contains("Alpha page content."))
  assert_true(default_markdown.contains("Beta page content."))
  assert_true(default_markdown.contains("Gamma page content."))
  assert_true(!default_markdown.contains("第"))
  assert_true(!default_markdown.contains("页 Beta"))
  assert_true(!default_markdown.contains("第页 Gamma"))
  assert_true(!default_markdown.contains("- 2 -"))
  assert_true(!default_markdown.contains("3/10"))

  let keep_doc = phase20_bridge_document(phase20_pipeline_ok(1, fragments), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    suppress_page_number_like_noise: false,
  })
  let keep_markdown = @cor.emit_markdown(keep_doc)
  assert_true(keep_markdown.contains("- 2 -"))
  assert_true(keep_markdown.contains("3/10"))
  assert_true(keep_markdown.contains("页 Beta page content."))
  assert_true(keep_markdown.contains("第页 Gamma page content."))
}

///|
test "pdf v2 product bridge suppresses repeated short header footer artifacts" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Project Report",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Alpha body sentence.",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Confidential Footer",
      Some(0),
      [phase14_text_ref(2)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Project Report",
      Some(1),
      [phase14_text_ref(3)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Beta body sentence.",
      Some(1),
      [phase14_text_ref(4)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Confidential Footer",
      Some(1),
      [phase14_text_ref(5)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(2, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Alpha body sentence."))
  assert_true(markdown.contains("Beta body sentence."))
  assert_true(!markdown.contains("Project Report"))
  assert_true(!markdown.contains("Confidential Footer"))
}

///|
test "pdf v2 product bridge keeps normal numeric content when noise suppression is on" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Revenue 2026 was 1234 units.",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Section 3 discusses growth.",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Revenue 2026 was 1234 units."))
  assert_true(markdown.contains("Section 3 discusses growth."))
}

///|
test "pdf v2 product bridge preserves page block order" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Page one first.",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Page one second.",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Page two first.",
      Some(1),
      [phase14_text_ref(2)],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(2, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Page one first."))
  assert_true(markdown.contains("Page one second."))
  assert_true(markdown.contains("Page two first."))
  assert_true(doc.blocks.val.length() == 3)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) => assert_true(text == "Page one first.")
    _ => fail("expected first page block")
  }
  match doc.blocks.val[1] {
    @cor.Block::Paragraph(text) => assert_true(text == "Page one second.")
    _ => fail("expected second page block")
  }
  match doc.blocks.val[2] {
    @cor.Block::Paragraph(text) => assert_true(text == "Page two first.")
    _ => fail("expected third page block")
  }
}

///|
test "pdf v2 product bridge page breaks are stable and opt in" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Alpha",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(@pdfv2conv.PdfV2FactFragmentKind::PageBreak, "", Some(0), []),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Beta",
      Some(1),
      [phase14_text_ref(1)],
    ),
  ]
  let default_doc = phase20_bridge_document(
    phase20_pipeline_ok(2, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  assert_true(default_doc.blocks.val.length() == 2)
  phase20_assert_text_bridge_blocks(default_doc)

  let page_break_doc = phase20_bridge_document(
    phase20_pipeline_ok(2, fragments),
    {
      ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
      emit_page_breaks: true,
    },
  )
  assert_true(page_break_doc.blocks.val.length() == 3)
  match page_break_doc.blocks.val[1] {
    @cor.Block::BlankLine => ()
    _ => fail("expected opt-in page break blank line")
  }

  let preserved_doc = phase20_bridge_document(
    phase20_pipeline_ok(2, fragments),
    {
      ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
      preserve_empty_pages: true,
    },
  )
  assert_true(preserved_doc.blocks.val.length() == 3)
  match preserved_doc.blocks.val[1] {
    @cor.Block::BlankLine => ()
    _ => fail("expected preserved page break blank line")
  }
}

///|
test "pdf v2 product bridge notes are disabled by default" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
      "gate abstained note",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
      "unsupported object note",
      Some(0),
      [phase14_image_ref()],
    ),
  ]
  let doc = phase20_bridge_document(
    phase20_pipeline_ok(1, fragments),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 0)
  assert_true(markdown == "")
  assert_true(!markdown.contains("gate abstained note"))
  assert_true(!markdown.contains("unsupported object note"))
}

///|
test "pdf v2 product bridge notes are plain opt in paragraphs" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "Visible text",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::LowConfidenceNote,
      "gate abstained note",
      Some(0),
      [phase14_text_ref(1)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::UnsupportedObjectNote,
      "unsupported object note",
      Some(0),
      [phase14_image_ref()],
    ),
  ]
  let doc = phase20_bridge_document(phase20_pipeline_ok(1, fragments), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    emit_low_confidence_notes: true,
    emit_unsupported_object_notes: true,
  })
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 3)
  assert_true(markdown.contains("Visible text"))
  assert_true(markdown.contains("gate abstained note"))
  assert_true(markdown.contains("unsupported object note"))
  assert_true(!phase14_text_contains_semantic_markdown(markdown))
  phase20_assert_text_bridge_blocks(doc)
}

///|
test "pdf v2 product bridge caps output characters" {
  let fragments = [
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "ABCDE.",
      Some(0),
      [phase14_text_ref(0)],
    ),
    phase20_fragment(
      @pdfv2conv.PdfV2FactFragmentKind::PlainText,
      "FGHI",
      Some(0),
      [phase14_text_ref(1)],
    ),
  ]
  let doc = phase20_bridge_document(phase20_pipeline_ok(1, fragments), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    enable_semantic_rules: false,
    max_output_chars: Some(7),
  })
  let markdown = @cor.emit_markdown(doc)

  assert_true(doc.blocks.val.length() == 2)
  assert_true(markdown.contains("ABCDE."))
  assert_true(markdown.contains("F"))
  assert_true(!markdown.contains("GHI"))
}

///|
test "pdf v2 product bridge fails closed on pipeline error" {
  match
    @pdfv2conv.pdf_v2_pipeline_result_to_document(
      phase20_pipeline_err("parse_pdf_v2_model_from_path", "broken xref"),
      @pdfv2conv.default_pdf_v2_product_bridge_options(),
    ) {
    Ok(doc) =>
      fail("expected product bridge failure, got " + @cor.emit_markdown(doc))
    Err(err) => {
      let message = err.to_string()
      assert_true(message.contains("parse_pdf_v2_model_from_path"))
      assert_true(message.contains("broken xref"))
      assert_true(!message.contains("Hello product bridge"))
    }
  }
}

///|
test "pdf v2 product bridge preserves minimal origins" {
  let source_ref = {
    ..phase14_text_ref(0),
    page_index: Some(2),
    object_id: Some("7 0 R"),
  }
  let fragment = phase20_fragment(
    @pdfv2conv.PdfV2FactFragmentKind::PlainText,
    "Origin text",
    Some(2),
    [source_ref],
  )
  let doc = phase20_bridge_document(phase20_pipeline_ok(3, [fragment]), {
    ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
    source_name: Some("bridge.pdf"),
  })

  assert_true(doc.block_origins.val.length() == 1)
  match doc.block_origins.val[0] {
    Some(origin) => {
      assert_true(origin.source_name == Some("bridge.pdf"))
      assert_true(origin.page == Some(3))
      assert_true(origin.block_index == Some(0))
      assert_true(origin.object_ref == Some("7 0 R"))
      assert_true(origin.line_start is None)
      assert_true(origin.relationship_id is None)
    }
    None => fail("expected product bridge origin")
  }
}

///|
test "pdf v2 product bridge consumes parser fact candidates for list evidence" {
  let list_line = phase14_line(0, "• parser item", phase14_text_ref(0))
  let list_block = phase14_block(
    0,
    "• parser item",
    [list_line],
    @pdfv2.PdfV2TextDecodeConfidence::High,
  )
  let model = phase14_model([list_block])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )
  let doc = phase20_bridge_document(
    phase20_pipeline_ok_with_candidates(
      1,
      lowered.fragments,
      lowered.text_flow_candidates,
    ),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )

  assert_true(doc.blocks.val.length() == 1)
  match doc.blocks.val[0] {
    @cor.Block::ListItem(ordered, _, text) => {
      assert_true(!ordered)
      assert_true(text == "parser item")
    }
    _ => fail("expected parser-fact list item")
  }
}

///|
test "pdf v2 product bridge suppresses parser page artifact candidates" {
  let page_number_line = phase14_line(0, "Page 1", phase14_text_ref(0))
  let body_line = phase14_line(1, "Actual body sentence.", phase14_text_ref(1))
  let model = phase14_model([
    phase14_block(
      0,
      "Page 1",
      [page_number_line],
      @pdfv2.PdfV2TextDecodeConfidence::High,
    ),
    phase14_block(
      1,
      "Actual body sentence.",
      [body_line],
      @pdfv2.PdfV2TextDecodeConfidence::High,
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )
  let doc = phase20_bridge_document(
    phase20_pipeline_ok_with_candidates(
      1,
      lowered.fragments,
      lowered.text_flow_candidates,
    ),
    @pdfv2conv.default_pdf_v2_product_bridge_options(),
  )

  assert_true(doc.blocks.val.length() == 1)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) => assert_true(text == "Actual body sentence.")
    _ => fail("expected body paragraph only")
  }
}

///|
test "pdf v2 product bridge semantic disabled keeps parser fact text plain" {
  let title_line = phase14_line(0, "Introduction", phase14_text_ref(0))
  let body_line = phase14_line(1, "Body sentence.", phase14_text_ref(1))
  let model = phase14_model([
    phase14_block(
      0,
      "Introduction\nBody sentence.",
      [title_line, body_line],
      @pdfv2.PdfV2TextDecodeConfidence::High,
    ),
  ])
  let lowered = @pdfv2conv.pdf_v2_lower_fact_model(
    phase14_default_input(model, None),
  )
  let doc = phase20_bridge_document(
    phase20_pipeline_ok_with_candidates(
      1,
      lowered.fragments,
      lowered.text_flow_candidates,
    ),
    {
      ..@pdfv2conv.default_pdf_v2_product_bridge_options(),
      enable_semantic_rules: false,
    },
  )

  assert_true(doc.blocks.val.length() == 1)
  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      assert_true(
        text.contains("Introduction") && text.contains("Body sentence."),
      )
    _ => fail("expected plain paragraph when semantic rules are disabled")
  }
}

///|
test "pdf v2 convert boundary guard stays parser fact only" {
  let package_text = @fs.read_file_to_string(
    "convert/pdf_v2/moon.pkg",
    encoding="utf8",
  ) catch {
    err => fail("read convert package failed: " + err.to_string())
  }
  let parser_package_text = @fs.read_file_to_string(
    "doc_parse/pdf_v2/moon.pkg",
    encoding="utf8",
  ) catch {
    err => fail("read parser package failed: " + err.to_string())
  }
  let lowerer_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_fact_lowering.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read lowerer source failed: " + err.to_string())
  }
  let pipeline_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_pipeline.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read pipeline source failed: " + err.to_string())
  }
  let bridge_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_product_bridge.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read product bridge source failed: " + err.to_string())
  }
  let semantic_rules_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_semantic_rules.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read semantic rules source failed: " + err.to_string())
  }
  let semantic_arbitration_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_semantic_arbitration.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read semantic arbitration source failed: " + err.to_string())
  }

  assert_true(package_text.contains("doc_parse/pdf_v2"))
  assert_true(package_text.contains("markitdown/core"))
  assert_true(!package_text.contains("doc_parse/pdf/vendor"))
  assert_true(!package_text.contains("doc_parse/pdf\""))
  assert_true(!package_text.contains("mbtpdf"))
  assert_true(!parser_package_text.contains("convert/pdf_v2"))
  assert_true(!lowerer_text.contains("parse_pdf_v2_model_from_path"))
  assert_true(!lowerer_text.contains("parse_pdf_v2_source_from_path"))
  assert_true(!lowerer_text.contains("pdf_v2_open_source_document_from_path"))
  assert_true(!lowerer_text.contains("model.pkl"))
  assert_true(!lowerer_text.contains("features.tsv"))
  assert_true(!lowerer_text.contains("markitdown-quality-lab"))
  assert_true(!lowerer_text.contains("Heading"))
  assert_true(!lowerer_text.contains("ListItem"))
  assert_true(!lowerer_text.contains("Caption"))
  assert_true(!lowerer_text.contains("TableLike"))
  assert_true(pipeline_text.contains("parse_pdf_v2_model_from_path"))
  assert_true(!pipeline_text.contains("doc_parse/pdf/vendor"))
  assert_true(!pipeline_text.contains("doc_parse/pdf\""))
  assert_true(!pipeline_text.contains("mbtpdf"))
  assert_true(!pipeline_text.contains("model.pkl"))
  assert_true(!pipeline_text.contains("features.tsv"))
  assert_true(!pipeline_text.contains("markitdown-quality-lab"))
  assert_true(!pipeline_text.contains("PdfV2BlockRole"))
  assert_true(!pipeline_text.contains("Heading"))
  assert_true(!pipeline_text.contains("ListItem"))
  assert_true(!pipeline_text.contains("Caption"))
  assert_true(!pipeline_text.contains("TableLike"))
  assert_true(!bridge_text.contains("doc_parse/pdf/vendor"))
  assert_true(!bridge_text.contains("doc_parse/pdf\""))
  assert_true(!bridge_text.contains("mbtpdf"))
  assert_true(!bridge_text.contains("@fs"))
  assert_true(!bridge_text.contains("read_file"))
  assert_true(!bridge_text.contains("_from_path"))
  assert_true(!bridge_text.contains("convert/convert"))
  assert_true(!bridge_text.contains("parse_to_ir"))
  assert_true(!bridge_text.contains("dispatcher"))
  assert_true(!bridge_text.contains("model.pkl"))
  assert_true(!bridge_text.contains("features.tsv"))
  assert_true(!bridge_text.contains("markitdown-quality-lab"))
  assert_true(!bridge_text.contains("PdfV2BlockRole"))
  assert_true(!semantic_rules_text.contains("@fs"))
  assert_true(!semantic_rules_text.contains("read_file"))
  assert_true(!semantic_rules_text.contains("model.pkl"))
  assert_true(!semantic_rules_text.contains("features.tsv"))
  assert_true(!semantic_arbitration_text.contains("@fs"))
  assert_true(!semantic_arbitration_text.contains("read_file"))
  assert_true(!semantic_arbitration_text.contains("model.pkl"))
  assert_true(!semantic_arbitration_text.contains("features.tsv"))
  assert_true(bridge_text.contains("enable_semantic_rules"))
  assert_true(bridge_text.contains("pdf_v2_semantic_blocks_from_fragments"))
  assert_true(!bridge_text.contains("pdf_v2_should_emit_minimal_heading"))
  assert_true(!bridge_text.contains("RichHeading"))
  assert_true(!bridge_text.contains("RichParagraph"))
  assert_true(!bridge_text.contains("RichListItem"))
  assert_true(!bridge_text.contains("Caption"))
  assert_true(!bridge_text.contains("TableLike"))
  assert_true(!bridge_text.contains("RichTable"))
  assert_true(!bridge_text.contains("ImageBlock"))
  assert_true(!bridge_text.contains("@cor.Inline::Link"))
}
