///|
pub(all) struct PdfV2ConvertOptions {
  max_heading : Int
  emit_diagnostic_block : Bool
  emit_decision_summary : Bool
  fail_closed : Bool
}

///|
pub(all) struct PdfV2PipelineResult {
  document : @cor.Document
  core : @pdfv2.PdfV2CoreDocument
  source : @source_event.PdfV2SourceDocument
  text_model : @text_reconstruction.PdfV2TextModel
  model : @normalized_model.PdfV2DocumentModel
  layout : @layout_recovery.PdfV2LayoutRecoveryResult
  features : @feature_export.PdfV2FeatureExportResult
  decisions : Array[@classifier_gate.PdfV2BlockDecision]
  lowering : @lowering.PdfV2LoweringResult
  reason_tags : Array[String]
}

///|
pub fn default_pdf_v2_convert_options() -> PdfV2ConvertOptions {
  {
    max_heading: 6,
    emit_diagnostic_block: true,
    emit_decision_summary: true,
    fail_closed: true,
  }
}

///|
pub fn parse_pdf_v2(
  input_path : String,
  out_root : String,
  max_heading : Int,
  _enhance_mode : String?,
  _extract_debug : Bool,
  _dump_selected_raw : Bool,
  _pipeline_debug : Bool,
) -> @cor.Document raise {
  let options = { ..default_pdf_v2_convert_options(), max_heading, }
  parse_pdf_v2_with_options(input_path, out_root, options).document
}

///|
pub fn parse_pdf_v2_with_options(
  input_path : String,
  _out_root : String,
  options : PdfV2ConvertOptions,
) -> PdfV2PipelineResult raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf_v2: file not found: " + input_path)
  }
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("pdf_v2: read failed: " + e.to_string())
  }
  parse_pdf_v2_bytes_with_options(bytes, @cor.basename(input_path), options)
}

///|
pub fn parse_pdf_v2_bytes_with_options(
  bytes : Bytes,
  source_name : String,
  options : PdfV2ConvertOptions,
) -> PdfV2PipelineResult {
  let core = @pdfv2.open_pdf_core_v2(bytes)
  let source = @source_event.build_pdf_v2_source_event_document(core, [])
  let text_model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  let model = @normalized_model.build_pdf_v2_document_model(source, text_model)
  let layout = @layout_recovery.recover_pdf_v2_layout(
    model,
    @layout_recovery.default_pdf_v2_layout_recovery_options(),
  )
  let features = @feature_export.export_pdf_v2_block_features(model, layout, {
    ..@feature_export.default_pdf_v2_feature_export_options(),
    doc_id: source_name,
  })
  let decisions = @classifier_gate.build_pdf_v2_block_decisions(
    features.records,
    @classifier_gate.default_pdf_v2_block_decision_options(),
  )
  let lowering_options = {
    ..@lowering.default_pdf_v2_lowering_options(),
    fail_closed: options.fail_closed,
    emit_decision_summary: options.emit_decision_summary,
  }
  let lowered = @lowering.lower_pdf_v2_document(
    model,
    features.records,
    decisions,
    lowering_options,
  )
  let document = lower_pdf_v2_result_to_core_document(
    lowered, source_name, options,
  )
  {
    document,
    core,
    source,
    text_model,
    model,
    layout,
    features,
    decisions,
    lowering: lowered,
    reason_tags: [
      "pdf_v2_experimental_route", "dispatcher_ready_entry", "no_legacy_fallback",
      "no_old_convert_pdf", "no_old_doc_parse_pdf", "no_external_model_file", "no_feature_tsv",
      "fail_closed",
    ],
  }
}

///|
pub fn lower_pdf_v2_result_to_core_document(
  lowered : @lowering.PdfV2LoweringResult,
  source_name : String,
  options : PdfV2ConvertOptions,
) -> @cor.Document {
  let doc = @cor.new_document()
  for block in lowered.blocks {
    emit_lowered_block(doc, block, source_name, options)
  }
  if doc.blocks.val.is_empty() && options.emit_diagnostic_block {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph(pdf_v2_fail_closed_diagnostic_text(lowered)),
      Some(origin_for_diagnostic(source_name)),
    )
  }
  doc
}

///|
pub fn pdf_v2_pipeline_preserves_no_fallback(
  result : PdfV2PipelineResult,
) -> Bool {
  result.core.fallback_policy.legacy_fallback_allowed == false &&
  result.core.scan_boundary.convert_raw_reparse_allowed == false &&
  result.source.summary.legacy_fallback_allowed == false &&
  result.source.summary.convert_raw_reparse_allowed == false &&
  result.text_model.summary.legacy_fallback_allowed == false &&
  result.text_model.summary.convert_raw_reparse_allowed == false &&
  result.model.source_summary.legacy_fallback_allowed == false &&
  result.model.source_summary.convert_raw_reparse_allowed == false &&
  result.layout.summary.legacy_fallback_allowed == false &&
  result.layout.summary.convert_raw_reparse_allowed == false &&
  result.features.summary.legacy_fallback_allowed == false &&
  result.features.summary.convert_raw_reparse_allowed == false &&
  result.lowering.summary.legacy_fallback_allowed == false &&
  result.lowering.summary.convert_raw_reparse_allowed == false
}

///|
fn emit_lowered_block(
  doc : @cor.Document,
  block : @lowering.PdfV2LoweredBlock,
  source_name : String,
  options : PdfV2ConvertOptions,
) -> Unit {
  if block.kind == @lowering.PdfV2LoweredBlockKind::NoiseSuppressed {
    return
  }
  if block.text.trim() == "" {
    return
  }
  let origin = Some(origin_for_lowered_block(source_name, block))
  match block.kind {
    @lowering.PdfV2LoweredBlockKind::Heading =>
      @cor.push_with_origin(
        doc,
        @cor.Block::Heading(clamp_heading(options.max_heading), block.text),
        origin,
      )
    @lowering.PdfV2LoweredBlockKind::ListItem =>
      @cor.push_with_origin(
        doc,
        @cor.Block::ListItem(false, 0, block.text),
        origin,
      )
    @lowering.PdfV2LoweredBlockKind::ImagePlaceholder
    | @lowering.PdfV2LoweredBlockKind::FormNote
    | @lowering.PdfV2LoweredBlockKind::AnnotationNote
    | @lowering.PdfV2LoweredBlockKind::Unsupported
    | @lowering.PdfV2LoweredBlockKind::Uncertain
    | @lowering.PdfV2LoweredBlockKind::Text
    | @lowering.PdfV2LoweredBlockKind::Paragraph
    | @lowering.PdfV2LoweredBlockKind::CaptionText
    | @lowering.PdfV2LoweredBlockKind::TableLikeText =>
      @cor.push_with_origin(doc, @cor.Block::Paragraph(block.text), origin)
    @lowering.PdfV2LoweredBlockKind::NoiseSuppressed => ()
  }
}

///|
fn pdf_v2_fail_closed_diagnostic_text(
  lowered : @lowering.PdfV2LoweringResult,
) -> String {
  "PDF v2 experimental route: reader scaffold produced no text blocks; " +
  "conversion failed closed without legacy fallback. " +
  "warnings=" +
  lowered.summary.warning_count.to_string() +
  " parser_warnings=" +
  lowered.summary.parser_warning_count.to_string() +
  " parser_risks=" +
  lowered.summary.parser_risk_count.to_string()
}

///|
fn origin_for_lowered_block(
  source_name : String,
  block : @lowering.PdfV2LoweredBlock,
) -> @cor.Origin {
  {
    source_name: Some(source_name),
    page: Some(block.page_index + 1),
    slide: None,
    sheet: None,
    block_index: None,
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: first_object_ref(block.origin.object_refs),
    relationship_id: None,
    key_path: block.origin.block_id,
  }
}

///|
fn origin_for_diagnostic(source_name : String) -> @cor.Origin {
  {
    source_name: Some(source_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(0),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: Some("pdf_v2_experimental_route"),
  }
}

///|
fn first_object_ref(values : Array[String]) -> String? {
  if values.is_empty() {
    None
  } else {
    Some(values[0])
  }
}

///|
fn clamp_heading(max_heading : Int) -> Int {
  if max_heading < 1 {
    1
  } else if max_heading > 6 {
    6
  } else {
    max_heading
  }
}
