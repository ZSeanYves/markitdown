///|
pub enum LayoutAssistMode {
  ReportOnly
  Advisory
  GatedNormal
} derive(Eq)

///|
pub struct LayoutAssistProviderInfo {
  name : String
  version : String?
  mode : LayoutAssistMode
  available : Bool
}

///|
pub struct LayoutAssistFeature {
  target_id : String
  text : String
  page_index : Int
  block_kind_hint : String?
  metrics_json : String?
}

///|
pub struct LayoutAssistPrediction {
  target_id : String
  suggested_label : String
  confidence : Double?
  provider : String
  mode : LayoutAssistMode
  reasons : Array[String]
}

///|
pub fn noop_layout_assist_provider_info() -> LayoutAssistProviderInfo {
  {
    name: "noop-layout-assist",
    version: None,
    mode: LayoutAssistMode::ReportOnly,
    available: true,
  }
}

///|
pub fn heuristic_layout_assist_provider_info() -> LayoutAssistProviderInfo {
  {
    name: "heuristic-layout-assist",
    version: Some("rule-wrap-v1"),
    mode: LayoutAssistMode::ReportOnly,
    available: true,
  }
}

///|
pub fn list_layout_assist_providers() -> Array[LayoutAssistProviderInfo] {
  [noop_layout_assist_provider_info(), heuristic_layout_assist_provider_info()]
}

///|
pub fn predict_with_noop_layout_assist(
  _features : Array[LayoutAssistFeature],
) -> Array[LayoutAssistPrediction] {
  []
}

///|
pub fn predict_with_heuristic_layout_assist(
  features : Array[LayoutAssistFeature],
) -> Array[LayoutAssistPrediction] {
  let out : Array[LayoutAssistPrediction] = []
  for feature in features {
    match heuristic_layout_assist_prediction(feature) {
      Some(prediction) => out.push(prediction)
      None => ()
    }
  }
  out
}

///|
fn heuristic_layout_assist_prediction(
  feature : LayoutAssistFeature,
) -> LayoutAssistPrediction? {
  let trimmed = feature.text.trim().to_owned()
  if trimmed == "" {
    return None
  }

  let hint = feature.block_kind_hint |> Option::unwrap_or("")
  let reasons : Array[String] = []

  if hint == "caption" {
    reasons.push("block_kind_hint=caption")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        "caption_candidate",
        Some(0.85),
        "heuristic-layout-assist",
        reasons,
      ),
    )
  }

  if hint == "table" {
    reasons.push("block_kind_hint=table")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        "table_candidate",
        Some(0.80),
        "heuristic-layout-assist",
        reasons,
      ),
    )
  }

  if hint == "heading" {
    reasons.push("block_kind_hint=heading")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        "heading_candidate",
        Some(0.75),
        "heuristic-layout-assist",
        reasons,
      ),
    )
  }

  if looks_like_table_caption_prefix(trimmed) ||
    looks_like_image_caption_prefix(trimmed) {
    reasons.push("caption_prefix")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        "caption_candidate",
        Some(0.70),
        "heuristic-layout-assist",
        reasons,
      ),
    )
  }

  None
}

///|
fn make_layout_assist_prediction(
  target_id : String,
  suggested_label : String,
  confidence : Double?,
  provider : String,
  reasons : Array[String],
) -> LayoutAssistPrediction {
  {
    target_id,
    suggested_label,
    confidence,
    provider,
    mode: LayoutAssistMode::ReportOnly,
    reasons,
  }
}
