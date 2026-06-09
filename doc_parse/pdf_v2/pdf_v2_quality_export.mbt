///|
pub fn pdf_v2_default_feature_contract() -> Array[PdfV2FeatureContractField] {
  [
    feature_field(
      "block.text_len",
      "block",
      PdfV2FeatureUse::DerivedFeature,
      true,
      true,
      "stable block text length",
    ),
    feature_field(
      "block.bbox",
      "block",
      PdfV2FeatureUse::DerivedFeature,
      true,
      true,
      "block geometry",
    ),
    feature_field(
      "line.hanging_indent_delta",
      "line",
      PdfV2FeatureUse::DerivedFeature,
      true,
      true,
      "list continuation support",
    ),
    feature_field(
      "block.near_image_distance",
      "block",
      PdfV2FeatureUse::SoftHint,
      true,
      true,
      "caption proximity support",
    ),
    feature_field(
      "block.font_size_delta_from_body",
      "block",
      PdfV2FeatureUse::DerivedFeature,
      true,
      true,
      "heading guard support",
    ),
    feature_field(
      "page.low_signal_risk",
      "page",
      PdfV2FeatureUse::Abstain,
      true,
      true,
      "fail-closed risk support",
    ),
    feature_field(
      "source.content_order_index",
      "source",
      PdfV2FeatureUse::ReportOnly,
      true,
      true,
      "provenance and reading order audit",
    ),
  ]
}

///|
fn feature_field(
  name : String,
  level : String,
  usage : PdfV2FeatureUse,
  required_for_convert : Bool,
  required_for_training : Bool,
  notes : String,
) -> PdfV2FeatureContractField {
  { name, level, usage, required_for_convert, required_for_training, notes }
}
