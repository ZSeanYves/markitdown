///|
test "pdf v2 classifier gate abstains on low confidence" {
  let decision = @pdfv2conv.decide_pdf_v2_block_role(None, {
    deterministic_constraint_score: 0.0,
    model_confidence: 0.1,
    feature_support_score: 0.1,
    risk_penalty: 0.8,
  })

  assert_true(decision.abstained)
  assert_true(decision.role == @pdfv2conv.PdfV2BlockRole::Uncertain)
  assert_true(decision.source == @pdfv2conv.PdfV2DecisionSource::Abstain)
  assert_true(decision.reason_tags.length() > 0)
}

///|
test "pdf v2 classifier gate accepts high confidence model hint" {
  let decision = @pdfv2conv.decide_pdf_v2_block_role(
    Some({
      role: @pdfv2conv.PdfV2BlockRole::Heading,
      confidence: 0.93,
      reason_tags: ["model_heading"],
    }),
    {
      deterministic_constraint_score: 0.0,
      model_confidence: 0.93,
      feature_support_score: 0.8,
      risk_penalty: 0.0,
    },
  )

  assert_true(!decision.abstained)
  assert_true(decision.role == @pdfv2conv.PdfV2BlockRole::Heading)
  assert_true(decision.source == @pdfv2conv.PdfV2DecisionSource::ModelHint)
  assert_true(decision.confidence == 0.93)
}

///|
test "pdf v2 classifier gate lets hard constraints outrank model hint" {
  let decision = @pdfv2conv.decide_pdf_v2_block_role(
    Some({
      role: @pdfv2conv.PdfV2BlockRole::Heading,
      confidence: 0.99,
      reason_tags: ["model_heading"],
    }),
    {
      deterministic_constraint_score: 0.98,
      model_confidence: 0.99,
      feature_support_score: 0.9,
      risk_penalty: 0.0,
    },
  )

  assert_true(decision.role == @pdfv2conv.PdfV2BlockRole::KeepAsText)
  assert_true(
    decision.source == @pdfv2conv.PdfV2DecisionSource::DeterministicRule,
  )
}

///|
fn phase15_source_ref() -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(0),
    object_id: Some("4 0 R"),
    stream_index: Some(0),
    op_index: Some(0),
    content_order_index: Some(0),
    kind: @pdfv2.PdfV2SourceKind::TextOp,
  }
}

///|
fn phase15_object_flags() -> @pdfv2.PdfV2ObjectPresenceFlags {
  {
    has_images: false,
    has_inline_images: false,
    has_annotations: false,
    has_links: false,
    has_forms: false,
    has_resources: false,
  }
}

///|
fn phase15_block_row(
  text_length : Int,
  unsupported_count : Int,
  partial_count : Int,
  missing_geometry : Bool,
  capped_context : Bool,
  low_signal : Bool,
) -> @pdfv2.PdfV2BlockFeatureRow {
  let source_ref = phase15_source_ref()
  {
    page_index: Some(0),
    block_index: 0,
    text_length,
    line_count: if text_length > 0 {
      1
    } else {
      0
    },
    span_count: 0,
    char_count: text_length,
    avg_decode_confidence: if low_signal {
      0.2
    } else {
      0.75
    },
    geometry_confidence: if missing_geometry {
      @pdfv2.PdfV2GeometryConfidence::Unknown
    } else {
      @pdfv2.PdfV2GeometryConfidence::High
    },
    has_bbox: !missing_geometry,
    source_ref_count: 1,
    warning_count: 0,
    risk_count: if low_signal {
      1
    } else {
      0
    },
    unsupported_nearby_or_page_count: unsupported_count,
    partial_fact_nearby_or_page_count: partial_count,
    object_presence_flags: phase15_object_flags(),
    low_signal_flag: low_signal,
    missing_geometry_flag: missing_geometry,
    capped_context_flag: capped_context,
    reason_tags: ["phase15_feature_row"],
    source_refs: [source_ref],
  }
}

///|
fn phase15_features(
  rows : Array[@pdfv2.PdfV2BlockFeatureRow],
) -> @pdfv2.PdfV2FeatureSet {
  {
    document_features: {
      page_count: 1,
      has_text: rows.length() > 0,
      has_images: false,
      has_annotations: false,
      has_forms: false,
      has_outlines: false,
      has_metadata: false,
      unsupported_capability_count: 0,
      partial_fact_count: 0,
      capped_object_count: 0,
      metadata_only_count: 0,
      warning_count: 0,
      risk_count: 0,
    },
    page_features: [],
    block_features: rows,
    object_features: [],
    summary: {
      document_feature_count: 1,
      page_feature_count: 0,
      block_feature_count: rows.length(),
      object_feature_count: 0,
      low_signal_block_count: 0,
      missing_geometry_block_count: 0,
      unsupported_object_count: 0,
      partial_object_count: 0,
      capped_object_count: 0,
      warning_count: 0,
      risk_count: 0,
    },
    warnings: [],
    risks: [],
    source_refs: [phase15_source_ref()],
    one_pass: true,
    no_fallback: true,
  }
}

///|
fn phase15_run(
  row : @pdfv2.PdfV2BlockFeatureRow,
  options : @pdfv2conv.PdfV2NoModelGateOptions,
) -> @pdfv2conv.PdfV2BlockGateDecision raise {
  let result = @pdfv2conv.pdf_v2_run_no_model_block_gate(
    phase15_features([row]),
    options,
  )
  assert_true(result.decisions.length() == 1)
  result.decisions[0]
}

///|
fn phase15_is_no_model_safe_kind(
  kind : @pdfv2conv.PdfV2BlockDecisionKind,
) -> Bool {
  kind == @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate ||
  kind == @pdfv2conv.PdfV2BlockDecisionKind::Abstain ||
  kind == @pdfv2conv.PdfV2BlockDecisionKind::Unknown
}

///|
test "pdf v2 no-model gate emits conservative plain text candidate" {
  let row = phase15_block_row(12, 0, 0, false, false, false)
  let decision = phase15_run(
    row,
    @pdfv2conv.default_pdf_v2_no_model_gate_options(),
  )

  assert_true(
    decision.decision_kind ==
    @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
  )
  assert_true(decision.confidence <= 0.65)
  assert_true(decision.source_refs.length() == 1)
  assert_true(decision.source_refs[0].page_index == Some(0))
  assert_true(decision.source_refs[0].object_id == Some("4 0 R"))
  assert_true(decision.source_refs[0].kind == @pdfv2.PdfV2SourceKind::TextOp)
  assert_true(phase15_is_no_model_safe_kind(decision.decision_kind))
  assert_true(
    decision.decision_source ==
    @pdfv2conv.PdfV2NoModelDecisionSource::NoModelGate,
  )
}

///|
test "pdf v2 no-model gate abstains on unsupported object context" {
  let row = phase15_block_row(10, 1, 0, false, false, false)
  let decision = phase15_run(
    row,
    @pdfv2conv.default_pdf_v2_no_model_gate_options(),
  )

  assert_true(
    decision.decision_kind == @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
  )
  assert_true(decision.abstain_reason_tags.contains("unsupported_guard"))
  assert_true(
    decision.decision_source ==
    @pdfv2conv.PdfV2NoModelDecisionSource::UnsupportedGuard,
  )
  assert_true(phase15_is_no_model_safe_kind(decision.decision_kind))
}

///|
test "pdf v2 no-model gate abstains on capped context" {
  let row = phase15_block_row(10, 0, 0, false, true, false)
  let decision = phase15_run(
    row,
    @pdfv2conv.default_pdf_v2_no_model_gate_options(),
  )

  assert_true(
    decision.decision_kind == @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
  )
  assert_true(decision.abstain_reason_tags.contains("cap_guard"))
  assert_true(
    decision.decision_source == @pdfv2conv.PdfV2NoModelDecisionSource::CapGuard,
  )
}

///|
test "pdf v2 no-model gate missing geometry is option gated" {
  let row = phase15_block_row(10, 0, 0, true, false, false)
  let keep_decision = phase15_run(
    row,
    @pdfv2conv.default_pdf_v2_no_model_gate_options(),
  )

  assert_true(
    keep_decision.decision_kind ==
    @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate,
  )
  assert_true(
    keep_decision.abstain_reason_tags.contains("missing_geometry_kept_as_text"),
  )

  let abstain_decision = phase15_run(row, {
    ..@pdfv2conv.default_pdf_v2_no_model_gate_options(),
    abstain_on_missing_geometry: true,
  })
  assert_true(
    abstain_decision.decision_kind == @pdfv2conv.PdfV2BlockDecisionKind::Abstain,
  )
  assert_true(
    abstain_decision.abstain_reason_tags.contains("missing_geometry_guard"),
  )
}

///|
test "pdf v2 no-model gate keeps empty low signal block unknown" {
  let row = phase15_block_row(0, 0, 0, true, false, true)
  let decision = phase15_run(
    row,
    @pdfv2conv.default_pdf_v2_no_model_gate_options(),
  )

  assert_true(
    decision.decision_kind == @pdfv2conv.PdfV2BlockDecisionKind::Unknown,
  )
  assert_true(
    !(decision.decision_kind ==
    @pdfv2conv.PdfV2BlockDecisionKind::PlainTextCandidate),
  )
  assert_true(decision.abstain_reason_tags.contains("empty_text"))
}

///|
test "pdf v2 no-model gate summary counts guards" {
  let clean = phase15_block_row(8, 0, 0, false, false, false)
  let unsupported = {
    ..phase15_block_row(8, 1, 0, false, false, false),
    block_index: 1,
  }
  let capped = {
    ..phase15_block_row(8, 0, 0, false, true, false),
    block_index: 2,
  }
  let missing = {
    ..phase15_block_row(8, 0, 0, true, false, false),
    block_index: 3,
  }
  let unknown = {
    ..phase15_block_row(0, 0, 0, false, false, true),
    block_index: 4,
  }
  let result = @pdfv2conv.pdf_v2_run_no_model_block_gate(
    phase15_features([clean, unsupported, capped, missing, unknown]),
    {
      ..@pdfv2conv.default_pdf_v2_no_model_gate_options(),
      abstain_on_missing_geometry: true,
    },
  )

  assert_true(result.summary.block_count == 5)
  assert_true(result.summary.plain_text_candidate_count == 1)
  assert_true(result.summary.abstain_count == 3)
  assert_true(result.summary.unknown_count == 1)
  assert_true(result.summary.cap_guard_count == 1)
  assert_true(result.summary.unsupported_guard_count == 1)
  assert_true(result.summary.missing_geometry_guard_count == 1)
  assert_true(result.one_pass)
  assert_true(result.no_fallback)
}

///|
test "pdf v2 no-model gate boundary guard has no model or raw pdf dependency" {
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
  let gate_text = @fs.read_file_to_string(
    "convert/pdf_v2/pdf_v2_no_model_gate.mbt",
    encoding="utf8",
  ) catch {
    err => fail("read no-model gate failed: " + err.to_string())
  }

  assert_true(!package_text.contains("doc_parse/pdf/vendor"))
  assert_true(!package_text.contains("mbtpdf"))
  assert_true(!parser_package_text.contains("convert/pdf_v2"))
  assert_true(!gate_text.contains("parse_pdf_v2_model_from_path"))
  assert_true(!gate_text.contains("parse_pdf_v2_features_from_path"))
  assert_true(!gate_text.contains("pdf_v2_open_source_document_from_path"))
  assert_true(!gate_text.contains("model.pkl"))
  assert_true(!gate_text.contains("features.tsv"))
  assert_true(!gate_text.contains("markitdown-quality-lab"))
}
