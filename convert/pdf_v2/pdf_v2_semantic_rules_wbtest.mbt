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
fn semantic_test_ref_for_page_block_line(
  page_index : Int,
  block_index : Int,
  line_index : Int,
  order : Int,
) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(page_index),
    object_id: Some("block-\{block_index}-line-\{line_index}"),
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
fn semantic_test_block_candidate(
  page_index : Int,
  block_index : Int,
  text : String,
  lines : Array[String],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
) -> @pdfv2.PdfV2BlockCandidate {
  let line_candidates : Array[@pdfv2.PdfV2LineCandidate] = []
  for i in 0..<lines.length() {
    let line_text = lines[i]
    line_candidates.push({
      page_index: Some(page_index),
      line_index: i,
      text: line_text,
      spans: [],
      source_refs,
      decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
      geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Medium,
      warnings: [],
      reason_tags: ["semantic_test_line"],
      merge_reason_tags: [],
      break_reason_tags: [],
      text_signal: @pdfv2.pdf_v2_build_line_text_signal(
        line_text,
        @pdfv2.PdfV2TextDecodeConfidence::High,
        source_refs,
        reason_tags,
      ),
      bbox: Some(@pdfv2.pdf_v2_empty_bbox()),
      baseline: None,
      writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
      rotation: None,
    })
  }
  {
    page_index: Some(page_index),
    block_index,
    text,
    lines: line_candidates,
    source_refs,
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Medium,
    warnings: [],
    reason_tags,
    merge_reason_tags: [],
    break_reason_tags: [],
    boundary_signal: @pdfv2.pdf_v2_build_block_boundary_signal(
      line_candidates,
      reason_tags,
      Some(@pdfv2.pdf_v2_empty_bbox()),
    ),
    bbox: Some(@pdfv2.pdf_v2_empty_bbox()),
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
    block_kind_hint: @pdfv2.PdfV2BlockKindHint::TextLike,
  }
}

///|
fn semantic_test_text_flow_candidate(
  page_index : Int,
  block_index : Int,
  flow_index : Int,
  text : String,
  line_indices : Array[Int],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
) -> @pdfv2.PdfV2TextFlowCandidate {
  let lines = if line_indices.length() == 0 { [0] } else { line_indices }
  let line_signals : Array[@pdfv2.PdfV2LineTextSignal] = []
  for _ in lines {
    line_signals.push(
      @pdfv2.pdf_v2_build_line_text_signal(
        text,
        @pdfv2.PdfV2TextDecodeConfidence::High,
        source_refs,
        reason_tags,
      ),
    )
  }
  {
    page_index: Some(page_index),
    block_index: Some(block_index),
    flow_index,
    line_indices: lines,
    text,
    normalized_text: text,
    original_lines: [text],
    normalized_lines: [text],
    line_signals,
    boundary_signal: @pdfv2.pdf_v2_build_block_boundary_signal(
      [
        semantic_test_block_candidate(
          page_index,
          block_index,
          text,
          [text],
          source_refs,
          reason_tags,
        ).lines[0],
      ],
      reason_tags,
      Some(@pdfv2.pdf_v2_empty_bbox()),
    ),
    artifact_refs: [],
    source_refs,
    reason_tags,
  }
}

///|
fn semantic_test_text_flow_candidate_with_parser_signals(
  page_index : Int,
  block_index : Int,
  flow_index : Int,
  lines : Array[String],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
) -> @pdfv2.PdfV2TextFlowCandidate {
  let text = lines.join("\n")
  let block = semantic_test_block_candidate(
    page_index, block_index, text, lines, source_refs, reason_tags,
  )
  let line_indices : Array[Int] = []
  let original_lines : Array[String] = []
  let normalized_lines : Array[String] = []
  let line_signals : Array[@pdfv2.PdfV2LineTextSignal] = []
  for i in 0..<block.lines.length() {
    line_indices.push(i)
    original_lines.push(block.lines[i].text)
    normalized_lines.push(block.lines[i].text_signal.normalized_text)
    line_signals.push(block.lines[i].text_signal)
  }
  {
    page_index: Some(page_index),
    block_index: Some(block_index),
    flow_index,
    line_indices,
    text,
    normalized_text: normalized_lines.join("\n"),
    original_lines,
    normalized_lines,
    line_signals,
    boundary_signal: block.boundary_signal,
    artifact_refs: [],
    source_refs,
    reason_tags,
  }
}

///|
fn semantic_test_heading_fact(
  page_index : Int,
  block_ref : Int,
  line_refs : Array[Int],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  confidence : Double,
  reason_tags : Array[String],
) -> @pdfv2.PdfV2HeadingBoundaryFact {
  {
    page_index: Some(page_index),
    block_ref: Some(block_ref),
    line_refs,
    short_text_risk: reason_tags.contains("short_text_risk"),
    sentence_like_risk: reason_tags.contains("sentence_like_risk"),
    font_layout_evidence: "synthetic",
    numbering_evidence: reason_tags.contains("numbering_evidence"),
    body_continuation_evidence: reason_tags.contains(
      "body_continuation_evidence",
    ),
    confidence,
    reason_tags,
    source_refs,
  }
}

///|
fn semantic_test_signal_trace_report(
  source_name : String,
  page_count : Int,
  parser_blocks : Array[@pdfv2.PdfV2BlockCandidate],
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact],
  fragments : Array[PdfV2FactFragment],
) -> PdfV2TargetSignalTraceReport {
  pdf_v2_target_signal_trace_report({
    source_name,
    page_count,
    parser_blocks,
    candidates,
    cross_page_facts,
    heading_facts,
    fragments,
    bridge_options: semantic_test_options(),
    selection_override: None,
  })
}

///|
fn semantic_test_signal_trace_report_with_override(
  source_name : String,
  page_count : Int,
  parser_blocks : Array[@pdfv2.PdfV2BlockCandidate],
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact],
  fragments : Array[PdfV2FactFragment],
  path : PdfV2SignalTraceSelectionPath,
  candidate_semantic_mode : Bool,
  selected_blocks : Array[PdfV2SemanticBlock],
) -> PdfV2TargetSignalTraceReport {
  pdf_v2_target_signal_trace_report({
    source_name,
    page_count,
    parser_blocks,
    candidates,
    cross_page_facts,
    heading_facts,
    fragments,
    bridge_options: semantic_test_options(),
    selection_override: Some((path, candidate_semantic_mode, selected_blocks)),
  })
}

///|
fn semantic_test_trace_boundary(
  report : PdfV2TargetSignalTraceReport,
  page_from : Int,
  page_to : Int,
) -> PdfV2SignalTraceBoundary raise {
  for boundary in report.boundaries {
    if boundary.page_from == page_from && boundary.page_to == page_to {
      return boundary
    }
  }
  fail(
    "expected trace boundary " +
    page_from.to_string() +
    "->" +
    page_to.to_string(),
  )
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
test "pdf v2 cross page fragment audit exposes semantically equivalent source ref mismatch" {
  let left_fragment_ref = semantic_test_ref_for_page_block_line(0, 0, 0, 10)
  let right_fragment_ref = semantic_test_ref_for_page_block_line(1, 0, 0, 20)
  let left_fact_line_ref = {
    ..left_fragment_ref,
    op_index: Some(11),
    content_order_index: Some(11),
  }
  let right_fact_line_ref = {
    ..right_fragment_ref,
    op_index: Some(21),
    content_order_index: Some(21),
  }
  let left = {
    ..semantic_test_fragment_for_page(
      0, 0, "This paragraph continues across the page",
    ),
    source_refs: [left_fragment_ref],
    reason_tags: ["semantic_test_fragment", "source_ref_equivalent_block_line"],
  }
  let right = {
    ..semantic_test_fragment_for_page(
      1, 0, "break and should still become one paragraph.",
    ),
    source_refs: [right_fragment_ref],
    reason_tags: ["semantic_test_fragment", "source_ref_equivalent_block_line"],
  }
  let fact = semantic_test_cross_page_fact(0.70, [
    left_fact_line_ref, right_fact_line_ref,
  ])
  let audit = pdf_v2_cross_page_fragment_arbitration_audit(
    [left, right],
    semantic_test_options(),
    [fact],
  )
  let with_facts = pdf_v2_semantic_blocks_from_fragments_with_cross_page_facts(
    [left, right],
    semantic_test_options(),
    [fact],
  )

  assert_true(fact.prev_block_ref == left.block_index)
  assert_true(fact.next_block_ref == right.block_index)
  assert_true(fact.prev_line_refs == [0])
  assert_true(fact.next_line_refs == [0])
  assert_true(fact.source_refs.length() == 2)
  assert_true(left.source_refs[0].page_index == fact.source_refs[0].page_index)
  assert_true(right.source_refs[0].page_index == fact.source_refs[1].page_index)
  assert_true(left.source_refs[0].object_id == fact.source_refs[0].object_id)
  assert_true(right.source_refs[0].object_id == fact.source_refs[1].object_id)
  assert_true(left.source_refs[0].op_index != fact.source_refs[0].op_index)
  assert_true(right.source_refs[0].op_index != fact.source_refs[1].op_index)
  assert_true(audit.generated_fact_count == 1)
  assert_true(audit.product_candidate_fact_count == 1)
  assert_true(audit.facts_passing_confidence_gate == 1)
  assert_true(audit.facts_passing_source_ref_gate == 1)
  assert_true(audit.facts_passing_prev_open_ended_gate == 1)
  assert_true(audit.facts_passing_next_marker_gate == 1)
  assert_true(audit.facts_passing_ambiguity_tag_gate == 1)
  assert_true(audit.rejected_mismatched_source_refs_count == 1)
  assert_true(audit.rejected_no_matching_fragment_or_semantic_pair_count == 0)
  assert_true(audit.rejected_next_heading_title_like_blocker_count == 0)
  assert_true(audit.actual_join_decision_changed_count == 0)
  assert_true(audit.fallback_existing_behavior_count == 1)
  assert_true(
    semantic_test_audit_count(
      audit.gate_rejection_distribution,
      "mismatched_source_refs",
    ) ==
    1,
  )
  assert_true(with_facts.length() == 2)
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
test "pdf v2 structural handoff does not activate for heading like next page without parser backed structure" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let left = semantic_test_cross_page_block(
    "The paragraph continues across the page", 0, left_ref,
  )
  let right_heading = {
    ..semantic_test_cross_page_block("Running Footer", 1, right_ref),
    kind: PdfV2SemanticBlockKind::Heading,
    level: Some(1),
    decision: {
      ..pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Heading,
        0.88,
        "heading.short_single_line_followed_by_body.parser_fact",
        ["short_single_line", "parser_fact", "boundary_heading_score"],
        [],
        [right_ref],
        [],
      )
    },
    reason_tags: ["semantic_test_block", "short_single_line", "parser_fact"],
  }
  let fact = semantic_test_cross_page_fact(0.50, [left_ref, right_ref])
  let handoffs = pdf_v2_build_cross_page_structural_handoffs(
    [left, right_heading],
    [fact],
  )

  assert_true(handoffs.length() == 1)
  assert_true(!handoffs[0].should_join_paragraph)
  assert_true(!handoffs[0].should_preserve_heading_level)
  assert_true(!pdf_v2_has_cross_page_structural_handoff_candidate(handoffs))
}

///|
test "pdf v2 target signal trace reports parser evidence present but semantic boundary missing" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let title_ref = semantic_test_ref_for_page(1, 10)
  let body_ref = semantic_test_ref_for_page(1, 11)
  let parser_blocks = [
    semantic_test_block_candidate(
      0,
      0,
      "The paragraph continues across the page",
      ["The paragraph continues across the page"],
      [left_ref],
      ["semantic_test_parser_block"],
    ),
    semantic_test_block_candidate(
      1,
      0,
      "Cross-page should merge",
      ["Cross-page should merge"],
      [title_ref],
      ["heading_body_split", "heading_line_candidate"],
    ),
    semantic_test_block_candidate(
      1,
      1,
      "This paragraph should stay as body text.",
      ["This paragraph should stay as body text."],
      [body_ref],
      ["heading_body_split", "body_flow_candidate"],
    ),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "The paragraph continues across the page",
      [0],
      [left_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      0,
      1,
      "Cross-page should merge",
      [0],
      [title_ref],
      ["text_flow_candidate", "heading_body_split", "heading_line_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      1,
      2,
      "This paragraph should stay as body text.",
      [1],
      [body_ref],
      ["text_flow_candidate", "heading_body_split", "body_flow_candidate"],
    ),
  ]
  let fragments = [
    semantic_test_fragment_for_page(
      0, 0, "The paragraph continues across the page",
    ),
    semantic_test_fragment_for_page(1, 0, "Cross-page should merge"),
    semantic_test_fragment_for_page(
      1, 1, "This paragraph should stay as body text.",
    ),
  ]
  let fact = semantic_test_cross_page_fact(0.72, [left_ref, title_ref])
  let report = semantic_test_signal_trace_report(
    "semantic_loss",
    2,
    parser_blocks,
    candidates,
    [fact],
    [],
    fragments,
  )
  let boundary = semantic_test_trace_boundary(report, 0, 1)

  assert_true(boundary.cross_page_fact is Some(_))
  assert_true(boundary.candidate_prev is Some(_))
  assert_true(boundary.candidate_next is Some(_))
  assert_true(boundary.baseline_candidate_pair is Some(_))
  assert_true(
    boundary.loss_layer == PdfV2SignalTraceLossLayer::SemanticCandidateBlockLoss,
  )
  assert_true(
    boundary.reason_tags.contains(
      "title_body_boundary_merged_before_semantic_boundary",
    ),
  )
}

///|
test "pdf v2 target signal trace reports structural handoff present but bridge path not used" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let parser_blocks = [
    semantic_test_block_candidate(
      0,
      0,
      "This section ends cleanly here.",
      ["This section ends cleanly here."],
      [left_ref],
      ["semantic_test_parser_block"],
    ),
    semantic_test_block_candidate(
      1,
      0,
      "## page 2 new section",
      ["## page 2 new section"],
      [right_ref],
      ["semantic_test_parser_block", "inline_list_split"],
    ),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "This section ends cleanly here.",
      [0],
      [left_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      0,
      1,
      "## page 2 new section",
      [0],
      [right_ref],
      ["text_flow_candidate", "inline_list_split"],
    ),
  ]
  let fragments = [
    semantic_test_fragment_for_page(0, 0, "This section ends cleanly here."),
    semantic_test_fragment_for_page(1, 0, "## page 2 new section"),
  ]
  let fact = semantic_test_cross_page_fact(0.72, [left_ref, right_ref])
  let selected_blocks = pdf_v2_semantic_blocks_from_fragments_with_cross_page_facts(
    fragments,
    { ..semantic_test_options(), suppress_page_number_like_noise: false },
    [],
  )
  let report = semantic_test_signal_trace_report_with_override(
    "bridge_loss",
    2,
    parser_blocks,
    candidates,
    [fact],
    [],
    fragments,
    PdfV2SignalTraceSelectionPath::FragmentCrossPageArbitration,
    false,
    selected_blocks,
  )
  let boundary = semantic_test_trace_boundary(report, 0, 1)

  assert_true(boundary.structural_handoff is Some(_))
  assert_true(boundary.selected_pair is Some(_))
  assert_true(
    boundary.loss_layer == PdfV2SignalTraceLossLayer::BridgeLoweringPathLoss,
  )
  assert_true(
    boundary.reason_tags.contains(
      "candidate_structural_handoff_path_not_selected",
    ),
  )
}

///|
test "pdf v2 target signal trace reports parser candidate fact loss for missing source refs" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let parser_blocks = [
    semantic_test_block_candidate(
      0,
      0,
      "The paragraph continues across the page",
      ["The paragraph continues across the page"],
      [left_ref],
      ["semantic_test_parser_block"],
    ),
    semantic_test_block_candidate(
      1,
      0,
      "break and resumes.",
      ["break and resumes."],
      [right_ref],
      ["semantic_test_parser_block"],
    ),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "The paragraph continues across the page",
      [0],
      [left_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      0,
      1,
      "break and resumes.",
      [0],
      [right_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
  ]
  let fragments = [
    semantic_test_fragment_for_page(
      0, 0, "The paragraph continues across the page",
    ),
    semantic_test_fragment_for_page(1, 0, "break and resumes."),
  ]
  let fact = semantic_test_cross_page_fact(0.72, [])
  let report = semantic_test_signal_trace_report(
    "missing_refs",
    2,
    parser_blocks,
    candidates,
    [fact],
    [],
    fragments,
  )
  let boundary = semantic_test_trace_boundary(report, 0, 1)

  assert_true(boundary.cross_page_fact is Some(_))
  assert_true(
    boundary.loss_layer == PdfV2SignalTraceLossLayer::ParserCandidateFactLoss,
  )
  assert_true(boundary.reason_tags.contains("missing_source_refs"))
}

///|
test "pdf v2 target signal trace reports next page list structure preserved through lowering" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let right_ref = semantic_test_ref_for_page(1, 1)
  let parser_blocks = [
    semantic_test_block_candidate(
      0,
      0,
      "This section ends cleanly here.",
      ["This section ends cleanly here."],
      [left_ref],
      ["semantic_test_parser_block"],
    ),
    semantic_test_block_candidate(
      1,
      0,
      "1. New section starts here and must remain separated.",
      ["1. New section starts here and must remain separated."],
      [right_ref],
      ["semantic_test_parser_block", "inline_list_split"],
    ),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "This section ends cleanly here.",
      [0],
      [left_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      0,
      1,
      "1. New section starts here and must remain separated.",
      [0],
      [right_ref],
      ["text_flow_candidate", "inline_list_split"],
    ),
  ]
  let fragments = [
    semantic_test_fragment_for_page(0, 0, "This section ends cleanly here."),
    semantic_test_fragment_for_page(
      1, 0, "1. New section starts here and must remain separated.",
    ),
  ]
  let fact = semantic_test_cross_page_fact(0.72, [left_ref, right_ref])
  let report = semantic_test_signal_trace_report(
    "structure_loss",
    2,
    parser_blocks,
    candidates,
    [fact],
    [],
    fragments,
  )
  let boundary = semantic_test_trace_boundary(report, 0, 1)

  assert_true(boundary.next_list_marker_evidence)
  assert_true(boundary.baseline_candidate_pair is Some(_))
  assert_true(boundary.selected_pair is Some(_))
  assert_true(boundary.loss_layer == PdfV2SignalTraceLossLayer::NoLossDetected)
}

///|
test "pdf v2 target signal trace selects candidate path for preserved title body structure" {
  let left_ref = semantic_test_ref_for_page(0, 0)
  let title_ref = semantic_test_ref_for_page(1, 10)
  let body_ref = semantic_test_ref_for_page(1, 11)
  let parser_blocks = [
    semantic_test_block_candidate(
      0,
      0,
      "The paragraph continues across the page",
      ["The paragraph continues across the page"],
      [left_ref],
      ["semantic_test_parser_block"],
    ),
    semantic_test_block_candidate(
      1,
      0,
      "Cross-page should merge",
      ["Cross-page should merge"],
      [title_ref],
      [
        "semantic_test_parser_block", "heading_body_split", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
    semantic_test_block_candidate(
      1,
      1,
      "This paragraph should stay as body text.",
      ["This paragraph should stay as body text."],
      [body_ref],
      [
        "semantic_test_parser_block", "heading_body_split", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "The paragraph continues across the page",
      [0],
      [left_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      1,
      0,
      1,
      "Cross-page should merge",
      [0],
      [title_ref],
      [
        "text_flow_candidate", "heading_body_split", "heading_line_candidate", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
    semantic_test_text_flow_candidate(
      1,
      1,
      2,
      "This paragraph should stay as body text.",
      [1],
      [body_ref],
      [
        "text_flow_candidate", "heading_body_split", "body_flow_candidate", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
  ]
  let fragments = [
    semantic_test_fragment_for_page(
      0, 0, "The paragraph continues across the page",
    ),
    semantic_test_fragment_for_page(1, 0, "Cross-page should merge"),
    semantic_test_fragment_for_page(
      1, 1, "This paragraph should stay as body text.",
    ),
  ]
  let fact = semantic_test_cross_page_fact(0.72, [left_ref, title_ref])
  let report = semantic_test_signal_trace_report(
    "preserved_title_body",
    2,
    parser_blocks,
    candidates,
    [fact],
    [],
    fragments,
  )

  assert_true(report.selection.candidate_semantic_mode)
  assert_true(
    report.selection.path ==
    PdfV2SignalTraceSelectionPath::CandidateStructuralHandoff ||
    report.selection.path ==
    PdfV2SignalTraceSelectionPath::CandidateCrossPageArbitration ||
    report.selection.path ==
    PdfV2SignalTraceSelectionPath::CandidateSemanticActionableTextFlow,
  )
}

///|
test "pdf v2 target signal trace reports heading candidate acceptance and reason tags" {
  let heading_ref = semantic_test_ref_for_page(1, 1)
  let heading_candidate = semantic_test_text_flow_candidate(
    1,
    0,
    0,
    "Introduction",
    [0],
    [heading_ref],
    ["text_flow_candidate", "heading_line_candidate"],
  )
  let heading_fact = semantic_test_heading_fact(
    1,
    0,
    [0],
    [heading_ref],
    0.78,
    [
      "heading_boundary_fact", "parser_layout_backed", "short_text_risk", "body_continuation_evidence",
    ],
  )
  let parser_blocks = [
    semantic_test_block_candidate(
      1,
      0,
      "Introduction",
      ["Introduction"],
      [heading_ref],
      ["semantic_test_parser_block"],
    ),
  ]
  let fragments = [semantic_test_fragment_for_page(1, 0, "Introduction")]
  let report = semantic_test_signal_trace_report(
    "heading_trace",
    2,
    parser_blocks,
    [heading_candidate],
    [],
    [heading_fact],
    fragments,
  )

  assert_true(report.heading_traces.length() == 1)
  let heading = report.heading_traces[0]
  assert_true(heading.reason_tags.contains("short_text_risk"))
  assert_true(heading.reason_tags.contains("body_continuation_evidence"))
  assert_true(heading.semantic_preview is Some(_))
  assert_true(heading.accepted_as_heading)
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
test "pdf v2 semantic arbitration promotes parser-backed title body candidate to heading" {
  let title_ref = semantic_test_ref_for_page(1, 10)
  let body_ref = semantic_test_ref_for_page(1, 11)
  let candidates = [
    semantic_test_text_flow_candidate_with_parser_signals(
      1,
      0,
      0,
      ["merge strategy"],
      [title_ref],
      [
        "text_flow_candidate", "heading_body_split", "heading_line_candidate", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
    semantic_test_text_flow_candidate_with_parser_signals(
      1,
      1,
      1,
      ["This paragraph should stay as body text."],
      [body_ref],
      [
        "text_flow_candidate", "heading_body_split", "body_flow_candidate", "structure_boundary_candidate",
        "title_body_boundary_candidate",
      ],
    ),
  ]

  let blocks = pdf_v2_semantic_blocks_from_candidates(
    candidates,
    semantic_test_options(),
  )

  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[0].level == Some(1))
  assert_true(blocks[0].reason_tags.contains("parser_structure_evidence"))
  assert_true(blocks[0].reason_tags.contains("title_body_boundary_candidate"))
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Paragraph)
}

///|
test "pdf v2 semantic arbitration promotes parser-backed heading fact without title body split" {
  let lead_ref = semantic_test_ref_for_page(0, 29)
  let heading_ref = semantic_test_ref_for_page(0, 30)
  let candidates = [
    semantic_test_text_flow_candidate_with_parser_signals(
      0,
      0,
      0,
      ["Body paragraph opens here."],
      [lead_ref],
      ["text_flow_candidate"],
    ),
    semantic_test_text_flow_candidate_with_parser_signals(
      0,
      1,
      1,
      ["New Section"],
      [heading_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
  ]

  let blocks = pdf_v2_semantic_blocks_from_candidates(
    candidates,
    semantic_test_options(),
  )

  assert_true(blocks.length() == 2)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Paragraph)
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[1].level == Some(1))
  assert_true(blocks[1].reason_tags.contains("heading_title_evidence"))
  assert_true(blocks[1].reason_tags.contains("stable_parser_heading_candidate"))
}

///|
test "pdf v2 semantic arbitration promotes parser-backed section phrase before list as subsection" {
  let heading_ref = semantic_test_ref_for_page(1, 40)
  let list_ref = semantic_test_ref_for_page(1, 41)
  let candidates = [
    semantic_test_text_flow_candidate_with_parser_signals(
      0,
      0,
      0,
      ["Introduction"],
      [semantic_test_ref_for_page(0, 39)],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate_with_parser_signals(
      1,
      0,
      1,
      ["Next section"],
      [heading_ref],
      [
        "text_flow_candidate", "structure_boundary_candidate", "parser_layout_backed",
      ],
    ),
    semantic_test_text_flow_candidate_with_parser_signals(
      1,
      1,
      2,
      ["1. First item must remain separated."],
      [list_ref],
      [
        "text_flow_candidate", "structure_boundary_candidate", "parser_layout_backed",
        "list_marker_body_boundary_candidate",
      ],
    ),
  ]

  let blocks = pdf_v2_semantic_blocks_from_candidates(
    candidates,
    semantic_test_options(),
  )

  assert_true(blocks.length() == 3)
  assert_true(blocks[1].kind == PdfV2SemanticBlockKind::Heading)
  assert_true(blocks[1].level == Some(2))
  assert_true(
    blocks[1].reason_tags.contains("stable_list_section_heading_candidate"),
  )
  assert_true(blocks[2].kind == PdfV2SemanticBlockKind::OrderedListItem)
}

///|
test "pdf v2 semantic arbitration preserves multiline parser-backed list item body" {
  let list_refs = [
    semantic_test_ref_for_page_block_line(1, 2, 0, 200),
    semantic_test_ref_for_page_block_line(1, 2, 1, 201),
  ]
  let candidates = [
    semantic_test_text_flow_candidate(
      1,
      2,
      0,
      "1. New section starts here and must remain separated. This block should not\nbe attached to previous page paragraph.",
      [0, 1],
      list_refs,
      [
        "text_flow_candidate", "structure_boundary_candidate", "parser_layout_backed",
        "list_marker_body_boundary_candidate",
      ],
    ),
  ]

  let blocks = pdf_v2_semantic_blocks_from_candidates(
    candidates,
    semantic_test_options(),
  )

  assert_true(blocks.length() == 1)
  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::OrderedListItem)
  assert_eq(
    blocks[0].text,
    "New section starts here and must remain separated. This block should not be attached to previous page paragraph.",
  )
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
test "pdf v2 heading rules keep strong parser-backed intro phrase safe" {
  let heading_ref = semantic_test_ref_for_page(0, 50)
  let body_ref = semantic_test_ref_for_page(0, 51)
  let candidates = [
    semantic_test_text_flow_candidate(
      0,
      0,
      0,
      "In conclusion,",
      [0],
      [heading_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
    semantic_test_text_flow_candidate(
      0,
      1,
      1,
      "This final paragraph should remain a normal paragraph.",
      [1],
      [body_ref],
      ["text_flow_candidate", "block_flow_candidate"],
    ),
  ]

  let blocks = pdf_v2_semantic_blocks_from_candidates(
    candidates,
    semantic_test_options(),
  )

  assert_true(blocks[0].kind == PdfV2SemanticBlockKind::Paragraph)
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
