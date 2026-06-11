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
