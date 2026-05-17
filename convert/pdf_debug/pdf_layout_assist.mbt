///|
#warnings("-unused_constructor")
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
  rule_label_hint : String?
  deterministic_constraints : Array[String]
  metrics_json : String?
}

///|
pub struct LayoutAssistPrediction {
  target_id : String
  page_index : Int
  suggested_label : String
  confidence : Double?
  provider : String
  mode : LayoutAssistMode
  reasons : Array[String]
  secondary_label : String?
  rule_label_hint : String?
  disagreement : Bool
  blocked_by_constraints : Array[String]
  would_change_output : Bool
}

///|
pub struct LayoutAssistSummary {
  provider_count : Int
  feature_count : Int
  prediction_count : Int
  label_counts : Map[String, Int]
  reason_counts : Map[String, Int]
  disagreement_count : Int
  change_candidate_count : Int
  warning_count : Int
  providers : Array[LayoutAssistProviderInfo]
  predictions : Array[LayoutAssistPrediction]
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
        feature.page_index,
        "caption_candidate",
        Some(0.85),
        "heuristic-layout-assist",
        None,
        feature.rule_label_hint,
        layout_assist_has_disagreement(
          feature.rule_label_hint,
          "caption_candidate",
        ),
        feature.deterministic_constraints,
        reasons,
      ),
    )
  }

  if hint == "table" {
    reasons.push("block_kind_hint=table")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        feature.page_index,
        "table_like_candidate",
        Some(0.80),
        "heuristic-layout-assist",
        None,
        feature.rule_label_hint,
        layout_assist_has_disagreement(
          feature.rule_label_hint,
          "table_like_candidate",
        ),
        feature.deterministic_constraints,
        reasons,
      ),
    )
  }

  if hint == "heading" {
    reasons.push("block_kind_hint=heading")
    return Some(
      make_layout_assist_prediction(
        feature.target_id,
        feature.page_index,
        "heading_candidate",
        Some(0.75),
        "heuristic-layout-assist",
        None,
        feature.rule_label_hint,
        layout_assist_has_disagreement(
          feature.rule_label_hint,
          "heading_candidate",
        ),
        feature.deterministic_constraints,
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
        feature.page_index,
        "caption_candidate",
        Some(0.70),
        "heuristic-layout-assist",
        None,
        feature.rule_label_hint,
        layout_assist_has_disagreement(
          feature.rule_label_hint,
          "caption_candidate",
        ),
        feature.deterministic_constraints,
        reasons,
      ),
    )
  }

  None
}

///|
fn make_layout_assist_prediction(
  target_id : String,
  page_index : Int,
  suggested_label : String,
  confidence : Double?,
  provider : String,
  secondary_label : String?,
  rule_label_hint : String?,
  disagreement : Bool,
  blocked_by_constraints : Array[String],
  reasons : Array[String],
) -> LayoutAssistPrediction {
  let would_change_output = layout_assist_would_change_output(
    rule_label_hint, suggested_label, confidence, blocked_by_constraints,
  )
  {
    target_id,
    page_index,
    suggested_label,
    confidence,
    provider,
    mode: LayoutAssistMode::ReportOnly,
    reasons,
    secondary_label,
    rule_label_hint,
    disagreement,
    blocked_by_constraints,
    would_change_output,
  }
}

///|
pub fn classify_model_decisions_as_layout_assist(
  features : Array[LayoutAssistFeature],
  decisions : Array[@pdfcore.PdfLayoutModelDecision],
  provider? : String = "linear-layout-assist",
  mode? : LayoutAssistMode = LayoutAssistMode::ReportOnly,
) -> Array[LayoutAssistPrediction] {
  let out : Array[LayoutAssistPrediction] = []
  let count = min_layout_assist_int(features.length(), decisions.length())
  for i = 0; i < count; i = i + 1 {
    let feature = features[i]
    let decision = decisions[i]
    let prediction = make_layout_assist_prediction(
      feature.target_id,
      feature.page_index,
      decision.label,
      Some(decision.confidence),
      provider,
      feature.block_kind_hint,
      feature.rule_label_hint,
      layout_assist_has_disagreement(feature.rule_label_hint, decision.label),
      feature.deterministic_constraints,
      decision.reasons,
    )
    out.push({ ..prediction, mode, })
  }
  out
}

///|
fn looks_like_image_caption_prefix(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  lower.has_prefix("figure ") ||
  lower.has_prefix("figure") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("fig.") ||
  lower.has_prefix("image ") ||
  lower.has_prefix("photo ") ||
  trimmed.has_prefix("图 ") ||
  trimmed.has_prefix("图") ||
  trimmed.has_prefix("图片 ")
}

///|
fn looks_like_table_caption_prefix(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  lower.has_prefix("table ") ||
  lower.has_prefix("table") ||
  trimmed.has_prefix("表 ")
}

///|
pub fn summarize_layout_assist_predictions(
  features : Array[LayoutAssistFeature],
  predictions : Array[LayoutAssistPrediction],
) -> LayoutAssistSummary {
  let providers = list_layout_assist_providers()
  let label_counts = Map([])
  let reason_counts = Map([])
  let mut disagreement_count = 0
  let mut change_candidate_count = 0
  let mut warning_count = 0
  for prediction in predictions {
    bump_layout_assist_count(label_counts, prediction.suggested_label)
    if prediction.disagreement {
      disagreement_count += 1
    }
    if prediction.would_change_output {
      change_candidate_count += 1
    }
    if prediction.reasons.length() == 0 {
      warning_count += 1
    }
    for reason in prediction.reasons {
      bump_layout_assist_count(reason_counts, reason)
    }
  }
  {
    provider_count: providers.length(),
    feature_count: features.length(),
    prediction_count: predictions.length(),
    label_counts,
    reason_counts,
    disagreement_count,
    change_candidate_count,
    warning_count,
    providers,
    predictions,
  }
}

///|
fn bump_layout_assist_count(counts : Map[String, Int], key : String) -> Unit {
  let prev = counts.get(key).unwrap_or(0)
  counts.set(key, prev + 1)
}

///|
fn layout_assist_has_disagreement(
  rule_label_hint : String?,
  suggested_label : String,
) -> Bool {
  match rule_label_hint {
    Some(rule) =>
      normalize_layout_assist_label(rule) !=
      normalize_layout_assist_label(suggested_label)
    None => false
  }
}

///|
fn layout_assist_would_change_output(
  rule_label_hint : String?,
  suggested_label : String,
  confidence : Double?,
  blocked_by_constraints : Array[String],
) -> Bool {
  if blocked_by_constraints.length() > 0 {
    return false
  }
  if !layout_assist_has_disagreement(rule_label_hint, suggested_label) {
    return false
  }
  match confidence {
    Some(value) => value >= 0.85
    None => false
  }
}

///|
fn normalize_layout_assist_label(label : String) -> String {
  let lower = label.trim().to_lower()
  if lower == "heading" ||
    lower == "heading_candidate" ||
    lower == "title" ||
    lower == "section-header" {
    "heading"
  } else if lower == "paragraph" ||
    lower == "bodytext" ||
    lower == "body_text" ||
    lower == "text" ||
    lower == "keep_as_text" {
    "paragraph"
  } else if lower == "table" ||
    lower == "tablelike" ||
    lower == "table_like" ||
    lower == "table_like_candidate" {
    "table"
  } else if lower == "caption" || lower == "caption_candidate" {
    "caption"
  } else if lower == "noise" ||
    lower == "separator" ||
    lower == "footer_header_noise" {
    "noise"
  } else if lower == "list" ||
    lower == "list_item" ||
    lower == "list_item_candidate" {
    "list"
  } else {
    lower.to_owned()
  }
}
