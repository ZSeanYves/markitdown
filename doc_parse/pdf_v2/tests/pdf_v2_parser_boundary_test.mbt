///|
test "pdf v2 layout recovery scaffold fails closed" {
  let source_ref = @pdfv2.pdf_v2_document_source_ref()
  let result = @pdfv2.recover_pdf_v2_layout_noop([source_ref])

  assert_true(result.regions.length() == 0)
  assert_true(result.reading_order.region_indices.length() == 0)
  assert_true(result.confidence == 0.0)
  assert_true(result.risks.length() == 1)
  assert_true(result.risks[0].kind == @pdfv2.PdfV2RiskKind::LowSignal)
}

///|
test "pdf v2 text facts expose classifier-ready parser features" {
  let features = @pdfv2.pdf_v2_empty_classifier_ready_features()
  assert_true(features.text_preview == "")
  assert_true(!features.text_shape.has_list_marker)
  assert_true(!features.text_shape.has_caption_prefix)
  assert_true(features.text_shape.heading_shape_score == 0.0)
  assert_true(features.text_shape.body_density_guard_score == 0.0)
  assert_true(features.risk_tags.length() == 0)
}
