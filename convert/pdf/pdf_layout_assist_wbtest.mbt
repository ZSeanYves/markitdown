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
  assert_eq(predictions[0].suggested_label, "caption_candidate")
  assert_true(predictions[0].mode == LayoutAssistMode::ReportOnly)
  assert_eq(predictions[0].provider, "heuristic-layout-assist")
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
