///|
test "test_feature_export_consumes_normalized_model_and_layout_only" {
  let doc = fe_doc_with_text("A", 0.98, 12.0)
  let layout = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  let result = @feature_export.export_pdf_v2_block_features(
    doc,
    layout,
    @feature_export.default_pdf_v2_feature_export_options(),
  )
  assert_eq(result.summary.record_count, 1)
  assert_eq(result.summary.one_pass_required, true)
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
  assert_eq(result.reason_tags[1], "parser_owned_classifier_ready_features")
}

///|
test "test_default_schema_contains_caption_list_heading_features" {
  let schema = @feature_export.default_pdf_v2_block_feature_schema()
  assert_eq(schema_has(schema, "caption_prefix_candidate"), true)
  assert_eq(schema_has(schema, "caption_prefix_confidence"), true)
  assert_eq(schema_has(schema, "list_marker_candidate"), true)
  assert_eq(schema_has(schema, "list_marker_text"), true)
  assert_eq(schema_has(schema, "heading_shape_candidate"), true)
  assert_eq(schema_has(schema, "heading_shape_confidence"), true)
  assert_eq(schema_has(schema, "near_image_distance"), true)
  assert_eq(schema_has(schema, "table_region_confidence"), true)
}

///|
test "test_feature_record_preserves_block_page_source_context" {
  let result = fe_result_for_text("B", 0.98, 12.0)
  let record = result.records[0]
  assert_eq(record.doc_id, "pdf_v2_document")
  assert_eq(record.page_index, 0)
  assert_eq(record.block_id, "block_0")
  assert_eq(record.line_ids[0], "line_0")
  assert_eq(record.source_refs[0].page_index, 0)
  assert_eq(record.object_refs[0], "100 0 R")
  assert_eq(record.text, "B")
  assert_eq(record.text_length, 1)
  assert_eq(record.char_count, 1)
}

///|
test "test_candidate_facts_export_as_evidence_not_final_labels" {
  let result = fe_result_for_text("Figure", 0.98, 12.0)
  let record = result.records[0]
  assert_eq(value_bool(record, "caption_prefix_candidate"), true)
  assert_eq(value_float(record, "caption_prefix_confidence") > 0.0, true)
  assert_eq(
    record.candidate_fact_tags.contains("caption_prefix_candidate"),
    true,
  )
  assert_eq(record_has_field(record, "final_caption"), false)
  assert_eq(record_has_field(record, "final_markdown_block_kind"), false)
}

///|
test "test_layout_region_membership_exports_region_features" {
  let result = fe_result_for_text("C", 0.98, 12.0)
  let record = result.records[0]
  assert_eq(record.layout_region_ids.length(), 1)
  assert_eq(record.layout_region_kinds[0], "paragraph")
  assert_eq(value_enum(record, "layout_region_kind"), "paragraph")
  assert_eq(value_float(record, "layout_region_confidence") > 0.0, true)
  assert_eq(value_int(record, "reading_order_index"), 0)
  assert_eq(value_float(record, "reading_order_confidence") > 0.0, true)
}

///|
test "test_missing_visual_proximity_features_are_structured_diagnostics" {
  let result = fe_result_for_text("D", 0.98, 12.0)
  let record = result.records[0]
  assert_eq(
    value_availability(record, "near_image_distance") ==
    @feature_export.PdfV2FeatureAvailability::MissingWithWarning,
    true,
  )
  assert_eq(
    has_feature_diagnostic(record.diagnostics, "near_image_distance"),
    true,
  )
  assert_eq(
    has_feature_diagnostic(result.diagnostics, "nearest_table_region_id"),
    true,
  )
  assert_eq(result.summary.missing_warning_count > 0, true)
}

///|
test "test_risk_features_propagate_to_feature_record" {
  let doc = fe_doc_with_text("E", 0.20, 12.0)
  let layout = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  let result = @feature_export.export_pdf_v2_block_features(
    doc,
    layout,
    @feature_export.default_pdf_v2_feature_export_options(),
  )
  let record = result.records[0]
  assert_eq(record.risks.length() > 0, true)
  assert_eq(value_int(record, "decode_low_confidence_count"), 1)
  assert_eq(value_bool(record, "low_signal_document"), false)
}

///|
test "test_summary_counts_available_planned_missing_features" {
  let result = fe_result_for_text("F", 0.98, 12.0)
  assert_eq(result.summary.field_count, result.schema.fields.length())
  assert_eq(result.summary.available_count > 0, true)
  assert_eq(result.summary.planned_count > 0, true)
  assert_eq(result.summary.missing_warning_count > 0, true)
  assert_eq(result.summary.diagnostic_count > 0, true)
}

///|
test "test_schema_marks_runtime_gate_and_training_requirements" {
  let schema = @feature_export.default_pdf_v2_block_feature_schema()
  let field = schema_field(schema, "caption_prefix_candidate")
  assert_eq(field.required_by_runtime_gate, true)
  assert_eq(field.required_by_training, true)
  assert_eq(
    field.group == @feature_export.PdfV2FeatureGroup::CandidateFacts,
    true,
  )
  let visual = schema_field(schema, "near_image_distance")
  assert_eq(
    visual.availability ==
    @feature_export.PdfV2FeatureAvailability::MissingWithWarning,
    true,
  )
  assert_eq(visual.missing_behavior, "emit_structured_warning")
}

///|
test "test_feature_export_preserves_one_pass_no_fallback_policy" {
  let result = fe_result_for_text("G", 0.98, 12.0)
  assert_eq(result.summary.one_pass_required, true)
  assert_eq(result.summary.legacy_fallback_allowed, false)
  assert_eq(result.summary.convert_raw_reparse_allowed, false)
  assert_eq(result.reason_tags[2], "no_pdf_reparse")
  assert_eq(result.reason_tags[4], "no_tsv_writer")
}

///|
test "test_feature_export_does_not_emit_final_semantic_labels" {
  let result = fe_result_for_text("1.", 0.98, 12.0)
  let schema = result.schema
  let record = result.records[0]
  assert_eq(schema_has(schema, "final_heading"), false)
  assert_eq(schema_has(schema, "final_paragraph"), false)
  assert_eq(schema_has(schema, "final_list_item"), false)
  assert_eq(schema_has(schema, "final_table"), false)
  assert_eq(record_has_field(record, "final_ir_kind"), false)
  assert_eq(value_bool(record, "list_marker_candidate"), true)
}

///|
fn fe_result_for_text(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @feature_export.PdfV2FeatureExportResult {
  let doc = fe_doc_with_text(text, confidence, font_size)
  let layout = @layout_recovery.recover_pdf_v2_layout(
    doc,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  @feature_export.export_pdf_v2_block_features(
    doc,
    layout,
    @feature_export.default_pdf_v2_feature_export_options(),
  )
}

///|
fn fe_doc_with_text(
  text : String,
  confidence : Double,
  font_size : Double,
) -> @normalized_model.PdfV2DocumentModel {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70])),
    [fe_text_event("text_event", 0, text, confidence, font_size, 4)],
  )
  let text_model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  @normalized_model.build_pdf_v2_document_model(source, text_model)
}

///|
fn fe_text_event(
  id : String,
  page_index : Int,
  text : String,
  confidence : Double,
  font_size : Double,
  content_order_index : Int,
) -> @source_event.PdfV2SourceEvent {
  @source_event.pdf_v2_text_payload_event(
    id,
    page_index,
    Some("100 0 R"),
    fe_source_ref(page_index, content_order_index),
    fe_payload(text, confidence, font_size, content_order_index),
  )
}

///|
fn fe_payload(
  text : String,
  confidence : Double,
  font_size : Double,
  content_order_index : Int,
) -> @source_event.PdfV2SourceTextPayload {
  {
    text,
    raw_bytes: Some(Bytes::from_array([65])),
    decoded_unicode: Some(text),
    bbox: Some({ x0: 20.0, y0: 30.0, x1: 92.0, y1: 48.0 }),
    origin: Some({ x: 20.0, y: 45.0 }),
    quad: None,
    advance_width: Some(8.0),
    glyph_width: Some(7.0),
    font_name: Some("F1"),
    font_family: Some("TestFont"),
    font_size: Some(font_size),
    style_flags: ["regular"],
    fill_color: None,
    stroke_color: None,
    rotation: 0,
    writing_direction: @pdfv2.PdfV2WritingDirection::LeftToRight,
    content_order_index: Some(content_order_index),
    decode_confidence: Some(confidence),
    reason_tags: ["feature_export_test_payload"],
  }
}

///|
fn fe_source_ref(
  page_index : Int,
  content_order_index : Int,
) -> @pdfv2.PdfV2SourceRef {
  {
    page_index,
    object_ref: Some("100 0 R"),
    stream_index: Some(0),
    op_index: Some(2),
    content_order_index: Some(content_order_index),
    text_object_id: Some(1),
  }
}

///|
fn schema_has(
  schema : @feature_export.PdfV2BlockFeatureSchema,
  name : String,
) -> Bool {
  @feature_export.pdf_v2_feature_schema_has_field(schema, name)
}

///|
fn record_has_field(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> Bool {
  @feature_export.pdf_v2_block_feature_has_field(record, name)
}

///|
fn schema_field(
  schema : @feature_export.PdfV2BlockFeatureSchema,
  name : String,
) -> @feature_export.PdfV2FeatureField {
  for field in schema.fields {
    if field.name == name {
      return field
    }
  }
  abort("missing schema field: " + name)
}

///|
fn feature_value(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> @feature_export.PdfV2FeatureValue {
  for value in record.values {
    if value.field_name == name {
      return value
    }
  }
  abort("missing feature value: " + name)
}

///|
fn value_bool(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> Bool {
  feature_value(record, name).bool_value.unwrap_or(false)
}

///|
fn value_int(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> Int {
  feature_value(record, name).int_value.unwrap_or(-1)
}

///|
fn value_float(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> Double {
  feature_value(record, name).float_value.unwrap_or(-1.0)
}

///|
fn value_enum(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> String {
  feature_value(record, name).enum_value.unwrap_or("")
}

///|
fn value_availability(
  record : @feature_export.PdfV2BlockFeatureRecord,
  name : String,
) -> @feature_export.PdfV2FeatureAvailability {
  feature_value(record, name).availability
}

///|
fn has_feature_diagnostic(
  diagnostics : Array[@feature_export.PdfV2FeatureDiagnostic],
  field_name : String,
) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.field_name == field_name {
      return true
    }
  }
  false
}
