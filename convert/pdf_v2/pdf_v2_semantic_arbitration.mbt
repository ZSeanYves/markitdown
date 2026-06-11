///|
pub fn pdf_v2_arbitrate_semantic_decision(
  input : PdfV2SemanticArbitrationInput,
) -> PdfV2SemanticArbitrationResult {
  let model_hint_present = input.model_hint is Some(_)
  let mut decision = input.rule_decision
  let reason_tags : Array[String] = ["semantic_arbitration", "rule_decision"]
  if model_hint_present {
    reason_tags.push("model_hint_present_ignored")
  } else {
    reason_tags.push("model_hint_absent")
  }

  if pdf_v2_rule_decision_has_hard_negative(decision) {
    decision = pdf_v2_rule_decision_force_safe_fallback(decision)
    reason_tags.push("hard_negative_rule_precedence")
    return {
      decision,
      model_hint_present,
      model_hint_used: false,
      disagreement_policy: input.disagreement_policy,
      reason_tags,
    }
  }

  if decision.confidence >= 0.70 {
    reason_tags.push("high_confidence_rule_accept")
    return {
      decision,
      model_hint_present,
      model_hint_used: false,
      disagreement_policy: input.disagreement_policy,
      reason_tags,
    }
  }

  if decision.confidence < 0.45 {
    decision = pdf_v2_rule_decision_weak_rule_fallback(decision)
    reason_tags.push("weak_rule_plain_text_fallback")
    return {
      decision,
      model_hint_present,
      model_hint_used: false,
      disagreement_policy: input.disagreement_policy,
      reason_tags,
    }
  }

  reason_tags.push("medium_rule_accept_without_model")
  {
    decision,
    model_hint_present,
    model_hint_used: false,
    disagreement_policy: input.disagreement_policy,
    reason_tags,
  }
}

///|
fn pdf_v2_rule_decision_has_hard_negative(decision : PdfV2RuleDecision) -> Bool {
  decision.risk_tags.contains("hard_negative_rule") ||
  decision.risk_tags.contains("hard_negative") ||
  decision.negative_reason_tags.contains("hard_negative_rule")
}

///|
fn pdf_v2_rule_decision_force_safe_fallback(
  decision : PdfV2RuleDecision,
) -> PdfV2RuleDecision {
  let kind = match decision.kind {
    PdfV2SemanticBlockKind::Unknown => PdfV2SemanticBlockKind::Unknown
    _ => PdfV2SemanticBlockKind::Paragraph
  }
  {
    ..decision,
    kind,
    confidence: 1.0,
    rule_id: decision.rule_id + ".hard_negative_fallback",
    reason_tags: pdf_v2_semantic_append_unique_tag(
      decision.reason_tags,
      "hard_negative_fallback",
    ),
  }
}

///|
fn pdf_v2_rule_decision_weak_rule_fallback(
  decision : PdfV2RuleDecision,
) -> PdfV2RuleDecision {
  let kind = match decision.kind {
    PdfV2SemanticBlockKind::Unknown => PdfV2SemanticBlockKind::Unknown
    PdfV2SemanticBlockKind::PlainText => PdfV2SemanticBlockKind::PlainText
    _ => PdfV2SemanticBlockKind::Paragraph
  }
  {
    ..decision,
    kind,
    rule_id: decision.rule_id + ".weak_rule_fallback",
    reason_tags: pdf_v2_semantic_append_unique_tag(
      decision.reason_tags,
      "weak_rule_fallback",
    ),
  }
}

///|
fn pdf_v2_semantic_append_unique_tag(
  tags : Array[String],
  tag : String,
) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    let out : Array[String] = []
    out.append(tags)
    out.push(tag)
    out
  }
}
