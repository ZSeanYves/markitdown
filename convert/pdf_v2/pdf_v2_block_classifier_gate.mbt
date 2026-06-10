///|
pub(all) struct PdfV2BlockClassifierHint {
  role : PdfV2BlockRole
  confidence : Double
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2DecisionInputs {
  deterministic_constraint_score : Double
  model_confidence : Double
  feature_support_score : Double
  risk_penalty : Double
}

///|
pub fn decide_pdf_v2_block_role(
  hint : PdfV2BlockClassifierHint?,
  inputs : PdfV2DecisionInputs,
) -> PdfV2BlockDecision {
  if inputs.deterministic_constraint_score >= 0.95 {
    return {
      role: PdfV2BlockRole::KeepAsText,
      confidence: inputs.deterministic_constraint_score,
      source: PdfV2DecisionSource::DeterministicRule,
      reason_tags: ["hard_constraint", "keep_parser_text"],
      abstained: false,
    }
  }

  match hint {
    Some(model_hint) =>
      if model_hint.confidence >= 0.85 &&
        inputs.model_confidence >= 0.85 &&
        inputs.feature_support_score >= 0.5 &&
        inputs.risk_penalty <= 0.2 {
        return {
          role: model_hint.role,
          confidence: model_hint.confidence,
          source: PdfV2DecisionSource::ModelHint,
          reason_tags: model_hint.reason_tags,
          abstained: false,
        }
      }
    None => ()
  }

  if inputs.feature_support_score >= 0.75 && inputs.risk_penalty <= 0.1 {
    return pdf_v2_keep_as_text_decision(
      inputs.feature_support_score,
      PdfV2DecisionSource::WeightedGate,
      ["weak_heuristic", "keep_as_text"],
    )
  }

  pdf_v2_abstain_decision(["low_confidence", "fail_closed"])
}
