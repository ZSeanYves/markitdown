///|
pub(all) enum PdfV2SemanticBlockKind {
  Paragraph
  Heading
  OrderedListItem
  UnorderedListItem
  Continuation
  PlainText
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2TextFlowMarkerKind {
  HeadingMarker
  OrderedListMarker
  UnorderedListMarker
} derive(Eq)

///|
pub(all) struct PdfV2TextFlowMarker {
  kind : PdfV2TextFlowMarkerKind
  marker_text : String
  body_text : String
  level_hint : Int?
}

///|
pub(all) struct PdfV2TextFlowSignals {
  is_single_line : Bool
  is_short : Bool
  ends_with_sentence_punctuation : Bool
  starts_with_ordered_marker : Bool
  starts_with_unordered_marker : Bool
  starts_with_heading_marker : Bool
  looks_like_page_number : Bool
  looks_like_caption_marker : Bool
  has_following_body : Bool
  has_previous_heading : Bool
  continuation_candidate : Bool
  parser_fact_backed : Bool
  parser_heading_candidate_score : Double
  parser_list_candidate_score : Double
  parser_continuation_candidate_score : Double
  parser_artifact_candidate_score : Double
}

///|
pub(all) struct PdfV2TextFlowUnit {
  page_index : Int?
  block_index : Int?
  flow_index : Int
  fragment_index : Int
  line_start : Int?
  line_end : Int?
  text : String
  normalized_text : String
  line_count : Int
  char_count : Int
  starts_with_marker : Bool
  marker_kind : PdfV2TextFlowMarkerKind?
  marker : PdfV2TextFlowMarker?
  indent_level : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  signals : PdfV2TextFlowSignals
}

///|
pub(all) struct PdfV2RuleDecision {
  kind : PdfV2SemanticBlockKind
  confidence : Double
  rule_id : String
  reason_tags : Array[String]
  negative_reason_tags : Array[String]
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  risk_tags : Array[String]
}

///|
pub(all) struct PdfV2SemanticBlock {
  kind : PdfV2SemanticBlockKind
  text : String
  level : Int?
  ordered : Bool?
  list_level : Int
  page_index : Int?
  block_index : Int?
  fragment_index : Int
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
  risk_tags : Array[String]
  decision : PdfV2RuleDecision
}

///|
pub(all) struct PdfV2CrossPageArbitrationAuditCounter {
  key : String
  count : Int
}

///|
pub(all) struct PdfV2CrossPageArbitrationAudit {
  generated_fact_count : Int
  facts_reaching_product_arbitration_count : Int
  product_candidate_fact_count : Int
  facts_passing_confidence_gate : Int
  facts_passing_source_ref_gate : Int
  facts_passing_prev_open_ended_gate : Int
  facts_passing_next_marker_gate : Int
  facts_passing_ambiguity_tag_gate : Int
  rejected_confidence_below_threshold_count : Int
  rejected_missing_source_refs_count : Int
  rejected_mismatched_source_refs_count : Int
  rejected_prev_not_open_ended_count : Int
  rejected_next_marker_list_page_number_blocker_count : Int
  rejected_next_heading_title_like_blocker_count : Int
  rejected_ambiguity_audit_or_low_confidence_tag_count : Int
  rejected_no_matching_fragment_or_semantic_pair_count : Int
  evaluated_pair_count : Int
  semantic_pair_count : Int
  fragment_pair_count : Int
  actual_join_decision_changed_count : Int
  actual_split_decision_changed_count : Int
  fallback_existing_behavior_count : Int
  reason_tag_distribution : Array[PdfV2CrossPageArbitrationAuditCounter]
  gate_rejection_distribution : Array[PdfV2CrossPageArbitrationAuditCounter]
}

///|
pub(all) struct PdfV2CrossPageStructuralHandoff {
  boundary_index : Int
  page_from : Int
  page_to : Int
  prev_refs : Array[@pdfv2.PdfV2SourceRef]
  next_refs : Array[@pdfv2.PdfV2SourceRef]
  prev_block_kind : PdfV2SemanticBlockKind
  next_block_kind : PdfV2SemanticBlockKind
  prev_heading_level : Int?
  next_heading_level : Int?
  next_list_marker_evidence : Bool
  prev_open_ended : Bool
  next_starts_structural_block : Bool
  title_body_boundary_evidence : Bool
  should_join_paragraph : Bool
  should_preserve_next_structure : Bool
  should_preserve_heading_level : Bool
  should_preserve_list_marker : Bool
  confidence : Double
  reason_tags : Array[String]
  blockers : Array[String]
  matched_fact : @pdfv2.PdfV2CrossPageBoundaryFact?
}

///|
pub(all) struct PdfV2ModelHint {
  model_kind : String
  predicted_kind : PdfV2SemanticBlockKind?
  confidence : Double
  evidence : Array[String]
}

///|
pub(all) enum PdfV2SemanticDisagreementPolicy {
  RuleHardConstraintsFirst
  RuleOnly
} derive(Eq)

///|
pub(all) struct PdfV2SemanticArbitrationInput {
  rule_decision : PdfV2RuleDecision
  model_hint : PdfV2ModelHint?
  disagreement_policy : PdfV2SemanticDisagreementPolicy
}

///|
pub(all) struct PdfV2SemanticArbitrationResult {
  decision : PdfV2RuleDecision
  model_hint_present : Bool
  model_hint_used : Bool
  disagreement_policy : PdfV2SemanticDisagreementPolicy
  reason_tags : Array[String]
}
