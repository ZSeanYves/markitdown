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
