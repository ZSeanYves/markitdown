///|
fn pdf_v2_semantic_blocks_from_fragments(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  let flow = pdf_v2_text_flow_from_fragments(fragments, options)
  pdf_v2_semantic_blocks_from_flow(flow, options)
}

///|
fn pdf_v2_semantic_blocks_from_fragments_with_cross_page_facts(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> Array[PdfV2SemanticBlock] {
  let flow = pdf_v2_text_flow_from_fragments_with_cross_page_facts(
    fragments, options, cross_page_facts,
  )
  pdf_v2_semantic_blocks_from_flow(flow, options)
}

///|
fn pdf_v2_semantic_blocks_from_candidates(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  let flow = pdf_v2_text_flow_from_candidates(candidates, options)
  pdf_v2_semantic_blocks_from_flow(flow, options)
}

///|
fn pdf_v2_semantic_blocks_from_candidates_with_cross_page_facts(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  options : PdfV2ProductBridgeOptions,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> Array[PdfV2SemanticBlock] {
  let blocks = pdf_v2_semantic_blocks_from_candidates(candidates, options)
  let handoffs = pdf_v2_build_cross_page_structural_handoffs(
    blocks, cross_page_facts,
  )
  if pdf_v2_has_cross_page_structural_handoff_candidate(handoffs) {
    pdf_v2_apply_cross_page_structural_handoffs(blocks, handoffs)
  } else {
    pdf_v2_apply_cross_page_boundary_arbitration(blocks, cross_page_facts)
  }
}

///|
fn pdf_v2_semantic_blocks_from_flow(
  flow : Array[PdfV2TextFlowUnit],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  let blocks : Array[PdfV2SemanticBlock] = []
  let mut i = 0
  while i < flow.length() {
    let sequence_length = pdf_v2_semantic_page_label_sequence_length(
      flow, i, options,
    )
    if sequence_length > 0 {
      for offset in 0..<sequence_length {
        let unit = flow[i + offset]
        let decision = pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::Unknown,
          1.0,
          "noise.page_label_sequence_guard",
          ["noise_guard", "page_label_sequence"],
          ["not_heading", "not_list"],
          unit.source_refs,
          ["hard_negative_rule", "noise_guard", "suppress_output"],
        )
        blocks.push(pdf_v2_semantic_block_from_decision(unit, decision))
      }
      i = i + sequence_length
      continue
    }
    let unit = flow[i]
    let rule_decision = pdf_v2_semantic_rule_decision(unit, options)
    let arbitration = pdf_v2_arbitrate_semantic_decision({
      rule_decision,
      model_hint: None,
      disagreement_policy: PdfV2SemanticDisagreementPolicy::RuleHardConstraintsFirst,
    })
    blocks.push(pdf_v2_semantic_block_from_decision(unit, arbitration.decision))
    i = i + 1
  }
  blocks
}

///|
fn pdf_v2_apply_cross_page_boundary_arbitration(
  blocks : Array[PdfV2SemanticBlock],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> Array[PdfV2SemanticBlock] {
  if cross_page_facts.length() == 0 {
    return blocks
  }
  let out : Array[PdfV2SemanticBlock] = []
  let mut i = 0
  while i < blocks.length() {
    if i + 1 < blocks.length() {
      let left = blocks[i]
      let right = blocks[i + 1]
      match pdf_v2_cross_page_arbitration_fact(left, right, cross_page_facts) {
        Some(fact) => {
          out.push(pdf_v2_merge_cross_page_semantic_blocks(left, right, fact))
          i = i + 2
          continue
        }
        None => ()
      }
    }
    out.push(blocks[i])
    i = i + 1
  }
  out
}

///|
fn pdf_v2_structural_handoff_blocks_from_candidates(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  options : PdfV2ProductBridgeOptions,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> Array[PdfV2SemanticBlock]? {
  if candidates.length() == 0 || cross_page_facts.length() == 0 {
    return None
  }
  let blocks = pdf_v2_semantic_blocks_from_candidates_with_cross_page_facts(
    candidates, options, cross_page_facts,
  )
  let handoffs = pdf_v2_build_cross_page_structural_handoffs(
    pdf_v2_semantic_blocks_from_candidates(candidates, options),
    cross_page_facts,
  )
  if pdf_v2_has_cross_page_structural_handoff_candidate(handoffs) {
    Some(blocks)
  } else {
    None
  }
}

///|
fn pdf_v2_build_cross_page_structural_handoffs(
  blocks : Array[PdfV2SemanticBlock],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> Array[PdfV2CrossPageStructuralHandoff] {
  let out : Array[PdfV2CrossPageStructuralHandoff] = []
  let mut i = 0
  while i + 1 < blocks.length() {
    let left = blocks[i]
    let right = blocks[i + 1]
    match (left.page_index, right.page_index) {
      (Some(page_from), Some(page_to)) if page_to > page_from => {
        let matched_fact = pdf_v2_cross_page_boundary_fact_for_blocks(
          left, right, cross_page_facts,
        )
        let matched_fact_qualifies = match matched_fact {
          Some(fact) => pdf_v2_cross_page_fact_qualifies(fact)
          None => false
        }
        let next_list_marker_evidence = pdf_v2_semantic_kind_is_list(right.kind)
        let repeated_artifact_boundary = pdf_v2_cross_page_handoff_has_repeated_artifact_boundary(
          left, right, matched_fact,
        )
        let next_starts_structural_block = right.kind ==
          PdfV2SemanticBlockKind::Heading ||
          next_list_marker_evidence
        let following_page_structure_evidence = matched_fact_qualifies &&
          pdf_v2_cross_page_handoff_has_following_page_structure(blocks, i)
        let title_body_boundary_evidence = pdf_v2_cross_page_handoff_has_title_body_boundary_evidence(
          blocks, i,
        )
        let should_join_paragraph = pdf_v2_cross_page_semantic_pair_can_join(
            left, right,
          ) &&
          matched_fact_qualifies
        let next_heading_level = pdf_v2_cross_page_preserved_heading_level(
          blocks, i, right,
        )
        let should_preserve_heading_level = right.kind ==
          PdfV2SemanticBlockKind::Heading &&
          matched_fact_qualifies &&
          next_heading_level != right.level
        let should_preserve_list_marker = next_list_marker_evidence
        let should_preserve_next_structure = should_preserve_list_marker ||
          title_body_boundary_evidence ||
          (
            right.kind == PdfV2SemanticBlockKind::Heading &&
            matched_fact_qualifies
          ) ||
          following_page_structure_evidence
        let blockers : Array[String] = []
        if repeated_artifact_boundary {
          blockers.push("repeated_artifact_boundary")
        }
        if next_starts_structural_block {
          blockers.push("next_structural_block")
        }
        if title_body_boundary_evidence {
          blockers.push("title_body_boundary_evidence")
        }
        if !pdf_v2_ends_sentence(left.text.trim().to_owned()) {
          blockers.push("previous_open_ended")
        } else {
          blockers.push("previous_sentence_ended")
        }
        if matched_fact is None &&
          pdf_v2_cross_page_semantic_pair_can_join(left, right) {
          blockers.push("no_matching_boundary_fact")
        }
        let reason_tags : Array[String] = ["cross_page_structural_handoff"]
        if matched_fact is Some(_) {
          reason_tags.push("cross_page_boundary_fact_backed")
        }
        if should_join_paragraph {
          reason_tags.push("join_paragraph_continuation")
        }
        if should_preserve_next_structure {
          reason_tags.push("preserve_next_structure")
        }
        if should_preserve_heading_level {
          reason_tags.push("preserve_heading_level")
        }
        if should_preserve_list_marker {
          reason_tags.push("preserve_list_marker")
        }
        if title_body_boundary_evidence {
          reason_tags.push("title_body_boundary")
        }
        if following_page_structure_evidence {
          reason_tags.push("following_page_structure")
        }
        if repeated_artifact_boundary {
          reason_tags.push("repeated_artifact_boundary")
        }
        out.push({
          boundary_index: i,
          page_from,
          page_to,
          prev_refs: left.source_refs,
          next_refs: right.source_refs,
          prev_block_kind: left.kind,
          next_block_kind: right.kind,
          prev_heading_level: left.level,
          next_heading_level,
          next_list_marker_evidence,
          prev_open_ended: !pdf_v2_ends_sentence(left.text.trim().to_owned()),
          next_starts_structural_block,
          title_body_boundary_evidence,
          should_join_paragraph,
          should_preserve_next_structure,
          should_preserve_heading_level,
          should_preserve_list_marker,
          confidence: pdf_v2_cross_page_structural_handoff_confidence(
            matched_fact, should_preserve_next_structure, should_preserve_heading_level,
            should_preserve_list_marker, title_body_boundary_evidence,
          ),
          reason_tags,
          blockers,
          matched_fact,
        })
      }
      _ => ()
    }
    i = i + 1
  }
  out
}

///|
fn pdf_v2_has_cross_page_structural_handoff_candidate(
  handoffs : Array[PdfV2CrossPageStructuralHandoff],
) -> Bool {
  for handoff in handoffs {
    if pdf_v2_cross_page_structural_handoff_requires_candidate_semantics(
        handoff,
      ) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_cross_page_structural_handoff_requires_candidate_semantics(
  handoff : PdfV2CrossPageStructuralHandoff,
) -> Bool {
  if handoff.blockers.contains("repeated_artifact_boundary") {
    return false
  }
  handoff.should_preserve_next_structure ||
  handoff.should_preserve_heading_level ||
  handoff.should_preserve_list_marker
}

///|
fn pdf_v2_apply_cross_page_structural_handoffs(
  blocks : Array[PdfV2SemanticBlock],
  handoffs : Array[PdfV2CrossPageStructuralHandoff],
) -> Array[PdfV2SemanticBlock] {
  let adjusted : Array[PdfV2SemanticBlock] = []
  adjusted.append(blocks)
  for handoff in handoffs {
    if handoff.should_preserve_heading_level &&
      handoff.boundary_index + 1 < adjusted.length() {
      adjusted[handoff.boundary_index + 1] = pdf_v2_apply_cross_page_preserved_heading_level(
        adjusted[handoff.boundary_index + 1],
        handoff,
      )
    }
  }
  let out : Array[PdfV2SemanticBlock] = []
  let mut i = 0
  while i < adjusted.length() {
    if i + 1 < adjusted.length() {
      match pdf_v2_cross_page_structural_handoff_at(handoffs, i) {
        Some(handoff) =>
          match handoff.matched_fact {
            Some(fact) =>
              if handoff.should_join_paragraph {
                out.push(
                  pdf_v2_merge_cross_page_semantic_blocks_with_handoff(
                    adjusted[i],
                    adjusted[i + 1],
                    fact,
                    handoff,
                  ),
                )
                i = i + 2
                continue
              }
            None => ()
          }
        None => ()
      }
    }
    out.push(adjusted[i])
    i = i + 1
  }
  out
}

///|
fn pdf_v2_cross_page_structural_handoff_at(
  handoffs : Array[PdfV2CrossPageStructuralHandoff],
  boundary_index : Int,
) -> PdfV2CrossPageStructuralHandoff? {
  for handoff in handoffs {
    if handoff.boundary_index == boundary_index {
      return Some(handoff)
    }
  }
  None
}

///|
fn pdf_v2_cross_page_handoff_has_title_body_boundary_evidence(
  blocks : Array[PdfV2SemanticBlock],
  boundary_index : Int,
) -> Bool {
  let left = blocks[boundary_index]
  let right = blocks[boundary_index + 1]
  if pdf_v2_cross_page_block_has_title_body_reason(left) ||
    pdf_v2_cross_page_block_has_title_body_reason(right) {
    return true
  }
  if boundary_index > 0 {
    let previous = blocks[boundary_index - 1]
    if previous.page_index == left.page_index &&
      pdf_v2_cross_page_block_has_title_body_reason(previous) {
      return true
    }
  }
  if boundary_index + 2 < blocks.length() {
    let following = blocks[boundary_index + 2]
    if following.page_index == right.page_index &&
      pdf_v2_cross_page_block_has_title_body_reason(following) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_cross_page_handoff_has_following_page_structure(
  blocks : Array[PdfV2SemanticBlock],
  boundary_index : Int,
) -> Bool {
  let right = blocks[boundary_index + 1]
  if boundary_index + 2 >= blocks.length() {
    return false
  }
  let following = blocks[boundary_index + 2]
  following.page_index == right.page_index &&
  (
    following.kind == PdfV2SemanticBlockKind::Heading ||
    pdf_v2_semantic_kind_is_list(following.kind) ||
    pdf_v2_cross_page_block_has_title_body_reason(following)
  )
}

///|
fn pdf_v2_cross_page_handoff_has_repeated_artifact_boundary(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
  matched_fact : @pdfv2.PdfV2CrossPageBoundaryFact?,
) -> Bool {
  if left.reason_tags.contains("page_artifact_fact_attached") ||
    right.reason_tags.contains("page_artifact_fact_attached") ||
    left.reason_tags.contains("parser_repeated_artifact_fact") ||
    right.reason_tags.contains("parser_repeated_artifact_fact") {
    return true
  }
  match matched_fact {
    Some(fact) => fact.repeated_artifact_gap
    None => false
  }
}

///|
fn pdf_v2_cross_page_block_has_title_body_reason(
  block : PdfV2SemanticBlock,
) -> Bool {
  block.reason_tags.contains("heading_body_split") ||
  block.decision.reason_tags.contains("heading_body_split")
}

///|
fn pdf_v2_cross_page_structural_handoff_confidence(
  matched_fact : @pdfv2.PdfV2CrossPageBoundaryFact?,
  should_preserve_next_structure : Bool,
  should_preserve_heading_level : Bool,
  should_preserve_list_marker : Bool,
  title_body_boundary_evidence : Bool,
) -> Double {
  match matched_fact {
    Some(fact) => fact.confidence
    None => {
      let mut confidence = 0.0
      if should_preserve_next_structure {
        confidence = confidence + 0.58
      }
      if should_preserve_heading_level {
        confidence = confidence + 0.12
      }
      if should_preserve_list_marker {
        confidence = confidence + 0.18
      }
      if title_body_boundary_evidence {
        confidence = confidence + 0.16
      }
      if confidence > 0.92 {
        0.92
      } else {
        confidence
      }
    }
  }
}

///|
fn pdf_v2_cross_page_preserved_heading_level(
  blocks : Array[PdfV2SemanticBlock],
  boundary_index : Int,
  right : PdfV2SemanticBlock,
) -> Int? {
  if right.kind != PdfV2SemanticBlockKind::Heading {
    return right.level
  }
  match right.level {
    Some(level) =>
      if level > 1 {
        Some(level)
      } else if pdf_v2_cross_page_should_promote_following_heading(
          blocks, boundary_index, right,
        ) {
        Some(2)
      } else {
        Some(level)
      }
    None => None
  }
}

///|
fn pdf_v2_cross_page_should_promote_following_heading(
  blocks : Array[PdfV2SemanticBlock],
  boundary_index : Int,
  right : PdfV2SemanticBlock,
) -> Bool {
  if !pdf_v2_heading_has_title_shape(right.text) {
    return false
  }
  let mut saw_prior_heading = false
  let mut saw_prior_body = false
  for i in 0..<=boundary_index {
    let block = blocks[i]
    if block.kind == PdfV2SemanticBlockKind::Heading {
      saw_prior_heading = true
    } else if block.kind == PdfV2SemanticBlockKind::Paragraph ||
      block.kind == PdfV2SemanticBlockKind::Continuation {
      saw_prior_body = true
    }
  }
  saw_prior_heading && saw_prior_body
}

///|
fn pdf_v2_apply_cross_page_preserved_heading_level(
  block : PdfV2SemanticBlock,
  handoff : PdfV2CrossPageStructuralHandoff,
) -> PdfV2SemanticBlock {
  match handoff.next_heading_level {
    Some(level) => {
      let handoff_tags = pdf_v2_semantic_merge_tags(handoff.reason_tags, [
        "cross_page_structural_handoff", "preserve_heading_level",
      ])
      let decision = {
        ..block.decision,
        reason_tags: pdf_v2_semantic_merge_tags(
          block.decision.reason_tags,
          handoff_tags,
        ),
        confidence: if block.decision.confidence < handoff.confidence {
          block.decision.confidence
        } else {
          handoff.confidence
        },
      }
      {
        ..block,
        level: Some(level),
        reason_tags: pdf_v2_semantic_merge_tags(block.reason_tags, handoff_tags),
        decision,
      }
    }
    None => block
  }
}

///|
fn pdf_v2_merge_cross_page_semantic_blocks_with_handoff(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
  handoff : PdfV2CrossPageStructuralHandoff,
) -> PdfV2SemanticBlock {
  let merged = pdf_v2_merge_cross_page_semantic_blocks(
    pdf_v2_cross_page_paragraph_like_block(left),
    pdf_v2_cross_page_paragraph_like_block(right),
    fact,
  )
  let merged_tags = pdf_v2_semantic_merge_tags(
    merged.reason_tags,
    handoff.reason_tags,
  )
  let decision = {
    ..merged.decision,
    kind: PdfV2SemanticBlockKind::Paragraph,
    reason_tags: pdf_v2_semantic_merge_tags(
      merged.decision.reason_tags,
      handoff.reason_tags,
    ),
  }
  {
    ..merged,
    kind: PdfV2SemanticBlockKind::Paragraph,
    level: None,
    ordered: None,
    reason_tags: merged_tags,
    decision,
  }
}

///|
fn pdf_v2_cross_page_paragraph_like_block(
  block : PdfV2SemanticBlock,
) -> PdfV2SemanticBlock {
  if block.kind == PdfV2SemanticBlockKind::Paragraph {
    return block
  }
  {
    ..block,
    kind: PdfV2SemanticBlockKind::Paragraph,
    level: None,
    ordered: None,
    decision: { ..block.decision, kind: PdfV2SemanticBlockKind::Paragraph },
  }
}

///|
fn pdf_v2_semantic_kind_is_list(kind : PdfV2SemanticBlockKind) -> Bool {
  kind == PdfV2SemanticBlockKind::OrderedListItem ||
  kind == PdfV2SemanticBlockKind::UnorderedListItem
}

///|
pub fn pdf_v2_cross_page_arbitration_audit(
  blocks : Array[PdfV2SemanticBlock],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> PdfV2CrossPageArbitrationAudit {
  pdf_v2_cross_page_arbitration_audit_for_blocks(
    blocks,
    cross_page_facts,
    false,
    None,
  )
}

///|
pub fn pdf_v2_cross_page_fragment_arbitration_audit(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> PdfV2CrossPageArbitrationAudit {
  let baseline = pdf_v2_semantic_blocks_from_fragments(fragments, options)
  let with_facts = pdf_v2_semantic_blocks_from_fragments_with_cross_page_facts(
    fragments, options, cross_page_facts,
  )
  let actual_join_count = if baseline.length() > with_facts.length() {
    baseline.length() - with_facts.length()
  } else {
    0
  }
  pdf_v2_cross_page_arbitration_audit_for_blocks(
    baseline,
    cross_page_facts,
    true,
    Some(actual_join_count),
  )
}

///|
fn pdf_v2_cross_page_arbitration_audit_for_blocks(
  blocks : Array[PdfV2SemanticBlock],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  fragment_path : Bool,
  actual_join_count_override : Int?,
) -> PdfV2CrossPageArbitrationAudit {
  let reason_tag_distribution : Array[PdfV2CrossPageArbitrationAuditCounter] = []
  let gate_rejection_distribution : Array[PdfV2CrossPageArbitrationAuditCounter] = []
  let mut facts_passing_confidence_gate = 0
  let mut facts_passing_source_ref_gate = 0
  let mut facts_passing_prev_open_ended_gate = 0
  let mut facts_passing_next_marker_gate = 0
  let mut facts_passing_ambiguity_tag_gate = 0
  let mut rejected_confidence_below_threshold_count = 0
  let mut rejected_missing_source_refs_count = 0
  let mut rejected_prev_not_open_ended_count = 0
  let mut rejected_next_marker_list_page_number_blocker_count = 0
  let mut rejected_ambiguity_audit_or_low_confidence_tag_count = 0
  let mut product_candidate_fact_count = 0
  for fact in cross_page_facts {
    pdf_v2_cross_page_audit_add_tags(reason_tag_distribution, fact.reason_tags)
    if fact.confidence >= 0.60 {
      facts_passing_confidence_gate = facts_passing_confidence_gate + 1
    } else {
      rejected_confidence_below_threshold_count = rejected_confidence_below_threshold_count +
        1
      pdf_v2_cross_page_audit_add_counter(
        gate_rejection_distribution, "confidence_below_threshold",
      )
    }
    if fact.source_refs.length() > 0 {
      facts_passing_source_ref_gate = facts_passing_source_ref_gate + 1
    } else {
      rejected_missing_source_refs_count = rejected_missing_source_refs_count +
        1
      pdf_v2_cross_page_audit_add_counter(
        gate_rejection_distribution, "missing_source_refs",
      )
    }
    if fact.prev_open_ended {
      facts_passing_prev_open_ended_gate = facts_passing_prev_open_ended_gate +
        1
    } else {
      rejected_prev_not_open_ended_count = rejected_prev_not_open_ended_count +
        1
      pdf_v2_cross_page_audit_add_counter(
        gate_rejection_distribution, "previous_not_open_ended",
      )
    }
    if !fact.next_starts_with_marker {
      facts_passing_next_marker_gate = facts_passing_next_marker_gate + 1
    } else {
      rejected_next_marker_list_page_number_blocker_count = rejected_next_marker_list_page_number_blocker_count +
        1
      pdf_v2_cross_page_audit_add_counter(
        gate_rejection_distribution, "next_marker_list_page_number_blocker",
      )
    }
    if !pdf_v2_cross_page_audit_fact_has_blocking_tag(fact) {
      facts_passing_ambiguity_tag_gate = facts_passing_ambiguity_tag_gate + 1
    } else {
      rejected_ambiguity_audit_or_low_confidence_tag_count = rejected_ambiguity_audit_or_low_confidence_tag_count +
        1
      pdf_v2_cross_page_audit_add_counter(
        gate_rejection_distribution, "ambiguity_audit_or_low_confidence_tag",
      )
    }
    if pdf_v2_cross_page_fact_qualifies(fact) {
      product_candidate_fact_count = product_candidate_fact_count + 1
    }
  }
  let facts_reaching_product_arbitration_count = product_candidate_fact_count
  let mut rejected_mismatched_source_refs_count = 0
  let mut rejected_next_heading_title_like_blocker_count = 0
  let mut rejected_no_matching_fragment_or_semantic_pair_count = 0
  let mut evaluated_pair_count = 0
  let mut semantic_pair_count = 0
  let mut fragment_pair_count = 0
  let mut actual_join_decision_changed_count = 0
  let actual_split_decision_changed_count = 0
  let mut fallback_existing_behavior_count = 0
  let mut i = 0
  while i + 1 < blocks.length() {
    evaluated_pair_count = evaluated_pair_count + 1
    if fragment_path {
      fragment_pair_count = fragment_pair_count + 1
    } else {
      semantic_pair_count = semantic_pair_count + 1
    }
    let left = blocks[i]
    let right = blocks[i + 1]
    match pdf_v2_cross_page_semantic_pair_rejection(left, right) {
      Some(reason) => {
        fallback_existing_behavior_count = fallback_existing_behavior_count + 1
        pdf_v2_cross_page_audit_add_counter(gate_rejection_distribution, reason)
        if reason == "next_marker_list_page_number_blocker" {
          rejected_next_marker_list_page_number_blocker_count = rejected_next_marker_list_page_number_blocker_count +
            1
        } else if reason == "next_heading_title_like_blocker" {
          rejected_next_heading_title_like_blocker_count = rejected_next_heading_title_like_blocker_count +
            1
        }
      }
      None => {
        let mut matched = false
        let mut saw_missing_refs = false
        let mut saw_mismatched_refs = false
        let mut saw_no_matching_pair = false
        for fact in cross_page_facts {
          if pdf_v2_cross_page_fact_qualifies(fact) {
            match
              pdf_v2_cross_page_fact_semantic_pair_match_status(
                fact, left, right,
              ) {
              "match" => {
                matched = true
                break
              }
              "missing_source_refs" => saw_missing_refs = true
              "mismatched_source_refs" => saw_mismatched_refs = true
              _ => saw_no_matching_pair = true
            }
          }
        }
        if matched {
          actual_join_decision_changed_count = actual_join_decision_changed_count +
            1
        } else {
          fallback_existing_behavior_count = fallback_existing_behavior_count +
            1
          if saw_missing_refs {
            rejected_missing_source_refs_count = rejected_missing_source_refs_count +
              1
            pdf_v2_cross_page_audit_add_counter(
              gate_rejection_distribution, "missing_source_refs",
            )
          } else if saw_mismatched_refs {
            rejected_mismatched_source_refs_count = rejected_mismatched_source_refs_count +
              1
            pdf_v2_cross_page_audit_add_counter(
              gate_rejection_distribution, "mismatched_source_refs",
            )
          } else if saw_no_matching_pair || product_candidate_fact_count > 0 {
            rejected_no_matching_fragment_or_semantic_pair_count = rejected_no_matching_fragment_or_semantic_pair_count +
              1
            pdf_v2_cross_page_audit_add_counter(
              gate_rejection_distribution, "no_matching_fragment_or_semantic_pair",
            )
          }
        }
      }
    }
    i = i + 1
  }
  {
    generated_fact_count: cross_page_facts.length(),
    facts_reaching_product_arbitration_count,
    product_candidate_fact_count,
    facts_passing_confidence_gate,
    facts_passing_source_ref_gate,
    facts_passing_prev_open_ended_gate,
    facts_passing_next_marker_gate,
    facts_passing_ambiguity_tag_gate,
    rejected_confidence_below_threshold_count,
    rejected_missing_source_refs_count,
    rejected_mismatched_source_refs_count,
    rejected_prev_not_open_ended_count,
    rejected_next_marker_list_page_number_blocker_count,
    rejected_next_heading_title_like_blocker_count,
    rejected_ambiguity_audit_or_low_confidence_tag_count,
    rejected_no_matching_fragment_or_semantic_pair_count,
    evaluated_pair_count,
    semantic_pair_count,
    fragment_pair_count,
    actual_join_decision_changed_count: match actual_join_count_override {
      Some(count) => count
      None => actual_join_decision_changed_count
    },
    actual_split_decision_changed_count,
    fallback_existing_behavior_count,
    reason_tag_distribution,
    gate_rejection_distribution,
  }
}

///|
fn pdf_v2_cross_page_arbitration_fact(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> @pdfv2.PdfV2CrossPageBoundaryFact? {
  if !pdf_v2_cross_page_semantic_pair_can_join(left, right) {
    return None
  }
  for fact in cross_page_facts {
    if pdf_v2_cross_page_fact_qualifies(fact) &&
      pdf_v2_cross_page_fact_matches_semantic_pair(fact, left, right) {
      return Some(fact)
    }
  }
  None
}

///|
fn pdf_v2_cross_page_boundary_fact_for_blocks(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
) -> @pdfv2.PdfV2CrossPageBoundaryFact? {
  for fact in cross_page_facts {
    if pdf_v2_cross_page_fact_matches_semantic_pair(fact, left, right) {
      return Some(fact)
    }
  }
  None
}

///|
fn pdf_v2_cross_page_semantic_pair_rejection(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
) -> String? {
  if left.kind != PdfV2SemanticBlockKind::Paragraph ||
    right.kind != PdfV2SemanticBlockKind::Paragraph {
    return Some("pair_not_paragraph")
  }
  if left.page_index == right.page_index {
    return Some("not_cross_page_pair")
  }
  let l = left.text.trim().to_owned()
  let r = right.text.trim().to_owned()
  if l == "" || r == "" {
    return Some("empty_text")
  }
  if pdf_v2_ends_sentence(l) {
    return Some("previous_sentence_ended")
  }
  if pdf_v2_is_page_number_like_noise(l) {
    return Some("previous_page_number_blocker")
  }
  if pdf_v2_text_flow_parse_marker(r) is Some(_) ||
    pdf_v2_is_page_number_like_noise(r) {
    return Some("next_marker_list_page_number_blocker")
  }
  if pdf_v2_looks_like_standalone_title_line(l) {
    return Some("previous_heading_title_like_blocker")
  }
  if pdf_v2_looks_like_standalone_title_line(r) {
    return Some("next_heading_title_like_blocker")
  }
  if !pdf_v2_cross_page_output_line_continues(l, r) {
    return Some("not_hardwrap_continuation")
  }
  None
}

///|
fn pdf_v2_cross_page_semantic_pair_can_join(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
) -> Bool {
  if left.kind != PdfV2SemanticBlockKind::Paragraph ||
    right.kind != PdfV2SemanticBlockKind::Paragraph ||
    left.page_index == right.page_index {
    return false
  }
  let l = left.text.trim().to_owned()
  let r = right.text.trim().to_owned()
  if l == "" ||
    r == "" ||
    pdf_v2_ends_sentence(l) ||
    pdf_v2_text_flow_parse_marker(r) is Some(_) ||
    pdf_v2_is_page_number_like_noise(l) ||
    pdf_v2_is_page_number_like_noise(r) ||
    pdf_v2_looks_like_standalone_title_line(l) ||
    pdf_v2_looks_like_standalone_title_line(r) ||
    !pdf_v2_cross_page_output_line_continues(l, r) {
    return false
  }
  true
}

///|
fn pdf_v2_cross_page_fact_semantic_pair_match_status(
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
) -> String {
  if left.page_index != Some(fact.page_from) ||
    right.page_index != Some(fact.page_to) {
    return "no_matching_fragment_or_semantic_pair"
  }
  match fact.prev_block_ref {
    Some(block_ref) =>
      match left.block_index {
        Some(left_block) =>
          if left_block != block_ref {
            return "no_matching_fragment_or_semantic_pair"
          }
        None => ()
      }
    None => ()
  }
  match fact.next_block_ref {
    Some(block_ref) =>
      match right.block_index {
        Some(right_block) =>
          if right_block != block_ref {
            return "no_matching_fragment_or_semantic_pair"
          }
        None => ()
      }
    None => ()
  }
  if left.source_refs.length() == 0 ||
    right.source_refs.length() == 0 ||
    fact.source_refs.length() == 0 {
    return "missing_source_refs"
  }
  if pdf_v2_source_refs_overlap(left.source_refs, fact.source_refs) &&
    pdf_v2_source_refs_overlap(right.source_refs, fact.source_refs) {
    "match"
  } else {
    "mismatched_source_refs"
  }
}

///|
fn pdf_v2_cross_page_fact_matches_semantic_pair(
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
) -> Bool {
  if left.page_index != Some(fact.page_from) ||
    right.page_index != Some(fact.page_to) {
    return false
  }
  match fact.prev_block_ref {
    Some(block_ref) =>
      match left.block_index {
        Some(left_block) => if left_block != block_ref { return false }
        None => ()
      }
    None => ()
  }
  match fact.next_block_ref {
    Some(block_ref) =>
      match right.block_index {
        Some(right_block) => if right_block != block_ref { return false }
        None => ()
      }
    None => ()
  }
  if left.source_refs.length() == 0 || right.source_refs.length() == 0 {
    return false
  }
  pdf_v2_source_refs_overlap(left.source_refs, fact.source_refs) &&
  pdf_v2_source_refs_overlap(right.source_refs, fact.source_refs)
}

///|
fn pdf_v2_cross_page_audit_fact_has_blocking_tag(
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
) -> Bool {
  fact.reason_tags.contains("low_confidence") ||
  fact.reason_tags.contains("cross_page_ambiguous") ||
  fact.reason_tags.contains("ambiguity") ||
  fact.reason_tags.contains("audit_only")
}

///|
fn pdf_v2_cross_page_audit_add_counter(
  counters : Array[PdfV2CrossPageArbitrationAuditCounter],
  key : String,
) -> Unit {
  for i in 0..<counters.length() {
    if counters[i].key == key {
      counters[i] = { ..counters[i], count: counters[i].count + 1 }
      return
    }
  }
  counters.push({ key, count: 1 })
}

///|
fn pdf_v2_cross_page_audit_add_tags(
  counters : Array[PdfV2CrossPageArbitrationAuditCounter],
  tags : Array[String],
) -> Unit {
  for tag in tags {
    pdf_v2_cross_page_audit_add_counter(counters, tag)
  }
}

///|
fn pdf_v2_merge_cross_page_semantic_blocks(
  left : PdfV2SemanticBlock,
  right : PdfV2SemanticBlock,
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
) -> PdfV2SemanticBlock {
  let merged_refs = pdf_v2_merge_source_refs(
    left.source_refs,
    right.source_refs,
  )
  let merged_tags = pdf_v2_semantic_merge_tags(
    pdf_v2_semantic_merge_tags(left.reason_tags, right.reason_tags),
    ["cross_page_boundary_fact_arbitration", "fact_backed_cross_page_join"],
  )
  let decision = {
    ..left.decision,
    source_refs: merged_refs,
    reason_tags: pdf_v2_semantic_merge_tags(
      pdf_v2_semantic_merge_tags(
        left.decision.reason_tags,
        right.decision.reason_tags,
      ),
      ["cross_page_boundary_fact_arbitration", "fact_backed_cross_page_join"],
    ),
    confidence: if left.decision.confidence < fact.confidence {
      left.decision.confidence
    } else {
      fact.confidence
    },
  }
  {
    ..left,
    text: pdf_v2_join_cross_page_semantic_text(left.text, right.text),
    source_refs: merged_refs,
    reason_tags: merged_tags,
    risk_tags: pdf_v2_semantic_merge_tags(left.risk_tags, right.risk_tags),
    decision,
  }
}

///|
fn pdf_v2_join_cross_page_semantic_text(
  left : String,
  right : String,
) -> String {
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()
  if l == "" {
    r
  } else if r == "" {
    l
  } else if pdf_v2_should_unwrap_hyphenated_word(l, r) {
    pdf_v2_trim_trailing_wrap_hyphen(l) + r
  } else if pdf_v2_join_without_space(l, r) {
    l + r
  } else {
    l + " " + r
  }
}

///|
fn pdf_v2_merge_source_refs(
  left : Array[@pdfv2.PdfV2SourceRef],
  right : Array[@pdfv2.PdfV2SourceRef],
) -> Array[@pdfv2.PdfV2SourceRef] {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  refs.append(left)
  for source_ref in right {
    if !pdf_v2_source_refs_contains(refs, source_ref) {
      refs.push(source_ref)
    }
  }
  refs
}

///|
fn pdf_v2_source_refs_contains(
  refs : Array[@pdfv2.PdfV2SourceRef],
  target : @pdfv2.PdfV2SourceRef,
) -> Bool {
  for source_ref in refs {
    if pdf_v2_same_source_ref(source_ref, target) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_semantic_page_label_sequence_length(
  flow : Array[PdfV2TextFlowUnit],
  index : Int,
  options : PdfV2ProductBridgeOptions,
) -> Int {
  if !options.enable_noise_guards ||
    !options.suppress_page_number_like_noise ||
    index >= flow.length() {
    return 0
  }
  let a = flow[index].normalized_text.trim().to_owned()
  if a == "" {
    return 0
  }
  match pdf_v2_semantic_next_non_empty_flow_index(flow, index + 1) {
    Some(second_index) => {
      let b = flow[second_index].normalized_text.trim().to_owned()
      match pdf_v2_semantic_next_non_empty_flow_index(flow, second_index + 1) {
        Some(third_index) => {
          let c = flow[third_index].normalized_text.trim().to_owned()
          if a == "第" && b == "页" && pdf_v2_is_page_number_like_noise(c) {
            return third_index - index + 1
          }
          if a == "第" && pdf_v2_all_ascii_digits(b) && c == "页" {
            return third_index - index + 1
          }
        }
        None => ()
      }
      if a == "第" && b == "页" {
        return second_index - index + 1
      }
      if pdf_v2_is_page_number_like_noise(a + b) {
        return second_index - index + 1
      }
    }
    None => ()
  }
  0
}

///|
fn pdf_v2_semantic_next_non_empty_flow_index(
  flow : Array[PdfV2TextFlowUnit],
  start : Int,
) -> Int? {
  let mut i = start
  while i < flow.length() {
    if flow[i].normalized_text.trim().to_owned() != "" {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn pdf_v2_semantic_rule_decision(
  unit : PdfV2TextFlowUnit,
  options : PdfV2ProductBridgeOptions,
) -> PdfV2RuleDecision {
  let decision = if options.enable_noise_guards {
    match pdf_v2_semantic_noise_guard_decision(unit, options) {
      Some(decision) => decision
      None =>
        if options.enable_list_rules {
          match pdf_v2_semantic_list_decision(unit) {
            Some(decision) => decision
            None =>
              if options.enable_heading_rules {
                match pdf_v2_semantic_heading_decision(unit) {
                  Some(decision) => decision
                  None => pdf_v2_semantic_paragraph_decision(unit)
                }
              } else {
                pdf_v2_semantic_paragraph_decision(unit)
              }
          }
        } else if options.enable_heading_rules {
          match pdf_v2_semantic_heading_decision(unit) {
            Some(decision) => decision
            None => pdf_v2_semantic_paragraph_decision(unit)
          }
        } else {
          pdf_v2_semantic_paragraph_decision(unit)
        }
    }
  } else if options.enable_list_rules {
    match pdf_v2_semantic_list_decision(unit) {
      Some(decision) => decision
      None =>
        if options.enable_heading_rules {
          match pdf_v2_semantic_heading_decision(unit) {
            Some(decision) => decision
            None => pdf_v2_semantic_paragraph_decision(unit)
          }
        } else {
          pdf_v2_semantic_paragraph_decision(unit)
        }
    }
  } else if options.enable_heading_rules {
    match pdf_v2_semantic_heading_decision(unit) {
      Some(decision) => decision
      None => pdf_v2_semantic_paragraph_decision(unit)
    }
  } else {
    pdf_v2_semantic_paragraph_decision(unit)
  }
  pdf_v2_apply_structure_evidence_arbitration(unit, decision, options)
}

///|
fn pdf_v2_apply_structure_evidence_arbitration(
  unit : PdfV2TextFlowUnit,
  decision : PdfV2RuleDecision,
  options : PdfV2ProductBridgeOptions,
) -> PdfV2RuleDecision {
  if decision.risk_tags.contains("suppress_output") {
    return decision
  }
  if options.enable_list_rules {
    match pdf_v2_semantic_structure_evidence_list_decision(unit, decision) {
      Some(adjusted) => return adjusted
      None => ()
    }
  }
  if options.enable_heading_rules {
    match pdf_v2_semantic_structure_evidence_heading_decision(unit, decision) {
      Some(adjusted) => return adjusted
      None => ()
    }
  }
  decision
}

///|
fn pdf_v2_semantic_structure_evidence_list_decision(
  unit : PdfV2TextFlowUnit,
  decision : PdfV2RuleDecision,
) -> PdfV2RuleDecision? {
  if decision.kind == PdfV2SemanticBlockKind::OrderedListItem ||
    decision.kind == PdfV2SemanticBlockKind::UnorderedListItem {
    return None
  }
  if !unit.reason_tags.contains("list_marker_body_boundary_candidate") ||
    !unit.signals.parser_fact_backed {
    return None
  }
  if unit.signals.starts_with_unordered_marker {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::UnorderedListItem,
        0.93,
        "list.structure_boundary.parser_fact",
        [
          "parser_structure_evidence", "structure_boundary_candidate", "list_marker_body_boundary_candidate",
          "unordered_marker",
        ],
        [],
        unit.source_refs,
        [],
      ),
    )
  }
  if unit.signals.starts_with_ordered_marker {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::OrderedListItem,
        0.91,
        "list.structure_boundary.parser_fact",
        [
          "parser_structure_evidence", "structure_boundary_candidate", "list_marker_body_boundary_candidate",
          "ordered_marker",
        ],
        [],
        unit.source_refs,
        [],
      ),
    )
  }
  None
}

///|
fn pdf_v2_semantic_structure_evidence_heading_decision(
  unit : PdfV2TextFlowUnit,
  decision : PdfV2RuleDecision,
) -> PdfV2RuleDecision? {
  if decision.kind == PdfV2SemanticBlockKind::Heading {
    return None
  }
  if !unit.reason_tags.contains("structure_boundary_candidate") ||
    !unit.reason_tags.contains("title_body_boundary_candidate") ||
    unit.reason_tags.contains("body_flow_candidate") ||
    unit.reason_tags.contains("list_marker_body_boundary_candidate") ||
    unit.signals.starts_with_ordered_marker ||
    unit.signals.starts_with_unordered_marker ||
    unit.signals.starts_with_heading_marker ||
    !unit.signals.is_single_line ||
    unit.signals.ends_with_sentence_punctuation ||
    unit.signals.looks_like_page_number ||
    unit.signals.looks_like_caption_marker ||
    !unit.signals.has_following_body {
    return None
  }
  if !unit.reason_tags.contains("heading_line_candidate") &&
    unit.signals.parser_heading_candidate_score < 0.60 {
    return None
  }
  Some(
    pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Heading,
      0.84,
      "heading.structure_boundary.parser_fact",
      [
        "parser_structure_evidence", "structure_boundary_candidate", "title_body_boundary_candidate",
      ],
      [],
      unit.source_refs,
      [],
    ),
  )
}

///|
fn pdf_v2_semantic_noise_guard_decision(
  unit : PdfV2TextFlowUnit,
  options : PdfV2ProductBridgeOptions,
) -> PdfV2RuleDecision? {
  if unit.normalized_text == "" {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Unknown,
        1.0,
        "noise.empty_line_guard",
        ["noise_guard", "empty_line"],
        [],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard", "suppress_output"],
      ),
    )
  }
  if unit.signals.parser_fact_backed &&
    unit.signals.parser_artifact_candidate_score >= 0.90 &&
    unit.signals.looks_like_page_number &&
    options.suppress_page_number_like_noise {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Unknown,
        1.0,
        "noise.parser_artifact_guard",
        ["noise_guard", "parser_artifact_fact"],
        ["not_heading", "not_list"],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard", "suppress_output"],
      ),
    )
  }
  if unit.signals.parser_fact_backed &&
    unit.signals.parser_artifact_candidate_score >= 0.90 &&
    !unit.signals.looks_like_page_number &&
    options.suppress_repeated_page_artifact_noise {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Unknown,
        0.96,
        "noise.parser_repeated_artifact_guard",
        ["noise_guard", "parser_repeated_artifact_fact"],
        ["not_heading", "not_list"],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard", "suppress_output"],
      ),
    )
  }
  if unit.signals.looks_like_page_number &&
    options.suppress_page_number_like_noise {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Unknown,
        1.0,
        "noise.page_number_guard",
        ["noise_guard", "page_number_like"],
        ["not_heading", "not_list"],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard", "suppress_output"],
      ),
    )
  }
  None
}

///|
fn pdf_v2_semantic_list_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision? {
  if pdf_v2_semantic_indent_unsupported(unit) {
    return None
  }
  if unit.signals.parser_fact_backed &&
    unit.signals.parser_list_candidate_score >= 0.70 {
    if unit.signals.starts_with_unordered_marker {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::UnorderedListItem,
          0.94,
          "list.unordered_marker.parser_fact",
          ["list_marker", "unordered_marker", "parser_fact"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
    if unit.signals.starts_with_ordered_marker {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::OrderedListItem,
          0.92,
          "list.ordered_marker.parser_fact",
          ["list_marker", "ordered_marker", "parser_fact"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
  }
  match unit.marker {
    Some(marker) =>
      match marker.kind {
        PdfV2TextFlowMarkerKind::UnorderedListMarker =>
          Some(
            pdf_v2_semantic_decision(
              PdfV2SemanticBlockKind::UnorderedListItem,
              0.93,
              "list.unordered_marker",
              ["list_marker", "unordered_marker", marker.marker_text],
              [],
              unit.source_refs,
              [],
            ),
          )
        PdfV2TextFlowMarkerKind::OrderedListMarker =>
          Some(
            pdf_v2_semantic_decision(
              PdfV2SemanticBlockKind::OrderedListItem,
              0.90,
              "list.ordered_marker",
              ["list_marker", "ordered_marker", marker.marker_text],
              [],
              unit.source_refs,
              [],
            ),
          )
        PdfV2TextFlowMarkerKind::HeadingMarker => None
      }
    None => None
  }
}

///|
fn pdf_v2_semantic_heading_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision? {
  if unit.signals.starts_with_heading_marker {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Heading,
        0.98,
        "heading.marker_prefix",
        ["heading_marker", "marker_prefix"],
        [],
        unit.source_refs,
        [],
      ),
    )
  }
  let t = pdf_v2_heading_normalize(unit.normalized_text)
  if t == "" {
    return None
  }
  if unit.signals.parser_fact_backed &&
    unit.signals.parser_heading_candidate_score >= 0.75 &&
    unit.signals.is_single_line &&
    !unit.signals.ends_with_sentence_punctuation &&
    !unit.signals.looks_like_page_number &&
    !unit.signals.looks_like_caption_marker &&
    !unit.signals.starts_with_ordered_marker &&
    !unit.signals.starts_with_unordered_marker {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Heading,
        0.88,
        "heading.short_single_line_followed_by_body.parser_fact",
        ["short_single_line", "parser_fact", "boundary_heading_score"],
        [],
        unit.source_refs,
        [],
      ),
    )
  }
  if !unit.signals.is_single_line {
    return None
  }
  if !pdf_v2_heading_basic_shape_ok(t) {
    return None
  }
  if pdf_v2_heading_has_title_shape(t) {
    if unit.signals.has_following_body {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::Heading,
          0.86,
          "heading.short_single_line_followed_by_body",
          ["short_single_line", "following_body", "title_shape"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
    if unit.flow_index == 0 {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::Heading,
          0.78,
          "heading.document_lead_title_shape",
          ["document_lead", "short_single_line", "title_shape"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
  }
  None
}

///|
fn pdf_v2_semantic_paragraph_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision {
  if unit.signals.parser_fact_backed &&
    unit.signals.parser_continuation_candidate_score >= 0.55 {
    return pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Continuation,
      0.66,
      "continuation.parser_boundary_fact",
      ["parser_fact", "continuation_boundary_score"],
      [],
      unit.source_refs,
      [],
    )
  }
  if unit.signals.continuation_candidate && unit.line_count > 1 {
    return pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Continuation,
      0.60,
      "continuation.hardwrap_join",
      ["hardwrap_join", "paragraph_continuation"],
      [],
      unit.source_refs,
      [],
    )
  }
  if unit.signals.ends_with_sentence_punctuation {
    return pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Paragraph,
      0.76,
      "paragraph.sentence_guard",
      ["sentence_punctuation", "paragraph_guard"],
      [],
      unit.source_refs,
      [],
    )
  }
  pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Paragraph,
    0.55,
    "paragraph.default",
    ["paragraph_default"],
    [],
    unit.source_refs,
    [],
  )
}

///|
fn pdf_v2_semantic_block_from_decision(
  unit : PdfV2TextFlowUnit,
  decision : PdfV2RuleDecision,
) -> PdfV2SemanticBlock {
  let text = if decision.risk_tags.contains("suppress_output") {
    ""
  } else {
    pdf_v2_semantic_block_text(unit, decision.kind)
  }
  {
    kind: decision.kind,
    text,
    level: pdf_v2_semantic_heading_level(unit, decision.kind),
    ordered: pdf_v2_semantic_ordered_flag(decision.kind),
    list_level: 0,
    page_index: unit.page_index,
    block_index: unit.block_index,
    fragment_index: unit.fragment_index,
    source_refs: unit.source_refs,
    reason_tags: pdf_v2_semantic_merge_tags(
      unit.reason_tags,
      decision.reason_tags,
    ),
    risk_tags: decision.risk_tags,
    decision,
  }
}

///|
fn pdf_v2_semantic_block_text(
  unit : PdfV2TextFlowUnit,
  kind : PdfV2SemanticBlockKind,
) -> String {
  match kind {
    PdfV2SemanticBlockKind::Heading =>
      match unit.marker {
        Some(marker) =>
          if marker.kind == PdfV2TextFlowMarkerKind::HeadingMarker {
            pdf_v2_semantic_normalize_heading_text(marker.body_text)
          } else {
            pdf_v2_semantic_normalize_heading_text(unit.normalized_text)
          }
        None => pdf_v2_semantic_normalize_heading_text(unit.normalized_text)
      }
    PdfV2SemanticBlockKind::OrderedListItem
    | PdfV2SemanticBlockKind::UnorderedListItem =>
      pdf_v2_semantic_list_item_text(unit)
    _ => unit.normalized_text
  }
}

///|
fn pdf_v2_semantic_list_item_text(unit : PdfV2TextFlowUnit) -> String {
  match pdf_v2_text_flow_parse_marker(unit.normalized_text) {
    Some(marker) =>
      match marker.kind {
        PdfV2TextFlowMarkerKind::OrderedListMarker
        | PdfV2TextFlowMarkerKind::UnorderedListMarker => marker.body_text
        PdfV2TextFlowMarkerKind::HeadingMarker =>
          match unit.marker {
            Some(fallback) => fallback.body_text
            None => unit.normalized_text
          }
      }
    None =>
      match unit.marker {
        Some(marker) => marker.body_text
        None => unit.normalized_text
      }
  }
}

///|
fn pdf_v2_semantic_heading_level(
  unit : PdfV2TextFlowUnit,
  kind : PdfV2SemanticBlockKind,
) -> Int? {
  if kind != PdfV2SemanticBlockKind::Heading {
    return None
  }
  match unit.marker {
    Some(marker) =>
      if marker.kind == PdfV2TextFlowMarkerKind::HeadingMarker {
        marker.level_hint
      } else {
        Some(pdf_v2_semantic_infer_heading_level(unit))
      }
    None => Some(pdf_v2_semantic_infer_heading_level(unit))
  }
}

///|
fn pdf_v2_semantic_ordered_flag(kind : PdfV2SemanticBlockKind) -> Bool? {
  match kind {
    PdfV2SemanticBlockKind::OrderedListItem => Some(true)
    PdfV2SemanticBlockKind::UnorderedListItem => Some(false)
    _ => None
  }
}

///|
fn pdf_v2_semantic_infer_heading_level(unit : PdfV2TextFlowUnit) -> Int {
  let text = unit.normalized_text
  if pdf_v2_semantic_numbered_section_depth(text) >= 2 {
    2
  } else if unit.signals.has_previous_heading &&
    pdf_v2_heading_looks_like_common_english_section_label(text) {
    2
  } else if unit.flow_index > 0 &&
    pdf_v2_heading_looks_like_common_english_section_label(text) {
    2
  } else {
    1
  }
}

///|
fn pdf_v2_semantic_numbered_section_depth(text : String) -> Int {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 || !pdf_v2_is_ascii_digit(chars[0]) {
    return 0
  }
  let mut i = 0
  let mut dots = 0
  let mut saw_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_is_ascii_digit(ch) {
      saw_digit = true
      i = i + 1
    } else if ch == '.' {
      dots = dots + 1
      i = i + 1
    } else {
      break
    }
  }
  if saw_digit {
    dots + 1
  } else {
    0
  }
}

///|
fn pdf_v2_semantic_normalize_heading_text(text : String) -> String {
  pdf_v2_semantic_normalize_cjk_heading_spacing(text.trim().to_owned())
}

///|
fn pdf_v2_semantic_normalize_cjk_heading_spacing(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder::new()
  for i in 0..<chars.length() {
    let ch = chars[i]
    out.write_char(ch)
    if (ch == '章' || ch == '节') &&
      i + 1 < chars.length() &&
      chars[i + 1] != ' ' &&
      pdf_v2_is_cjk(chars[i + 1]) {
      out.write_char(' ')
    }
  }
  out.to_string()
}

///|
fn pdf_v2_semantic_indent_unsupported(unit : PdfV2TextFlowUnit) -> Bool {
  match unit.indent_level {
    Some(level) => level > 0
    None => false
  }
}

///|
fn pdf_v2_semantic_decision(
  kind : PdfV2SemanticBlockKind,
  confidence : Double,
  rule_id : String,
  reason_tags : Array[String],
  negative_reason_tags : Array[String],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  risk_tags : Array[String],
) -> PdfV2RuleDecision {
  {
    kind,
    confidence,
    rule_id,
    reason_tags: pdf_v2_semantic_merge_tags(
      ["pdf_v2_semantic_rule"],
      reason_tags,
    ),
    negative_reason_tags,
    source_refs,
    risk_tags,
  }
}

///|
fn pdf_v2_semantic_merge_tags(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(left)
  for tag in right {
    if !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn pdf_v2_heading_normalize(text : String) -> String {
  pdf_v2_normalize_paragraph_text(text).trim().to_owned()
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: parser LineTextSignal
// facts and a future BlockKindClassifier. Keep lexical heading exclusions narrow.
// TODO(pdf-v2-model): export exclusions as weak negative block-kind features.
fn pdf_v2_heading_basic_shape_ok(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if t.length() < 4 || t.length() > 72 {
    return false
  }
  if t.contains("\n") || t.contains("<br") || t.contains("://") {
    return false
  }
  if pdf_v2_heading_ends_sentence(t) ||
    t.has_suffix(":") ||
    t.has_suffix("：") ||
    t.has_suffix(",") ||
    t.has_suffix("，") ||
    t.has_suffix(";") ||
    t.has_suffix("；") {
    return false
  }
  if pdf_v2_heading_contains_inline_cjk_body_marker(t) {
    return false
  }
  if pdf_v2_is_page_number_like_noise(t) ||
    pdf_v2_heading_looks_like_caption(t) ||
    pdf_v2_heading_looks_like_bullet_or_list_item(t) ||
    pdf_v2_heading_looks_like_complete_statement(t) ||
    pdf_v2_heading_looks_like_intro_phrase(t) {
    return false
  }
  true
}

///|
fn pdf_v2_heading_has_title_shape(text : String) -> Bool {
  pdf_v2_heading_looks_like_chapter_title(text) ||
  pdf_v2_heading_looks_like_numbered_section(text) ||
  pdf_v2_heading_looks_like_english_title(text) ||
  pdf_v2_heading_looks_like_common_english_section_label(text) ||
  pdf_v2_heading_looks_like_cjk_title(text)
}

///|
fn pdf_v2_heading_next_looks_like_body(next_text : String?) -> Bool {
  match next_text {
    None => false
    Some(value) => {
      let t = pdf_v2_heading_normalize(value)
      if t == "" {
        return false
      }
      if pdf_v2_heading_looks_like_bullet_or_list_item(t) {
        return true
      }
      if pdf_v2_heading_ends_sentence(t) {
        return true
      }
      if t.length() >= 24 || pdf_v2_heading_word_count(t) >= 5 {
        return true
      }
      if pdf_v2_heading_looks_like_intro_phrase(t) {
        return true
      }
      false
    }
  }
}

///|
fn pdf_v2_heading_looks_like_chapter_title(text : String) -> Bool {
  if !text.has_prefix("第") {
    return false
  }
  let n = text.to_array().length()
  n >= 4 && n <= 30 && !pdf_v2_heading_contains_sentence_punct(text)
}

///|
fn pdf_v2_heading_looks_like_numbered_section(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 3 || chars.length() > 48 {
    return false
  }
  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
    saw_digit = true
    i = i + 1
  }
  if !saw_digit || i >= chars.length() || chars[i] != '.' {
    return false
  }
  i = i + 1
  let mut saw_section_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_is_ascii_digit(ch) {
      saw_section_digit = true
      i = i + 1
    } else if ch == '.' {
      i = i + 1
    } else {
      break
    }
  }
  if !saw_section_digit || i >= chars.length() {
    return false
  }
  let tail = String::from_array(chars[i:].to_owned()).trim().to_owned()
  tail != "" &&
  tail.length() <= 32 &&
  !pdf_v2_heading_ends_sentence(tail) &&
  !pdf_v2_heading_looks_like_numbered_body_sentence(text)
}

///|
fn pdf_v2_heading_looks_like_english_title(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() < 2 || words.length() > 6 {
    return false
  }
  let first = pdf_v2_heading_ascii_lower(
    pdf_v2_heading_strip_edge_punct(words[0]),
  )
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }
  let mut latin_words = 0
  let mut capitalized_words = 0
  let mut has_title_keyword = false
  let mut has_connector = false
  for word in words {
    let stripped = pdf_v2_heading_strip_edge_punct(word)
    let lower = pdf_v2_heading_ascii_lower(stripped)
    if lower == "vs" || lower == "and" || lower == "or" {
      has_connector = true
    }
    if pdf_v2_heading_is_common_english_section_word(lower) ||
      lower == "report" ||
      lower == "pipeline" ||
      lower == "test" ||
      lower == "sample" ||
      lower == "heading" {
      has_title_keyword = true
    }
    if pdf_v2_heading_starts_latin(stripped) {
      latin_words = latin_words + 1
      match pdf_v2_first_char(stripped) {
        Some(ch) =>
          if ch >= 'A' && ch <= 'Z' {
            capitalized_words = capitalized_words + 1
          }
        None => ()
      }
    }
  }
  latin_words >= 2 &&
  capitalized_words >= 2 &&
  (has_title_keyword || has_connector || capitalized_words == latin_words)
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: future BlockKindClassifier
// features. These labels require boundary/body evidence before promotion.
// TODO(pdf-v2-model): replace section-label tables with labeled block-kind data.
fn pdf_v2_heading_looks_like_common_english_section_label(
  text : String,
) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  pdf_v2_heading_is_common_english_section_word(lower)
}

///|
fn pdf_v2_heading_is_common_english_section_word(text : String) -> Bool {
  text == "abstract" ||
  text == "introduction" ||
  text == "background" ||
  text == "method" ||
  text == "methods" ||
  text == "results" ||
  text == "discussion" ||
  text == "summary" ||
  text == "details" ||
  text == "conclusion" ||
  text == "references"
}

///|
fn pdf_v2_heading_looks_like_cjk_title(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 || chars.length() > 16 {
    return false
  }
  if text.contains(" ") || pdf_v2_heading_contains_sentence_punct(text) {
    return false
  }
  if text.has_prefix("本") ||
    text.has_prefix("该") ||
    text.has_prefix("此") ||
    text.has_prefix("这") {
    return false
  }
  let mut cjkish = 0
  for ch in chars {
    if pdf_v2_is_cjk(ch) {
      cjkish = cjkish + 1
    } else if !pdf_v2_is_ascii_digit(ch) && ch != '.' {
      return false
    }
  }
  cjkish >= 4 && pdf_v2_heading_looks_like_common_cjk_section_label(text)
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: parser CJK text-flow
// boundary facts or a future BlockKindClassifier.
// TODO(pdf-v2-model): replace CJK section-label tables with labeled block data.
fn pdf_v2_heading_looks_like_common_cjk_section_label(text : String) -> Bool {
  text == "研究内容" ||
  text == "技术路线" ||
  text == "研究方法" ||
  text == "研究目标" ||
  text == "研究背景" ||
  text == "项目概述" ||
  text == "系统概述" ||
  text == "方案概述" ||
  text == "总结" ||
  text == "结论" ||
  text == "下一节"
}

///|
fn pdf_v2_heading_ends_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_v2_heading_contains_sentence_punct(text : String) -> Bool {
  text.contains("。") ||
  text.contains("！") ||
  text.contains("？") ||
  text.contains("；") ||
  text.contains(";")
}

///|
fn pdf_v2_heading_looks_like_caption(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("table ") ||
  lower.has_prefix("chart ") ||
  lower.has_prefix("image ") ||
  text.has_prefix("图") ||
  text.has_prefix("表")
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: parser sentence/body
// boundary facts. Guard CJK inline body markers from heading promotion.
// TODO(pdf-v2-model): export as negative heading evidence.
fn pdf_v2_heading_contains_inline_cjk_body_marker(text : String) -> Bool {
  let chars = text.to_array()
  for i in 0..<chars.length() {
    let ch = chars[i]
    if (ch == '：' || ch == ':') &&
      i > 0 &&
      i + 1 < chars.length() &&
      pdf_v2_is_cjk(chars[i - 1]) &&
      pdf_v2_is_cjk(chars[i + 1]) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_heading_looks_like_bullet_or_list_item(text : String) -> Bool {
  match pdf_v2_text_flow_parse_marker(text) {
    Some(marker) =>
      marker.kind == PdfV2TextFlowMarkerKind::OrderedListMarker ||
      marker.kind == PdfV2TextFlowMarkerKind::UnorderedListMarker
    None => false
  }
}

///|
fn pdf_v2_heading_looks_like_numbered_body_sentence(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.contains(" this ") ||
  lower.contains(" is ") ||
  lower.contains(" inside ") ||
  lower.contains(" should ") ||
  lower.contains(" paragraph ")
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: parser boundary facts or
// future BlockKindClassifier negative features.
// TODO(pdf-v2-model): export as negative block-kind evidence.
fn pdf_v2_heading_looks_like_intro_phrase(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower == "in conclusion," ||
  lower == "in conclusion" ||
  lower == "key points:" ||
  lower == "key points" ||
  lower == "as follows" ||
  text.has_suffix("如下。") ||
  text.has_suffix("如下")
}

///|
// PDF v2 temporary rule.
// Owner today: convert semantic rules. Correct owner: parser sentence/body facts
// or future BlockKindClassifier negative features.
// TODO(pdf-v2-model): export as negative block-kind evidence.
fn pdf_v2_heading_looks_like_complete_statement(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() >= 8 {
    return true
  }
  let lower = pdf_v2_heading_ascii_lower(text)
  if lower.contains(" actually ") ||
    lower.contains(" should ") ||
    lower.contains(" remain ") ||
    lower.contains(" across ") ||
    lower.contains(" method") {
    return true
  }
  false
}

///|
fn pdf_v2_heading_words(text : String) -> Array[String] {
  let out : Array[String] = []
  for raw in text.split(" ") {
    let word = raw.trim().to_owned()
    if word != "" {
      out.push(word)
    }
  }
  out
}

///|
fn pdf_v2_heading_word_count(text : String) -> Int {
  pdf_v2_heading_words(text).length()
}

///|
fn pdf_v2_heading_starts_latin(text : String) -> Bool {
  match pdf_v2_first_char(text) {
    Some(ch) => (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
    None => false
  }
}

///|
fn pdf_v2_heading_strip_edge_punct(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 {
    return ""
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end && pdf_v2_heading_edge_punct(chars[start]) {
    start = start + 1
  }
  while end > start && pdf_v2_heading_edge_punct(chars[end - 1]) {
    end = end - 1
  }
  String::from_array(chars[start:end].to_owned())
}

///|
fn pdf_v2_heading_edge_punct(ch : Char) -> Bool {
  ch == '"' ||
  ch == '\'' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == ',' ||
  ch == '.' ||
  ch == ':' ||
  ch == ';'
}

///|
fn pdf_v2_heading_ascii_lower(text : String) -> String {
  text.to_lower()
}
