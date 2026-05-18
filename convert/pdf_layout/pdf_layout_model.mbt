///|
pub enum PdfLayoutModelErrorKind {
  InvalidJson
  MissingField
  WrongType
  InvalidValue
  UnknownFeature
  MissingWeight
} derive(Eq)

///|
pub struct PdfLayoutModelError {
  kind : PdfLayoutModelErrorKind
  message : String
}

///|
pub struct PdfLayoutLabelWeights {
  label : String
  bias : Double
  values : Array[Double]
}

///|
pub struct PdfLayoutThreshold {
  label : String
  min_score : Double
  min_confidence : Double
}

///|
pub struct PdfLayoutModel {
  version : Int
  task : String
  model_type : String
  labels : Array[String]
  features : Array[String]
  normalization_mean : Array[Double]
  normalization_scale : Array[Double]
  weights : Array[PdfLayoutLabelWeights]
  thresholds : Array[PdfLayoutThreshold]
  metadata : Map[String, String]
}

///|
pub fn parse_pdf_layout_model_json(
  text : String,
) -> Result[PdfLayoutModel, PdfLayoutModelError] {
  let doc = try? @dpjson.parse_json_document(text)
  match doc {
    Err(err) =>
      Err({
        kind: PdfLayoutModelErrorKind::InvalidJson,
        message: err.to_string(),
      })
    Ok(v) => parse_pdf_layout_model_value(v.root)
  }
}

///|
pub fn validate_pdf_layout_model(
  model : PdfLayoutModel,
) -> Result[Unit, PdfLayoutModelError] {
  if model.version <= 0 {
    return Err(model_error(InvalidValue, "model version must be > 0"))
  }
  if model.task != "pdf_layout_classifier" {
    return Err(
      model_error(InvalidValue, "model task must be pdf_layout_classifier"),
    )
  }
  if model.model_type.trim() == "" {
    return Err(model_error(InvalidValue, "model_type must be non-empty"))
  }
  if model.labels.is_empty() {
    return Err(model_error(InvalidValue, "labels must be non-empty"))
  }
  if model.features.is_empty() {
    return Err(model_error(InvalidValue, "features must be non-empty"))
  }
  if model.normalization_mean.length() != model.features.length() {
    return Err(
      model_error(
        InvalidValue,
        "normalization.mean length must match features length",
      ),
    )
  }
  if model.normalization_scale.length() != model.features.length() {
    return Err(
      model_error(
        InvalidValue,
        "normalization.scale length must match features length",
      ),
    )
  }

  let feature_seen : Map[String, Bool] = Map([])
  for feature in model.features {
    if feature.trim() == "" {
      return Err(model_error(InvalidValue, "feature names must be non-empty"))
    }
    if feature_seen.contains(feature) {
      return Err(model_error(InvalidValue, "duplicate feature: " + feature))
    }
    feature_seen.set(feature, true)
  }

  let label_seen : Map[String, Bool] = Map([])
  for label in model.labels {
    if label.trim() == "" {
      return Err(model_error(InvalidValue, "labels must be non-empty"))
    }
    if label_seen.contains(label) {
      return Err(model_error(InvalidValue, "duplicate label: " + label))
    }
    label_seen.set(label, true)
  }

  let threshold_seen : Map[String, Bool] = Map([])
  for threshold in model.thresholds {
    if !label_seen.contains(threshold.label) {
      return Err(
        model_error(
          InvalidValue,
          "threshold label missing from labels: " + threshold.label,
        ),
      )
    }
    if threshold_seen.contains(threshold.label) {
      return Err(
        model_error(
          InvalidValue,
          "duplicate threshold label: " + threshold.label,
        ),
      )
    }
    threshold_seen.set(threshold.label, true)
  }

  let weight_seen : Map[String, Bool] = Map([])
  for weight in model.weights {
    if !label_seen.contains(weight.label) {
      return Err(
        model_error(
          InvalidValue,
          "weight label missing from labels: " + weight.label,
        ),
      )
    }
    if weight_seen.contains(weight.label) {
      return Err(
        model_error(InvalidValue, "duplicate weight label: " + weight.label),
      )
    }
    if weight.values.length() != model.features.length() {
      return Err(
        model_error(
          MissingWeight,
          "weight length mismatch for label: " + weight.label,
        ),
      )
    }
    weight_seen.set(weight.label, true)
  }

  for label in model.labels {
    if !weight_seen.contains(label) {
      return Err(
        model_error(MissingWeight, "missing weights for label: " + label),
      )
    }
  }

  Ok(())
}

///|
fn parse_pdf_layout_model_value(
  value : @dpjson.JsonValue,
) -> Result[PdfLayoutModel, PdfLayoutModelError] {
  let root = match expect_object(value, "root") {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  let version = match required_int(root, "version") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let task = match required_string(root, "task") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let model_type = match required_string(root, "model_type") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let labels = match required_string_array(root, "labels") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let features = match required_string_array(root, "features") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let normalization = match required_object(root, "normalization") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let normalization_mean = match required_number_array(normalization, "mean") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let normalization_scale = match
    required_number_array(normalization, "scale") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let weights_value = match required_object(root, "weights") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let thresholds_value = match optional_object(root, "thresholds") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let metadata_value = match optional_object(root, "metadata") {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  let weights = match parse_label_weights(weights_value) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let thresholds = match parse_thresholds(thresholds_value) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let metadata = parse_stringish_metadata(metadata_value)

  let model = {
    version,
    task,
    model_type,
    labels,
    features,
    normalization_mean,
    normalization_scale,
    weights,
    thresholds,
    metadata,
  }

  match validate_pdf_layout_model(model) {
    Ok(_) => Ok(model)
    Err(err) => Err(err)
  }
}

///|
fn parse_label_weights(
  members : Array[@dpjson.JsonMember],
) -> Result[Array[PdfLayoutLabelWeights], PdfLayoutModelError] {
  let out : Array[PdfLayoutLabelWeights] = []
  for entry in members {
    let obj = match expect_object(entry.value, "weights." + entry.key) {
      Ok(v) => v
      Err(err) => return Err(err)
    }
    let bias = match required_number(obj, "bias") {
      Ok(v) => v
      Err(err) =>
        return Err(prefix_model_error(err, "weights." + entry.key + "."))
    }
    let values = match required_number_array(obj, "values") {
      Ok(v) => v
      Err(err) =>
        return Err(prefix_model_error(err, "weights." + entry.key + "."))
    }
    out.push({ label: entry.key, bias, values })
  }
  Ok(out)
}

///|
fn parse_thresholds(
  members : Array[@dpjson.JsonMember]?,
) -> Result[Array[PdfLayoutThreshold], PdfLayoutModelError] {
  let out : Array[PdfLayoutThreshold] = []
  match members {
    None => Ok(out)
    Some(items) => {
      for entry in items {
        let obj = match expect_object(entry.value, "thresholds." + entry.key) {
          Ok(v) => v
          Err(err) => return Err(err)
        }
        let min_score = match optional_number_default(obj, "min_score", 0.0) {
          Ok(v) => v
          Err(err) =>
            return Err(prefix_model_error(err, "thresholds." + entry.key + "."))
        }
        let min_confidence = match
          optional_number_default(obj, "min_confidence", 0.0) {
          Ok(v) => v
          Err(err) =>
            return Err(prefix_model_error(err, "thresholds." + entry.key + "."))
        }
        out.push({ label: entry.key, min_score, min_confidence })
      }
      Ok(out)
    }
  }
}

///|
fn parse_stringish_metadata(
  members : Array[@dpjson.JsonMember]?,
) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  match members {
    None => out
    Some(items) => {
      for entry in items {
        out.set(entry.key, json_value_string(entry.value))
      }
      out
    }
  }
}

///|
fn required_object(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Array[@dpjson.JsonMember], PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(value) => expect_object(value, key)
    None => Err(model_error(MissingField, "missing object field: " + key))
  }
}

///|
fn optional_object(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Array[@dpjson.JsonMember]?, PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(value) =>
      match expect_object(value, key) {
        Ok(v) => Ok(Some(v))
        Err(err) => Err(err)
      }
    None => Ok(None)
  }
}

///|
fn required_string(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[String, PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(@dpjson.JsonValue::String(v)) => Ok(v)
    Some(_) => Err(model_error(WrongType, "field must be string: " + key))
    None => Err(model_error(MissingField, "missing string field: " + key))
  }
}

///|
fn required_int(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Int, PdfLayoutModelError] {
  match required_number(members, key) {
    Ok(v) => Ok(v.to_int())
    Err(err) => Err(err)
  }
}

///|
fn required_number(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Double, PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(@dpjson.JsonValue::Number(raw)) =>
      match try_parse_number(raw) {
        Some(v) => Ok(v)
        None => Err(model_error(InvalidValue, "invalid number field: " + key))
      }
    Some(_) => Err(model_error(WrongType, "field must be number: " + key))
    None => Err(model_error(MissingField, "missing number field: " + key))
  }
}

///|
fn optional_number_default(
  members : Array[@dpjson.JsonMember],
  key : String,
  default : Double,
) -> Result[Double, PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(@dpjson.JsonValue::Number(raw)) =>
      match try_parse_number(raw) {
        Some(v) => Ok(v)
        None => Err(model_error(InvalidValue, "invalid number field: " + key))
      }
    Some(_) => Err(model_error(WrongType, "field must be number: " + key))
    None => Ok(default)
  }
}

///|
fn required_string_array(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Array[String], PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(@dpjson.JsonValue::Array(values)) => {
      let out : Array[String] = []
      for value in values {
        match value {
          @dpjson.JsonValue::String(s) => out.push(s)
          _ =>
            return Err(
              model_error(WrongType, "array items must be string: " + key),
            )
        }
      }
      Ok(out)
    }
    Some(_) => Err(model_error(WrongType, "field must be array: " + key))
    None => Err(model_error(MissingField, "missing array field: " + key))
  }
}

///|
fn required_number_array(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> Result[Array[Double], PdfLayoutModelError] {
  match find_json_member(members, key) {
    Some(@dpjson.JsonValue::Array(values)) => {
      let out : Array[Double] = []
      for value in values {
        match value {
          @dpjson.JsonValue::Number(raw) =>
            match try_parse_number(raw) {
              Some(v) => out.push(v)
              None =>
                return Err(
                  model_error(
                    InvalidValue,
                    "array items must be valid numbers: " + key,
                  ),
                )
            }
          _ =>
            return Err(
              model_error(WrongType, "array items must be number: " + key),
            )
        }
      }
      Ok(out)
    }
    Some(_) => Err(model_error(WrongType, "field must be array: " + key))
    None => Err(model_error(MissingField, "missing array field: " + key))
  }
}

///|
fn expect_object(
  value : @dpjson.JsonValue,
  name : String,
) -> Result[Array[@dpjson.JsonMember], PdfLayoutModelError] {
  match value {
    @dpjson.JsonValue::Object(members) => Ok(members)
    _ => Err(model_error(WrongType, name + " must be an object"))
  }
}

///|
fn find_json_member(
  members : Array[@dpjson.JsonMember],
  key : String,
) -> @dpjson.JsonValue? {
  for entry in members {
    if entry.key == key {
      return Some(entry.value)
    }
  }
  None
}

///|
fn try_parse_number(raw : String) -> Double? {
  try @string.parse_double(raw) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn json_value_string(value : @dpjson.JsonValue) -> String {
  match value {
    @dpjson.JsonValue::String(s) => s
    @dpjson.JsonValue::Number(n) => n
    @dpjson.JsonValue::Bool(b) => if b { "true" } else { "false" }
    @dpjson.JsonValue::Null => "null"
    @dpjson.JsonValue::Array(_) => "[array]"
    @dpjson.JsonValue::Object(_) => "{object}"
  }
}

///|
fn model_error(
  kind : PdfLayoutModelErrorKind,
  message : String,
) -> PdfLayoutModelError {
  { kind, message }
}

///|
fn prefix_model_error(
  err : PdfLayoutModelError,
  prefix : String,
) -> PdfLayoutModelError {
  { kind: err.kind, message: prefix + err.message }
}
