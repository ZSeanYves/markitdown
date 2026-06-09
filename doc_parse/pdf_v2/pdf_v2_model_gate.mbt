///|
pub(all) struct PdfV2GateScores {
  deterministic_constraint_score : Double
  model_confidence : Double
  feature_support_score : Double
  risk_penalty : Double
  final_confidence : Double
}

///|
pub(all) struct PdfV2GateDecision {
  accepted : Bool
  abstain : Bool
  decision_source : PdfV2DecisionSource
  scores : PdfV2GateScores
  reason_tags : Array[String]
  blocked_reason : String?
}

///|
pub fn pdf_v2_fail_closed_gate(
  hard_constraints : Array[String],
  model_confidence : Double,
  feature_support_score : Double,
  risk_penalty : Double,
) -> PdfV2GateDecision {
  if !hard_constraints.is_empty() {
    return {
      accepted: false,
      abstain: true,
      decision_source: PdfV2DecisionSource::DeterministicConstraint,
      scores: {
        deterministic_constraint_score: 1.0,
        model_confidence,
        feature_support_score,
        risk_penalty,
        final_confidence: 0.0,
      },
      reason_tags: hard_constraints,
      blocked_reason: Some("hard_constraints"),
    }
  }
  let final_confidence = model_confidence + feature_support_score - risk_penalty
  if final_confidence < 0.80 {
    {
      accepted: false,
      abstain: true,
      decision_source: PdfV2DecisionSource::Abstain,
      scores: {
        deterministic_constraint_score: 0.0,
        model_confidence,
        feature_support_score,
        risk_penalty,
        final_confidence,
      },
      reason_tags: ["low_confidence"],
      blocked_reason: Some("low_confidence"),
    }
  } else {
    {
      accepted: true,
      abstain: false,
      decision_source: PdfV2DecisionSource::MixedGate,
      scores: {
        deterministic_constraint_score: 0.0,
        model_confidence,
        feature_support_score,
        risk_penalty,
        final_confidence,
      },
      reason_tags: ["high_confidence_gate"],
      blocked_reason: None,
    }
  }
}
