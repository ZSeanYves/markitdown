///|
pub(all) enum PdfV2SignalTraceSelectionPath {
  CandidateStructuralHandoff
  CandidateCrossPageArbitration
  CandidateSemanticActionableTextFlow
  FragmentCrossPageArbitration
  FragmentSemanticFallback
  SemanticRulesDisabled
} derive(Eq)

///|
pub(all) enum PdfV2SignalTraceLossLayer {
  NoLossDetected
  ParserModelExtractionLoss
  ParserCandidateFactLoss
  SemanticCandidateBlockLoss
  StructuralHandoffGateRejection
  BridgeLoweringPathLoss
  ExpectedOutputNotOwnedByStructuralHandoff
} derive(Eq)

///|
pub(all) struct PdfV2SignalTraceSelection {
  path : PdfV2SignalTraceSelectionPath
  candidate_semantic_mode : Bool
  structural_handoff_candidate_mode : Bool
  candidate_backed_emission : Bool
}

///|
pub(all) struct PdfV2SignalTraceParserBlockPreview {
  page_index : Int?
  block_index : Int
  text : String
  lines : Array[String]
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2SignalTraceCandidatePreview {
  page_index : Int?
  block_index : Int?
  flow_index : Int
  line_indices : Array[Int]
  text : String
  normalized_text : String
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  starts_with_list_marker : Bool
  title_body_boundary_evidence : Bool
}

///|
pub(all) struct PdfV2SignalTraceSemanticPreview {
  kind : PdfV2SemanticBlockKind
  text : String
  level : Int?
  page_index : Int?
  block_index : Int?
  fragment_index : Int
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  negative_reason_tags : Array[String]
}

///|
pub(all) struct PdfV2SignalTraceSemanticPair {
  left : PdfV2SignalTraceSemanticPreview
  right : PdfV2SignalTraceSemanticPreview
}

///|
pub(all) struct PdfV2SignalTraceBoundary {
  page_from : Int
  page_to : Int
  parser_prev_block : PdfV2SignalTraceParserBlockPreview?
  parser_next_block : PdfV2SignalTraceParserBlockPreview?
  candidate_pair_adjacent : Bool
  candidate_prev : PdfV2SignalTraceCandidatePreview?
  candidate_next : PdfV2SignalTraceCandidatePreview?
  cross_page_fact : @pdfv2.PdfV2CrossPageBoundaryFact?
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact]
  baseline_candidate_pair : PdfV2SignalTraceSemanticPair?
  selected_pair : PdfV2SignalTraceSemanticPair?
  structural_handoff : PdfV2CrossPageStructuralHandoff?
  title_body_boundary_evidence : Bool
  next_list_marker_evidence : Bool
  selection_path : PdfV2SignalTraceSelectionPath
  candidate_backed_emission : Bool
  fragment_path_used : Bool
  loss_layer : PdfV2SignalTraceLossLayer
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2SignalTraceHeading {
  page_index : Int?
  block_ref : Int?
  line_refs : Array[Int]
  text : String
  confidence : Double
  reason_tags : Array[String]
  semantic_preview : PdfV2SignalTraceSemanticPreview?
  accepted_as_heading : Bool
}

///|
pub(all) struct PdfV2TargetSignalTraceReport {
  source_name : String
  page_count : Int
  cross_page_fact_count : Int
  heading_fact_count : Int
  candidate_semantic_block_count : Int
  selected_semantic_block_count : Int
  selection : PdfV2SignalTraceSelection
  boundaries : Array[PdfV2SignalTraceBoundary]
  heading_traces : Array[PdfV2SignalTraceHeading]
  candidate_semantic_blocks : Array[PdfV2SignalTraceSemanticPreview]
  selected_semantic_blocks : Array[PdfV2SignalTraceSemanticPreview]
  notes : Array[String]
}

///|
priv struct PdfV2SignalTraceInput {
  source_name : String
  page_count : Int
  parser_blocks : Array[@pdfv2.PdfV2BlockCandidate]
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate]
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact]
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact]
  fragments : Array[PdfV2FactFragment]
  bridge_options : PdfV2ProductBridgeOptions
  selection_override : (
    PdfV2SignalTraceSelectionPath,
    Bool,
    Array[PdfV2SemanticBlock],
  )?
}

///|
pub fn pdf_v2_target_signal_trace_from_path(
  path : String,
  pipeline_options : PdfV2ConvertPipelineOptions,
  bridge_options : PdfV2ProductBridgeOptions,
) -> Result[PdfV2TargetSignalTraceReport, @cor.AppError] {
  let model = match
    @pdfv2.parse_pdf_v2_model_from_path(path, pipeline_options.parser_options) {
    @pdfv2.ModelAssemblyOk(value) => value
    @pdfv2.ModelAssemblyErr(_, _, message) =>
      return Err(@cor.AppError("pdf-v2 trace parse failed: " + message))
  }
  let layout = @pdfv2.pdf_v2_layout_facts_from_model(model)
  let features = @pdfv2.pdf_v2_features_from_model_and_layout(model, layout)
  let gate_result = pdf_v2_convert_pipeline_gate_result(
    features, pipeline_options,
  )
  let lowered = pdf_v2_lower_fact_model(
    pdf_v2_fact_lowering_input_with_gate(
      model,
      Some(features),
      gate_result,
      pipeline_options.lowering_options,
    ),
  )
  let facts = @pdfv2.pdf_v2_parity_facts_from_model(model)
  let parser_blocks = pdf_v2_trace_flatten_blocks(model)
  Ok(
    pdf_v2_target_signal_trace_report({
      source_name: path,
      page_count: model.page_count,
      parser_blocks,
      candidates: lowered.text_flow_candidates,
      cross_page_facts: facts.cross_page_boundaries,
      heading_facts: facts.heading_boundaries,
      fragments: lowered.fragments,
      bridge_options,
      selection_override: None,
    }),
  )
}

///|
pub fn pdf_v2_target_signal_trace_to_json(
  report : PdfV2TargetSignalTraceReport,
) -> String {
  let heading_items : Array[String] = []
  for heading in report.heading_traces {
    heading_items.push(pdf_v2_signal_trace_heading_json(heading))
  }
  let boundary_items : Array[String] = []
  for boundary in report.boundaries {
    boundary_items.push(pdf_v2_signal_trace_boundary_json(boundary))
  }
  let candidate_block_items : Array[String] = []
  for block in report.candidate_semantic_blocks {
    candidate_block_items.push(pdf_v2_signal_trace_semantic_preview_json(block))
  }
  let selected_block_items : Array[String] = []
  for block in report.selected_semantic_blocks {
    selected_block_items.push(pdf_v2_signal_trace_semantic_preview_json(block))
  }
  @cor.object_json([
    @cor.json_string("source_name") +
    ": " +
    @cor.json_string(report.source_name),
    @cor.json_string("page_count") + ": " + report.page_count.to_string(),
    @cor.json_string("cross_page_fact_count") +
    ": " +
    report.cross_page_fact_count.to_string(),
    @cor.json_string("heading_fact_count") +
    ": " +
    report.heading_fact_count.to_string(),
    @cor.json_string("candidate_semantic_block_count") +
    ": " +
    report.candidate_semantic_block_count.to_string(),
    @cor.json_string("selected_semantic_block_count") +
    ": " +
    report.selected_semantic_block_count.to_string(),
    @cor.json_string("selection") +
    ": " +
    pdf_v2_signal_trace_selection_json(report.selection),
    @cor.json_string("boundaries") + ": " + @cor.array_json(boundary_items),
    @cor.json_string("heading_traces") + ": " + @cor.array_json(heading_items),
    @cor.json_string("candidate_semantic_blocks") +
    ": " +
    @cor.array_json(candidate_block_items),
    @cor.json_string("selected_semantic_blocks") +
    ": " +
    @cor.array_json(selected_block_items),
    @cor.json_string("notes") + ": " + @cor.string_array_json(report.notes),
  ])
}

///|
pub fn pdf_v2_target_signal_trace_to_text(
  report : PdfV2TargetSignalTraceReport,
) -> String {
  let lines : Array[String] = [
    "pdf-v2 target signal trace",
    "source=" + report.source_name,
    "pages=" + report.page_count.to_string(),
    "selection_path=" +
    pdf_v2_signal_trace_selection_path_name(report.selection.path),
    "candidate_semantic_mode=" +
    report.selection.candidate_semantic_mode.to_string(),
    "candidate_backed_emission=" +
    report.selection.candidate_backed_emission.to_string(),
    "structural_handoff_candidate_mode=" +
    report.selection.structural_handoff_candidate_mode.to_string(),
    "cross_page_facts=" + report.cross_page_fact_count.to_string(),
    "heading_facts=" + report.heading_fact_count.to_string(),
    "candidate_semantic_blocks=" +
    report.candidate_semantic_block_count.to_string(),
    "selected_semantic_blocks=" +
    report.selected_semantic_block_count.to_string(),
  ]
  if report.notes.length() > 0 {
    lines.push("notes=" + report.notes.join(" | "))
  }
  for boundary in report.boundaries {
    lines.push("")
    lines.push(
      "[boundary " +
      boundary.page_from.to_string() +
      "->" +
      boundary.page_to.to_string() +
      "] loss_layer=" +
      pdf_v2_signal_trace_loss_layer_name(boundary.loss_layer),
    )
    lines.push(
      "selection_path=" +
      pdf_v2_signal_trace_selection_path_name(boundary.selection_path) +
      " candidate_backed_emission=" +
      boundary.candidate_backed_emission.to_string() +
      " fragment_path_used=" +
      boundary.fragment_path_used.to_string(),
    )
    lines.push(
      "candidate_pair_adjacent=" +
      boundary.candidate_pair_adjacent.to_string() +
      " title_body_boundary_evidence=" +
      boundary.title_body_boundary_evidence.to_string() +
      " next_list_marker_evidence=" +
      boundary.next_list_marker_evidence.to_string(),
    )
    match boundary.parser_prev_block {
      Some(block) =>
        lines.push(
          "parser_prev=page " +
          pdf_v2_signal_trace_page_text(block.page_index) +
          " block " +
          block.block_index.to_string() +
          " text=" +
          pdf_v2_signal_trace_shorten_text(block.text, 120),
        )
      None => lines.push("parser_prev=none")
    }
    match boundary.parser_next_block {
      Some(block) =>
        lines.push(
          "parser_next=page " +
          pdf_v2_signal_trace_page_text(block.page_index) +
          " block " +
          block.block_index.to_string() +
          " text=" +
          pdf_v2_signal_trace_shorten_text(block.text, 120),
        )
      None => lines.push("parser_next=none")
    }
    match boundary.candidate_prev {
      Some(candidate) =>
        lines.push(
          "candidate_prev=flow " +
          candidate.flow_index.to_string() +
          " text=" +
          pdf_v2_signal_trace_shorten_text(candidate.normalized_text, 120),
        )
      None => lines.push("candidate_prev=none")
    }
    match boundary.candidate_next {
      Some(candidate) =>
        lines.push(
          "candidate_next=flow " +
          candidate.flow_index.to_string() +
          " text=" +
          pdf_v2_signal_trace_shorten_text(candidate.normalized_text, 120),
        )
      None => lines.push("candidate_next=none")
    }
    match boundary.cross_page_fact {
      Some(fact) =>
        lines.push(
          "cross_page_fact=confidence " +
          fact.confidence.to_string() +
          " refs=" +
          fact.source_refs.length().to_string() +
          " tags=" +
          fact.reason_tags.join(","),
        )
      None => lines.push("cross_page_fact=none")
    }
    if boundary.heading_facts.length() == 0 {
      lines.push("heading_facts=none")
    } else {
      let heading_parts : Array[String] = []
      for fact in boundary.heading_facts {
        heading_parts.push(
          "page=" +
          pdf_v2_signal_trace_page_text(fact.page_index) +
          " block=" +
          pdf_v2_signal_trace_int_opt_text(fact.block_ref) +
          " conf=" +
          fact.confidence.to_string() +
          " tags=" +
          fact.reason_tags.join(","),
        )
      }
      lines.push("heading_facts=" + heading_parts.join(" | "))
    }
    match boundary.baseline_candidate_pair {
      Some(pair) =>
        lines.push(
          "baseline_candidate_pair=" +
          pdf_v2_signal_trace_semantic_kind_name(pair.left.kind) +
          " -> " +
          pdf_v2_signal_trace_semantic_kind_name(pair.right.kind),
        )
      None => lines.push("baseline_candidate_pair=none")
    }
    match boundary.selected_pair {
      Some(pair) =>
        lines.push(
          "selected_pair=" +
          pdf_v2_signal_trace_semantic_kind_name(pair.left.kind) +
          " -> " +
          pdf_v2_signal_trace_semantic_kind_name(pair.right.kind),
        )
      None => lines.push("selected_pair=none")
    }
    match boundary.structural_handoff {
      Some(handoff) =>
        lines.push(
          "structural_handoff=confidence " +
          handoff.confidence.to_string() +
          " preserve_next_structure=" +
          handoff.should_preserve_next_structure.to_string() +
          " preserve_heading_level=" +
          handoff.should_preserve_heading_level.to_string() +
          " preserve_list_marker=" +
          handoff.should_preserve_list_marker.to_string() +
          " blockers=" +
          handoff.blockers.join(","),
        )
      None => lines.push("structural_handoff=none")
    }
    if boundary.reason_tags.length() > 0 {
      lines.push("reasons=" + boundary.reason_tags.join(","))
    }
  }
  if report.heading_traces.length() > 0 {
    lines.push("")
    lines.push("[heading-traces]")
    for heading in report.heading_traces {
      lines.push(
        "page=" +
        pdf_v2_signal_trace_page_text(heading.page_index) +
        " block=" +
        pdf_v2_signal_trace_int_opt_text(heading.block_ref) +
        " accepted_as_heading=" +
        heading.accepted_as_heading.to_string() +
        " text=" +
        pdf_v2_signal_trace_shorten_text(heading.text, 100),
      )
      lines.push(
        "  confidence=" +
        heading.confidence.to_string() +
        " tags=" +
        heading.reason_tags.join(","),
      )
      match heading.semantic_preview {
        Some(block) =>
          lines.push(
            "  semantic=" +
            pdf_v2_signal_trace_semantic_kind_name(block.kind) +
            " level=" +
            pdf_v2_signal_trace_int_opt_text(block.level),
          )
        None => lines.push("  semantic=none")
      }
    }
  }
  lines.join("\n")
}

///|
fn pdf_v2_target_signal_trace_report(
  input : PdfV2SignalTraceInput,
) -> PdfV2TargetSignalTraceReport {
  let candidate_semantic_blocks = pdf_v2_semantic_blocks_from_candidates(
    input.candidates,
    input.bridge_options,
  )
  let handoffs = pdf_v2_build_cross_page_structural_handoffs(
    candidate_semantic_blocks,
    input.cross_page_facts,
  )
  let selection = match input.selection_override {
    Some((path, candidate_semantic_mode, selected_blocks)) =>
      (
        {
          path,
          candidate_semantic_mode,
          structural_handoff_candidate_mode: path ==
          PdfV2SignalTraceSelectionPath::CandidateStructuralHandoff,
          candidate_backed_emission: candidate_semantic_mode,
        },
        selected_blocks,
      )
    None =>
      pdf_v2_target_signal_trace_select_blocks(
        input.candidates,
        input.fragments,
        input.cross_page_facts,
        input.bridge_options,
      )
  }
  let candidate_semantic_previews : Array[PdfV2SignalTraceSemanticPreview] = []
  for block in candidate_semantic_blocks {
    candidate_semantic_previews.push(
      pdf_v2_signal_trace_semantic_preview(block),
    )
  }
  let selected_semantic_previews : Array[PdfV2SignalTraceSemanticPreview] = []
  for block in selection.1 {
    selected_semantic_previews.push(pdf_v2_signal_trace_semantic_preview(block))
  }
  let boundaries : Array[PdfV2SignalTraceBoundary] = []
  let mut page_from = 0
  while page_from + 1 < input.page_count {
    let page_to = page_from + 1
    boundaries.push(
      pdf_v2_target_signal_trace_boundary(
        page_from,
        page_to,
        input.parser_blocks,
        input.candidates,
        input.cross_page_facts,
        input.heading_facts,
        candidate_semantic_blocks,
        selection.1,
        handoffs,
        selection.0,
      ),
    )
    page_from = page_from + 1
  }
  let heading_traces : Array[PdfV2SignalTraceHeading] = []
  for fact in input.heading_facts {
    heading_traces.push(
      pdf_v2_signal_trace_heading(
        fact,
        input.candidates,
        candidate_semantic_blocks,
      ),
    )
  }
  let notes : Array[String] = []
  if input.cross_page_facts.length() == 0 {
    notes.push("no_cross_page_boundary_facts")
  }
  if handoffs.length() == 0 {
    notes.push("no_cross_page_structural_handoffs")
  }
  {
    source_name: input.source_name,
    page_count: input.page_count,
    cross_page_fact_count: input.cross_page_facts.length(),
    heading_fact_count: input.heading_facts.length(),
    candidate_semantic_block_count: candidate_semantic_blocks.length(),
    selected_semantic_block_count: selection.1.length(),
    selection: selection.0,
    boundaries,
    heading_traces,
    candidate_semantic_blocks: candidate_semantic_previews,
    selected_semantic_blocks: selected_semantic_previews,
    notes,
  }
}

///|
fn pdf_v2_target_signal_trace_select_blocks(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  fragments : Array[PdfV2FactFragment],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  bridge_options : PdfV2ProductBridgeOptions,
) -> (PdfV2SignalTraceSelection, Array[PdfV2SemanticBlock]) {
  if !bridge_options.normalize_plain_text ||
    !bridge_options.enable_semantic_rules {
    return (
      {
        path: PdfV2SignalTraceSelectionPath::SemanticRulesDisabled,
        candidate_semantic_mode: false,
        structural_handoff_candidate_mode: false,
        candidate_backed_emission: false,
      },
      [],
    )
  }
  match
    pdf_v2_structural_handoff_blocks_from_candidates(
      candidates, bridge_options, cross_page_facts,
    ) {
    Some(blocks) =>
      return (
        {
          path: PdfV2SignalTraceSelectionPath::CandidateStructuralHandoff,
          candidate_semantic_mode: true,
          structural_handoff_candidate_mode: true,
          candidate_backed_emission: true,
        },
        blocks,
      )
    None => ()
  }
  if pdf_v2_product_bridge_has_actionable_text_flow_candidates(candidates) {
    if pdf_v2_has_product_cross_page_arbitration_candidate(cross_page_facts) {
      return (
        {
          path: PdfV2SignalTraceSelectionPath::CandidateCrossPageArbitration,
          candidate_semantic_mode: true,
          structural_handoff_candidate_mode: false,
          candidate_backed_emission: true,
        },
        pdf_v2_semantic_blocks_from_candidates_with_cross_page_facts(
          candidates, bridge_options, cross_page_facts,
        ),
      )
    }
    return (
      {
        path: PdfV2SignalTraceSelectionPath::CandidateSemanticActionableTextFlow,
        candidate_semantic_mode: true,
        structural_handoff_candidate_mode: false,
        candidate_backed_emission: true,
      },
      pdf_v2_semantic_blocks_from_candidates(candidates, bridge_options),
    )
  }
  if pdf_v2_has_product_cross_page_arbitration_candidate(cross_page_facts) {
    return (
      {
        path: PdfV2SignalTraceSelectionPath::FragmentCrossPageArbitration,
        candidate_semantic_mode: false,
        structural_handoff_candidate_mode: false,
        candidate_backed_emission: false,
      },
      pdf_v2_semantic_blocks_from_fragments_with_cross_page_facts(
        fragments, bridge_options, cross_page_facts,
      ),
    )
  }
  (
    {
      path: PdfV2SignalTraceSelectionPath::FragmentSemanticFallback,
      candidate_semantic_mode: false,
      structural_handoff_candidate_mode: false,
      candidate_backed_emission: false,
    },
    pdf_v2_semantic_blocks_from_fragments(fragments, bridge_options),
  )
}

///|
fn pdf_v2_target_signal_trace_boundary(
  page_from : Int,
  page_to : Int,
  parser_blocks : Array[@pdfv2.PdfV2BlockCandidate],
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  cross_page_facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact],
  candidate_semantic_blocks : Array[PdfV2SemanticBlock],
  selected_blocks : Array[PdfV2SemanticBlock],
  handoffs : Array[PdfV2CrossPageStructuralHandoff],
  selection : PdfV2SignalTraceSelection,
) -> PdfV2SignalTraceBoundary {
  let parser_prev_block = pdf_v2_trace_last_block_on_page(
    parser_blocks, page_from,
  )
  let parser_next_block = pdf_v2_trace_first_block_on_page(
    parser_blocks, page_to,
  )
  let prev_candidate = pdf_v2_trace_last_candidate_on_page(
    candidates, page_from,
  )
  let next_candidate = pdf_v2_trace_first_candidate_on_page(candidates, page_to)
  let candidate_pair_adjacent = pdf_v2_trace_candidates_adjacent(
    candidates, prev_candidate, next_candidate,
  )
  let matched_fact = pdf_v2_trace_cross_page_fact(
    cross_page_facts, page_from, page_to, prev_candidate, next_candidate,
  )
  let pair_heading_facts = pdf_v2_trace_heading_facts_for_boundary(
    heading_facts, page_from, page_to, prev_candidate, next_candidate, parser_prev_block,
    parser_next_block,
  )
  let baseline_candidate_pair = pdf_v2_trace_semantic_pair_for_page_boundary(
    candidate_semantic_blocks, page_from, page_to,
  )
  let selected_pair = pdf_v2_trace_semantic_pair_for_page_boundary(
    selected_blocks, page_from, page_to,
  )
  let structural_handoff = pdf_v2_trace_structural_handoff(
    handoffs, page_from, page_to,
  )
  let title_body_boundary_evidence = match structural_handoff {
    Some(handoff) => handoff.title_body_boundary_evidence
    None =>
      pdf_v2_trace_candidate_has_title_body_evidence(prev_candidate) ||
      pdf_v2_trace_candidate_has_title_body_evidence(next_candidate) ||
      pdf_v2_trace_parser_has_title_body_evidence(parser_prev_block) ||
      pdf_v2_trace_parser_has_title_body_evidence(parser_next_block)
  }
  let next_list_marker_evidence = match structural_handoff {
    Some(handoff) => handoff.next_list_marker_evidence
    None =>
      match next_candidate {
        Some(candidate) =>
          candidate.reason_tags.contains("inline_list_split") ||
          candidate.boundary_signal.list_candidate_score >= 0.70
        None => false
      }
  }
  let loss = pdf_v2_trace_boundary_loss_layer(
    parser_prev_block, parser_next_block, prev_candidate, next_candidate, candidate_pair_adjacent,
    matched_fact, baseline_candidate_pair, selected_pair, structural_handoff, selection,
    title_body_boundary_evidence, next_list_marker_evidence,
  )
  {
    page_from,
    page_to,
    parser_prev_block: parser_prev_block.map(
      pdf_v2_signal_trace_parser_block_preview,
    ),
    parser_next_block: parser_next_block.map(
      pdf_v2_signal_trace_parser_block_preview,
    ),
    candidate_pair_adjacent,
    candidate_prev: prev_candidate.map(pdf_v2_signal_trace_candidate_preview),
    candidate_next: next_candidate.map(pdf_v2_signal_trace_candidate_preview),
    cross_page_fact: matched_fact,
    heading_facts: pair_heading_facts,
    baseline_candidate_pair: baseline_candidate_pair.map(
      pdf_v2_signal_trace_semantic_pair_preview,
    ),
    selected_pair: selected_pair.map(pdf_v2_signal_trace_semantic_pair_preview),
    structural_handoff,
    title_body_boundary_evidence,
    next_list_marker_evidence,
    selection_path: selection.path,
    candidate_backed_emission: selection.candidate_backed_emission,
    fragment_path_used: !selection.candidate_backed_emission,
    loss_layer: loss.0,
    reason_tags: loss.1,
  }
}

///|
fn pdf_v2_trace_boundary_loss_layer(
  parser_prev_block : @pdfv2.PdfV2BlockCandidate?,
  parser_next_block : @pdfv2.PdfV2BlockCandidate?,
  prev_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  next_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  candidate_pair_adjacent : Bool,
  matched_fact : @pdfv2.PdfV2CrossPageBoundaryFact?,
  baseline_candidate_pair : (PdfV2SemanticBlock, PdfV2SemanticBlock)?,
  selected_pair : (PdfV2SemanticBlock, PdfV2SemanticBlock)?,
  structural_handoff : PdfV2CrossPageStructuralHandoff?,
  selection : PdfV2SignalTraceSelection,
  title_body_boundary_evidence : Bool,
  next_list_marker_evidence : Bool,
) -> (PdfV2SignalTraceLossLayer, Array[String]) {
  let reasons : Array[String] = []
  if parser_prev_block is None || parser_next_block is None {
    reasons.push("parser_boundary_blocks_missing")
    return (PdfV2SignalTraceLossLayer::ParserModelExtractionLoss, reasons)
  }
  if prev_candidate is None || next_candidate is None {
    reasons.push("page_boundary_candidates_missing")
    return (PdfV2SignalTraceLossLayer::ParserCandidateFactLoss, reasons)
  }
  if !candidate_pair_adjacent {
    reasons.push("page_boundary_candidates_not_adjacent")
  }
  if matched_fact is None {
    reasons.push("cross_page_boundary_fact_missing")
    if title_body_boundary_evidence {
      reasons.push("title_body_evidence_without_cross_page_fact")
    }
    return (PdfV2SignalTraceLossLayer::ParserCandidateFactLoss, reasons)
  }
  match matched_fact {
    Some(fact) =>
      if fact.source_refs.length() == 0 {
        reasons.push("missing_source_refs")
        return (PdfV2SignalTraceLossLayer::ParserCandidateFactLoss, reasons)
      }
    None => ()
  }
  if baseline_candidate_pair is None {
    reasons.push("candidate_semantic_boundary_pair_missing")
    if title_body_boundary_evidence {
      reasons.push("title_body_boundary_merged_before_semantic_boundary")
    }
    if next_list_marker_evidence {
      reasons.push("next_page_structure_not_visible_in_candidate_semantics")
    }
    return (PdfV2SignalTraceLossLayer::SemanticCandidateBlockLoss, reasons)
  }
  match baseline_candidate_pair {
    Some((_, right_block)) => {
      if title_body_boundary_evidence &&
        right_block.kind == PdfV2SemanticBlockKind::Paragraph {
        reasons.push("title_body_boundary_merged_before_semantic_boundary")
        return (PdfV2SignalTraceLossLayer::SemanticCandidateBlockLoss, reasons)
      }
      if next_list_marker_evidence &&
        !pdf_v2_semantic_kind_is_list(right_block.kind) {
        reasons.push("next_page_structure_not_visible_in_candidate_semantics")
        return (PdfV2SignalTraceLossLayer::SemanticCandidateBlockLoss, reasons)
      }
    }
    None => ()
  }
  match structural_handoff {
    Some(handoff) =>
      if pdf_v2_cross_page_structural_handoff_requires_candidate_semantics(
          handoff,
        ) &&
        selection.path !=
        PdfV2SignalTraceSelectionPath::CandidateStructuralHandoff {
        reasons.push("structural_handoff_present")
        reasons.push("candidate_structural_handoff_path_not_selected")
        return (PdfV2SignalTraceLossLayer::BridgeLoweringPathLoss, reasons)
      } else if selection.path !=
        PdfV2SignalTraceSelectionPath::CandidateStructuralHandoff &&
        (
          handoff.blockers.length() > 0 ||
          title_body_boundary_evidence ||
          next_list_marker_evidence
        ) {
        reasons.push("structural_handoff_not_selected")
        reasons.append(handoff.blockers)
        return (
          PdfV2SignalTraceLossLayer::StructuralHandoffGateRejection,
          reasons,
        )
      }
    None =>
      if title_body_boundary_evidence || next_list_marker_evidence {
        reasons.push("structural_handoff_missing_despite_boundary_evidence")
        return (PdfV2SignalTraceLossLayer::SemanticCandidateBlockLoss, reasons)
      }
  }
  if selection.candidate_backed_emission && selected_pair is None {
    reasons.push("selected_candidate_backed_boundary_pair_missing")
    return (PdfV2SignalTraceLossLayer::BridgeLoweringPathLoss, reasons)
  }
  if !selection.candidate_backed_emission {
    reasons.push("fragment_path_selected")
    return (
      PdfV2SignalTraceLossLayer::ExpectedOutputNotOwnedByStructuralHandoff,
      reasons,
    )
  }
  (PdfV2SignalTraceLossLayer::NoLossDetected, reasons)
}

///|
fn pdf_v2_signal_trace_heading(
  fact : @pdfv2.PdfV2HeadingBoundaryFact,
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  candidate_semantic_blocks : Array[PdfV2SemanticBlock],
) -> PdfV2SignalTraceHeading {
  let candidate = pdf_v2_trace_candidate_for_heading_fact(candidates, fact)
  let semantic = pdf_v2_trace_semantic_for_heading_fact(
    candidate_semantic_blocks, fact,
  )
  {
    page_index: fact.page_index,
    block_ref: fact.block_ref,
    line_refs: fact.line_refs,
    text: match candidate {
      Some(value) => value.normalized_text
      None => ""
    },
    confidence: fact.confidence,
    reason_tags: fact.reason_tags,
    semantic_preview: semantic.map(pdf_v2_signal_trace_semantic_preview),
    accepted_as_heading: match semantic {
      Some(block) => block.kind == PdfV2SemanticBlockKind::Heading
      None => false
    },
  }
}

///|
fn pdf_v2_trace_flatten_blocks(
  model : @pdfv2.PdfV2DocumentModel,
) -> Array[@pdfv2.PdfV2BlockCandidate] {
  let out : Array[@pdfv2.PdfV2BlockCandidate] = []
  for page in model.pages {
    out.append(page.blocks)
  }
  out
}

///|
fn pdf_v2_trace_last_block_on_page(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
  page_index : Int,
) -> @pdfv2.PdfV2BlockCandidate? {
  let mut best : @pdfv2.PdfV2BlockCandidate? = None
  for block in blocks {
    if block.page_index == Some(page_index) {
      match best {
        Some(current) =>
          if block.block_index > current.block_index {
            best = Some(block)
          }
        None => best = Some(block)
      }
    }
  }
  best
}

///|
fn pdf_v2_trace_first_block_on_page(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
  page_index : Int,
) -> @pdfv2.PdfV2BlockCandidate? {
  let mut best : @pdfv2.PdfV2BlockCandidate? = None
  for block in blocks {
    if block.page_index == Some(page_index) {
      match best {
        Some(current) =>
          if block.block_index < current.block_index {
            best = Some(block)
          }
        None => best = Some(block)
      }
    }
  }
  best
}

///|
fn pdf_v2_trace_last_candidate_on_page(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  page_index : Int,
) -> @pdfv2.PdfV2TextFlowCandidate? {
  let ordered = pdf_v2_trace_ordered_candidates(candidates)
  let mut best : @pdfv2.PdfV2TextFlowCandidate? = None
  for candidate in ordered {
    if candidate.page_index == Some(page_index) {
      best = Some(candidate)
    }
  }
  best
}

///|
fn pdf_v2_trace_first_candidate_on_page(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  page_index : Int,
) -> @pdfv2.PdfV2TextFlowCandidate? {
  let ordered = pdf_v2_trace_ordered_candidates(candidates)
  for candidate in ordered {
    if candidate.page_index == Some(page_index) {
      return Some(candidate)
    }
  }
  None
}

///|
fn pdf_v2_trace_candidates_adjacent(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  prev_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  next_candidate : @pdfv2.PdfV2TextFlowCandidate?,
) -> Bool {
  match (prev_candidate, next_candidate) {
    (Some(prev), Some(next)) =>
      for index in 0..<candidates.length() {
        let candidate = candidates[index]
        if candidate.flow_index == prev.flow_index &&
          index + 1 < candidates.length() &&
          candidates[index + 1].flow_index == next.flow_index {
          return true
        }
      }
    _ => ()
  }
  false
}

///|
fn pdf_v2_trace_cross_page_fact(
  facts : Array[@pdfv2.PdfV2CrossPageBoundaryFact],
  page_from : Int,
  page_to : Int,
  prev_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  next_candidate : @pdfv2.PdfV2TextFlowCandidate?,
) -> @pdfv2.PdfV2CrossPageBoundaryFact? {
  for fact in facts {
    if fact.page_from != page_from || fact.page_to != page_to {
      continue
    }
    match (prev_candidate, next_candidate) {
      (Some(prev), Some(next)) =>
        if fact.prev_block_ref == prev.block_index &&
          fact.next_block_ref == next.block_index {
          return Some(fact)
        }
      _ => ()
    }
  }
  for fact in facts {
    if fact.page_from == page_from && fact.page_to == page_to {
      return Some(fact)
    }
  }
  None
}

///|
fn pdf_v2_trace_heading_facts_for_boundary(
  heading_facts : Array[@pdfv2.PdfV2HeadingBoundaryFact],
  page_from : Int,
  page_to : Int,
  prev_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  next_candidate : @pdfv2.PdfV2TextFlowCandidate?,
  parser_prev_block : @pdfv2.PdfV2BlockCandidate?,
  parser_next_block : @pdfv2.PdfV2BlockCandidate?,
) -> Array[@pdfv2.PdfV2HeadingBoundaryFact] {
  let out : Array[@pdfv2.PdfV2HeadingBoundaryFact] = []
  let prev_block_ref = match prev_candidate {
    Some(candidate) => candidate.block_index
    None =>
      parser_prev_block
      .map(fn(block) { Some(block.block_index) })
      .unwrap_or(None)
  }
  let next_block_ref = match next_candidate {
    Some(candidate) => candidate.block_index
    None =>
      parser_next_block
      .map(fn(block) { Some(block.block_index) })
      .unwrap_or(None)
  }
  for fact in heading_facts {
    if fact.page_index == Some(page_to) {
      match next_block_ref {
        Some(block_ref) =>
          if fact.block_ref == Some(block_ref) || fact.block_ref is None {
            out.push(fact)
          }
        None => out.push(fact)
      }
    } else if fact.page_index == Some(page_from) {
      match prev_block_ref {
        Some(block_ref) =>
          if fact.block_ref == Some(block_ref) {
            out.push(fact)
          }
        None => ()
      }
    }
  }
  out
}

///|
fn pdf_v2_trace_semantic_pair_for_page_boundary(
  blocks : Array[PdfV2SemanticBlock],
  page_from : Int,
  page_to : Int,
) -> (PdfV2SemanticBlock, PdfV2SemanticBlock)? {
  let mut i = 0
  while i + 1 < blocks.length() {
    let left = blocks[i]
    let right = blocks[i + 1]
    if left.page_index == Some(page_from) && right.page_index == Some(page_to) {
      return Some((left, right))
    }
    i = i + 1
  }
  None
}

///|
fn pdf_v2_trace_structural_handoff(
  handoffs : Array[PdfV2CrossPageStructuralHandoff],
  page_from : Int,
  page_to : Int,
) -> PdfV2CrossPageStructuralHandoff? {
  for handoff in handoffs {
    if handoff.page_from == page_from && handoff.page_to == page_to {
      return Some(handoff)
    }
  }
  None
}

///|
fn pdf_v2_trace_candidate_has_title_body_evidence(
  candidate : @pdfv2.PdfV2TextFlowCandidate?,
) -> Bool {
  match candidate {
    Some(value) => value.reason_tags.contains("heading_body_split")
    None => false
  }
}

///|

///|
fn pdf_v2_trace_parser_has_title_body_evidence(
  block : @pdfv2.PdfV2BlockCandidate?,
) -> Bool {
  match block {
    Some(value) => value.reason_tags.contains("heading_body_split")
    None => false
  }
}

///|
fn pdf_v2_trace_candidate_for_heading_fact(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
  fact : @pdfv2.PdfV2HeadingBoundaryFact,
) -> @pdfv2.PdfV2TextFlowCandidate? {
  for candidate in candidates {
    if candidate.page_index != fact.page_index {
      continue
    }
    if fact.block_ref is Some(block_ref) &&
      candidate.block_index != Some(block_ref) {
      continue
    }
    if fact.line_refs.length() > 0 {
      let mut matched_line_ref = false
      for line_ref in fact.line_refs {
        if candidate.line_indices.contains(line_ref) {
          matched_line_ref = true
          break
        }
      }
      if !matched_line_ref {
        continue
      }
    }
    return Some(candidate)
  }
  None
}

///|
fn pdf_v2_trace_semantic_for_heading_fact(
  blocks : Array[PdfV2SemanticBlock],
  fact : @pdfv2.PdfV2HeadingBoundaryFact,
) -> PdfV2SemanticBlock? {
  for block in blocks {
    if block.page_index != fact.page_index {
      continue
    }
    if fact.block_ref is Some(block_ref) && block.block_index != Some(block_ref) {
      continue
    }
    if fact.source_refs.length() > 0 &&
      pdf_v2_source_refs_overlap(block.source_refs, fact.source_refs) {
      return Some(block)
    }
  }
  for block in blocks {
    if block.page_index == fact.page_index &&
      block.block_index == fact.block_ref {
      return Some(block)
    }
  }
  None
}

///|
fn pdf_v2_signal_trace_parser_block_preview(
  block : @pdfv2.PdfV2BlockCandidate,
) -> PdfV2SignalTraceParserBlockPreview {
  let lines : Array[String] = []
  for line in block.lines {
    lines.push(line.text_signal.normalized_text)
  }
  {
    page_index: block.page_index,
    block_index: block.block_index,
    text: block.text,
    lines,
    source_refs: block.source_refs,
    reason_tags: block.reason_tags,
  }
}

///|
fn pdf_v2_signal_trace_candidate_preview(
  candidate : @pdfv2.PdfV2TextFlowCandidate,
) -> PdfV2SignalTraceCandidatePreview {
  let starts_with_list_marker = candidate.boundary_signal.list_candidate_score >=
    0.70
  {
    page_index: candidate.page_index,
    block_index: candidate.block_index,
    flow_index: candidate.flow_index,
    line_indices: candidate.line_indices,
    text: candidate.text,
    normalized_text: candidate.normalized_text,
    source_refs: candidate.source_refs,
    reason_tags: candidate.reason_tags,
    starts_with_list_marker,
    title_body_boundary_evidence: candidate.reason_tags.contains(
      "heading_body_split",
    ),
  }
}

///|
fn pdf_v2_signal_trace_semantic_preview(
  block : PdfV2SemanticBlock,
) -> PdfV2SignalTraceSemanticPreview {
  {
    kind: block.kind,
    text: block.text,
    level: block.level,
    page_index: block.page_index,
    block_index: block.block_index,
    fragment_index: block.fragment_index,
    source_refs: block.source_refs,
    reason_tags: block.reason_tags,
    negative_reason_tags: block.decision.negative_reason_tags,
  }
}

///|
fn pdf_v2_signal_trace_semantic_pair_preview(
  pair : (PdfV2SemanticBlock, PdfV2SemanticBlock),
) -> PdfV2SignalTraceSemanticPair {
  {
    left: pdf_v2_signal_trace_semantic_preview(pair.0),
    right: pdf_v2_signal_trace_semantic_preview(pair.1),
  }
}

///|
fn pdf_v2_trace_ordered_candidates(
  candidates : Array[@pdfv2.PdfV2TextFlowCandidate],
) -> Array[@pdfv2.PdfV2TextFlowCandidate] {
  let ordered : Array[@pdfv2.PdfV2TextFlowCandidate] = []
  ordered.append(candidates)
  ordered.sort_by(fn(a, b) { a.flow_index - b.flow_index })
  ordered
}

///|
fn pdf_v2_signal_trace_selection_json(
  selection : PdfV2SignalTraceSelection,
) -> String {
  @cor.object_json([
    @cor.json_string("path") +
    ": " +
    @cor.json_string(pdf_v2_signal_trace_selection_path_name(selection.path)),
    @cor.json_string("candidate_semantic_mode") +
    ": " +
    @cor.bool_json(selection.candidate_semantic_mode),
    @cor.json_string("structural_handoff_candidate_mode") +
    ": " +
    @cor.bool_json(selection.structural_handoff_candidate_mode),
    @cor.json_string("candidate_backed_emission") +
    ": " +
    @cor.bool_json(selection.candidate_backed_emission),
  ])
}

///|
fn pdf_v2_signal_trace_boundary_json(
  boundary : PdfV2SignalTraceBoundary,
) -> String {
  let heading_items : Array[String] = []
  for fact in boundary.heading_facts {
    heading_items.push(pdf_v2_signal_trace_heading_fact_json(fact))
  }
  @cor.object_json([
    @cor.json_string("page_from") + ": " + boundary.page_from.to_string(),
    @cor.json_string("page_to") + ": " + boundary.page_to.to_string(),
    @cor.json_string("parser_prev_block") +
    ": " +
    pdf_v2_signal_trace_parser_block_opt_json(boundary.parser_prev_block),
    @cor.json_string("parser_next_block") +
    ": " +
    pdf_v2_signal_trace_parser_block_opt_json(boundary.parser_next_block),
    @cor.json_string("candidate_pair_adjacent") +
    ": " +
    @cor.bool_json(boundary.candidate_pair_adjacent),
    @cor.json_string("candidate_prev") +
    ": " +
    pdf_v2_signal_trace_candidate_opt_json(boundary.candidate_prev),
    @cor.json_string("candidate_next") +
    ": " +
    pdf_v2_signal_trace_candidate_opt_json(boundary.candidate_next),
    @cor.json_string("cross_page_fact") +
    ": " +
    pdf_v2_signal_trace_cross_page_fact_opt_json(boundary.cross_page_fact),
    @cor.json_string("heading_facts") + ": " + @cor.array_json(heading_items),
    @cor.json_string("baseline_candidate_pair") +
    ": " +
    pdf_v2_signal_trace_semantic_pair_opt_json(boundary.baseline_candidate_pair),
    @cor.json_string("selected_pair") +
    ": " +
    pdf_v2_signal_trace_semantic_pair_opt_json(boundary.selected_pair),
    @cor.json_string("structural_handoff") +
    ": " +
    pdf_v2_signal_trace_structural_handoff_opt_json(boundary.structural_handoff),
    @cor.json_string("title_body_boundary_evidence") +
    ": " +
    @cor.bool_json(boundary.title_body_boundary_evidence),
    @cor.json_string("next_list_marker_evidence") +
    ": " +
    @cor.bool_json(boundary.next_list_marker_evidence),
    @cor.json_string("selection_path") +
    ": " +
    @cor.json_string(
      pdf_v2_signal_trace_selection_path_name(boundary.selection_path),
    ),
    @cor.json_string("candidate_backed_emission") +
    ": " +
    @cor.bool_json(boundary.candidate_backed_emission),
    @cor.json_string("fragment_path_used") +
    ": " +
    @cor.bool_json(boundary.fragment_path_used),
    @cor.json_string("loss_layer") +
    ": " +
    @cor.json_string(pdf_v2_signal_trace_loss_layer_name(boundary.loss_layer)),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(boundary.reason_tags),
  ])
}

///|
fn pdf_v2_signal_trace_heading_json(
  heading : PdfV2SignalTraceHeading,
) -> String {
  @cor.object_json([
    @cor.json_string("page_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(heading.page_index),
    @cor.json_string("block_ref") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(heading.block_ref),
    @cor.json_string("line_refs") +
    ": " +
    pdf_v2_signal_trace_int_array_json(heading.line_refs),
    @cor.json_string("text") + ": " + @cor.json_string(heading.text),
    @cor.json_string("confidence") + ": " + heading.confidence.to_string(),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(heading.reason_tags),
    @cor.json_string("semantic_preview") +
    ": " +
    pdf_v2_signal_trace_semantic_opt_json(heading.semantic_preview),
    @cor.json_string("accepted_as_heading") +
    ": " +
    @cor.bool_json(heading.accepted_as_heading),
  ])
}

///|
fn pdf_v2_signal_trace_parser_block_opt_json(
  block : PdfV2SignalTraceParserBlockPreview?,
) -> String {
  match block {
    Some(value) => pdf_v2_signal_trace_parser_block_json(value)
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_candidate_opt_json(
  candidate : PdfV2SignalTraceCandidatePreview?,
) -> String {
  match candidate {
    Some(value) => pdf_v2_signal_trace_candidate_json(value)
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_cross_page_fact_opt_json(
  fact : @pdfv2.PdfV2CrossPageBoundaryFact?,
) -> String {
  match fact {
    Some(value) => pdf_v2_signal_trace_cross_page_fact_json(value)
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_semantic_pair_opt_json(
  pair : PdfV2SignalTraceSemanticPair?,
) -> String {
  match pair {
    Some(value) =>
      @cor.object_json([
        @cor.json_string("left") +
        ": " +
        pdf_v2_signal_trace_semantic_preview_json(value.left),
        @cor.json_string("right") +
        ": " +
        pdf_v2_signal_trace_semantic_preview_json(value.right),
      ])
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_structural_handoff_opt_json(
  handoff : PdfV2CrossPageStructuralHandoff?,
) -> String {
  match handoff {
    Some(value) => pdf_v2_signal_trace_structural_handoff_json(value)
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_semantic_opt_json(
  block : PdfV2SignalTraceSemanticPreview?,
) -> String {
  match block {
    Some(value) => pdf_v2_signal_trace_semantic_preview_json(value)
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_parser_block_json(
  block : PdfV2SignalTraceParserBlockPreview,
) -> String {
  @cor.object_json([
    @cor.json_string("page_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(block.page_index),
    @cor.json_string("block_index") + ": " + block.block_index.to_string(),
    @cor.json_string("text") + ": " + @cor.json_string(block.text),
    @cor.json_string("lines") + ": " + @cor.string_array_json(block.lines),
    @cor.json_string("source_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(block.source_refs),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(block.reason_tags),
  ])
}

///|
fn pdf_v2_signal_trace_candidate_json(
  candidate : PdfV2SignalTraceCandidatePreview,
) -> String {
  @cor.object_json([
    @cor.json_string("page_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(candidate.page_index),
    @cor.json_string("block_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(candidate.block_index),
    @cor.json_string("flow_index") + ": " + candidate.flow_index.to_string(),
    @cor.json_string("line_indices") +
    ": " +
    pdf_v2_signal_trace_int_array_json(candidate.line_indices),
    @cor.json_string("text") + ": " + @cor.json_string(candidate.text),
    @cor.json_string("normalized_text") +
    ": " +
    @cor.json_string(candidate.normalized_text),
    @cor.json_string("source_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(candidate.source_refs),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(candidate.reason_tags),
    @cor.json_string("starts_with_list_marker") +
    ": " +
    @cor.bool_json(candidate.starts_with_list_marker),
    @cor.json_string("title_body_boundary_evidence") +
    ": " +
    @cor.bool_json(candidate.title_body_boundary_evidence),
  ])
}

///|
fn pdf_v2_signal_trace_cross_page_fact_json(
  fact : @pdfv2.PdfV2CrossPageBoundaryFact,
) -> String {
  @cor.object_json([
    @cor.json_string("page_from") + ": " + fact.page_from.to_string(),
    @cor.json_string("page_to") + ": " + fact.page_to.to_string(),
    @cor.json_string("prev_block_ref") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(fact.prev_block_ref),
    @cor.json_string("next_block_ref") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(fact.next_block_ref),
    @cor.json_string("prev_line_refs") +
    ": " +
    pdf_v2_signal_trace_int_array_json(fact.prev_line_refs),
    @cor.json_string("next_line_refs") +
    ": " +
    pdf_v2_signal_trace_int_array_json(fact.next_line_refs),
    @cor.json_string("prev_open_ended") +
    ": " +
    @cor.bool_json(fact.prev_open_ended),
    @cor.json_string("next_starts_with_marker") +
    ": " +
    @cor.bool_json(fact.next_starts_with_marker),
    @cor.json_string("repeated_artifact_gap") +
    ": " +
    @cor.bool_json(fact.repeated_artifact_gap),
    @cor.json_string("confidence") + ": " + fact.confidence.to_string(),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(fact.reason_tags),
    @cor.json_string("source_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(fact.source_refs),
  ])
}

///|
fn pdf_v2_signal_trace_heading_fact_json(
  fact : @pdfv2.PdfV2HeadingBoundaryFact,
) -> String {
  @cor.object_json([
    @cor.json_string("page_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(fact.page_index),
    @cor.json_string("block_ref") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(fact.block_ref),
    @cor.json_string("line_refs") +
    ": " +
    pdf_v2_signal_trace_int_array_json(fact.line_refs),
    @cor.json_string("confidence") + ": " + fact.confidence.to_string(),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(fact.reason_tags),
    @cor.json_string("source_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(fact.source_refs),
  ])
}

///|
fn pdf_v2_signal_trace_structural_handoff_json(
  handoff : PdfV2CrossPageStructuralHandoff,
) -> String {
  @cor.object_json([
    @cor.json_string("boundary_index") +
    ": " +
    handoff.boundary_index.to_string(),
    @cor.json_string("page_from") + ": " + handoff.page_from.to_string(),
    @cor.json_string("page_to") + ": " + handoff.page_to.to_string(),
    @cor.json_string("prev_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(handoff.prev_refs),
    @cor.json_string("next_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(handoff.next_refs),
    @cor.json_string("prev_block_kind") +
    ": " +
    @cor.json_string(
      pdf_v2_signal_trace_semantic_kind_name(handoff.prev_block_kind),
    ),
    @cor.json_string("next_block_kind") +
    ": " +
    @cor.json_string(
      pdf_v2_signal_trace_semantic_kind_name(handoff.next_block_kind),
    ),
    @cor.json_string("prev_heading_level") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(handoff.prev_heading_level),
    @cor.json_string("next_heading_level") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(handoff.next_heading_level),
    @cor.json_string("next_list_marker_evidence") +
    ": " +
    @cor.bool_json(handoff.next_list_marker_evidence),
    @cor.json_string("prev_open_ended") +
    ": " +
    @cor.bool_json(handoff.prev_open_ended),
    @cor.json_string("next_starts_structural_block") +
    ": " +
    @cor.bool_json(handoff.next_starts_structural_block),
    @cor.json_string("title_body_boundary_evidence") +
    ": " +
    @cor.bool_json(handoff.title_body_boundary_evidence),
    @cor.json_string("should_join_paragraph") +
    ": " +
    @cor.bool_json(handoff.should_join_paragraph),
    @cor.json_string("should_preserve_next_structure") +
    ": " +
    @cor.bool_json(handoff.should_preserve_next_structure),
    @cor.json_string("should_preserve_heading_level") +
    ": " +
    @cor.bool_json(handoff.should_preserve_heading_level),
    @cor.json_string("should_preserve_list_marker") +
    ": " +
    @cor.bool_json(handoff.should_preserve_list_marker),
    @cor.json_string("confidence") + ": " + handoff.confidence.to_string(),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(handoff.reason_tags),
    @cor.json_string("blockers") +
    ": " +
    @cor.string_array_json(handoff.blockers),
  ])
}

///|
fn pdf_v2_signal_trace_semantic_preview_json(
  block : PdfV2SignalTraceSemanticPreview,
) -> String {
  @cor.object_json([
    @cor.json_string("kind") +
    ": " +
    @cor.json_string(pdf_v2_signal_trace_semantic_kind_name(block.kind)),
    @cor.json_string("text") + ": " + @cor.json_string(block.text),
    @cor.json_string("level") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(block.level),
    @cor.json_string("page_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(block.page_index),
    @cor.json_string("block_index") +
    ": " +
    pdf_v2_signal_trace_int_opt_json(block.block_index),
    @cor.json_string("fragment_index") + ": " + block.fragment_index.to_string(),
    @cor.json_string("source_refs") +
    ": " +
    pdf_v2_signal_trace_source_ref_array_json(block.source_refs),
    @cor.json_string("reason_tags") +
    ": " +
    @cor.string_array_json(block.reason_tags),
    @cor.json_string("negative_reason_tags") +
    ": " +
    @cor.string_array_json(block.negative_reason_tags),
  ])
}

///|
fn pdf_v2_signal_trace_source_ref_array_json(
  refs : Array[@pdfv2.PdfV2SourceRef],
) -> String {
  let items : Array[String] = []
  for source_ref in refs {
    items.push(
      @cor.object_json([
        @cor.json_string("page_index") +
        ": " +
        pdf_v2_signal_trace_int_opt_json(source_ref.page_index),
        @cor.json_string("object_id") +
        ": " +
        @cor.json_string_opt(source_ref.object_id),
        @cor.json_string("stream_index") +
        ": " +
        pdf_v2_signal_trace_int_opt_json(source_ref.stream_index),
        @cor.json_string("op_index") +
        ": " +
        pdf_v2_signal_trace_int_opt_json(source_ref.op_index),
        @cor.json_string("content_order_index") +
        ": " +
        pdf_v2_signal_trace_int_opt_json(source_ref.content_order_index),
        @cor.json_string("kind") +
        ": " +
        @cor.json_string(pdf_v2_signal_trace_source_kind_name(source_ref.kind)),
      ]),
    )
  }
  @cor.array_json(items)
}

///|
fn pdf_v2_signal_trace_int_opt_json(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "null"
  }
}

///|
fn pdf_v2_signal_trace_int_array_json(values : Array[Int]) -> String {
  let items : Array[String] = []
  for value in values {
    items.push(value.to_string())
  }
  @cor.array_json(items)
}

///|
fn pdf_v2_signal_trace_selection_path_name(
  path : PdfV2SignalTraceSelectionPath,
) -> String {
  match path {
    CandidateStructuralHandoff => "candidate_structural_handoff"
    CandidateCrossPageArbitration => "candidate_cross_page_arbitration"
    CandidateSemanticActionableTextFlow =>
      "candidate_semantic_actionable_text_flow"
    FragmentCrossPageArbitration => "fragment_cross_page_arbitration"
    FragmentSemanticFallback => "fragment_semantic_fallback"
    SemanticRulesDisabled => "semantic_rules_disabled"
  }
}

///|
fn pdf_v2_signal_trace_loss_layer_name(
  layer : PdfV2SignalTraceLossLayer,
) -> String {
  match layer {
    NoLossDetected => "no_loss_detected"
    ParserModelExtractionLoss => "parser_model_extraction_loss"
    ParserCandidateFactLoss => "parser_candidate_fact_loss"
    SemanticCandidateBlockLoss => "semantic_candidate_block_loss"
    StructuralHandoffGateRejection => "structural_handoff_gate_rejection"
    BridgeLoweringPathLoss => "bridge_lowering_path_loss"
    ExpectedOutputNotOwnedByStructuralHandoff =>
      "expected_output_not_owned_by_structural_handoff"
  }
}

///|
fn pdf_v2_signal_trace_semantic_kind_name(
  kind : PdfV2SemanticBlockKind,
) -> String {
  match kind {
    Paragraph => "Paragraph"
    Heading => "Heading"
    OrderedListItem => "OrderedListItem"
    UnorderedListItem => "UnorderedListItem"
    Continuation => "Continuation"
    PlainText => "PlainText"
    Unknown => "Unknown"
  }
}

///|
fn pdf_v2_signal_trace_source_kind_name(
  kind : @pdfv2.PdfV2SourceKind,
) -> String {
  match kind {
    @pdfv2.PdfV2SourceKind::Document => "Document"
    @pdfv2.PdfV2SourceKind::Page => "Page"
    @pdfv2.PdfV2SourceKind::ContentStream => "ContentStream"
    @pdfv2.PdfV2SourceKind::Object => "Object"
    @pdfv2.PdfV2SourceKind::TextOp => "TextOp"
    @pdfv2.PdfV2SourceKind::Glyph => "Glyph"
    @pdfv2.PdfV2SourceKind::Image => "Image"
    @pdfv2.PdfV2SourceKind::InlineImage => "InlineImage"
    @pdfv2.PdfV2SourceKind::Vector => "Vector"
    @pdfv2.PdfV2SourceKind::Annotation => "Annotation"
    @pdfv2.PdfV2SourceKind::Form => "Form"
    @pdfv2.PdfV2SourceKind::Outline => "Outline"
    @pdfv2.PdfV2SourceKind::Destination => "Destination"
    @pdfv2.PdfV2SourceKind::Metadata => "Metadata"
    @pdfv2.PdfV2SourceKind::Resource => "Resource"
    @pdfv2.PdfV2SourceKind::Malformed => "Malformed"
    @pdfv2.PdfV2SourceKind::Unsupported => "Unsupported"
    @pdfv2.PdfV2SourceKind::Unknown => "Unknown"
  }
}

///|
fn pdf_v2_signal_trace_page_text(page_index : Int?) -> String {
  match page_index {
    Some(value) => value.to_string()
    None => "unknown"
  }
}

///|
fn pdf_v2_signal_trace_int_opt_text(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "none"
  }
}

///|
fn pdf_v2_signal_trace_shorten_text(text : String, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  let chars = text.to_array()
  if chars.length() <= limit {
    text
  } else {
    String::from_array(chars[:limit]) + "..."
  }
}
