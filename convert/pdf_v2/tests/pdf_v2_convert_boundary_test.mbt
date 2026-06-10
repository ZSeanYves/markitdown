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
fn phase14_has_risk_tag(risks : Array[@pdfv2.PdfV2Risk], tag : String) -> Bool {
  for risk in risks {
    if risk.reason_tags.contains(tag) {
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

  assert_true(package_text.contains("doc_parse/pdf_v2"))
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
}
