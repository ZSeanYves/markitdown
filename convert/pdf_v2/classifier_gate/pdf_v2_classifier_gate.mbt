///|
pub(all) enum PdfV2BlockDecisionLabel {
  HeadingCandidate
  ParagraphCandidate
  ListItemCandidate
  CaptionCandidate
  TableCandidate
  NoiseCandidate
  TextCandidate
  Uncertain
} derive(Eq)

///|
pub(all) enum PdfV2BlockDecisionSource {
  DeterministicConstraint
  ModelHint
  WeakHeuristic
  CombinedGate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2BlockDecisionReasonTag {
  FeaturesOnly
  EmptyFeatures
  CandidateEvidenceOnly
  LayoutMembershipPreserved
  ParserRiskPresent
  ParserWarningPresent
  ModelHintAccepted
  ModelHintIgnored
  WeakHeuristicUsed
  FailClosed
  NoFallback
  NoFinalSemanticLabel
} derive(Eq)

///|
pub(all) struct PdfV2BlockDecisionScore {
  deterministic_constraint_score : Double
  model_confidence : Double
  feature_support_score : Double
  risk_penalty : Double
  final_confidence : Double
}

///|
pub(all) struct PdfV2ClassifierHint {
  block_id : String
  suggested_label : PdfV2BlockDecisionLabel
  confidence : Double
  reason_tags : Array[PdfV2BlockDecisionReasonTag]
}

///|
pub(all) struct PdfV2BlockDecisionOptions {
  fail_closed : Bool
  allow_model_hints : Bool
  model_hints : Array[PdfV2ClassifierHint]
  weak_heuristics_enabled : Bool
  min_model_confidence : Double
  min_final_confidence : Double
}

///|
pub(all) struct PdfV2DecisionTrace {
  block_id : String?
  decision_source : PdfV2BlockDecisionSource
  scores : PdfV2BlockDecisionScore
  abstain : Bool
  blocked_reason : String?
  reason_tags : Array[PdfV2BlockDecisionReasonTag]
  evidence_feature_names : Array[String]
}

///|
pub(all) struct PdfV2BlockDecision {
  block_id : String
  page_index : Int
  label : PdfV2BlockDecisionLabel
  confidence : Double
  abstain : Bool
  source : PdfV2BlockDecisionSource
  scores : PdfV2BlockDecisionScore
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  feature_diagnostics : Array[@feature_export.PdfV2FeatureDiagnostic]
  candidate_fact_tags : Array[String]
  layout_region_ids : Array[String]
  layout_region_kinds : Array[String]
  reading_order_index : Int?
  blocked_reason : String?
  reason_tags : Array[PdfV2BlockDecisionReasonTag]
  trace : PdfV2DecisionTrace
}

///|
pub(all) struct PdfV2DecisionSummary {
  input_record_count : Int
  decision_count : Int
  abstain_count : Int
  parser_warning_count : Int
  parser_risk_count : Int
  model_hint_count : Int
  accepted_model_hint_count : Int
  fail_closed : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  reason_tags : Array[PdfV2BlockDecisionReasonTag]
}

///|
pub fn default_pdf_v2_block_decision_options() -> PdfV2BlockDecisionOptions {
  {
    fail_closed: true,
    allow_model_hints: false,
    model_hints: [],
    weak_heuristics_enabled: true,
    min_model_confidence: 0.90,
    min_final_confidence: 0.80,
  }
}

///|
pub fn build_pdf_v2_block_decisions(
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  options : PdfV2BlockDecisionOptions,
) -> Array[PdfV2BlockDecision] {
  let decisions : Array[PdfV2BlockDecision] = []
  for feature in features {
    decisions.push(decision_for_feature(feature, options))
  }
  decisions
}

///|
pub fn summarize_pdf_v2_block_decisions(
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[PdfV2BlockDecision],
  options : PdfV2BlockDecisionOptions,
) -> PdfV2DecisionSummary {
  let mut abstain_count = 0
  let mut parser_warning_count = 0
  let mut parser_risk_count = 0
  let mut accepted_model_hint_count = 0
  for decision in decisions {
    if decision.abstain {
      abstain_count = abstain_count + 1
    }
    parser_warning_count = parser_warning_count + decision.warnings.length()
    parser_risk_count = parser_risk_count + decision.risks.length()
    if decision.source == PdfV2BlockDecisionSource::ModelHint {
      accepted_model_hint_count = accepted_model_hint_count + 1
    }
  }
  {
    input_record_count: features.length(),
    decision_count: decisions.length(),
    abstain_count,
    parser_warning_count,
    parser_risk_count,
    model_hint_count: options.model_hints.length(),
    accepted_model_hint_count,
    fail_closed: options.fail_closed,
    one_pass_required: true,
    legacy_fallback_allowed: false,
    convert_raw_reparse_allowed: false,
    reason_tags: [
      PdfV2BlockDecisionReasonTag::FeaturesOnly,
      PdfV2BlockDecisionReasonTag::NoFallback,
      PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ],
  }
}

///|
fn decision_for_feature(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  options : PdfV2BlockDecisionOptions,
) -> PdfV2BlockDecision {
  if feature.text_length == 0 {
    return abstain_decision(feature, "empty_feature_text", [
      PdfV2BlockDecisionReasonTag::FeaturesOnly,
      PdfV2BlockDecisionReasonTag::FailClosed,
    ])
  }
  if options.fail_closed && !feature.risks.is_empty() {
    return abstain_decision(feature, "parser_risk_present", [
      PdfV2BlockDecisionReasonTag::ParserRiskPresent,
      PdfV2BlockDecisionReasonTag::FailClosed,
    ])
  }
  match find_model_hint(options.model_hints, feature.block_id) {
    Some(hint) =>
      if options.allow_model_hints &&
        hint.confidence >= options.min_model_confidence {
        return model_hint_decision(feature, hint, options)
      } else {
        return abstain_decision(feature, "model_hint_ignored", [
          PdfV2BlockDecisionReasonTag::ModelHintIgnored,
          PdfV2BlockDecisionReasonTag::FailClosed,
        ])
      }
    None => ()
  }
  if options.weak_heuristics_enabled {
    let decision = weak_heuristic_decision(feature, options)
    if !decision.abstain {
      return decision
    }
  }
  abstain_decision(feature, "no_high_confidence_evidence", [
    PdfV2BlockDecisionReasonTag::CandidateEvidenceOnly,
    PdfV2BlockDecisionReasonTag::FailClosed,
  ])
}

///|
fn model_hint_decision(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  hint : PdfV2ClassifierHint,
  options : PdfV2BlockDecisionOptions,
) -> PdfV2BlockDecision {
  let score = score(
    0.0,
    hint.confidence,
    feature_support_score(feature),
    risk_penalty(feature),
  )
  if score.final_confidence < options.min_final_confidence {
    return abstain_decision(feature, "model_hint_low_final_confidence", [
      PdfV2BlockDecisionReasonTag::ModelHintIgnored,
      PdfV2BlockDecisionReasonTag::FailClosed,
    ])
  }
  make_decision(
    feature,
    hint.suggested_label,
    PdfV2BlockDecisionSource::ModelHint,
    score,
    false,
    None,
    hint.reason_tags +
    [
      PdfV2BlockDecisionReasonTag::FeaturesOnly,
      PdfV2BlockDecisionReasonTag::ModelHintAccepted,
      PdfV2BlockDecisionReasonTag::CandidateEvidenceOnly,
      PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ],
  )
}

///|
fn weak_heuristic_decision(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  options : PdfV2BlockDecisionOptions,
) -> PdfV2BlockDecision {
  let label = if has_candidate_tag(feature, "caption_prefix_candidate") {
    PdfV2BlockDecisionLabel::CaptionCandidate
  } else if has_candidate_tag(feature, "list_marker_candidate") {
    PdfV2BlockDecisionLabel::ListItemCandidate
  } else if has_candidate_tag(feature, "heading_shape_candidate") {
    PdfV2BlockDecisionLabel::HeadingCandidate
  } else if has_layout_kind(feature, "paragraph") {
    PdfV2BlockDecisionLabel::ParagraphCandidate
  } else {
    PdfV2BlockDecisionLabel::Uncertain
  }
  if label == PdfV2BlockDecisionLabel::Uncertain {
    return abstain_decision(feature, "weak_heuristic_no_signal", [
      PdfV2BlockDecisionReasonTag::WeakHeuristicUsed,
      PdfV2BlockDecisionReasonTag::FailClosed,
    ])
  }
  let score = score(
    0.0,
    0.0,
    feature_support_score(feature),
    risk_penalty(feature),
  )
  if score.final_confidence < options.min_final_confidence {
    return abstain_decision(feature, "weak_heuristic_low_confidence", [
      PdfV2BlockDecisionReasonTag::WeakHeuristicUsed,
      PdfV2BlockDecisionReasonTag::FailClosed,
    ])
  }
  make_decision(
    feature,
    label,
    PdfV2BlockDecisionSource::WeakHeuristic,
    score,
    false,
    None,
    [
      PdfV2BlockDecisionReasonTag::FeaturesOnly,
      PdfV2BlockDecisionReasonTag::WeakHeuristicUsed,
      PdfV2BlockDecisionReasonTag::CandidateEvidenceOnly,
      PdfV2BlockDecisionReasonTag::LayoutMembershipPreserved,
      PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ],
  )
}

///|
fn abstain_decision(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  blocked_reason : String,
  reason_tags : Array[PdfV2BlockDecisionReasonTag],
) -> PdfV2BlockDecision {
  make_decision(
    feature,
    PdfV2BlockDecisionLabel::Uncertain,
    PdfV2BlockDecisionSource::Abstain,
    score(0.0, 0.0, feature_support_score(feature), 1.0),
    true,
    Some(blocked_reason),
    reason_tags +
    [
      PdfV2BlockDecisionReasonTag::FeaturesOnly,
      PdfV2BlockDecisionReasonTag::NoFallback,
      PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel,
    ],
  )
}

///|
fn make_decision(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  label : PdfV2BlockDecisionLabel,
  source : PdfV2BlockDecisionSource,
  scores : PdfV2BlockDecisionScore,
  abstain : Bool,
  blocked_reason : String?,
  reason_tags : Array[PdfV2BlockDecisionReasonTag],
) -> PdfV2BlockDecision {
  let trace : PdfV2DecisionTrace = {
    block_id: Some(feature.block_id),
    decision_source: source,
    scores,
    abstain,
    blocked_reason,
    reason_tags,
    evidence_feature_names: evidence_feature_names(feature),
  }
  {
    block_id: feature.block_id,
    page_index: feature.page_index,
    label,
    confidence: scores.final_confidence,
    abstain,
    source,
    scores,
    warnings: feature.warnings,
    risks: feature.risks,
    feature_diagnostics: feature.diagnostics,
    candidate_fact_tags: feature.candidate_fact_tags,
    layout_region_ids: feature.layout_region_ids,
    layout_region_kinds: feature.layout_region_kinds,
    reading_order_index: feature.reading_order_index,
    blocked_reason,
    reason_tags,
    trace,
  }
}

///|
fn score(
  deterministic_constraint_score : Double,
  model_confidence : Double,
  feature_support_score : Double,
  risk_penalty : Double,
) -> PdfV2BlockDecisionScore {
  let final_confidence = clamp(
    deterministic_constraint_score +
    model_confidence +
    feature_support_score -
    risk_penalty,
  )
  {
    deterministic_constraint_score,
    model_confidence,
    feature_support_score,
    risk_penalty,
    final_confidence,
  }
}

///|
fn feature_support_score(
  feature : @feature_export.PdfV2BlockFeatureRecord,
) -> Double {
  let mut support = 0.35
  if !feature.candidate_fact_tags.is_empty() {
    support = support + 0.25
  }
  if !feature.layout_region_ids.is_empty() {
    support = support + 0.20
  }
  if feature.reading_order_index != None {
    support = support + 0.10
  }
  clamp(support)
}

///|
fn risk_penalty(feature : @feature_export.PdfV2BlockFeatureRecord) -> Double {
  let mut penalty = 0.0
  if !feature.warnings.is_empty() {
    penalty = penalty + 0.10
  }
  if !feature.risks.is_empty() {
    penalty = penalty + 0.60
  }
  if !feature.feature_risks.is_empty() {
    penalty = penalty + 0.20
  }
  clamp(penalty)
}

///|
fn find_model_hint(
  hints : Array[PdfV2ClassifierHint],
  block_id : String,
) -> PdfV2ClassifierHint? {
  for hint in hints {
    if hint.block_id == block_id {
      return Some(hint)
    }
  }
  None
}

///|
fn has_candidate_tag(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  tag : String,
) -> Bool {
  feature.candidate_fact_tags.contains(tag)
}

///|
fn has_layout_kind(
  feature : @feature_export.PdfV2BlockFeatureRecord,
  kind : String,
) -> Bool {
  feature.layout_region_kinds.contains(kind)
}

///|
fn evidence_feature_names(
  feature : @feature_export.PdfV2BlockFeatureRecord,
) -> Array[String] {
  let names : Array[String] = []
  for value in feature.values {
    if value.availability == @feature_export.PdfV2FeatureAvailability::Available ||
      value.availability ==
      @feature_export.PdfV2FeatureAvailability::DerivedAvailable {
      names.push(value.field_name)
    }
  }
  names
}

///|
fn clamp(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}
