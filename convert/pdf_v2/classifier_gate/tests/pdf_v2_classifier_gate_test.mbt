///|
test "classifier gate consumes features only" {
  let feature = gate_feature(
    "b0",
    "Body",
    ["parser_shape_fact"],
    ["paragraph"],
    [],
    [],
  )
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  assert_eq(decisions.length(), 1)
  assert_eq(decisions[0].block_id, "b0")
  assert_eq(
    decisions[0].reason_tags.contains(
      @classifier_gate.PdfV2BlockDecisionReasonTag::FeaturesOnly,
    ),
    true,
  )
}

///|
test "classifier gate fail closed empty features" {
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [],
    gate_options(),
  )
  let summary = @classifier_gate.summarize_pdf_v2_block_decisions(
    [],
    decisions,
    gate_options(),
  )
  assert_eq(decisions.length(), 0)
  assert_eq(summary.input_record_count, 0)
  assert_eq(summary.fail_closed, true)
  assert_eq(summary.legacy_fallback_allowed, false)
}

///|
test "candidate facts remain evidence only" {
  let feature = gate_feature(
    "b1",
    "Figure",
    ["caption_prefix_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  assert_eq(
    decisions[0].candidate_fact_tags.contains("caption_prefix_candidate"),
    true,
  )
  assert_eq(
    decisions[0].reason_tags.contains(
      @classifier_gate.PdfV2BlockDecisionReasonTag::CandidateEvidenceOnly,
    ),
    true,
  )
  assert_eq(
    decisions[0].reason_tags.contains(
      @classifier_gate.PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ),
    true,
  )
}

///|
test "layout membership preserved" {
  let feature = gate_feature("b2", "Body", [], ["paragraph"], [], [])
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  assert_eq(decisions[0].layout_region_ids[0], "region_b2")
  assert_eq(decisions[0].layout_region_kinds[0], "paragraph")
  assert_eq(decisions[0].reading_order_index == Some(0), true)
}

///|
test "risk propagation preserved" {
  let risk = @pdfv2.risk_low_signal_document("synthetic gate risk")
  let feature = gate_feature("b3", "Risk", [], ["paragraph"], [], [risk])
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  assert_eq(decisions[0].risks.length(), 1)
  assert_eq(decisions[0].abstain, true)
  assert_eq(decisions[0].blocked_reason == Some("parser_risk_present"), true)
}

///|
test "model hints are optional" {
  let feature = gate_feature("b4", "Body", [], ["paragraph"], [], [])
  let hint : @classifier_gate.PdfV2ClassifierHint = {
    block_id: "b4",
    suggested_label: @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    confidence: 0.99,
    reason_tags: [
      @classifier_gate.PdfV2BlockDecisionReasonTag::ModelHintAccepted,
    ],
  }
  let disabled = @classifier_gate.build_pdf_v2_block_decisions([feature], {
    ..gate_options(),
    model_hints: [hint],
    allow_model_hints: false,
  })
  let enabled = @classifier_gate.build_pdf_v2_block_decisions([feature], {
    ..gate_options(),
    model_hints: [hint],
    allow_model_hints: true,
  })
  assert_eq(disabled[0].abstain, true)
  assert_eq(
    enabled[0].source == @classifier_gate.PdfV2BlockDecisionSource::ModelHint,
    true,
  )
  assert_eq(
    enabled[0].label ==
    @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    true,
  )
}

///|
test "classifier gate emits no final semantic labels" {
  let feature = gate_feature(
    "b5",
    "1.",
    ["list_marker_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  assert_eq(
    decisions[0].label ==
    @classifier_gate.PdfV2BlockDecisionLabel::ListItemCandidate,
    true,
  )
  assert_eq(
    decisions[0].reason_tags.contains(
      @classifier_gate.PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ),
    true,
  )
}

///|
test "one pass no fallback policy in summary" {
  let feature = gate_feature("b6", "Body", [], ["paragraph"], [], [])
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    [feature],
    gate_options(),
  )
  let summary = @classifier_gate.summarize_pdf_v2_block_decisions(
    [feature],
    decisions,
    gate_options(),
  )
  assert_eq(summary.one_pass_required, true)
  assert_eq(summary.legacy_fallback_allowed, false)
  assert_eq(summary.convert_raw_reparse_allowed, false)
  assert_eq(
    summary.reason_tags.contains(
      @classifier_gate.PdfV2BlockDecisionReasonTag::NoFallback,
    ),
    true,
  )
}

///|
fn gate_options() -> @classifier_gate.PdfV2BlockDecisionOptions {
  {
    ..@classifier_gate.default_pdf_v2_block_decision_options(),
    min_final_confidence: 0.55,
  }
}

///|
fn gate_feature(
  block_id : String,
  text : String,
  candidate_fact_tags : Array[String],
  layout_region_kinds : Array[String],
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> @feature_export.PdfV2BlockFeatureRecord {
  {
    doc_id: "gate_doc",
    page_index: 0,
    block_id,
    line_ids: ["line_" + block_id],
    source_refs: [@pdfv2.pdf_v2_source_ref_for_page(0)],
    object_refs: ["200 0 R"],
    bbox: @pdfv2.pdf_v2_default_rect(),
    page_relative_bbox: @pdfv2.pdf_v2_default_rect(),
    text,
    text_length: text.length(),
    line_count: 1,
    char_count: text.length(),
    word_count: 1,
    dominant_font_name: Some("F1"),
    dominant_font_size: Some(12.0),
    decode_confidence: @text_reconstruction.PdfV2DecodeConfidence::High,
    writing_direction: @pdfv2.PdfV2WritingDirection::LeftToRight,
    candidate_fact_tags,
    layout_region_ids: ["region_" + block_id],
    layout_region_kinds,
    reading_order_index: Some(0),
    cross_page_boundary_kinds: [],
    warnings,
    risks,
    diagnostics: [],
    feature_risks: [],
    values: [
      gate_value("text_length"),
      gate_value("layout_region_kind"),
      gate_value("classifier_input_feature"),
    ],
    reason_tags: ["gate_test_feature"],
  }
}

///|
fn gate_value(name : String) -> @feature_export.PdfV2FeatureValue {
  {
    field_name: name,
    value_kind: @feature_export.PdfV2FeatureValueKind::String,
    bool_value: None,
    int_value: None,
    float_value: None,
    string_value: Some(name),
    string_list_value: [],
    bbox_value: None,
    enum_value: None,
    availability: @feature_export.PdfV2FeatureAvailability::Available,
    source: @feature_export.PdfV2FeatureSource::Derived,
    diagnostics: [],
    reason_tags: ["gate_test_value"],
  }
}
