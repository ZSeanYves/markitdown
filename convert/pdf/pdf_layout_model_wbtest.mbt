///|
fn test_layout_feature(
  sample_id : String,
  label : String?,
  values : Array[(String, Double)],
) -> PdfLayoutFeature {
  let map : Map[String, Double] = Map([])
  for pair in values {
    let (key, value) = pair
    map.set(key, value)
  }
  make_pdf_layout_feature(
    sample_id,
    "sample.pdf",
    PdfLayoutRecordKind::Block,
    0,
    0,
    0,
    None,
    None,
    None,
    "Heading Example",
    label,
    None,
    map,
  )
}

///|
fn base_model_json() -> String {
  "{\n" +
  "  \"version\": 1,\n" +
  "  \"task\": \"pdf_layout_classifier\",\n" +
  "  \"model_type\": \"linear_v1\",\n" +
  "  \"labels\": [\"BodyText\", \"Heading\"],\n" +
  "  \"features\": [\"font_size_hint\", \"is_heading_candidate\", \"word_count\"],\n" +
  "  \"normalization\": {\n" +
  "    \"mean\": [0, 0, 0],\n" +
  "    \"scale\": [1, 1, 1]\n" +
  "  },\n" +
  "  \"weights\": {\n" +
  "    \"BodyText\": {\"bias\": 0.8, \"values\": [-0.2, -0.8, 0.5]},\n" +
  "    \"Heading\": {\"bias\": -1.5, \"values\": [1.6, 2.4, -0.6]}\n" +
  "  },\n" +
  "  \"thresholds\": {\n" +
  "    \"BodyText\": {\"min_score\": 0.0, \"min_confidence\": 0.0},\n" +
  "    \"Heading\": {\"min_score\": 0.6, \"min_confidence\": 0.5}\n" +
  "  },\n" +
  "  \"metadata\": {\n" +
  "    \"notes\": \"test\"\n" +
  "  }\n" +
  "}\n"
}

///|
test "pdf layout model parses valid json" {
  let parsed = parse_pdf_layout_model_json(base_model_json())
  match parsed {
    Ok(model) => {
      assert_eq(model.labels.length(), 2)
      assert_eq(model.features.length(), 3)
      assert_eq(model.weights.length(), 2)
    }
    Err(err) => fail("expected valid model parse, got " + err.message)
  }
}

///|
test "pdf layout model malformed json fails closed" {
  let parsed = parse_pdf_layout_model_json("{bad json")
  match parsed {
    Ok(_) => fail("expected malformed json failure")
    Err(err) => assert_true(err.kind == PdfLayoutModelErrorKind::InvalidJson)
  }
}

///|
test "pdf layout model missing weights fails closed" {
  let raw = "{\n" +
    "  \"version\": 1,\n" +
    "  \"task\": \"pdf_layout_classifier\",\n" +
    "  \"model_type\": \"linear_v1\",\n" +
    "  \"labels\": [\"Heading\"],\n" +
    "  \"features\": [\"font_size_hint\"],\n" +
    "  \"normalization\": {\"mean\": [0], \"scale\": [1]},\n" +
    "  \"weights\": {},\n" +
    "  \"thresholds\": {}\n" +
    "}\n"
  let parsed = parse_pdf_layout_model_json(raw)
  match parsed {
    Ok(_) => fail("expected missing weights failure")
    Err(err) => assert_true(err.kind == PdfLayoutModelErrorKind::MissingWeight)
  }
}

///|
test "pdf layout inference missing feature fails closed" {
  let model = match parse_pdf_layout_model_json(base_model_json()) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let feature = test_layout_feature("sample", None, [("font_size_hint", 16.0)])
  let decision = classify_pdf_layout_feature(model, feature)
  match decision {
    Ok(_) => fail("expected missing feature failure")
    Err(err) => assert_true(err.kind == PdfLayoutModelErrorKind::UnknownFeature)
  }
}

///|
test "pdf layout inference deterministic heading decision" {
  let model = match parse_pdf_layout_model_json(base_model_json()) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let feature = test_layout_feature("sample", Some("Heading"), [
    ("font_size_hint", 16.0),
    ("is_heading_candidate", 1.0),
    ("word_count", 2.0),
  ])
  let first = match classify_pdf_layout_feature(model, feature) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let second = match classify_pdf_layout_feature(model, feature) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  assert_eq(first.label, "Heading")
  assert_eq(first.label, second.label)
  assert_eq(first.score.to_string(), second.score.to_string())
}

///|
test "pdf layout threshold can reject low score decision" {
  let model = match parse_pdf_layout_model_json(base_model_json()) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let feature = test_layout_feature("sample", Some("BodyText"), [
    ("font_size_hint", 0.1),
    ("is_heading_candidate", 0.0),
    ("word_count", 8.0),
  ])
  let decision = match classify_pdf_layout_feature(model, feature) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  assert_true(!decision.accepted || decision.label == "BodyText")
}

///|
test "pdf layout multiple labels sort deterministic" {
  let model = match parse_pdf_layout_model_json(base_model_json()) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let feature = test_layout_feature("sample", None, [
    ("font_size_hint", 9.0),
    ("is_heading_candidate", 1.0),
    ("word_count", 1.0),
  ])
  let vector = match feature_vector_for_model(model, feature) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let first = score_pdf_layout_feature(model, feature, vector)
  let second = score_pdf_layout_feature(model, feature, vector)
  assert_eq(first.length(), 2)
  assert_eq(first[0].label, second[0].label)
  assert_eq(first[1].label, second[1].label)
}

///|
test "pdf layout feature tsv parse and infer smoke" {
  let feature_tsv = "sample_id\tsource_path\trecord_kind\tpage_index\tblock_index\tline_index\tnext_page_index\tnext_block_index\tnext_line_index\ttext\tlabel\tfont_size_hint\tis_heading_candidate\tword_count\tnotes\n" +
    "sample\tsample.pdf\tblock\t1\t0\t0\t\t\t\tHeading Example\tHeading\t16\t1\t2\tmanual\n"
  let report = infer_pdf_layout_features_tsv(base_model_json(), feature_tsv)
  match report {
    Ok(text) => {
      assert_true(text.contains("predicted_label"))
      assert_true(text.contains("Heading"))
    }
    Err(err) => fail(err.message)
  }
}
