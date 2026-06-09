///|
pub(all) enum PdfV2LayoutRegionKind {
  Page
  Body
  Paragraph
  Table
  Figure
  Image
  Caption
  Header
  Footer
  PageNumber
  Annotation
  Form
  MultiColumn
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2LayoutRegionSource {
  DeterministicRule
  ModelHint
  CombinedGate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2LayoutRegionConfidence {
  High
  Medium
  Low
  Abstained
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2ReadingOrderSource {
  SourceOrder
  GeometryOrder
  ModelHint
  CombinedGate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2CrossPageBoundaryKind {
  MergeCandidate
  NoMergeCandidate
  Uncertain
} derive(Eq)

///|
pub(all) enum PdfV2CrossPageBoundarySource {
  DeterministicRule
  ModelHint
  CombinedGate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2LayoutRiskKind {
  MultiColumnRisk
  ReadingOrderUncertain
  CrossPageBoundaryUncertain
  GeometryInconsistent
  SourceOrderInconsistent
  RegionOverlapAmbiguous
  LowSignalLayout
  MalformedLayout
  ImageOnlyPage
  OcrRecommendedButNotFallback
  ModelHintConflict
} derive(Eq)

///|
pub(all) enum PdfV2LayoutHintTargetKind {
  Region
  ReadingOrder
  CrossPageBoundary
} derive(Eq)

///|
pub(all) enum PdfV2LayoutDecisionSource {
  DeterministicRule
  ModelHint
  CombinedGate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2LayoutDecisionTrace {
  deterministic_constraint_score : Double
  model_confidence : Double
  feature_support_score : Double
  risk_penalty : Double
  final_confidence : Double
  decision_source : PdfV2LayoutDecisionSource
  abstain : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutHint {
  id : String
  target_kind : PdfV2LayoutHintTargetKind
  page_index : Int?
  target_id : String?
  region_kind : PdfV2LayoutRegionKind?
  boundary_kind : PdfV2CrossPageBoundaryKind?
  confidence : Double
  feature_support_score : Double
  source : PdfV2LayoutDecisionSource
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutRisk {
  kind : PdfV2LayoutRiskKind
  risk : @pdfv2.PdfV2Risk
  decision_trace : PdfV2LayoutDecisionTrace
}

///|
pub(all) struct PdfV2LayoutRegion {
  id : String
  page_index : Int
  kind : PdfV2LayoutRegionKind
  bbox : @pdfv2.PdfV2Rect
  confidence : PdfV2LayoutRegionConfidence
  confidence_score : Double
  source : PdfV2LayoutRegionSource
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  member_block_ids : Array[String]
  member_line_ids : Array[String]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
  decision_trace : PdfV2LayoutDecisionTrace
}

///|
pub(all) struct PdfV2ReadingOrderCandidate {
  page_index : Int
  ordered_block_ids : Array[String]
  confidence : Double
  source : PdfV2ReadingOrderSource
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
  decision_trace : PdfV2LayoutDecisionTrace
}

///|
pub(all) struct PdfV2ReadingOrder {
  page_index : Int
  candidates : Array[PdfV2ReadingOrderCandidate]
  selected_candidate_index : Int?
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2CrossPageBoundary {
  from_page_index : Int
  to_page_index : Int
  from_block_id : String?
  to_block_id : String?
  kind : PdfV2CrossPageBoundaryKind
  confidence : Double
  source : PdfV2CrossPageBoundarySource
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
  decision_trace : PdfV2LayoutDecisionTrace
}

///|
pub(all) struct PdfV2LayoutRecoveryOptions {
  deterministic_rules_enabled : Bool
  model_hints_enabled : Bool
  fail_closed : Bool
  emit_low_signal_risk : Bool
  emit_ocr_recommendation_risk : Bool
  hints : Array[PdfV2LayoutHint]
}

///|
pub(all) struct PdfV2LayoutRecoverySummary {
  page_count : Int
  input_text_block_count : Int
  region_count : Int
  reading_order_candidate_count : Int
  cross_page_boundary_count : Int
  warning_count : Int
  risk_count : Int
  layout_risk_count : Int
  propagated_warning_count : Int
  propagated_risk_count : Int
  scanned_once : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  fail_closed : Bool
  abstain : Bool
  model_hint_count : Int
  accepted_model_hint_count : Int
  conflict_model_hint_count : Int
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutRecoveryResult {
  summary : PdfV2LayoutRecoverySummary
  regions : Array[PdfV2LayoutRegion]
  reading_orders : Array[PdfV2ReadingOrder]
  cross_page_boundaries : Array[PdfV2CrossPageBoundary]
  layout_risks : Array[PdfV2LayoutRisk]
  hints : Array[PdfV2LayoutHint]
  decision_traces : Array[PdfV2LayoutDecisionTrace]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub fn default_pdf_v2_layout_recovery_options() -> PdfV2LayoutRecoveryOptions {
  {
    deterministic_rules_enabled: true,
    model_hints_enabled: false,
    fail_closed: true,
    emit_low_signal_risk: true,
    emit_ocr_recommendation_risk: true,
    hints: [],
  }
}

///|
pub fn recover_pdf_v2_layout(
  doc : @normalized_model.PdfV2DocumentModel,
  options : PdfV2LayoutRecoveryOptions,
) -> PdfV2LayoutRecoveryResult {
  let regions : Array[PdfV2LayoutRegion] = []
  let reading_orders : Array[PdfV2ReadingOrder] = []
  let cross_page_boundaries : Array[PdfV2CrossPageBoundary] = []
  let layout_risks : Array[PdfV2LayoutRisk] = []
  let decision_traces : Array[PdfV2LayoutDecisionTrace] = []
  let warnings = copy_warnings(doc.warnings)
  let risks = copy_risks(doc.risks)
  let mut block_count = 0

  for page in doc.pages {
    block_count = block_count + page.text_blocks.length()
    let page_risks = layout_risks_for_page(page, options)
    for layout_risk in page_risks {
      layout_risks.push(layout_risk)
      decision_traces.push(layout_risk.decision_trace)
      risks.push(layout_risk.risk)
    }
    let page_regions = regions_for_page(page, options, page_risks)
    for region in page_regions {
      regions.push(region)
      decision_traces.push(region.decision_trace)
    }
    let reading_order = reading_order_for_page(page, options, page_risks)
    for candidate in reading_order.candidates {
      decision_traces.push(candidate.decision_trace)
    }
    reading_orders.push(reading_order)
  }

  for i = 0; i + 1 < doc.pages.length(); i = i + 1 {
    let boundary = cross_page_boundary_for_pages(
      doc.pages[i],
      doc.pages[i + 1],
      options,
    )
    cross_page_boundaries.push(boundary)
    decision_traces.push(boundary.decision_trace)
  }

  let model_hint_stats = apply_model_hints(
    options.hints,
    options.model_hints_enabled,
    layout_risks,
    risks,
    decision_traces,
  )
  let scaffold_warning = @pdfv2.pdf_v2_scaffold_warning(
    "pdf_v2 layout recovery scaffold consumes the normalized parser model only",
  )
  warnings.push(scaffold_warning)
  let mut abstain = false
  for trace in decision_traces {
    if trace.abstain {
      abstain = true
    }
  }
  let reason_tags = [
    "layout_recovery_scaffold", "normalized_model_only", "parser_owned_layout_facts",
    "no_final_semantic_labels", "no_pdf_reparse", "no_ocr_fallback",
  ]
  {
    summary: {
      page_count: doc.pages.length(),
      input_text_block_count: block_count,
      region_count: regions.length(),
      reading_order_candidate_count: count_reading_order_candidates(
        reading_orders,
      ),
      cross_page_boundary_count: cross_page_boundaries.length(),
      warning_count: warnings.length(),
      risk_count: risks.length(),
      layout_risk_count: layout_risks.length(),
      propagated_warning_count: doc.warnings.length(),
      propagated_risk_count: doc.risks.length(),
      scanned_once: doc.source_summary.scanned_once,
      one_pass_required: doc.source_summary.one_pass_required,
      legacy_fallback_allowed: doc.source_summary.legacy_fallback_allowed,
      convert_raw_reparse_allowed: doc.source_summary.convert_raw_reparse_allowed,
      fail_closed: options.fail_closed,
      abstain,
      model_hint_count: options.hints.length(),
      accepted_model_hint_count: model_hint_stats.0,
      conflict_model_hint_count: model_hint_stats.1,
      reason_tags,
    },
    regions,
    reading_orders,
    cross_page_boundaries,
    layout_risks,
    hints: options.hints,
    decision_traces,
    warnings,
    risks,
    reason_tags,
  }
}

///|
pub fn pdf_v2_layout_hint(
  id : String,
  target_kind : PdfV2LayoutHintTargetKind,
  page_index : Int?,
  target_id : String?,
  region_kind : PdfV2LayoutRegionKind?,
  boundary_kind : PdfV2CrossPageBoundaryKind?,
  confidence : Double,
  feature_support_score : Double,
  reason_tags : Array[String],
) -> PdfV2LayoutHint {
  {
    id,
    target_kind,
    page_index,
    target_id,
    region_kind,
    boundary_kind,
    confidence,
    feature_support_score,
    source: PdfV2LayoutDecisionSource::ModelHint,
    source_refs: [],
    object_refs: [],
    reason_tags,
  }
}

///|
pub fn pdf_v2_layout_region_candidate(
  id : String,
  page_index : Int,
  kind : PdfV2LayoutRegionKind,
  bbox : @pdfv2.PdfV2Rect,
  confidence_score : Double,
  source : PdfV2LayoutRegionSource,
  member_block_ids : Array[String],
  member_line_ids : Array[String],
  reason_tags : Array[String],
) -> PdfV2LayoutRegion {
  let trace = decision_trace(
    confidence_score,
    0.0,
    0.20,
    0.0,
    source_to_decision_source(source),
    reason_tags,
  )
  {
    id,
    page_index,
    kind,
    bbox,
    confidence: confidence_bucket(trace.final_confidence, trace.abstain),
    confidence_score: trace.final_confidence,
    source,
    source_refs: [],
    object_refs: [],
    member_block_ids,
    member_line_ids,
    warnings: [],
    risks: [],
    reason_tags,
    decision_trace: trace,
  }
}

///|
pub fn pdf_v2_cross_page_boundary_candidate(
  from_page_index : Int,
  to_page_index : Int,
  from_block_id : String?,
  to_block_id : String?,
  kind : PdfV2CrossPageBoundaryKind,
  confidence : Double,
  reason_tags : Array[String],
) -> PdfV2CrossPageBoundary {
  let trace = decision_trace(
    confidence,
    0.0,
    0.10,
    if kind == PdfV2CrossPageBoundaryKind::Uncertain {
      0.45
    } else {
      0.0
    },
    if kind == PdfV2CrossPageBoundaryKind::Uncertain {
      PdfV2LayoutDecisionSource::Abstain
    } else {
      PdfV2LayoutDecisionSource::DeterministicRule
    },
    reason_tags,
  )
  {
    from_page_index,
    to_page_index,
    from_block_id,
    to_block_id,
    kind,
    confidence: trace.final_confidence,
    source: if trace.abstain {
      PdfV2CrossPageBoundarySource::Abstain
    } else {
      PdfV2CrossPageBoundarySource::DeterministicRule
    },
    source_refs: [],
    object_refs: [],
    warnings: [],
    risks: [],
    reason_tags,
    decision_trace: trace,
  }
}

///|
fn regions_for_page(
  page : @normalized_model.PdfV2Page,
  options : PdfV2LayoutRecoveryOptions,
  page_layout_risks : Array[PdfV2LayoutRisk],
) -> Array[PdfV2LayoutRegion] {
  let regions : Array[PdfV2LayoutRegion] = []
  for block in page.text_blocks {
    regions.push(region_for_block(page, block, options, page_layout_risks))
  }
  regions
}

///|
fn region_for_block(
  page : @normalized_model.PdfV2Page,
  block : @normalized_model.PdfV2TextBlock,
  options : PdfV2LayoutRecoveryOptions,
  page_layout_risks : Array[PdfV2LayoutRisk],
) -> PdfV2LayoutRegion {
  let member_line_ids : Array[String] = []
  for line in block.lines {
    member_line_ids.push(line.id)
  }
  let risk_penalty = risk_penalty_for_layout_risks(page_layout_risks)
  let deterministic_score = if options.deterministic_rules_enabled {
    0.72
  } else {
    0.0
  }
  let trace = decision_trace(
    deterministic_score,
    0.0,
    0.12,
    risk_penalty,
    if options.deterministic_rules_enabled {
      PdfV2LayoutDecisionSource::DeterministicRule
    } else {
      PdfV2LayoutDecisionSource::Abstain
    },
    ["deterministic_rule", "paragraph_region_candidate", "parser_owned_fact"],
  )
  {
    id: "layout_region_page_" +
    page.page_index.to_string() +
    "_block_" +
    block.id,
    page_index: page.page_index,
    kind: PdfV2LayoutRegionKind::Paragraph,
    bbox: block.bbox,
    confidence: confidence_bucket(trace.final_confidence, trace.abstain),
    confidence_score: trace.final_confidence,
    source: if trace.abstain {
      PdfV2LayoutRegionSource::Abstain
    } else {
      PdfV2LayoutRegionSource::DeterministicRule
    },
    source_refs: block.source_refs,
    object_refs: block.object_refs,
    member_block_ids: [block.id],
    member_line_ids,
    warnings: block.warnings,
    risks: block.risks,
    reason_tags: trace.reason_tags,
    decision_trace: trace,
  }
}

///|
fn reading_order_for_page(
  page : @normalized_model.PdfV2Page,
  options : PdfV2LayoutRecoveryOptions,
  page_layout_risks : Array[PdfV2LayoutRisk],
) -> PdfV2ReadingOrder {
  let ordered_block_ids : Array[String] = []
  let source_refs : Array[@pdfv2.PdfV2SourceRef] = []
  let object_refs : Array[String] = []
  for block in page.text_blocks {
    ordered_block_ids.push(block.id)
    for source_ref in block.source_refs {
      source_refs.push(source_ref)
    }
    for object_ref in block.object_refs {
      object_refs.push(object_ref)
    }
  }
  let risk_penalty = risk_penalty_for_layout_risks(page_layout_risks)
  let trace = decision_trace(
    if options.deterministic_rules_enabled && !ordered_block_ids.is_empty() {
      0.74
    } else {
      0.0
    },
    0.0,
    if ordered_block_ids.is_empty() {
      0.0
    } else {
      0.12
    },
    risk_penalty,
    if options.deterministic_rules_enabled && !ordered_block_ids.is_empty() {
      PdfV2LayoutDecisionSource::DeterministicRule
    } else {
      PdfV2LayoutDecisionSource::Abstain
    },
    if ordered_block_ids.is_empty() {
      ["abstain", "empty_page", "reading_order_uncertain"]
    } else {
      [
        "source_order_placeholder", "reading_order_candidate", "parser_owned_fact",
      ]
    },
  )
  let candidate : PdfV2ReadingOrderCandidate = {
    page_index: page.page_index,
    ordered_block_ids,
    confidence: trace.final_confidence,
    source: if trace.abstain {
      PdfV2ReadingOrderSource::Abstain
    } else {
      PdfV2ReadingOrderSource::SourceOrder
    },
    source_refs,
    object_refs,
    warnings: page.warnings,
    risks: page.risks,
    reason_tags: trace.reason_tags,
    decision_trace: trace,
  }
  {
    page_index: page.page_index,
    candidates: [candidate],
    selected_candidate_index: if trace.abstain {
      None
    } else {
      Some(0)
    },
    warnings: page.warnings,
    risks: page.risks,
    reason_tags: ["reading_order_scaffold", "no_convert_policy"],
  }
}

///|
fn cross_page_boundary_for_pages(
  from_page : @normalized_model.PdfV2Page,
  to_page : @normalized_model.PdfV2Page,
  options : PdfV2LayoutRecoveryOptions,
) -> PdfV2CrossPageBoundary {
  let from_block_id = last_block_id(from_page.text_blocks)
  let to_block_id = first_block_id(to_page.text_blocks)
  let risk_penalty = if from_block_id == None || to_block_id == None {
    0.50
  } else {
    0.35
  }
  let trace = decision_trace(
    if options.deterministic_rules_enabled {
      0.45
    } else {
      0.0
    },
    0.0,
    if from_block_id == None || to_block_id == None {
      0.0
    } else {
      0.10
    },
    risk_penalty,
    PdfV2LayoutDecisionSource::Abstain,
    ["cross_page_boundary_uncertain", "abstain", "no_merge_without_evidence"],
  )
  {
    from_page_index: from_page.page_index,
    to_page_index: to_page.page_index,
    from_block_id,
    to_block_id,
    kind: PdfV2CrossPageBoundaryKind::Uncertain,
    confidence: trace.final_confidence,
    source: PdfV2CrossPageBoundarySource::Abstain,
    source_refs: page_source_refs(from_page) + page_source_refs(to_page),
    object_refs: page_object_refs(from_page) + page_object_refs(to_page),
    warnings: from_page.warnings + to_page.warnings,
    risks: from_page.risks + to_page.risks,
    reason_tags: trace.reason_tags,
    decision_trace: trace,
  }
}

///|
fn layout_risks_for_page(
  page : @normalized_model.PdfV2Page,
  options : PdfV2LayoutRecoveryOptions,
) -> Array[PdfV2LayoutRisk] {
  let risks : Array[PdfV2LayoutRisk] = []
  if options.emit_low_signal_risk && page.text_blocks.is_empty() {
    risks.push(
      layout_risk(
        PdfV2LayoutRiskKind::LowSignalLayout,
        @pdfv2.PdfV2RiskKind::LowSignal,
        @pdfv2.PdfV2RiskSeverity::Warning,
        Some(page.page_index),
        "layout recovery found no text blocks for page",
        [],
        page.source_refs,
        page.object_refs,
        ["low_signal_layout", "abstain", "fail_closed"],
        0.55,
      ),
    )
    if options.emit_ocr_recommendation_risk {
      risks.push(
        layout_risk(
          PdfV2LayoutRiskKind::OcrRecommendedButNotFallback,
          @pdfv2.PdfV2RiskKind::LowSignal,
          @pdfv2.PdfV2RiskSeverity::Info,
          Some(page.page_index),
          "page may need OCR, but layout recovery does not run OCR fallback",
          [],
          page.source_refs,
          page.object_refs,
          ["ocr_recommended_but_not_fallback", "no_ocr_fallback"],
          0.45,
        ),
      )
    }
  }
  if page.text_blocks.length() > 1 &&
    source_order_inconsistent(page.text_blocks) {
    risks.push(
      layout_risk(
        PdfV2LayoutRiskKind::SourceOrderInconsistent,
        @pdfv2.PdfV2RiskKind::SourceOrderConflict,
        @pdfv2.PdfV2RiskSeverity::Warning,
        Some(page.page_index),
        "block content order is inconsistent with normalized block sequence",
        block_ids(page.text_blocks),
        page_source_refs(page),
        page_object_refs(page),
        [
          "source_order_inconsistent", "reading_order_uncertain", "abstain_candidate",
        ],
        0.35,
      ),
    )
  }
  risks
}

///|
fn layout_risk(
  kind : PdfV2LayoutRiskKind,
  pdf_risk_kind : @pdfv2.PdfV2RiskKind,
  severity : @pdfv2.PdfV2RiskSeverity,
  page_index : Int?,
  reason : String,
  affected_ids : Array[String],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  object_refs : Array[String],
  reason_tags : Array[String],
  risk_penalty : Double,
) -> PdfV2LayoutRisk {
  let source_ref = if source_refs.is_empty() {
    None
  } else {
    Some(source_refs[0])
  }
  let object_ref = if object_refs.is_empty() {
    None
  } else {
    Some(object_refs[0])
  }
  let trace = decision_trace(
    0.0,
    0.0,
    0.0,
    risk_penalty,
    PdfV2LayoutDecisionSource::Abstain,
    reason_tags,
  )
  {
    kind,
    risk: {
      kind: pdf_risk_kind,
      severity,
      capability: Some(@pdfv2.PdfV2CoreCapabilityKind::LowSignalDocument),
      reason,
      affected_ids,
      source_ref,
      source_refs,
      object_ref,
      page_index,
      reason_tags,
      recoverability: @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
    },
    decision_trace: trace,
  }
}

///|
fn apply_model_hints(
  hints : Array[PdfV2LayoutHint],
  model_hints_enabled : Bool,
  layout_risks : Array[PdfV2LayoutRisk],
  risks : Array[@pdfv2.PdfV2Risk],
  decision_traces : Array[PdfV2LayoutDecisionTrace],
) -> (Int, Int) {
  let mut accepted_count = 0
  let mut conflict_count = 0
  for hint in hints {
    let risk_penalty = if model_hints_enabled { 0.10 } else { 0.65 }
    let hard_conflict = !model_hints_enabled ||
      hint.source != PdfV2LayoutDecisionSource::ModelHint ||
      hint.confidence < 0.80
    let trace = decision_trace(
      if hard_conflict {
        1.0
      } else {
        0.0
      },
      hint.confidence,
      hint.feature_support_score,
      risk_penalty,
      if hard_conflict {
        PdfV2LayoutDecisionSource::Abstain
      } else {
        PdfV2LayoutDecisionSource::CombinedGate
      },
      if hard_conflict {
        hint.reason_tags + ["model_hint_conflict", "abstain"]
      } else {
        hint.reason_tags + ["model_hint_candidate", "parser_facts_preserved"]
      },
    )
    decision_traces.push(trace)
    if trace.abstain {
      conflict_count = conflict_count + 1
      let affected_ids = match hint.target_id {
        Some(target_id) => [target_id]
        None => []
      }
      let layout_conflict = layout_risk(
        PdfV2LayoutRiskKind::ModelHintConflict,
        @pdfv2.PdfV2RiskKind::ModelUnavailable,
        @pdfv2.PdfV2RiskSeverity::Warning,
        hint.page_index,
        "layout model hint is unavailable, weak, or conflicts with parser facts",
        affected_ids,
        hint.source_refs,
        hint.object_refs,
        trace.reason_tags,
        risk_penalty,
      )
      layout_risks.push(layout_conflict)
      risks.push(layout_conflict.risk)
    } else {
      accepted_count = accepted_count + 1
    }
  }
  (accepted_count, conflict_count)
}

///|
fn decision_trace(
  deterministic_constraint_score : Double,
  model_confidence : Double,
  feature_support_score : Double,
  risk_penalty : Double,
  decision_source : PdfV2LayoutDecisionSource,
  reason_tags : Array[String],
) -> PdfV2LayoutDecisionTrace {
  let hard_constraint_abstain = decision_source ==
    PdfV2LayoutDecisionSource::Abstain &&
    deterministic_constraint_score >= 1.0
  let final_confidence = if hard_constraint_abstain {
    0.0
  } else {
    clamp_confidence(
      deterministic_constraint_score +
      model_confidence +
      feature_support_score -
      risk_penalty,
    )
  }
  {
    deterministic_constraint_score,
    model_confidence,
    feature_support_score,
    risk_penalty,
    final_confidence,
    decision_source,
    abstain: decision_source == PdfV2LayoutDecisionSource::Abstain ||
    final_confidence < 0.60,
    reason_tags,
  }
}

///|
fn risk_penalty_for_layout_risks(risks : Array[PdfV2LayoutRisk]) -> Double {
  let mut penalty = 0.0
  for risk in risks {
    penalty = penalty + risk.decision_trace.risk_penalty
  }
  clamp_confidence(penalty)
}

///|
fn confidence_bucket(
  score : Double,
  abstain : Bool,
) -> PdfV2LayoutRegionConfidence {
  if abstain {
    PdfV2LayoutRegionConfidence::Abstained
  } else if score >= 0.85 {
    PdfV2LayoutRegionConfidence::High
  } else if score >= 0.70 {
    PdfV2LayoutRegionConfidence::Medium
  } else if score > 0.0 {
    PdfV2LayoutRegionConfidence::Low
  } else {
    PdfV2LayoutRegionConfidence::Unknown
  }
}

///|
fn source_to_decision_source(
  source : PdfV2LayoutRegionSource,
) -> PdfV2LayoutDecisionSource {
  match source {
    DeterministicRule => PdfV2LayoutDecisionSource::DeterministicRule
    ModelHint => PdfV2LayoutDecisionSource::ModelHint
    CombinedGate => PdfV2LayoutDecisionSource::CombinedGate
    Abstain => PdfV2LayoutDecisionSource::Abstain
    Unknown => PdfV2LayoutDecisionSource::Unknown
  }
}

///|
fn clamp_confidence(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn count_reading_order_candidates(
  reading_orders : Array[PdfV2ReadingOrder],
) -> Int {
  let mut count = 0
  for reading_order in reading_orders {
    count = count + reading_order.candidates.length()
  }
  count
}

///|
fn block_ids(blocks : Array[@normalized_model.PdfV2TextBlock]) -> Array[String] {
  let ids : Array[String] = []
  for block in blocks {
    ids.push(block.id)
  }
  ids
}

///|
fn page_source_refs(
  page : @normalized_model.PdfV2Page,
) -> Array[@pdfv2.PdfV2SourceRef] {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  for source_ref in page.source_refs {
    refs.push(source_ref)
  }
  for block in page.text_blocks {
    for source_ref in block.source_refs {
      refs.push(source_ref)
    }
  }
  refs
}

///|
fn page_object_refs(page : @normalized_model.PdfV2Page) -> Array[String] {
  let refs : Array[String] = []
  for object_ref in page.object_refs {
    refs.push(object_ref)
  }
  for block in page.text_blocks {
    for object_ref in block.object_refs {
      refs.push(object_ref)
    }
  }
  refs
}

///|
fn first_block_id(blocks : Array[@normalized_model.PdfV2TextBlock]) -> String? {
  if blocks.is_empty() {
    None
  } else {
    Some(blocks[0].id)
  }
}

///|
fn last_block_id(blocks : Array[@normalized_model.PdfV2TextBlock]) -> String? {
  if blocks.is_empty() {
    None
  } else {
    Some(blocks[blocks.length() - 1].id)
  }
}

///|
fn source_order_inconsistent(
  blocks : Array[@normalized_model.PdfV2TextBlock],
) -> Bool {
  let mut previous : Int? = None
  for block in blocks {
    match block.content_order_start {
      Some(current) =>
        match previous {
          Some(prev) =>
            if current < prev {
              return true
            } else {
              previous = Some(current)
            }
          None => previous = Some(current)
        }
      None => ()
    }
  }
  false
}

///|
fn copy_warnings(
  warnings : Array[@pdfv2.PdfV2Warning],
) -> Array[@pdfv2.PdfV2Warning] {
  let out : Array[@pdfv2.PdfV2Warning] = []
  for warning in warnings {
    out.push(warning)
  }
  out
}

///|
fn copy_risks(risks : Array[@pdfv2.PdfV2Risk]) -> Array[@pdfv2.PdfV2Risk] {
  let out : Array[@pdfv2.PdfV2Risk] = []
  for risk in risks {
    out.push(risk)
  }
  out
}
