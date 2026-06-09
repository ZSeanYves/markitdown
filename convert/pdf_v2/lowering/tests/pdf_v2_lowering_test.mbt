///|
test "empty input yields empty result with summary" {
  let doc = test_doc([])
  let result = @lowering.lower_pdf_v2_document(
    doc,
    [],
    [],
    @lowering.default_pdf_v2_lowering_options(),
  )
  assert_eq(result.blocks.length(), 0)
  assert_eq(result.summary.lowered_block_count, 0)
  assert_eq(result.summary.feature_record_count, 0)
  assert_eq(result.summary.decision_count, 0)
  assert_eq(result.summary.fail_closed, true)
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
}

///|
test "missing decision keeps text with warning" {
  let block = test_block("b_missing_decision", "Body", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let result = lower_one(block, [feature], [])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(result.summary.missing_decision_count, 1)
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::MissingDecision,
    ),
    true,
  )
}

///|
test "abstain decision keeps text" {
  let block = test_block("b_abstain", "Body", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::Uncertain,
    0.0,
    true,
    [],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(result.summary.abstain_count, 1)
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::AbstainDecision,
    ),
    true,
  )
}

///|
test "high confidence heading lowers to heading" {
  let block = test_block("b_heading", "Section", [], [], [])
  let feature = test_feature(
    block,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    0.94,
    false,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Heading,
    true,
  )
  assert_eq(result.summary.heading_count, 1)
  assert_eq(result.decision_traces[0].final_confidence, 0.94)
}

///|
test "low confidence heading fails closed to text" {
  let block = test_block("b_low_heading", "Maybe", [], [], [])
  let feature = test_feature(
    block,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    0.70,
    false,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(result.summary.low_confidence_count, 1)
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::LowConfidenceDecision,
    ),
    true,
  )
}

///|
test "list requires marker evidence" {
  let block = test_block("b_list", "Item without marker", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::ListItemCandidate,
    0.90,
    false,
    [],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::MissingListMarkerEvidence,
    ),
    true,
  )
}

///|
test "list with marker evidence lowers to list item" {
  let block = test_block(
    "b_list_marker",
    "1. Item",
    ["list_marker_candidate"],
    [],
    [],
  )
  let feature = test_feature(
    block,
    ["list_marker_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::ListItemCandidate,
    0.90,
    false,
    ["list_marker_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::ListItem,
    true,
  )
  assert_eq(result.summary.list_item_count, 1)
}

///|
test "caption without visual evidence does not bind image" {
  let block = test_block("b_caption", "Figure 1. Caption", [], [], [])
  let feature = test_feature(
    block,
    ["caption_prefix_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::CaptionCandidate,
    0.90,
    false,
    ["caption_prefix_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::CaptionText,
    true,
  )
  assert_eq(result.asset_refs.length(), 0)
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::MissingVisualEvidence,
    ),
    true,
  )
}

///|
test "table-like without region confidence stays text" {
  let block = test_block("b_table", "A | B", [], [], [])
  let feature = test_feature(
    block,
    ["table_cell_shape_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::TableCandidate,
    0.95,
    false,
    ["table_cell_shape_candidate"],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::WeakTableEvidence,
    ),
    true,
  )
}

///|
test "high risk decision suppresses semantic lowering" {
  let risk = @pdfv2.risk_low_signal_document("synthetic high risk")
  let block = test_block("b_risk_heading", "Risk Heading", [], [], [risk])
  let feature = test_feature(
    block,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [risk],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    0.96,
    false,
    ["heading_shape_candidate"],
    ["title"],
    [],
    [risk],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(result.summary.high_risk_count, 1)
  assert_eq(result.blocks[0].parser_risks.length() > 0, true)
}

///|
test "noise suppression requires high confidence reason" {
  let block = test_block("b_noise", "1", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::NoiseCandidate,
    0.99,
    false,
    [],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(
    result.blocks[0].kind == @lowering.PdfV2LoweredBlockKind::Text,
    true,
  )
  assert_eq(
    has_warning_kind(
      result.warnings,
      @lowering.PdfV2LoweringWarningKind::MissingNoiseEvidence,
    ),
    true,
  )
}

///|
test "warnings risks and reason tags propagate" {
  let warning = @pdfv2.pdf_v2_scaffold_warning("synthetic warning")
  let risk = @pdfv2.risk_low_signal_document("synthetic risk")
  let block = test_block("b_diag", "Diagnostic", [], [warning], [risk])
  let feature = test_feature(
    block,
    ["heading_shape_candidate"],
    ["title"],
    [warning],
    [risk],
  )
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate,
    0.96,
    false,
    ["heading_shape_candidate"],
    ["title"],
    [warning],
    [risk],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(result.parser_warnings.length() > 0, true)
  assert_eq(result.parser_risks.length() > 0, true)
  assert_eq(result.blocks[0].origin.reason_tags.contains("test_block"), true)
  assert_eq(
    match result.blocks[0].decision_trace {
      Some(_) => true
      None => false
    },
    true,
  )
}

///|
test "lowering reports no raw pdf dependency" {
  let block = test_block("b_boundary", "Boundary", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::ParagraphCandidate,
    0.80,
    false,
    [],
    ["paragraph"],
    [],
    [],
  )
  let result = lower_one(block, [feature], [decision])
  assert_eq(result.reason_tags.contains("no_raw_pdf_read"), true)
  assert_eq(result.reason_tags.contains("no_old_parser_runtime"), true)
  assert_eq(result.reason_tags.contains("no_external_model_file"), true)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
}

///|
test "lowering does not mutate parser inputs" {
  let block = test_block("b_immutable", "Stable", [], [], [])
  let feature = test_feature(block, [], ["paragraph"], [], [])
  let decision = test_decision(
    block,
    @classifier_gate.PdfV2BlockDecisionLabel::ParagraphCandidate,
    0.80,
    false,
    [],
    ["paragraph"],
    [],
    [],
  )
  let doc = test_doc([block])
  let original_block_count = doc.pages[0].text_blocks.length()
  let original_feature_block = feature.block_id
  let original_decision_label = decision.label
  ignore(
    @lowering.lower_pdf_v2_document(
      doc,
      [feature],
      [decision],
      @lowering.default_pdf_v2_lowering_options(),
    ),
  )
  assert_eq(doc.pages[0].text_blocks.length(), original_block_count)
  assert_eq(feature.block_id, original_feature_block)
  assert_eq(decision.label == original_decision_label, true)
}

///|
fn lower_one(
  block : @normalized_model.PdfV2TextBlock,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
) -> @lowering.PdfV2LoweringResult {
  @lowering.lower_pdf_v2_document(
    test_doc([block]),
    features,
    decisions,
    @lowering.default_pdf_v2_lowering_options(),
  )
}

///|
fn test_doc(
  blocks : Array[@normalized_model.PdfV2TextBlock],
) -> @normalized_model.PdfV2DocumentModel {
  let page : @normalized_model.PdfV2Page = {
    page_index: 0,
    text_blocks: blocks,
    images: [],
    vectors: [],
    annotations: [],
    forms: [],
    layout_regions: [],
    reading_order: {
      page_index: 0,
      ordered_block_ids: block_ids(blocks),
      confidence: if blocks.is_empty() {
        0.0
      } else {
        1.0
      },
      reason_tags: ["test_reading_order"],
    },
    source_refs: [@pdfv2.pdf_v2_source_ref_for_page(0)],
    object_refs: ["10 0 R"],
    warnings: [],
    risks: [],
  }
  {
    source_summary: {
      bytes_len: 0,
      page_count: 1,
      source_event_count: 0,
      text_block_count: blocks.length(),
      warning_count: 0,
      risk_count: 0,
      scanned_once: true,
      one_pass_required: true,
      legacy_fallback_allowed: false,
      convert_raw_reparse_allowed: false,
    },
    pages: if blocks.is_empty() {
      []
    } else {
      [page]
    },
    outlines: [],
    destinations: [],
    cross_page_boundaries: [],
    warnings: [],
    risks: [],
    classifier_ready_features: { fields: Map([]), reason_tags: ["test_doc"] },
    reason_tags: ["test_doc"],
  }
}

///|
fn test_block(
  block_id : String,
  text : String,
  candidate_tags : Array[String],
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> @normalized_model.PdfV2TextBlock {
  {
    id: block_id,
    text,
    bbox: @pdfv2.pdf_v2_default_rect(),
    lines: [],
    dominant_font: Some("F1"),
    dominant_font_size: Some(12.0),
    writing_direction: @pdfv2.PdfV2WritingDirection::LeftToRight,
    page_index: 0,
    source_refs: [@pdfv2.pdf_v2_source_ref_for_page(0)],
    object_refs: ["20 0 R"],
    content_order_start: Some(0),
    content_order_end: Some(0),
    decode_confidence: @text_reconstruction.PdfV2DecodeConfidence::High,
    candidate_facts: [],
    list_marker_candidates: if candidate_tags.contains("list_marker_candidate") {
      [
        @text_reconstruction.list_marker_candidate("1.", 0.95, [
          @pdfv2.pdf_v2_source_ref_for_page(0),
        ]),
      ]
    } else {
      []
    },
    caption_prefix_candidates: [],
    heading_shape_candidates: [],
    classifier_ready_features: {
      fields: Map([("text_len", text.length().to_double())]),
      reason_tags: ["test_block_features"],
    },
    warnings,
    risks,
    reason_tags: ["test_block"],
  }
}

///|
fn test_feature(
  block : @normalized_model.PdfV2TextBlock,
  candidate_tags : Array[String],
  layout_kinds : Array[String],
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> @feature_export.PdfV2BlockFeatureRecord {
  {
    doc_id: "lowering_doc",
    page_index: block.page_index,
    block_id: block.id,
    line_ids: ["line_" + block.id],
    source_refs: block.source_refs,
    object_refs: block.object_refs,
    bbox: block.bbox,
    page_relative_bbox: block.bbox,
    text: block.text,
    text_length: block.text.length(),
    line_count: 1,
    char_count: block.text.length(),
    word_count: 1,
    dominant_font_name: block.dominant_font,
    dominant_font_size: block.dominant_font_size,
    decode_confidence: block.decode_confidence,
    writing_direction: block.writing_direction,
    candidate_fact_tags: candidate_tags,
    layout_region_ids: ["region_" + block.id],
    layout_region_kinds: layout_kinds,
    reading_order_index: Some(0),
    cross_page_boundary_kinds: [],
    warnings,
    risks,
    diagnostics: [],
    feature_risks: [],
    values: [test_value("text_length")],
    reason_tags: ["test_feature"],
  }
}

///|
fn test_decision(
  block : @normalized_model.PdfV2TextBlock,
  label : @classifier_gate.PdfV2BlockDecisionLabel,
  confidence : Double,
  abstain : Bool,
  candidate_tags : Array[String],
  layout_kinds : Array[String],
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> @classifier_gate.PdfV2BlockDecision {
  let source = if abstain {
    @classifier_gate.PdfV2BlockDecisionSource::Abstain
  } else {
    @classifier_gate.PdfV2BlockDecisionSource::CombinedGate
  }
  let score = test_score(confidence, if risks.is_empty() { 0.0 } else { 0.60 })
  let reason_tags = if abstain {
    [
      @classifier_gate.PdfV2BlockDecisionReasonTag::FailClosed,
      @classifier_gate.PdfV2BlockDecisionReasonTag::NoFallback,
    ]
  } else {
    [
      @classifier_gate.PdfV2BlockDecisionReasonTag::FeaturesOnly,
      @classifier_gate.PdfV2BlockDecisionReasonTag::ModelHintAccepted,
      @classifier_gate.PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ]
  }
  let trace : @classifier_gate.PdfV2DecisionTrace = {
    block_id: Some(block.id),
    decision_source: source,
    scores: score,
    abstain,
    blocked_reason: if abstain {
      Some("test_abstain")
    } else {
      None
    },
    reason_tags,
    evidence_feature_names: ["text_length"],
  }
  {
    block_id: block.id,
    page_index: block.page_index,
    label,
    confidence,
    abstain,
    source,
    scores: score,
    warnings,
    risks,
    feature_diagnostics: [],
    candidate_fact_tags: candidate_tags,
    layout_region_ids: ["region_" + block.id],
    layout_region_kinds: layout_kinds,
    reading_order_index: Some(0),
    blocked_reason: if abstain {
      Some("test_abstain")
    } else {
      None
    },
    reason_tags,
    trace,
  }
}

///|
fn test_score(
  final_confidence : Double,
  risk_penalty : Double,
) -> @classifier_gate.PdfV2BlockDecisionScore {
  {
    deterministic_constraint_score: 0.0,
    model_confidence: final_confidence,
    feature_support_score: 0.0,
    risk_penalty,
    final_confidence,
  }
}

///|
fn test_value(name : String) -> @feature_export.PdfV2FeatureValue {
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
    reason_tags: ["test_value"],
  }
}

///|
fn block_ids(blocks : Array[@normalized_model.PdfV2TextBlock]) -> Array[String] {
  let ids : Array[String] = []
  for block in blocks {
    ids.push(block.id)
  }
  ids
}

///|
fn has_warning_kind(
  warnings : Array[@lowering.PdfV2LoweringWarning],
  kind : @lowering.PdfV2LoweringWarningKind,
) -> Bool {
  for warning in warnings {
    if warning.kind == kind {
      return true
    }
  }
  false
}
