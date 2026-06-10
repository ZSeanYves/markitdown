///|
pub(all) struct PdfV2NoModelGateOptions {
  allow_plain_text_candidates : Bool
  abstain_on_missing_geometry : Bool
  abstain_on_unsupported_objects : Bool
  abstain_on_capped_context : Bool
  max_risk_score_for_plain_text : Double
}

///|
pub fn default_pdf_v2_no_model_gate_options() -> PdfV2NoModelGateOptions {
  {
    allow_plain_text_candidates: true,
    abstain_on_missing_geometry: false,
    abstain_on_unsupported_objects: true,
    abstain_on_capped_context: true,
    max_risk_score_for_plain_text: 0.35,
  }
}

///|
fn pdf_v2_gate_add_tag(tags : Array[String], tag : String) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    let out : Array[String] = []
    out.append(tags)
    out.push(tag)
    out
  }
}

///|
fn pdf_v2_gate_count_unsupported_context(
  row : @pdfv2.PdfV2BlockFeatureRow,
) -> Int {
  row.unsupported_nearby_or_page_count + row.partial_fact_nearby_or_page_count
}

///|
fn pdf_v2_gate_has_unsupported_context(
  row : @pdfv2.PdfV2BlockFeatureRow,
) -> Bool {
  pdf_v2_gate_count_unsupported_context(row) > 0
}

///|
fn pdf_v2_gate_base_risk_score(row : @pdfv2.PdfV2BlockFeatureRow) -> Double {
  let mut score = 0.0
  if row.low_signal_flag {
    score = score + 0.35
  }
  if row.missing_geometry_flag {
    score = score + 0.2
  }
  if row.avg_decode_confidence < 0.5 {
    score = score + 0.3
  }
  if row.warning_count > 0 {
    score = score + 0.1
  }
  if row.risk_count > 0 {
    score = score + 0.2
  }
  if pdf_v2_gate_has_unsupported_context(row) {
    score = score + 0.25
  }
  if row.capped_context_flag {
    score = score + 0.4
  }
  if score > 1.0 {
    1.0
  } else {
    score
  }
}

///|
fn pdf_v2_gate_feature_summary(row : @pdfv2.PdfV2BlockFeatureRow) -> String {
  "text_length=" +
  row.text_length.to_string() +
  ";line_count=" +
  row.line_count.to_string() +
  ";warning_count=" +
  row.warning_count.to_string() +
  ";risk_count=" +
  row.risk_count.to_string()
}

///|
fn pdf_v2_gate_guard_tags(
  row : @pdfv2.PdfV2BlockFeatureRow,
  options : PdfV2NoModelGateOptions,
) -> Array[String] {
  let tags : Array[String] = ["pdf_v2_no_model_gate"]
  if row.capped_context_flag && options.abstain_on_capped_context {
    tags.push("cap_guard")
    tags.push("abstain_on_capped_context")
  }
  if pdf_v2_gate_has_unsupported_context(row) &&
    options.abstain_on_unsupported_objects {
    tags.push("unsupported_guard")
    tags.push("abstain_on_unsupported_objects")
  }
  if row.missing_geometry_flag && options.abstain_on_missing_geometry {
    tags.push("missing_geometry_guard")
    tags.push("abstain_on_missing_geometry")
  }
  if row.low_signal_flag {
    tags.push("risk_guard")
    tags.push("low_signal_feature")
  }
  if row.text_length == 0 {
    tags.push("empty_text")
  }
  tags
}

///|
fn pdf_v2_gate_decision_source(
  row : @pdfv2.PdfV2BlockFeatureRow,
  options : PdfV2NoModelGateOptions,
) -> PdfV2NoModelDecisionSource {
  if row.capped_context_flag && options.abstain_on_capped_context {
    PdfV2NoModelDecisionSource::CapGuard
  } else if pdf_v2_gate_has_unsupported_context(row) &&
    options.abstain_on_unsupported_objects {
    PdfV2NoModelDecisionSource::UnsupportedGuard
  } else if row.missing_geometry_flag && options.abstain_on_missing_geometry {
    PdfV2NoModelDecisionSource::RiskGuard
  } else if row.low_signal_flag || row.warning_count > 0 || row.risk_count > 0 {
    PdfV2NoModelDecisionSource::RiskGuard
  } else {
    PdfV2NoModelDecisionSource::NoModelGate
  }
}

///|
fn pdf_v2_gate_for_block(
  row : @pdfv2.PdfV2BlockFeatureRow,
  options : PdfV2NoModelGateOptions,
) -> PdfV2BlockGateDecision {
  let risk_score = pdf_v2_gate_base_risk_score(row)
  let mut tags = pdf_v2_gate_guard_tags(row, options)
  let source = pdf_v2_gate_decision_source(row, options)
  let mut kind = PdfV2BlockDecisionKind::Unknown
  let mut confidence = 0.0
  if row.capped_context_flag && options.abstain_on_capped_context {
    kind = PdfV2BlockDecisionKind::Abstain
    confidence = 0.0
  } else if pdf_v2_gate_has_unsupported_context(row) &&
    options.abstain_on_unsupported_objects {
    kind = PdfV2BlockDecisionKind::Abstain
    confidence = 0.0
  } else if row.missing_geometry_flag && options.abstain_on_missing_geometry {
    kind = PdfV2BlockDecisionKind::Abstain
    confidence = 0.0
  } else if options.allow_plain_text_candidates &&
    row.text_length > 0 &&
    risk_score <= options.max_risk_score_for_plain_text {
    kind = PdfV2BlockDecisionKind::PlainTextCandidate
    confidence = 0.55
    tags = pdf_v2_gate_add_tag(tags, "plain_text_candidate")
    if row.missing_geometry_flag {
      tags = pdf_v2_gate_add_tag(tags, "missing_geometry_kept_as_text")
    }
  } else {
    kind = PdfV2BlockDecisionKind::Unknown
    confidence = 0.0
    tags = pdf_v2_gate_add_tag(tags, "unknown_fail_closed")
  }
  {
    page_index: row.page_index,
    block_index: row.block_index,
    decision_kind: kind,
    confidence,
    risk_score,
    abstain_reason_tags: tags,
    source_refs: row.source_refs,
    warning_count: row.warning_count,
    risk_count: row.risk_count,
    feature_summary: pdf_v2_gate_feature_summary(row),
    decision_source: source,
  }
}

///|
fn pdf_v2_gate_summary(
  decisions : Array[PdfV2BlockGateDecision],
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> PdfV2GateSummary {
  let mut plain_text_candidate_count = 0
  let mut abstain_count = 0
  let mut unknown_count = 0
  let mut risk_guard_count = 0
  let mut cap_guard_count = 0
  let mut unsupported_guard_count = 0
  let mut missing_geometry_guard_count = 0
  for decision in decisions {
    match decision.decision_kind {
      PlainTextCandidate =>
        plain_text_candidate_count = plain_text_candidate_count + 1
      Abstain => abstain_count = abstain_count + 1
      Unknown => unknown_count = unknown_count + 1
    }
    if decision.abstain_reason_tags.contains("risk_guard") {
      risk_guard_count = risk_guard_count + 1
    }
    if decision.abstain_reason_tags.contains("cap_guard") {
      cap_guard_count = cap_guard_count + 1
    }
    if decision.abstain_reason_tags.contains("unsupported_guard") {
      unsupported_guard_count = unsupported_guard_count + 1
    }
    if decision.abstain_reason_tags.contains("missing_geometry_guard") {
      missing_geometry_guard_count = missing_geometry_guard_count + 1
    }
  }
  {
    block_count: decisions.length(),
    plain_text_candidate_count,
    abstain_count,
    unknown_count,
    risk_guard_count,
    cap_guard_count,
    unsupported_guard_count,
    missing_geometry_guard_count,
    warning_count: warnings.length(),
    risk_count: risks.length(),
  }
}

///|
pub fn pdf_v2_run_no_model_block_gate(
  features : @pdfv2.PdfV2FeatureSet,
  options : PdfV2NoModelGateOptions,
) -> PdfV2GateResult {
  let decisions : Array[PdfV2BlockGateDecision] = []
  for row in features.block_features {
    decisions.push(pdf_v2_gate_for_block(row, options))
  }
  {
    decisions,
    warnings: features.warnings,
    risks: features.risks,
    summary: pdf_v2_gate_summary(decisions, features.warnings, features.risks),
    one_pass: features.one_pass,
    no_fallback: features.no_fallback,
  }
}
