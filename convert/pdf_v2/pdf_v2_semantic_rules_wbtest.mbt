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
