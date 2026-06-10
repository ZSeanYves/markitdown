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
