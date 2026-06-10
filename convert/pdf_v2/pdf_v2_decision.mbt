///|
pub(all) enum PdfV2BlockRole {
  Heading
  Paragraph
  ListItem
  Caption
  TableLike
  FooterHeaderNoise
  PageNumberNoise
  KeepAsText
  Uncertain
} derive(Eq)

///|
pub(all) enum PdfV2DecisionSource {
  DeterministicRule
  ModelHint
  WeightedGate
  Abstain
} derive(Eq)

///|
pub(all) struct PdfV2BlockDecision {
  role : PdfV2BlockRole
  confidence : Double
  source : PdfV2DecisionSource
  reason_tags : Array[String]
  abstained : Bool
}

///|
pub(all) enum PdfV2BlockDecisionKind {
  PlainTextCandidate
  Abstain
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2NoModelDecisionSource {
  NoModelGate
  RuleGuard
  RiskGuard
  CapGuard
  UnsupportedGuard
} derive(Eq)

///|
pub(all) struct PdfV2BlockGateDecision {
  page_index : Int?
  block_index : Int
  decision_kind : PdfV2BlockDecisionKind
  confidence : Double
  risk_score : Double
  abstain_reason_tags : Array[String]
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  warning_count : Int
  risk_count : Int
  feature_summary : String
  decision_source : PdfV2NoModelDecisionSource
}

///|
pub(all) struct PdfV2GateSummary {
  block_count : Int
  plain_text_candidate_count : Int
  abstain_count : Int
  unknown_count : Int
  risk_guard_count : Int
  cap_guard_count : Int
  unsupported_guard_count : Int
  missing_geometry_guard_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2GateResult {
  decisions : Array[PdfV2BlockGateDecision]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  summary : PdfV2GateSummary
  one_pass : Bool
  no_fallback : Bool
}

///|
pub fn pdf_v2_abstain_decision(
  reason_tags : Array[String],
) -> PdfV2BlockDecision {
  {
    role: PdfV2BlockRole::Uncertain,
    confidence: 0.0,
    source: PdfV2DecisionSource::Abstain,
    reason_tags,
    abstained: true,
  }
}

///|
pub fn pdf_v2_keep_as_text_decision(
  confidence : Double,
  source : PdfV2DecisionSource,
  reason_tags : Array[String],
) -> PdfV2BlockDecision {
  {
    role: PdfV2BlockRole::KeepAsText,
    confidence,
    source,
    reason_tags,
    abstained: false,
  }
}
