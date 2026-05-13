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
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 1)
  assert_eq(predictions[0].page_index, 0)
  assert_eq(predictions[0].suggested_label, "caption_candidate")
  assert_true(predictions[0].mode == LayoutAssistMode::ReportOnly)
  assert_eq(predictions[0].provider, "heuristic-layout-assist")
  assert_eq(predictions[0].reasons, ["caption_prefix"])
}

///|
test "layout assist heuristic provider respects block kind hints" {
  let predictions = predict_with_heuristic_layout_assist([
    {
      target_id: "b-heading",
      text: "Introduction",
      page_index: 1,
      block_kind_hint: Some("heading"),
      metrics_json: None,
    },
    {
      target_id: "b-table",
      text: "Revenue | Cost | Margin",
      page_index: 1,
      block_kind_hint: Some("table"),
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 2)
  assert_eq(predictions[0].target_id, "b-heading")
  assert_eq(predictions[0].page_index, 1)
  assert_eq(predictions[0].suggested_label, "heading_candidate")
  assert_eq(predictions[0].reasons, ["block_kind_hint=heading"])
  assert_eq(predictions[1].target_id, "b-table")
  assert_eq(predictions[1].page_index, 1)
  assert_eq(predictions[1].suggested_label, "table_candidate")
  assert_eq(predictions[1].reasons, ["block_kind_hint=table"])
}

///|
test "layout assist heuristic provider can stay empty" {
  let predictions = predict_with_heuristic_layout_assist([
    {
      target_id: "b1",
      text: "A long ordinary paragraph that should not produce a provider hint.",
      page_index: 0,
      block_kind_hint: None,
      metrics_json: None,
    },
  ])
  assert_eq(predictions.length(), 0)
}
