///|
test "layout assist noop provider is report only" {
  let info = noop_layout_assist_provider_info()
  assert_eq(info.name, "noop-layout-assist")
  assert_true(info.mode == LayoutAssistMode::ReportOnly)
  assert_true(info.available)
}

///|
test "layout assist provider list stays non-gated by default" {
  let providers = list_layout_assist_providers()
  assert_true(providers.length() >= 2)
  for provider in providers {
    assert_true(provider.mode != LayoutAssistMode::GatedNormal)
  }
}

///|
test "layout assist noop returns no predictions" {
  let predictions = predict_with_noop_layout_assist([
    {
      target_id: "b1",
      text: "Figure 1 Overview",
      page_index: 0,
      block_kind_hint: Some("caption"),
      rule_label_hint: None,
      deterministic_constraints: [],
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 0)
}

///|
test "layout assist heuristic provider emits stable advisory caption" {
  let predictions = predict_with_heuristic_layout_assist([
    {
      target_id: "b1",
      text: "Figure 1 Overview",
      page_index: 0,
      block_kind_hint: None,
      rule_label_hint: None,
      deterministic_constraints: [],
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 1)
  assert_eq(predictions[0].page_index, 0)
  assert_eq(predictions[0].suggested_label, "caption_candidate")
  assert_true(predictions[0].mode == LayoutAssistMode::ReportOnly)
  assert_eq(predictions[0].provider, "heuristic-layout-assist")
  assert_true(predictions[0].reasons == ["caption_prefix"])
  assert_true(!predictions[0].disagreement)
  assert_true(!predictions[0].would_change_output)
  assert_eq(predictions[0].blocked_by_constraints.length(), 0)
}

///|
test "layout assist heuristic provider respects block kind hints" {
  let predictions = predict_with_heuristic_layout_assist([
    {
      target_id: "b-heading",
      text: "Introduction",
      page_index: 1,
      block_kind_hint: Some("heading"),
      rule_label_hint: Some("heading"),
      deterministic_constraints: [],
      metrics_json: None,
    },
    {
      target_id: "b-table",
      text: "Revenue | Cost | Margin",
      page_index: 1,
      block_kind_hint: Some("table"),
      rule_label_hint: Some("paragraph"),
      deterministic_constraints: ["table_geometry"],
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 2)
  assert_eq(predictions[0].target_id, "b-heading")
  assert_eq(predictions[0].page_index, 1)
  assert_eq(predictions[0].suggested_label, "heading_candidate")
  assert_true(predictions[0].reasons == ["block_kind_hint=heading"])
  assert_eq(predictions[1].target_id, "b-table")
  assert_eq(predictions[1].page_index, 1)
  assert_eq(predictions[1].suggested_label, "table_like_candidate")
  assert_true(predictions[1].reasons == ["block_kind_hint=table"])
  assert_true(
    match predictions[1].rule_label_hint {
      Some(v) => v == "paragraph"
      None => false
    },
  )
  assert_true(predictions[1].disagreement)
  assert_true(predictions[1].blocked_by_constraints == ["table_geometry"])
}

///|
test "layout assist heuristic provider can stay empty" {
  let predictions = predict_with_heuristic_layout_assist([
    {
      target_id: "b1",
      text: "A long ordinary paragraph that should not produce a provider hint.",
      page_index: 0,
      block_kind_hint: None,
      rule_label_hint: None,
      deterministic_constraints: [],
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 0)
}

///|
test "layout assist summary reports stable label counts" {
  let features = [
    {
      target_id: "b-caption",
      text: "Figure 1 Overview",
      page_index: 0,
      block_kind_hint: None,
      rule_label_hint: Some("caption"),
      deterministic_constraints: [],
      metrics_json: None,
    },
    {
      target_id: "b-table",
      text: "Revenue | Cost | Margin",
      page_index: 0,
      block_kind_hint: Some("table"),
      rule_label_hint: Some("table"),
      deterministic_constraints: ["table_geometry"],
      metrics_json: None,
    },
  ]
  let predictions = predict_with_heuristic_layout_assist(features)
  let summary = summarize_layout_assist_predictions(features, predictions)
  assert_eq(summary.provider_count >= 2, true)
  assert_eq(summary.feature_count, 2)
  assert_eq(summary.prediction_count, 2)
  assert_eq(summary.disagreement_count, 0)
  assert_eq(summary.change_candidate_count, 0)
  assert_eq(summary.warning_count, 0)
  assert_eq(summary.label_counts.get("caption_candidate").unwrap_or(0), 1)
  assert_eq(summary.label_counts.get("table_like_candidate").unwrap_or(0), 1)
  assert_eq(summary.reason_counts.get("caption_prefix").unwrap_or(0), 1)
}

///|
test "layout assist model bridge records disagreement and constraints" {
  let features = [
    {
      target_id: "b1",
      text: "TOTAL $821.14",
      page_index: 0,
      block_kind_hint: None,
      rule_label_hint: Some("heading"),
      deterministic_constraints: ["table_geometry"],
      metrics_json: None,
    },
  ]
  let model = match
    @pdflayout.parse_pdf_layout_model_json(
      "{\n" +
      "  \"version\": 1,\n" +
      "  \"task\": \"pdf_layout_classifier\",\n" +
      "  \"model_type\": \"linear_v1\",\n" +
      "  \"labels\": [\"BodyText\", \"Heading\"],\n" +
      "  \"features\": [\"contains_currency\", \"looks_like_address\", \"is_heading_candidate\"],\n" +
      "  \"normalization\": {\"mean\": [0, 0, 0], \"scale\": [1, 1, 1]},\n" +
      "  \"weights\": {\n" +
      "    \"BodyText\": {\"bias\": 0.9, \"values\": [1.2, 0.9, -0.8]},\n" +
      "    \"Heading\": {\"bias\": -0.5, \"values\": [-0.3, -0.2, 1.4]}\n" +
      "  },\n" +
      "  \"thresholds\": {\n" +
      "    \"BodyText\": {\"min_score\": 0.0, \"min_confidence\": 0.0},\n" +
      "    \"Heading\": {\"min_score\": 0.0, \"min_confidence\": 0.0}\n" +
      "  }\n" +
      "}\n",
    ) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let feature_rows = match
    @pdflayout.parse_pdf_layout_features_tsv(
      "sample_id\tsource_path\trecord_kind\tpage_index\tblock_index\tline_index\tnext_page_index\tnext_block_index\tnext_line_index\ttext\tlabel\tcontains_currency\tlooks_like_address\tis_heading_candidate\tnotes\n" +
      "sample\tsample.pdf\tblock\t1\t0\t0\t\t\t\tTOTAL $821.14\t\t1\t0\t1\tmanual\n",
    ) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let decisions = match
    @pdflayout.classify_pdf_layout_features(model, feature_rows) {
    Ok(v) => v
    Err(err) => fail(err.message)
  }
  let predictions = classify_model_decisions_as_layout_assist(
    features, decisions,
  )
  assert_eq(predictions.length(), 1)
  assert_eq(predictions[0].suggested_label, "BodyText")
  assert_true(predictions[0].disagreement)
  assert_true(!predictions[0].would_change_output)
  assert_true(
    match predictions[0].rule_label_hint {
      Some(v) => v == "heading"
      None => false
    },
  )
  assert_true(predictions[0].blocked_by_constraints == ["table_geometry"])
}
