///|
pub struct PdfLayoutModelDecision {
  label : String
  score : Double
  confidence : Double
  threshold : Double
  accepted : Bool
  reasons : Array[String]
  page_index : Int
  block_index : Int
  line_index : Int
  record_kind : PdfLayoutRecordKind
}

///|
pub fn classify_pdf_layout_feature(
  model : PdfLayoutModel,
  feature : PdfLayoutFeature,
) -> Result[PdfLayoutModelDecision, PdfLayoutModelError] {
  match validate_pdf_layout_model(model) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }

  let vector = match feature_vector_for_model(model, feature) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let decisions = score_pdf_layout_feature(model, feature, vector)
  if decisions.is_empty() {
    return Err(model_error(InvalidValue, "model produced no decisions"))
  }
  Ok(decisions[0])
}

///|
pub fn classify_pdf_layout_features(
  model : PdfLayoutModel,
  features : Array[PdfLayoutFeature],
) -> Result[Array[PdfLayoutModelDecision], PdfLayoutModelError] {
  match validate_pdf_layout_model(model) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }

  let out : Array[PdfLayoutModelDecision] = []
  for feature in features {
    let vector = match feature_vector_for_model(model, feature) {
      Ok(v) => v
      Err(err) => return Err(err)
    }
    let decisions = score_pdf_layout_feature(model, feature, vector)
    if decisions.is_empty() {
      return Err(model_error(InvalidValue, "model produced no decisions"))
    }
    out.push(decisions[0])
  }
  Ok(out)
}

///|
pub fn score_pdf_layout_feature(
  model : PdfLayoutModel,
  feature : PdfLayoutFeature,
  normalized_vector : Array[Double],
) -> Array[PdfLayoutModelDecision] {
  let decisions : Array[PdfLayoutModelDecision] = []
  for weight in model.weights {
    let score = linear_score(weight.bias, weight.values, normalized_vector)
    let confidence = logistic(score)
    let threshold = threshold_for_label(model.thresholds, weight.label)
    let accepted = score >= threshold.min_score &&
      confidence >= threshold.min_confidence
    decisions.push({
      label: weight.label,
      score,
      confidence,
      threshold: threshold.min_score,
      accepted,
      reasons: feature_reason_summary(
        model.features,
        feature,
        normalized_vector,
      ),
      page_index: feature.page_index,
      block_index: feature.block_index,
      line_index: feature.line_index,
      record_kind: feature.record_kind,
    })
  }
  sort_layout_decisions(decisions)
}

///|
fn feature_vector_for_model(
  model : PdfLayoutModel,
  feature : PdfLayoutFeature,
) -> Result[Array[Double], PdfLayoutModelError] {
  let raw : Array[Double] = []
  for i = 0; i < model.features.length(); i = i + 1 {
    let name = model.features[i]
    match feature.feature_values.get(name) {
      Some(value) => {
        let mean = model.normalization_mean[i]
        let scale = normalized_scale(model.normalization_scale[i])
        raw.push((value - mean) / scale)
      }
      None =>
        return Err(
          model_error(UnknownFeature, "feature missing from record: " + name),
        )
    }
  }
  Ok(raw)
}

///|
fn linear_score(
  bias : Double,
  weights : Array[Double],
  vector : Array[Double],
) -> Double {
  let mut total = bias
  for i = 0; i < weights.length(); i = i + 1 {
    total = total + weights[i] * vector[i]
  }
  total
}

///|
fn logistic(value : Double) -> Double {
  let clipped = if value > 30.0 {
    30.0
  } else if value < -30.0 {
    -30.0
  } else {
    value
  }
  1.0 / (1.0 + exp_neg(clipped))
}

///|
fn exp_neg(value : Double) -> Double {
  let mut sum = 1.0
  let mut term = 1.0
  let neg = -value
  for n = 1; n <= 12; n = n + 1 {
    term = term * neg / n.to_double()
    sum = sum + term
  }
  sum
}

///|
fn threshold_for_label(
  thresholds : Array[PdfLayoutThreshold],
  label : String,
) -> PdfLayoutThreshold {
  for threshold in thresholds {
    if threshold.label == label {
      return threshold
    }
  }
  { label, min_score: 0.0, min_confidence: 0.0 }
}

///|
fn normalized_scale(value : Double) -> Double {
  if value == 0.0 {
    1.0
  } else {
    value
  }
}

///|
fn feature_reason_summary(
  feature_names : Array[String],
  feature : PdfLayoutFeature,
  vector : Array[Double],
) -> Array[String] {
  let out : Array[String] = []
  let magnitudes : Array[(String, Double)] = []
  for i = 0; i < feature_names.length(); i = i + 1 {
    let name = feature_names[i]
    let value = vector[i]
    let abs_value = if value < 0.0 { -value } else { value }
    if abs_value >= 0.35 {
      magnitudes.push((name, abs_value))
    }
  }

  magnitudes.sort_by(fn(a, b) {
    if a.1 > b.1 {
      -1
    } else if a.1 < b.1 {
      1
    } else if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    }
  })

  let limit = if magnitudes.length() < 3 { magnitudes.length() } else { 3 }
  for i = 0; i < limit; i = i + 1 {
    out.push(magnitudes[i].0)
  }

  if out.is_empty() {
    out.push(
      pdf_layout_record_kind_name(feature.record_kind) + "_baseline_feature",
    )
  }
  out
}

///|
fn sort_layout_decisions(
  decisions : Array[PdfLayoutModelDecision],
) -> Array[PdfLayoutModelDecision] {
  decisions.sort_by(fn(left, right) {
    if left.accepted && !right.accepted {
      return -1
    }
    if !left.accepted && right.accepted {
      return 1
    }
    if left.score > right.score {
      return -1
    }
    if left.score < right.score {
      return 1
    }
    if left.confidence > right.confidence {
      return -1
    }
    if left.confidence < right.confidence {
      return 1
    }
    if left.label < right.label {
      -1
    } else if left.label > right.label {
      1
    } else {
      0
    }
  })
  decisions
}
