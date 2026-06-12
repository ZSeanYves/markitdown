///|
fn semantic_test_ref(order : Int) -> @pdfv2.PdfV2SourceRef {
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
fn semantic_test_ref_for_page(
  page_index : Int,
  order : Int,
) -> @pdfv2.PdfV2SourceRef {
  { ..semantic_test_ref(order), page_index: Some(page_index) }
}

///|
fn semantic_test_fragment(
  index : Int,
  text : String,
  line_count : Int,
) -> PdfV2FactFragment {
  {
    kind: PdfV2FactFragmentKind::PlainText,
    text,
    page_index: Some(0),
    block_index: Some(index),
    line_count,
    source_refs: [semantic_test_ref(index)],
    reason_tags: ["semantic_test_fragment"],
  }
}

///|
fn semantic_test_fragment_for_page(
  page_index : Int,
  block_index : Int,
  text : String,
) -> PdfV2FactFragment {
  {
    kind: PdfV2FactFragmentKind::PlainText,
    text,
    page_index: Some(page_index),
    block_index: Some(block_index),
    line_count: 1,
    source_refs: [semantic_test_ref_for_page(page_index, block_index)],
    reason_tags: ["semantic_test_fragment"],
  }
}

///|
fn semantic_test_options() -> PdfV2ProductBridgeOptions {
  default_pdf_v2_product_bridge_options()
}

///|
fn semantic_test_blocks(texts : Array[String]) -> Array[PdfV2SemanticBlock] {
  let fragments : Array[PdfV2FactFragment] = []
  for i in 0..<texts.length() {
    fragments.push(semantic_test_fragment(i, texts[i], 1))
  }
  pdf_v2_semantic_blocks_from_fragments(fragments, semantic_test_options())
}

///|
fn semantic_test_cross_page_fact(
  confidence : Double,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> @pdfv2.PdfV2CrossPageBoundaryFact {
  {
    page_from: 0,
    page_to: 1,
    prev_block_ref: Some(0),
    next_block_ref: Some(0),
    prev_line_refs: [0],
    next_line_refs: [0],
    prev_vertical_band: @pdfv2.PdfV2ParityVerticalBand::Body,
    next_vertical_band: @pdfv2.PdfV2ParityVerticalBand::Body,
    prev_open_ended: true,
    next_starts_with_marker: false,
    repeated_artifact_gap: false,
    confidence,
    reason_tags: [
      "cross_page_boundary_fact", "parser_layout_backed", "source_order_pair", "prev_open_ended",
    ],
    source_refs,
  }
}

///|
fn semantic_test_audit_count(
  counters : Array[PdfV2CrossPageArbitrationAuditCounter],
  key : String,
) -> Int {
  for counter in counters {
    if counter.key == key {
      return counter.count
    }
  }
  0
}

///|
fn semantic_test_cross_page_block(
  text : String,
  page_index : Int,
  source_ref : @pdfv2.PdfV2SourceRef,
) -> PdfV2SemanticBlock {
  let decision = pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Paragraph,
    0.76,
    "paragraph.test",
    ["paragraph_guard"],
    [],
    [source_ref],
    [],
  )
  {
    kind: PdfV2SemanticBlockKind::Paragraph,
    text,
    level: None,
    ordered: None,
    list_level: 0,
    page_index: Some(page_index),
    block_index: Some(0),
    fragment_index: page_index,
    source_refs: [source_ref],
    reason_tags: ["semantic_test_block"],
    risk_tags: [],
    decision,
  }
}

///|
test "pdf v2 text flow records title body and source refs" {
  let fragments = [
    semantic_test_fragment(0, "Document Conversion Pipeline", 1),
    semantic_test_fragment(
      1, "This project aims to build a unified document conversion pipeline.", 1,
    ),
  ]
  let flow = pdf_v2_text_flow_from_fragments(fragments, semantic_test_options())

  assert_true(flow.length() == 2)
  assert_true(flow[0].page_index == Some(0))
  assert_true(flow[0].block_index == Some(0))
  assert_true(flow[0].line_count == 1)
  assert_true(flow[0].char_count > 0)
  assert_true(flow[0].signals.is_single_line)
  assert_true(flow[0].signals.has_following_body)
  assert_true(flow[0].source_refs.length() == 1)
  assert_true(flow[0].reason_tags.contains("semantic_test_fragment"))
}

///|
test "pdf v2 cross page arbitration rejects low confidence and missing refs" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("break and resumes.", 1, right_ref)
  let low = pdf_v2_apply_cross_page_boundary_arbitration([left, right], [
    semantic_test_cross_page_fact(0.50, [left_ref, right_ref]),
  ])
  let missing_refs = pdf_v2_apply_cross_page_boundary_arbitration(
    [left, right],
    [semantic_test_cross_page_fact(0.70, [])],
  )
  let joined = pdf_v2_apply_cross_page_boundary_arbitration([left, right], [
    semantic_test_cross_page_fact(0.70, [left_ref, right_ref]),
  ])

  assert_true(low.length() == 2)
  assert_true(missing_refs.length() == 2)
  assert_true(joined.length() == 1)
  assert_true(joined[0].reason_tags.contains("fact_backed_cross_page_join"))
  assert_true(joined[0].source_refs.length() == 2)
}

///|
test "pdf v2 cross page arbitration audit counts valid fact backed join" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("break and resumes.", 1, right_ref)
  let fact = semantic_test_cross_page_fact(0.70, [left_ref, right_ref])
  let joined = pdf_v2_apply_cross_page_boundary_arbitration([left, right], [
    fact,
  ])
  let audit = pdf_v2_cross_page_arbitration_audit([left, right], [fact])

  assert_true(joined.length() == 1)
  assert_true(audit.generated_fact_count == 1)
  assert_true(audit.facts_reaching_product_arbitration_count == 1)
  assert_true(audit.product_candidate_fact_count == 1)
  assert_true(audit.facts_passing_confidence_gate == 1)
  assert_true(audit.facts_passing_source_ref_gate == 1)
  assert_true(audit.facts_passing_prev_open_ended_gate == 1)
  assert_true(audit.facts_passing_next_marker_gate == 1)
  assert_true(audit.facts_passing_ambiguity_tag_gate == 1)
  assert_true(audit.semantic_pair_count == 1)
  assert_true(audit.actual_join_decision_changed_count == 1)
  assert_true(audit.fallback_existing_behavior_count == 0)
  assert_true(
    semantic_test_audit_count(
      audit.reason_tag_distribution,
      "cross_page_boundary_fact",
    ) ==
    1,
  )
}

///|
test "pdf v2 cross page fragment arbitration audit counts fragment path join" {
  let left = semantic_test_fragment_for_page(
    0, 0, "The paragraph continues across the page",
  )
  let right = semantic_test_fragment_for_page(1, 0, "break and resumes.")
  let left_ref = left.source_refs[0]
  let right_ref = right.source_refs[0]
  let fact = semantic_test_cross_page_fact(0.70, [left_ref, right_ref])
  let audit = pdf_v2_cross_page_fragment_arbitration_audit(
    [left, right],
    semantic_test_options(),
    [fact],
  )

  assert_true(audit.generated_fact_count == 1)
  assert_true(audit.product_candidate_fact_count == 1)
  assert_true(audit.fragment_pair_count == 1)
  assert_true(audit.semantic_pair_count == 0)
  assert_true(audit.actual_join_decision_changed_count == 1)
  assert_true(audit.fallback_existing_behavior_count == 0)
}

///|
test "pdf v2 cross page arbitration audit counts low confidence rejection" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("break and resumes.", 1, right_ref)
  let fact = semantic_test_cross_page_fact(0.50, [left_ref, right_ref])
  let audit = pdf_v2_cross_page_arbitration_audit([left, right], [fact])

  assert_true(audit.generated_fact_count == 1)
  assert_true(audit.facts_reaching_product_arbitration_count == 0)
  assert_true(audit.product_candidate_fact_count == 0)
  assert_true(audit.rejected_confidence_below_threshold_count == 1)
  assert_true(audit.actual_join_decision_changed_count == 0)
  assert_true(audit.fallback_existing_behavior_count == 1)
  assert_true(
    semantic_test_audit_count(
      audit.gate_rejection_distribution,
      "confidence_below_threshold",
    ) ==
    1,
  )
}

///|
test "pdf v2 cross page arbitration audit counts mismatched source refs" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let unrelated_left_ref = semantic_test_ref_for_page(0, 8)
  let unrelated_right_ref = semantic_test_ref_for_page(1, 9)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("break and resumes.", 1, right_ref)
  let fact = semantic_test_cross_page_fact(0.70, [
    unrelated_left_ref, unrelated_right_ref,
  ])
  let audit = pdf_v2_cross_page_arbitration_audit([left, right], [fact])

  assert_true(audit.product_candidate_fact_count == 1)
  assert_true(audit.rejected_mismatched_source_refs_count == 1)
  assert_true(audit.actual_join_decision_changed_count == 0)
  assert_true(audit.fallback_existing_behavior_count == 1)
  assert_true(
    semantic_test_audit_count(
      audit.gate_rejection_distribution,
      "mismatched_source_refs",
    ) ==
    1,
  )
}

///|
test "pdf v2 cross page arbitration audit counts heading blocker" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("Next Section", 1, right_ref)
  let fact = semantic_test_cross_page_fact(0.70, [left_ref, right_ref])
  let audit = pdf_v2_cross_page_arbitration_audit([left, right], [fact])

  assert_true(audit.product_candidate_fact_count == 1)
  assert_true(audit.rejected_next_heading_title_like_blocker_count == 1)
  assert_true(audit.actual_join_decision_changed_count == 0)
  assert_true(audit.fallback_existing_behavior_count == 1)
  assert_true(
    semantic_test_audit_count(
      audit.gate_rejection_distribution,
      "next_heading_title_like_blocker",
    ) ==
    1,
  )
}

///|
test "pdf v2 cross page arbitration audit counts missing pair and no fact fallback" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right = semantic_test_cross_page_block("break and resumes.", 1, right_ref)
  let mismatched_pair_fact = {
    ..semantic_test_cross_page_fact(0.70, [left_ref, right_ref]),
    next_block_ref: Some(3),
  }
  let missing_pair_audit = pdf_v2_cross_page_arbitration_audit([left, right], [
    mismatched_pair_fact,
  ])
  let no_fact = pdf_v2_apply_cross_page_boundary_arbitration([left, right], [])
  let no_fact_audit = pdf_v2_cross_page_arbitration_audit([left, right], [])

  assert_true(missing_pair_audit.product_candidate_fact_count == 1)
  assert_true(
    missing_pair_audit.rejected_no_matching_fragment_or_semantic_pair_count == 1,
  )
  assert_true(missing_pair_audit.actual_join_decision_changed_count == 0)
  assert_true(missing_pair_audit.fallback_existing_behavior_count == 1)
  assert_true(no_fact.length() == 2)
  assert_true(no_fact_audit.generated_fact_count == 0)
  assert_true(no_fact_audit.actual_join_decision_changed_count == 0)
  assert_true(no_fact_audit.fallback_existing_behavior_count == 1)
}

///|
test "pdf v2 text flow joins hardwrapped paragraph as continuation unit" {
  let fragments = [
    semantic_test_fragment(
      0, "This paragraph is hard wrapped\nacross two visual lines.", 2,
    ),
  ]
  let flow = pdf_v2_text_flow_from_fragments(fragments, semantic_test_options())

  assert_true(flow.length() == 1)
  assert_true(flow[0].normalized_text.contains("hard wrapped across"))
  assert_true(flow[0].line_count == 2)
  assert_true(flow[0].signals.continuation_candidate)
}

///|
test "pdf v2 text flow records list markers and page number guard signal" {
  let fragments = [
    semantic_test_fragment(0, "- item", 1),
    semantic_test_fragment(1, "12", 1),
  ]
  let flow = pdf_v2_text_flow_from_fragments(fragments, {
    ..semantic_test_options(),
    suppress_page_number_like_noise: false,
  })

  assert_true(flow.length() == 2)
  assert_true(flow[0].starts_with_marker)
  assert_true(
    flow[0].marker_kind == Some(PdfV2TextFlowMarkerKind::UnorderedListMarker),
  )
  assert_true(flow[1].signals.looks_like_page_number)
}

///|
test "pdf v2 heading rules promote short heading followed by body" {
  let blocks = semantic_test_blocks([
    "Document Conversion Pipeline", "This project aims to build a unified document conversion pipeline.",
  ])

  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].level == Some(1))
  assert_true(blocks[0].decision.rule_id.contains("heading."))
}

///|
test "pdf v2 heading rules promote document lead title before section" {
  let blocks = semantic_test_blocks([
    "Heading vs Short Sentence", "Introduction", "This matters for the document conversion pipeline.",
  ])

  assert_true(blocks.length() == 3)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].level == Some(1))
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[1].level == Some(2))
}

///|
test "pdf v2 heading rules keep short sentence page number list and caption safe" {
  let fragments = [
    semantic_test_fragment(0, "This is a short sentence.", 1),
    semantic_test_fragment(1, "1", 1),
    semantic_test_fragment(2, "- item", 1),
    semantic_test_fragment(3, "Figure 1. PDF caption", 1),
  ]
  let blocks = pdf_v2_semantic_blocks_from_fragments(fragments, {
    ..semantic_test_options(),
    suppress_page_number_like_noise: false,
  })

  assert_true(blocks.length() == 4)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(blocks[1].kind != PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[2].kind == PdfV2SemanticBlockKind::UnorderedListItem)
  assert_true(blocks[3].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 heading rules promote CJK short heading with body" {
  let blocks = semantic_test_blocks([
    "研究内容", "本项目围绕文档转换流程开展验证。",
  ])

  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].text == "研究内容")
}

///|
test "pdf v2 heading rules infer clear numbered subsection level" {
  let blocks = semantic_test_blocks([
    "1.1 研究目标", "本节说明研究目标和验证范围。",
  ])

  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].level == Some(2))
}

///|
test "pdf v2 list rules cover unordered and ordered marker families" {
  let blocks = semantic_test_blocks([
    "- dash item", "* star item", "• bullet item", "1. dot item", "1) paren item",
    "(1) parenthesized item", "（一）中文条目", "1.1 Section heading", "  - nested fallback",
  ])

  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::UnorderedListItem)
  assert_true(blocks[0].text == "dash item")
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::UnorderedListItem)
  assert_true(blocks[2].kind == PdfV2SemanticBlockKind::UnorderedListItem)
  assert_true(blocks[3].kind == PdfV2SemanticBlockKind::OrderedListItem)
  assert_true(blocks[4].kind == PdfV2SemanticBlockKind::OrderedListItem)
  assert_true(blocks[5].kind == PdfV2SemanticBlockKind::OrderedListItem)
  assert_true(blocks[6].kind == PdfV2SemanticBlockKind::OrderedListItem)
  assert_true(blocks[7].kind != PdfV2SemanticBlockKind::OrderedListItem)
  assert_true(blocks[8].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 list rules can be disabled" {
  let blocks = pdf_v2_semantic_blocks_from_fragments(
    [semantic_test_fragment(0, "- item", 1)],
    { ..semantic_test_options(), enable_list_rules: false },
  )

  assert_true(blocks.length() == 1)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 arbitration accepts rule and ignores absent model" {
  let decision = pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Heading,
    0.90,
    "heading.short_single_line_followed_by_body",
    ["test_rule"],
    [],
    [semantic_test_ref(0)],
    [],
  )
  let result = pdf_v2_arbitrate_semantic_decision({
    rule_decision: decision,
    model_hint: None,
    disagreement_policy: PdfV2SemanticDisagreementPolicy::RuleHardConstraintsFirst,
  })

  assert_true(result.decision.kind == PdfV2SemanticBlockKind::Heading)
  assert_true(!result.model_hint_present)
  assert_true(!result.model_hint_used)
  assert_true(result.reason_tags.contains("model_hint_absent"))
}

///|
test "pdf v2 arbitration hard negative overrides model hint" {
  let decision = pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Heading,
    0.95,
    "noise.page_number_guard",
    ["noise_guard"],
    ["hard_negative_rule"],
    [semantic_test_ref(0)],
    ["hard_negative_rule"],
  )
  let result = pdf_v2_arbitrate_semantic_decision({
    rule_decision: decision,
    model_hint: Some({
      model_kind: "future-test-model",
      predicted_kind: Some(PdfV2SemanticBlockKind::Heading),
      confidence: 0.99,
      evidence: ["synthetic_hint"],
    }),
    disagreement_policy: PdfV2SemanticDisagreementPolicy::RuleHardConstraintsFirst,
  })

  assert_true(result.model_hint_present)
  assert_true(!result.model_hint_used)
  assert_true(result.decision.kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(result.reason_tags.contains("hard_negative_rule_precedence"))
}

///|
test "pdf v2 arbitration weak rule falls back to paragraph" {
  let decision = pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Heading,
    0.20,
    "heading.weak_test",
    ["weak"],
    [],
    [semantic_test_ref(0)],
    [],
  )
  let result = pdf_v2_arbitrate_semantic_decision({
    rule_decision: decision,
    model_hint: None,
    disagreement_policy: PdfV2SemanticDisagreementPolicy::RuleHardConstraintsFirst,
  })

  assert_true(result.decision.kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(result.decision.rule_id.contains("weak_rule_fallback"))
}

///|
test "pdf v2 sample targeted heading basic like flow" {
  let blocks = semantic_test_blocks([
    "第一章项目概述", "本章介绍项目背景和总体目标。", "1.1 研究目标",
    "本节说明研究目标和产出。", "第二章技术路线", "本章描述技术路线。",
  ])

  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].text == "第一章 项目概述")
  assert_true(blocks[2].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[2].level == Some(2))
  assert_true(blocks[4].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[4].text == "第二章 技术路线")
}

///|
test "pdf v2 sample targeted heading versus short sentence like flow" {
  let blocks = semantic_test_blocks([
    "Heading vs Short Sentence", "Introduction", "This matters for the document conversion pipeline.",
    "Method", "This short section explains the approach.", "Key points:", "• First item",
  ])

  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[3].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[5].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(blocks[6].kind == PdfV2SemanticBlockKind::UnorderedListItem)
}

///|
test "pdf v2 heading rules do not blanket promote method-like labels" {
  let method_blocks = semantic_test_blocks([
    "Document Conversion Pipeline", "Method",
  ])
  let colon_blocks = semantic_test_blocks([
    "Document Conversion Pipeline", "This body sentence: remains inside paragraph",
  ])

  assert_true(method_blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(method_blocks[1].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(colon_blocks[1].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 heading rules promote section label before intro phrase as subsection" {
  let blocks = semantic_test_blocks([
    "Heading vs Short Sentence", "Introduction", "This matters.", "Figure 1. System overview.",
    "Method", "Key points:", "• First item",
  ])

  assert_true(blocks[4].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[4].level == Some(2))
  assert_true(blocks[5].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(blocks[6].kind == PdfV2SemanticBlockKind::UnorderedListItem)
}

///|
test "pdf v2 heading rules keep intro phrase and short body sentence safe" {
  let blocks = semantic_test_blocks([
    "Heading vs Short Sentence", "Introduction", "This matters.", "In conclusion,",
    "This final paragraph should remain a normal paragraph.",
  ])

  assert_true(blocks[3].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(blocks[4].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 heading rules keep inline CJK body marker as paragraph" {
  let blocks = semantic_test_blocks([
    "MarkItDown MoonBit MVP 测试（Simple）", "第一段：这是一个用于验证 PDF 文本抽取的样例。",
  ])

  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Paragraph)
}
