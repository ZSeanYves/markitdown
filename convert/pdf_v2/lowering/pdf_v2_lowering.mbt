///|
pub(all) enum PdfV2LoweredBlockKind {
  Text
  Paragraph
  Heading
  ListItem
  CaptionText
  TableLikeText
  ImagePlaceholder
  FormNote
  AnnotationNote
  NoiseSuppressed
  Unsupported
  Uncertain
} derive(Eq)

///|
pub(all) enum PdfV2LoweringWarningKind {
  MissingFeatureRecord
  MissingDecision
  AbstainDecision
  UncertainDecision
  LowConfidenceDecision
  HighRiskSemanticSuppressed
  BlockingReasonTag
  MissingListMarkerEvidence
  MissingVisualEvidence
  WeakTableEvidence
  MissingNoiseEvidence
  ParserDiagnosticsPropagated
  PlaceholderEmitted
  UnsupportedObject
} derive(Eq)

///|
pub(all) enum PdfV2LoweringAssetKind {
  Image
  Annotation
  Form
  UnsupportedVector
} derive(Eq)

///|
pub(all) struct PdfV2LoweringOptions {
  fail_closed : Bool
  min_heading_confidence : Double
  min_list_confidence : Double
  min_caption_confidence : Double
  min_noise_confidence : Double
  suppress_high_risk_semantics : Bool
  emit_decision_summary : Bool
  emit_warnings : Bool
}

///|
pub(all) struct PdfV2LoweringPolicy {
  fail_closed : Bool
  abstain_behavior : String
  uncertain_behavior : String
  low_confidence_behavior : String
  high_risk_behavior : String
  heading_policy : String
  list_policy : String
  caption_policy : String
  table_policy : String
  noise_policy : String
  min_heading_confidence : Double
  min_list_confidence : Double
  min_caption_confidence : Double
  min_noise_confidence : Double
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringWarning {
  kind : PdfV2LoweringWarningKind
  page_index : Int?
  block_id : String?
  message : String
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  parser_warnings : Array[@pdfv2.PdfV2Warning]
  parser_risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringDecisionTrace {
  block_id : String?
  label : @classifier_gate.PdfV2BlockDecisionLabel
  decision_source : @classifier_gate.PdfV2BlockDecisionSource
  deterministic_constraint_score : Double
  model_confidence : Double
  feature_support_score : Double
  risk_penalty : Double
  final_confidence : Double
  abstain : Bool
  blocked_reason : String?
  reason_tags : Array[@classifier_gate.PdfV2BlockDecisionReasonTag]
  evidence_feature_names : Array[String]
  lowering_action : String
}

///|
pub(all) struct PdfV2LoweringOrigin {
  page_index : Int
  block_id : String?
  line_ids : Array[String]
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  feature_record_id : String?
  decision_id : String?
  parser_warning_count : Int
  parser_risk_count : Int
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringAssetRef {
  id : String
  kind : PdfV2LoweringAssetKind
  page_index : Int
  object_ref : String?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  placeholder_block_id : String
  parser_warnings : Array[@pdfv2.PdfV2Warning]
  parser_risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweredBlock {
  id : String
  kind : PdfV2LoweredBlockKind
  text : String
  page_index : Int
  bbox : @pdfv2.PdfV2Rect?
  origin : PdfV2LoweringOrigin
  decision_trace : PdfV2LoweringDecisionTrace?
  asset_ref : PdfV2LoweringAssetRef?
  warnings : Array[PdfV2LoweringWarning]
  parser_warnings : Array[@pdfv2.PdfV2Warning]
  parser_risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringSummary {
  input_page_count : Int
  input_text_block_count : Int
  feature_record_count : Int
  decision_count : Int
  lowered_block_count : Int
  text_count : Int
  paragraph_count : Int
  heading_count : Int
  list_item_count : Int
  caption_text_count : Int
  table_like_text_count : Int
  image_placeholder_count : Int
  form_note_count : Int
  annotation_note_count : Int
  noise_suppressed_count : Int
  unsupported_count : Int
  uncertain_count : Int
  missing_feature_count : Int
  missing_decision_count : Int
  abstain_count : Int
  low_confidence_count : Int
  high_risk_count : Int
  warning_count : Int
  parser_warning_count : Int
  parser_risk_count : Int
  decision_trace_count : Int
  fail_closed : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringResult {
  blocks : Array[PdfV2LoweredBlock]
  asset_refs : Array[PdfV2LoweringAssetRef]
  warnings : Array[PdfV2LoweringWarning]
  parser_warnings : Array[@pdfv2.PdfV2Warning]
  parser_risks : Array[@pdfv2.PdfV2Risk]
  decision_traces : Array[PdfV2LoweringDecisionTrace]
  summary : PdfV2LoweringSummary
  policy : PdfV2LoweringPolicy
  reason_tags : Array[String]
}

///|
priv struct PdfV2LoweringBlockBuild {
  block : PdfV2LoweredBlock
  trace : PdfV2LoweringDecisionTrace?
  missing_feature : Bool
  missing_decision : Bool
  abstain : Bool
  low_confidence : Bool
  high_risk : Bool
}

///|
pub fn default_pdf_v2_lowering_options() -> PdfV2LoweringOptions {
  {
    fail_closed: true,
    min_heading_confidence: 0.90,
    min_list_confidence: 0.85,
    min_caption_confidence: 0.85,
    min_noise_confidence: 0.95,
    suppress_high_risk_semantics: true,
    emit_decision_summary: true,
    emit_warnings: true,
  }
}

///|
pub fn pdf_v2_lowering_policy(
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringPolicy {
  {
    fail_closed: options.fail_closed,
    abstain_behavior: "keep_as_text",
    uncertain_behavior: "keep_as_text",
    low_confidence_behavior: "keep_as_text",
    high_risk_behavior: if options.suppress_high_risk_semantics {
      "keep_as_text"
    } else {
      "emit_with_warning"
    },
    heading_policy: "accepted_decision_and_min_heading_confidence",
    list_policy: "accepted_decision_min_list_confidence_and_marker_evidence",
    caption_policy: "accepted_decision_min_caption_confidence_no_image_binding",
    table_policy: "table_like_text_only_with_strong_table_region_evidence",
    noise_policy: "suppress_only_with_min_noise_confidence_and_explicit_reason",
    min_heading_confidence: options.min_heading_confidence,
    min_list_confidence: options.min_list_confidence,
    min_caption_confidence: options.min_caption_confidence,
    min_noise_confidence: options.min_noise_confidence,
    reason_tags: [
      "conservative_lowering_policy", "fail_closed", "no_raw_pdf_read", "no_legacy_fallback",
      "convert_owned_policy",
    ],
  }
}

///|
pub fn lower_pdf_v2_document(
  doc : @normalized_model.PdfV2DocumentModel,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringResult {
  let blocks : Array[PdfV2LoweredBlock] = []
  let asset_refs : Array[PdfV2LoweringAssetRef] = []
  let warnings : Array[PdfV2LoweringWarning] = []
  let traces : Array[PdfV2LoweringDecisionTrace] = []
  let parser_warnings = collect_parser_warnings(doc, features, decisions)
  let parser_risks = collect_parser_risks(doc, features, decisions)
  let mut missing_feature_count = 0
  let mut missing_decision_count = 0
  let mut abstain_count = 0
  let mut low_confidence_count = 0
  let mut high_risk_count = 0
  for page in doc.pages {
    for block in page.text_blocks {
      let built = lower_text_block(block, features, decisions, options)
      blocks.push(built.block)
      match built.trace {
        Some(trace) => traces.push(trace)
        None => ()
      }
      if built.missing_feature {
        missing_feature_count = missing_feature_count + 1
      }
      if built.missing_decision {
        missing_decision_count = missing_decision_count + 1
      }
      if built.abstain {
        abstain_count = abstain_count + 1
      }
      if built.low_confidence {
        low_confidence_count = low_confidence_count + 1
      }
      if built.high_risk {
        high_risk_count = high_risk_count + 1
      }
      append_lowering_warnings(warnings, built.block.warnings)
    }
    lower_page_placeholders(page, blocks, asset_refs, warnings, options)
  }
  let emitted_warnings = if options.emit_warnings { warnings } else { [] }
  let emitted_traces = if options.emit_decision_summary { traces } else { [] }
  {
    blocks,
    asset_refs,
    warnings: emitted_warnings,
    parser_warnings,
    parser_risks,
    decision_traces: emitted_traces,
    summary: summarize_lowering(
      doc,
      features,
      decisions,
      blocks,
      emitted_warnings,
      parser_warnings,
      parser_risks,
      emitted_traces.length(),
      options,
      missing_feature_count,
      missing_decision_count,
      abstain_count,
      low_confidence_count,
      high_risk_count,
    ),
    policy: pdf_v2_lowering_policy(options),
    reason_tags: [
      "pdf_v2_lowering_scaffold", "convert_owned_policy", "normalized_model_plus_features_plus_decisions_only",
      "no_raw_pdf_read", "no_old_pdf_runtime", "no_old_parser_runtime", "no_external_model_file",
      "no_tsv_loader", "no_dispatcher_switch", "fail_closed",
    ],
  }
}

///|
fn lower_text_block(
  block : @normalized_model.PdfV2TextBlock,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringBlockBuild {
  let feature = find_feature(features, block.page_index, block.id)
  let decision = find_decision(decisions, block.page_index, block.id)
  let block_warnings : Array[PdfV2LoweringWarning] = []
  let mut missing_feature = false
  let mut missing_decision = false
  let mut abstain = false
  let mut low_confidence = false
  let mut high_risk = false
  match feature {
    None => {
      missing_feature = true
      push_warning(
        block_warnings,
        options,
        PdfV2LoweringWarningKind::MissingFeatureRecord,
        block.page_index,
        Some(block.id),
        "missing feature record; kept as text",
        source_refs_for(block, feature),
        object_refs_for(block, feature),
        parser_warnings_for(block, feature, decision),
        parser_risks_for(block, feature, decision),
        ["missing_feature_record", "keep_as_text", "fail_closed"],
      )
    }
    Some(_) => ()
  }
  match decision {
    None => {
      missing_decision = true
      push_warning(
        block_warnings,
        options,
        PdfV2LoweringWarningKind::MissingDecision,
        block.page_index,
        Some(block.id),
        "missing classifier decision; kept as text",
        source_refs_for(block, feature),
        object_refs_for(block, feature),
        parser_warnings_for(block, feature, decision),
        parser_risks_for(block, feature, decision),
        ["missing_decision", "keep_as_text", "fail_closed"],
      )
    }
    Some(decision) => if decision.abstain { abstain = true }
  }
  if has_high_risk(block, feature, decision) {
    high_risk = true
  }
  let kind = choose_text_block_kind(
    block, feature, decision, options, block_warnings,
  )
  if kind == PdfV2LoweredBlockKind::Text &&
    decision_is_low_confidence(decision, options) {
    low_confidence = true
  }
  let trace = match decision {
    Some(decision) => Some(make_decision_trace(decision, kind_action(kind)))
    None => None
  }
  {
    block: {
      id: "text:" + block.id,
      kind,
      text: block.text,
      page_index: block.page_index,
      bbox: Some(block.bbox),
      origin: make_text_origin(block, feature, decision),
      decision_trace: trace,
      asset_ref: None,
      warnings: block_warnings,
      parser_warnings: parser_warnings_for(block, feature, decision),
      parser_risks: parser_risks_for(block, feature, decision),
      reason_tags: text_block_reason_tags(block, feature, decision, kind),
    },
    trace,
    missing_feature,
    missing_decision,
    abstain,
    low_confidence,
    high_risk,
  }
}

///|
fn choose_text_block_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  match feature {
    None => return PdfV2LoweredBlockKind::Text
    Some(_) => ()
  }
  match decision {
    None => return PdfV2LoweredBlockKind::Text
    Some(decision) => {
      if decision.abstain {
        push_warning(
          warnings,
          options,
          PdfV2LoweringWarningKind::AbstainDecision,
          block.page_index,
          Some(block.id),
          "classifier abstained; kept as text",
          source_refs_for(block, feature),
          object_refs_for(block, feature),
          parser_warnings_for(block, feature, Some(decision)),
          parser_risks_for(block, feature, Some(decision)),
          ["abstain_decision", "keep_as_text", "fail_closed"],
        )
        return PdfV2LoweredBlockKind::Text
      }
      if decision.label == @classifier_gate.PdfV2BlockDecisionLabel::Uncertain {
        push_warning(
          warnings,
          options,
          PdfV2LoweringWarningKind::UncertainDecision,
          block.page_index,
          Some(block.id),
          "classifier decision was uncertain; kept as text",
          source_refs_for(block, feature),
          object_refs_for(block, feature),
          parser_warnings_for(block, feature, Some(decision)),
          parser_risks_for(block, feature, Some(decision)),
          ["uncertain_decision", "keep_as_text", "fail_closed"],
        )
        return PdfV2LoweredBlockKind::Text
      }
      if has_blocking_reason(block, feature, decision) {
        push_warning(
          warnings,
          options,
          PdfV2LoweringWarningKind::BlockingReasonTag,
          block.page_index,
          Some(block.id),
          "decision trace carried a blocking reason; kept as text",
          source_refs_for(block, feature),
          object_refs_for(block, feature),
          parser_warnings_for(block, feature, Some(decision)),
          parser_risks_for(block, feature, Some(decision)),
          ["blocking_reason_tag", "keep_as_text", "fail_closed"],
        )
        return PdfV2LoweredBlockKind::Text
      }
      if options.suppress_high_risk_semantics &&
        has_high_risk(block, feature, Some(decision)) {
        push_warning(
          warnings,
          options,
          PdfV2LoweringWarningKind::HighRiskSemanticSuppressed,
          block.page_index,
          Some(block.id),
          "parser or decision risk present; semantic lowering suppressed",
          source_refs_for(block, feature),
          object_refs_for(block, feature),
          parser_warnings_for(block, feature, Some(decision)),
          parser_risks_for(block, feature, Some(decision)),
          ["high_risk", "semantic_suppressed", "keep_as_text"],
        )
        return PdfV2LoweredBlockKind::Text
      }
      match decision.label {
        @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate =>
          lower_heading_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::ParagraphCandidate =>
          lower_paragraph_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::ListItemCandidate =>
          lower_list_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::CaptionCandidate =>
          lower_caption_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::TableCandidate =>
          lower_table_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::NoiseCandidate =>
          lower_noise_kind(block, feature, decision, options, warnings)
        @classifier_gate.PdfV2BlockDecisionLabel::TextCandidate =>
          PdfV2LoweredBlockKind::Text
        @classifier_gate.PdfV2BlockDecisionLabel::Uncertain =>
          PdfV2LoweredBlockKind::Text
      }
    }
  }
}

///|
fn lower_heading_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if decision.scores.final_confidence >= options.min_heading_confidence {
    PdfV2LoweredBlockKind::Heading
  } else {
    warn_low_confidence(block, feature, decision, options, warnings)
    PdfV2LoweredBlockKind::Text
  }
}

///|
fn lower_paragraph_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if decision.scores.final_confidence >= 0.50 {
    PdfV2LoweredBlockKind::Paragraph
  } else {
    warn_low_confidence(block, feature, decision, options, warnings)
    PdfV2LoweredBlockKind::Text
  }
}

///|
fn lower_list_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if decision.scores.final_confidence < options.min_list_confidence {
    warn_low_confidence(block, feature, decision, options, warnings)
    return PdfV2LoweredBlockKind::Text
  }
  if has_list_marker_evidence(block, feature, decision) {
    PdfV2LoweredBlockKind::ListItem
  } else {
    push_warning(
      warnings,
      options,
      PdfV2LoweringWarningKind::MissingListMarkerEvidence,
      block.page_index,
      Some(block.id),
      "list decision lacked marker evidence; kept as text",
      source_refs_for(block, feature),
      object_refs_for(block, feature),
      parser_warnings_for(block, feature, Some(decision)),
      parser_risks_for(block, feature, Some(decision)),
      ["missing_list_marker_evidence", "keep_as_text", "fail_closed"],
    )
    PdfV2LoweredBlockKind::Text
  }
}

///|
fn lower_caption_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if decision.scores.final_confidence < options.min_caption_confidence {
    warn_low_confidence(block, feature, decision, options, warnings)
    return PdfV2LoweredBlockKind::Text
  }
  if !has_visual_evidence(feature, decision) {
    push_warning(
      warnings,
      options,
      PdfV2LoweringWarningKind::MissingVisualEvidence,
      block.page_index,
      Some(block.id),
      "caption kept as caption text without image binding",
      source_refs_for(block, feature),
      object_refs_for(block, feature),
      parser_warnings_for(block, feature, Some(decision)),
      parser_risks_for(block, feature, Some(decision)),
      ["missing_visual_evidence", "caption_text_only", "no_image_binding"],
    )
  }
  PdfV2LoweredBlockKind::CaptionText
}

///|
fn lower_table_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if has_strong_table_evidence(feature, decision) &&
    decision.scores.final_confidence >= 0.90 {
    PdfV2LoweredBlockKind::TableLikeText
  } else {
    push_warning(
      warnings,
      options,
      PdfV2LoweringWarningKind::WeakTableEvidence,
      block.page_index,
      Some(block.id),
      "table decision lacked strong table-region evidence; kept as text",
      source_refs_for(block, feature),
      object_refs_for(block, feature),
      parser_warnings_for(block, feature, Some(decision)),
      parser_risks_for(block, feature, Some(decision)),
      ["weak_table_evidence", "keep_as_text", "fail_closed"],
    )
    PdfV2LoweredBlockKind::Text
  }
}

///|
fn lower_noise_kind(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> PdfV2LoweredBlockKind {
  if decision.scores.final_confidence < options.min_noise_confidence {
    warn_low_confidence(block, feature, decision, options, warnings)
    return PdfV2LoweredBlockKind::Text
  }
  if has_noise_evidence(feature, decision) {
    PdfV2LoweredBlockKind::NoiseSuppressed
  } else {
    push_warning(
      warnings,
      options,
      PdfV2LoweringWarningKind::MissingNoiseEvidence,
      block.page_index,
      Some(block.id),
      "noise decision lacked explicit reason tags; kept as text",
      source_refs_for(block, feature),
      object_refs_for(block, feature),
      parser_warnings_for(block, feature, Some(decision)),
      parser_risks_for(block, feature, Some(decision)),
      ["missing_noise_reason", "keep_as_text", "fail_closed"],
    )
    PdfV2LoweredBlockKind::Text
  }
}

///|
fn lower_page_placeholders(
  page : @normalized_model.PdfV2Page,
  blocks : Array[PdfV2LoweredBlock],
  asset_refs : Array[PdfV2LoweringAssetRef],
  warnings : Array[PdfV2LoweringWarning],
  options : PdfV2LoweringOptions,
) -> Unit {
  for image in page.images {
    let built = placeholder_for_image(image, options)
    blocks.push(built.block)
    match built.block.asset_ref {
      Some(asset_ref) => asset_refs.push(asset_ref)
      None => ()
    }
    append_lowering_warnings(warnings, built.block.warnings)
  }
  for annotation in page.annotations {
    let built = placeholder_for_annotation(annotation, options)
    blocks.push(built.block)
    match built.block.asset_ref {
      Some(asset_ref) => asset_refs.push(asset_ref)
      None => ()
    }
    append_lowering_warnings(warnings, built.block.warnings)
  }
  for form in page.forms {
    let built = placeholder_for_form(form, options)
    blocks.push(built.block)
    match built.block.asset_ref {
      Some(asset_ref) => asset_refs.push(asset_ref)
      None => ()
    }
    append_lowering_warnings(warnings, built.block.warnings)
  }
  for vector in page.vectors {
    let built = placeholder_for_vector(vector, options)
    blocks.push(built.block)
    match built.block.asset_ref {
      Some(asset_ref) => asset_refs.push(asset_ref)
      None => ()
    }
    append_lowering_warnings(warnings, built.block.warnings)
  }
}

///|
fn placeholder_for_image(
  image : @normalized_model.PdfV2Image,
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringBlockBuild {
  let block_id = "image:" + image.id
  let asset_ref = make_asset_ref(
    image.id,
    PdfV2LoweringAssetKind::Image,
    image.page_index,
    image.object_ref,
    image.source_refs,
    block_id,
    image.warnings,
    image.risks,
    ["image_placeholder", "no_asset_export"],
  )
  let block_warnings : Array[PdfV2LoweringWarning] = []
  push_placeholder_warning(
    block_warnings,
    options,
    PdfV2LoweringWarningKind::PlaceholderEmitted,
    image.page_index,
    Some(block_id),
    "image placeholder emitted; no image asset export",
    image.source_refs,
    object_ref_array(image.object_ref),
    image.warnings,
    image.risks,
    ["image_placeholder", "no_raw_image_export"],
  )
  {
    block: placeholder_block(
      block_id,
      PdfV2LoweredBlockKind::ImagePlaceholder,
      "[image placeholder]",
      image.page_index,
      image.bbox,
      asset_ref,
      block_warnings,
      image.warnings,
      image.risks,
      ["image_placeholder", "no_asset_export"],
    ),
    trace: None,
    missing_feature: false,
    missing_decision: false,
    abstain: false,
    low_confidence: false,
    high_risk: !image.risks.is_empty(),
  }
}

///|
fn placeholder_for_annotation(
  annotation : @normalized_model.PdfV2Annotation,
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringBlockBuild {
  let block_id = "annotation:" + annotation.id
  let asset_ref = make_asset_ref(
    annotation.id,
    PdfV2LoweringAssetKind::Annotation,
    annotation.page_index,
    annotation.object_ref,
    annotation.source_refs,
    block_id,
    annotation.warnings,
    annotation.risks,
    ["annotation_note", "no_raw_annotation_reparse"],
  )
  let block_warnings : Array[PdfV2LoweringWarning] = []
  push_placeholder_warning(
    block_warnings,
    options,
    PdfV2LoweringWarningKind::PlaceholderEmitted,
    annotation.page_index,
    Some(block_id),
    "annotation note emitted from parser facts only",
    annotation.source_refs,
    object_ref_array(annotation.object_ref),
    annotation.warnings,
    annotation.risks,
    ["annotation_note", "no_raw_annotation_reparse"],
  )
  {
    block: placeholder_block(
      block_id,
      PdfV2LoweredBlockKind::AnnotationNote,
      "[annotation note]",
      annotation.page_index,
      annotation.bbox,
      asset_ref,
      block_warnings,
      annotation.warnings,
      annotation.risks,
      ["annotation_note", "parser_fact_placeholder"],
    ),
    trace: None,
    missing_feature: false,
    missing_decision: false,
    abstain: false,
    low_confidence: false,
    high_risk: !annotation.risks.is_empty(),
  }
}

///|
fn placeholder_for_form(
  form : @normalized_model.PdfV2Form,
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringBlockBuild {
  let block_id = "form:" + form.id
  let asset_ref = make_asset_ref(
    form.id,
    PdfV2LoweringAssetKind::Form,
    form.page_index,
    form.object_ref,
    form.source_refs,
    block_id,
    form.warnings,
    form.risks,
    ["form_note", "no_acroform_traversal"],
  )
  let block_warnings : Array[PdfV2LoweringWarning] = []
  push_placeholder_warning(
    block_warnings,
    options,
    PdfV2LoweringWarningKind::PlaceholderEmitted,
    form.page_index,
    Some(block_id),
    "form note emitted from parser facts only",
    form.source_refs,
    object_ref_array(form.object_ref),
    form.warnings,
    form.risks,
    ["form_note", "no_acroform_traversal"],
  )
  {
    block: placeholder_block(
      block_id,
      PdfV2LoweredBlockKind::FormNote,
      "[form note]",
      form.page_index,
      None,
      asset_ref,
      block_warnings,
      form.warnings,
      form.risks,
      ["form_note", "parser_fact_placeholder"],
    ),
    trace: None,
    missing_feature: false,
    missing_decision: false,
    abstain: false,
    low_confidence: false,
    high_risk: !form.risks.is_empty(),
  }
}

///|
fn placeholder_for_vector(
  vector : @normalized_model.PdfV2Vector,
  options : PdfV2LoweringOptions,
) -> PdfV2LoweringBlockBuild {
  let block_id = "vector:" + vector.id
  let asset_ref = make_asset_ref(
    vector.id,
    PdfV2LoweringAssetKind::UnsupportedVector,
    vector.page_index,
    vector.object_ref,
    vector.source_refs,
    block_id,
    vector.warnings,
    vector.risks,
    ["unsupported_vector_placeholder", "no_vector_reparse"],
  )
  let block_warnings : Array[PdfV2LoweringWarning] = []
  push_placeholder_warning(
    block_warnings,
    options,
    PdfV2LoweringWarningKind::UnsupportedObject,
    vector.page_index,
    Some(block_id),
    "unsupported vector placeholder emitted",
    vector.source_refs,
    object_ref_array(vector.object_ref),
    vector.warnings,
    vector.risks,
    ["unsupported_vector", "no_vector_reparse"],
  )
  {
    block: placeholder_block(
      block_id,
      PdfV2LoweredBlockKind::Unsupported,
      "[unsupported vector placeholder]",
      vector.page_index,
      vector.bbox,
      asset_ref,
      block_warnings,
      vector.warnings,
      vector.risks,
      ["unsupported_vector_placeholder", "parser_fact_placeholder"],
    ),
    trace: None,
    missing_feature: false,
    missing_decision: false,
    abstain: false,
    low_confidence: false,
    high_risk: !vector.risks.is_empty(),
  }
}

///|
fn placeholder_block(
  id : String,
  kind : PdfV2LoweredBlockKind,
  text : String,
  page_index : Int,
  bbox : @pdfv2.PdfV2Rect?,
  asset_ref : PdfV2LoweringAssetRef,
  warnings : Array[PdfV2LoweringWarning],
  parser_warnings : Array[@pdfv2.PdfV2Warning],
  parser_risks : Array[@pdfv2.PdfV2Risk],
  reason_tags : Array[String],
) -> PdfV2LoweredBlock {
  {
    id,
    kind,
    text,
    page_index,
    bbox,
    origin: {
      page_index,
      block_id: Some(id),
      line_ids: [],
      source_refs: copy_source_refs(asset_ref.source_refs),
      object_refs: object_ref_array(asset_ref.object_ref),
      feature_record_id: None,
      decision_id: None,
      parser_warning_count: parser_warnings.length(),
      parser_risk_count: parser_risks.length(),
      reason_tags,
    },
    decision_trace: None,
    asset_ref: Some(asset_ref),
    warnings,
    parser_warnings: copy_warnings(parser_warnings),
    parser_risks: copy_risks(parser_risks),
    reason_tags,
  }
}

///|
fn make_asset_ref(
  id : String,
  kind : PdfV2LoweringAssetKind,
  page_index : Int,
  object_ref : String?,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  placeholder_block_id : String,
  parser_warnings : Array[@pdfv2.PdfV2Warning],
  parser_risks : Array[@pdfv2.PdfV2Risk],
  reason_tags : Array[String],
) -> PdfV2LoweringAssetRef {
  {
    id,
    kind,
    page_index,
    object_ref,
    source_refs: copy_source_refs(source_refs),
    placeholder_block_id,
    parser_warnings: copy_warnings(parser_warnings),
    parser_risks: copy_risks(parser_risks),
    reason_tags,
  }
}

///|
fn summarize_lowering(
  doc : @normalized_model.PdfV2DocumentModel,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
  blocks : Array[PdfV2LoweredBlock],
  warnings : Array[PdfV2LoweringWarning],
  parser_warnings : Array[@pdfv2.PdfV2Warning],
  parser_risks : Array[@pdfv2.PdfV2Risk],
  decision_trace_count : Int,
  options : PdfV2LoweringOptions,
  missing_feature_count : Int,
  missing_decision_count : Int,
  abstain_count : Int,
  low_confidence_count : Int,
  high_risk_count : Int,
) -> PdfV2LoweringSummary {
  {
    input_page_count: doc.pages.length(),
    input_text_block_count: count_input_text_blocks(doc),
    feature_record_count: features.length(),
    decision_count: decisions.length(),
    lowered_block_count: blocks.length(),
    text_count: count_kind(blocks, PdfV2LoweredBlockKind::Text),
    paragraph_count: count_kind(blocks, PdfV2LoweredBlockKind::Paragraph),
    heading_count: count_kind(blocks, PdfV2LoweredBlockKind::Heading),
    list_item_count: count_kind(blocks, PdfV2LoweredBlockKind::ListItem),
    caption_text_count: count_kind(blocks, PdfV2LoweredBlockKind::CaptionText),
    table_like_text_count: count_kind(
      blocks,
      PdfV2LoweredBlockKind::TableLikeText,
    ),
    image_placeholder_count: count_kind(
      blocks,
      PdfV2LoweredBlockKind::ImagePlaceholder,
    ),
    form_note_count: count_kind(blocks, PdfV2LoweredBlockKind::FormNote),
    annotation_note_count: count_kind(
      blocks,
      PdfV2LoweredBlockKind::AnnotationNote,
    ),
    noise_suppressed_count: count_kind(
      blocks,
      PdfV2LoweredBlockKind::NoiseSuppressed,
    ),
    unsupported_count: count_kind(blocks, PdfV2LoweredBlockKind::Unsupported),
    uncertain_count: count_kind(blocks, PdfV2LoweredBlockKind::Uncertain),
    missing_feature_count,
    missing_decision_count,
    abstain_count,
    low_confidence_count,
    high_risk_count,
    warning_count: warnings.length(),
    parser_warning_count: parser_warnings.length(),
    parser_risk_count: parser_risks.length(),
    decision_trace_count,
    fail_closed: options.fail_closed,
    one_pass_required: true,
    legacy_fallback_allowed: false,
    convert_raw_reparse_allowed: false,
    reason_tags: [
      "lowering_summary", "convert_owned_policy", "one_pass_required", "no_raw_pdf_read",
      "no_legacy_fallback", "no_dispatcher_switch",
    ],
  }
}

///|
fn count_input_text_blocks(doc : @normalized_model.PdfV2DocumentModel) -> Int {
  let mut count = 0
  for page in doc.pages {
    count = count + page.text_blocks.length()
  }
  count
}

///|
fn count_kind(
  blocks : Array[PdfV2LoweredBlock],
  kind : PdfV2LoweredBlockKind,
) -> Int {
  let mut count = 0
  for block in blocks {
    if block.kind == kind {
      count = count + 1
    }
  }
  count
}

///|
fn make_text_origin(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
) -> PdfV2LoweringOrigin {
  {
    page_index: block.page_index,
    block_id: Some(block.id),
    line_ids: line_ids_for(block, feature),
    source_refs: source_refs_for(block, feature),
    object_refs: object_refs_for(block, feature),
    feature_record_id: match feature {
      Some(feature) => Some(feature.doc_id + ":" + feature.block_id)
      None => None
    },
    decision_id: match decision {
      Some(decision) => Some("decision:" + decision.block_id)
      None => None
    },
    parser_warning_count: parser_warnings_for(block, feature, decision).length(),
    parser_risk_count: parser_risks_for(block, feature, decision).length(),
    reason_tags: origin_reason_tags(block, feature, decision),
  }
}

///|
fn make_decision_trace(
  decision : @classifier_gate.PdfV2BlockDecision,
  lowering_action : String,
) -> PdfV2LoweringDecisionTrace {
  {
    block_id: Some(decision.block_id),
    label: decision.label,
    decision_source: decision.trace.decision_source,
    deterministic_constraint_score: decision.trace.scores.deterministic_constraint_score,
    model_confidence: decision.trace.scores.model_confidence,
    feature_support_score: decision.trace.scores.feature_support_score,
    risk_penalty: decision.trace.scores.risk_penalty,
    final_confidence: decision.trace.scores.final_confidence,
    abstain: decision.trace.abstain,
    blocked_reason: decision.trace.blocked_reason,
    reason_tags: copy_decision_tags(decision.trace.reason_tags),
    evidence_feature_names: copy_strings(decision.trace.evidence_feature_names),
    lowering_action,
  }
}

///|
fn warn_low_confidence(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
  options : PdfV2LoweringOptions,
  warnings : Array[PdfV2LoweringWarning],
) -> Unit {
  push_warning(
    warnings,
    options,
    PdfV2LoweringWarningKind::LowConfidenceDecision,
    block.page_index,
    Some(block.id),
    "decision confidence below conservative threshold; kept as text",
    source_refs_for(block, feature),
    object_refs_for(block, feature),
    parser_warnings_for(block, feature, Some(decision)),
    parser_risks_for(block, feature, Some(decision)),
    ["low_confidence", "keep_as_text", "fail_closed"],
  )
}

///|
fn push_warning(
  warnings : Array[PdfV2LoweringWarning],
  options : PdfV2LoweringOptions,
  kind : PdfV2LoweringWarningKind,
  page_index : Int,
  block_id : String?,
  message : String,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  object_refs : Array[String],
  parser_warnings : Array[@pdfv2.PdfV2Warning],
  parser_risks : Array[@pdfv2.PdfV2Risk],
  reason_tags : Array[String],
) -> Unit {
  if options.emit_warnings {
    warnings.push({
      kind,
      page_index: Some(page_index),
      block_id,
      message,
      source_refs: copy_source_refs(source_refs),
      object_refs: copy_strings(object_refs),
      parser_warnings: copy_warnings(parser_warnings),
      parser_risks: copy_risks(parser_risks),
      reason_tags,
    })
  }
}

///|
fn push_placeholder_warning(
  warnings : Array[PdfV2LoweringWarning],
  options : PdfV2LoweringOptions,
  kind : PdfV2LoweringWarningKind,
  page_index : Int,
  block_id : String?,
  message : String,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  object_refs : Array[String],
  parser_warnings : Array[@pdfv2.PdfV2Warning],
  parser_risks : Array[@pdfv2.PdfV2Risk],
  reason_tags : Array[String],
) -> Unit {
  push_warning(
    warnings, options, kind, page_index, block_id, message, source_refs, object_refs,
    parser_warnings, parser_risks, reason_tags,
  )
}

///|
fn append_lowering_warnings(
  target : Array[PdfV2LoweringWarning],
  source : Array[PdfV2LoweringWarning],
) -> Unit {
  for warning in source {
    target.push(warning)
  }
}

///|
fn find_feature(
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  page_index : Int,
  block_id : String,
) -> @feature_export.PdfV2BlockFeatureRecord? {
  for feature in features {
    if feature.page_index == page_index && feature.block_id == block_id {
      return Some(feature)
    }
  }
  None
}

///|
fn find_decision(
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
  page_index : Int,
  block_id : String,
) -> @classifier_gate.PdfV2BlockDecision? {
  for decision in decisions {
    if decision.page_index == page_index && decision.block_id == block_id {
      return Some(decision)
    }
  }
  None
}

///|
fn decision_is_low_confidence(
  decision : @classifier_gate.PdfV2BlockDecision?,
  options : PdfV2LoweringOptions,
) -> Bool {
  match decision {
    None => false
    Some(decision) =>
      if decision.abstain {
        false
      } else {
        match decision.label {
          @classifier_gate.PdfV2BlockDecisionLabel::HeadingCandidate =>
            decision.scores.final_confidence < options.min_heading_confidence
          @classifier_gate.PdfV2BlockDecisionLabel::ListItemCandidate =>
            decision.scores.final_confidence < options.min_list_confidence
          @classifier_gate.PdfV2BlockDecisionLabel::CaptionCandidate =>
            decision.scores.final_confidence < options.min_caption_confidence
          @classifier_gate.PdfV2BlockDecisionLabel::NoiseCandidate =>
            decision.scores.final_confidence < options.min_noise_confidence
          @classifier_gate.PdfV2BlockDecisionLabel::TableCandidate =>
            decision.scores.final_confidence < 0.90
          @classifier_gate.PdfV2BlockDecisionLabel::ParagraphCandidate =>
            decision.scores.final_confidence < 0.50
          @classifier_gate.PdfV2BlockDecisionLabel::TextCandidate => false
          @classifier_gate.PdfV2BlockDecisionLabel::Uncertain => false
        }
      }
  }
}

///|
fn has_high_risk(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
) -> Bool {
  if !block.risks.is_empty() {
    return true
  }
  match feature {
    Some(feature) =>
      if !feature.risks.is_empty() || !feature.feature_risks.is_empty() {
        return true
      }
    None => ()
  }
  match decision {
    Some(decision) =>
      if !decision.risks.is_empty() || decision.scores.risk_penalty >= 0.50 {
        return true
      }
    None => ()
  }
  false
}

///|
fn has_blocking_reason(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
) -> Bool {
  if string_array_has_blocking_reason(block.reason_tags) {
    return true
  }
  match feature {
    Some(feature) =>
      if string_array_has_blocking_reason(feature.reason_tags) ||
        diagnostics_have_blocking_reason(feature.diagnostics) ||
        warnings_have_blocking_reason(feature.warnings) ||
        risks_have_blocking_reason(feature.risks) {
        return true
      }
    None => ()
  }
  if decision.blocked_reason == Some("model_hint_conflict") ||
    decision.blocked_reason == Some("low_signal") ||
    decision.blocked_reason == Some("malformed") ||
    decision.blocked_reason == Some("ocr_recommended_but_not_fallback") ||
    decision.blocked_reason == Some("missing_visual_proximity") {
    return true
  }
  false
}

///|
fn string_array_has_blocking_reason(tags : Array[String]) -> Bool {
  for tag in tags {
    if tag == "model_hint_conflict" ||
      tag == "low_signal" ||
      tag == "malformed" ||
      tag == "ocr_recommended_but_not_fallback" ||
      tag == "missing_visual_proximity" {
      return true
    }
  }
  false
}

///|
fn diagnostics_have_blocking_reason(
  diagnostics : Array[@feature_export.PdfV2FeatureDiagnostic],
) -> Bool {
  for diagnostic in diagnostics {
    if string_array_has_blocking_reason(diagnostic.reason_tags) {
      return true
    }
  }
  false
}

///|
fn warnings_have_blocking_reason(warnings : Array[@pdfv2.PdfV2Warning]) -> Bool {
  for warning in warnings {
    if string_array_has_blocking_reason(warning.reason_tags) {
      return true
    }
  }
  false
}

///|
fn risks_have_blocking_reason(risks : Array[@pdfv2.PdfV2Risk]) -> Bool {
  for risk in risks {
    if string_array_has_blocking_reason(risk.reason_tags) {
      return true
    }
  }
  false
}

///|
fn has_list_marker_evidence(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
) -> Bool {
  if !block.list_marker_candidates.is_empty() {
    return true
  }
  match feature {
    Some(feature) =>
      if feature.candidate_fact_tags.contains("list_marker_candidate") {
        return true
      }
    None => ()
  }
  decision.candidate_fact_tags.contains("list_marker_candidate")
}

///|
fn has_visual_evidence(
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
) -> Bool {
  match feature {
    Some(feature) =>
      if feature.layout_region_kinds.contains("figure") ||
        feature.layout_region_kinds.contains("caption") ||
        feature.layout_region_kinds.contains("image") ||
        feature.candidate_fact_tags.contains("visual_proximity") {
        return true
      }
    None => ()
  }
  decision.layout_region_kinds.contains("figure") ||
  decision.layout_region_kinds.contains("caption") ||
  decision.layout_region_kinds.contains("image")
}

///|
fn has_strong_table_evidence(
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
) -> Bool {
  match feature {
    Some(feature) =>
      if feature.layout_region_kinds.contains("table") &&
        (
          feature.candidate_fact_tags.contains("table_cell_shape_candidate") ||
          feature.candidate_fact_tags.contains("table_region_candidate")
        ) {
        return true
      }
    None => ()
  }
  decision.layout_region_kinds.contains("table") &&
  (
    decision.candidate_fact_tags.contains("table_cell_shape_candidate") ||
    decision.candidate_fact_tags.contains("table_region_candidate")
  )
}

///|
fn has_noise_evidence(
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision,
) -> Bool {
  match feature {
    Some(feature) =>
      if feature.candidate_fact_tags.contains("noise_candidate") ||
        feature.candidate_fact_tags.contains("page_number_shape_candidate") ||
        feature.layout_region_kinds.contains("artifact") ||
        feature.layout_region_kinds.contains("header_footer") {
        return true
      }
    None => ()
  }
  decision.candidate_fact_tags.contains("noise_candidate") ||
  decision.candidate_fact_tags.contains("page_number_shape_candidate") ||
  decision.layout_region_kinds.contains("artifact") ||
  decision.layout_region_kinds.contains("header_footer")
}

///|
fn line_ids_for(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
) -> Array[String] {
  match feature {
    Some(feature) => copy_strings(feature.line_ids)
    None => {
      let ids : Array[String] = []
      for line in block.lines {
        ids.push(line.id)
      }
      ids
    }
  }
}

///|
fn source_refs_for(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
) -> Array[@pdfv2.PdfV2SourceRef] {
  match feature {
    Some(feature) => copy_source_refs(feature.source_refs)
    None => copy_source_refs(block.source_refs)
  }
}

///|
fn object_refs_for(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
) -> Array[String] {
  match feature {
    Some(feature) => copy_strings(feature.object_refs)
    None => copy_strings(block.object_refs)
  }
}

///|
fn parser_warnings_for(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
) -> Array[@pdfv2.PdfV2Warning] {
  let warnings = copy_warnings(block.warnings)
  match feature {
    Some(feature) => append_warnings(warnings, feature.warnings)
    None => ()
  }
  match decision {
    Some(decision) => append_warnings(warnings, decision.warnings)
    None => ()
  }
  warnings
}

///|
fn parser_risks_for(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
) -> Array[@pdfv2.PdfV2Risk] {
  let risks = copy_risks(block.risks)
  match feature {
    Some(feature) => {
      append_risks(risks, feature.risks)
      for feature_risk in feature.feature_risks {
        risks.push(feature_risk.risk)
      }
    }
    None => ()
  }
  match decision {
    Some(decision) => append_risks(risks, decision.risks)
    None => ()
  }
  risks
}

///|
fn collect_parser_warnings(
  doc : @normalized_model.PdfV2DocumentModel,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
) -> Array[@pdfv2.PdfV2Warning] {
  let warnings = copy_warnings(doc.warnings)
  for page in doc.pages {
    append_warnings(warnings, page.warnings)
    for block in page.text_blocks {
      append_warnings(warnings, block.warnings)
    }
    for image in page.images {
      append_warnings(warnings, image.warnings)
    }
    for vector in page.vectors {
      append_warnings(warnings, vector.warnings)
    }
    for annotation in page.annotations {
      append_warnings(warnings, annotation.warnings)
    }
    for form in page.forms {
      append_warnings(warnings, form.warnings)
    }
  }
  for feature in features {
    append_warnings(warnings, feature.warnings)
  }
  for decision in decisions {
    append_warnings(warnings, decision.warnings)
  }
  warnings
}

///|
fn collect_parser_risks(
  doc : @normalized_model.PdfV2DocumentModel,
  features : Array[@feature_export.PdfV2BlockFeatureRecord],
  decisions : Array[@classifier_gate.PdfV2BlockDecision],
) -> Array[@pdfv2.PdfV2Risk] {
  let risks = copy_risks(doc.risks)
  for page in doc.pages {
    append_risks(risks, page.risks)
    for block in page.text_blocks {
      append_risks(risks, block.risks)
    }
    for image in page.images {
      append_risks(risks, image.risks)
    }
    for vector in page.vectors {
      append_risks(risks, vector.risks)
    }
    for annotation in page.annotations {
      append_risks(risks, annotation.risks)
    }
    for form in page.forms {
      append_risks(risks, form.risks)
    }
  }
  for feature in features {
    append_risks(risks, feature.risks)
    for feature_risk in feature.feature_risks {
      risks.push(feature_risk.risk)
    }
  }
  for decision in decisions {
    append_risks(risks, decision.risks)
  }
  risks
}

///|
fn origin_reason_tags(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
) -> Array[String] {
  let tags = copy_strings(block.reason_tags)
  match feature {
    Some(feature) => append_strings(tags, feature.reason_tags)
    None => ()
  }
  match decision {
    Some(decision) =>
      append_strings(tags, decision_tags_to_strings(decision.reason_tags))
    None => ()
  }
  tags.push("lowering_origin")
  tags.push("convert_owned_trace")
  tags
}

///|
fn text_block_reason_tags(
  block : @normalized_model.PdfV2TextBlock,
  feature : @feature_export.PdfV2BlockFeatureRecord?,
  decision : @classifier_gate.PdfV2BlockDecision?,
  kind : PdfV2LoweredBlockKind,
) -> Array[String] {
  let tags = origin_reason_tags(block, feature, decision)
  tags.push("lowered_as_" + kind_action(kind))
  tags.push("parser_model_not_mutated")
  tags.push("classifier_decision_not_mutated")
  tags
}

///|
fn kind_action(kind : PdfV2LoweredBlockKind) -> String {
  match kind {
    Text => "text"
    Paragraph => "paragraph"
    Heading => "heading"
    ListItem => "list_item"
    CaptionText => "caption_text"
    TableLikeText => "table_like_text"
    ImagePlaceholder => "image_placeholder"
    FormNote => "form_note"
    AnnotationNote => "annotation_note"
    NoiseSuppressed => "noise_suppressed"
    Unsupported => "unsupported"
    Uncertain => "uncertain"
  }
}

///|
fn decision_tags_to_strings(
  tags : Array[@classifier_gate.PdfV2BlockDecisionReasonTag],
) -> Array[String] {
  let strings : Array[String] = []
  for tag in tags {
    strings.push(decision_tag_to_string(tag))
  }
  strings
}

///|
fn decision_tag_to_string(
  tag : @classifier_gate.PdfV2BlockDecisionReasonTag,
) -> String {
  match tag {
    @classifier_gate.PdfV2BlockDecisionReasonTag::FeaturesOnly =>
      "features_only"
    @classifier_gate.PdfV2BlockDecisionReasonTag::EmptyFeatures =>
      "empty_features"
    @classifier_gate.PdfV2BlockDecisionReasonTag::CandidateEvidenceOnly =>
      "candidate_evidence_only"
    @classifier_gate.PdfV2BlockDecisionReasonTag::LayoutMembershipPreserved =>
      "layout_membership_preserved"
    @classifier_gate.PdfV2BlockDecisionReasonTag::ParserRiskPresent =>
      "parser_risk_present"
    @classifier_gate.PdfV2BlockDecisionReasonTag::ParserWarningPresent =>
      "parser_warning_present"
    @classifier_gate.PdfV2BlockDecisionReasonTag::ModelHintAccepted =>
      "model_hint_accepted"
    @classifier_gate.PdfV2BlockDecisionReasonTag::ModelHintIgnored =>
      "model_hint_ignored"
    @classifier_gate.PdfV2BlockDecisionReasonTag::WeakHeuristicUsed =>
      "weak_heuristic_used"
    @classifier_gate.PdfV2BlockDecisionReasonTag::FailClosed => "fail_closed"
    @classifier_gate.PdfV2BlockDecisionReasonTag::NoFallback => "no_fallback"
    @classifier_gate.PdfV2BlockDecisionReasonTag::NoFinalSemanticLabel =>
      "no_final_semantic_label"
  }
}

///|
fn append_strings(target : Array[String], source : Array[String]) -> Unit {
  for item in source {
    target.push(item)
  }
}

///|
fn append_warnings(
  target : Array[@pdfv2.PdfV2Warning],
  source : Array[@pdfv2.PdfV2Warning],
) -> Unit {
  for warning in source {
    target.push(warning)
  }
}

///|
fn append_risks(
  target : Array[@pdfv2.PdfV2Risk],
  source : Array[@pdfv2.PdfV2Risk],
) -> Unit {
  for risk in source {
    target.push(risk)
  }
}

///|
fn copy_strings(source : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for item in source {
    out.push(item)
  }
  out
}

///|
fn copy_source_refs(
  source : Array[@pdfv2.PdfV2SourceRef],
) -> Array[@pdfv2.PdfV2SourceRef] {
  let out : Array[@pdfv2.PdfV2SourceRef] = []
  for item in source {
    out.push(item)
  }
  out
}

///|
fn copy_warnings(
  source : Array[@pdfv2.PdfV2Warning],
) -> Array[@pdfv2.PdfV2Warning] {
  let out : Array[@pdfv2.PdfV2Warning] = []
  for warning in source {
    out.push(warning)
  }
  out
}

///|
fn copy_risks(source : Array[@pdfv2.PdfV2Risk]) -> Array[@pdfv2.PdfV2Risk] {
  let out : Array[@pdfv2.PdfV2Risk] = []
  for risk in source {
    out.push(risk)
  }
  out
}

///|
fn copy_decision_tags(
  source : Array[@classifier_gate.PdfV2BlockDecisionReasonTag],
) -> Array[@classifier_gate.PdfV2BlockDecisionReasonTag] {
  let out : Array[@classifier_gate.PdfV2BlockDecisionReasonTag] = []
  for tag in source {
    out.push(tag)
  }
  out
}

///|
fn object_ref_array(object_ref : String?) -> Array[String] {
  match object_ref {
    Some(object_ref) => [object_ref]
    None => []
  }
}
