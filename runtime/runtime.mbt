///|
pub fn parse_result_to_ir_input(result : @parser.ParseResult) -> @core.IRInput {
  match result.container_plan {
    Some(plan) => return @core.IRInput::ContainerPlan(plan)
    None => ()
  }
  match result.container_manifest {
    Some(manifest) => return @core.IRInput::ContainerManifest(manifest)
    None => ()
  }
  match result.document {
    Some(document) => @core.IRInput::Document(document)
    None =>
      match result.block_stream {
        Some(blocks) => @core.IRInput::BlockStream(blocks)
        None =>
          match result.event_stream {
            Some(events) => @core.IRInput::EventStream(events)
            None => @core.IRInput::Document(@core.empty_document_ir())
          }
      }
  }
}

///|
pub fn merge_diagnostics_unique(
  left : @core.Diagnostics,
  right : @core.Diagnostics,
) -> @core.Diagnostics {
  merge_diagnostics(left, right, true)
}

///|
pub fn merge_diagnostics_append(
  left : @core.Diagnostics,
  right : @core.Diagnostics,
) -> @core.Diagnostics {
  merge_diagnostics(left, right, false)
}

///|
pub fn parse_child_to_document(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[@core.DocumentIR, String] {
  let inner_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(format),
    context.requested_mode,
    context.max_rows,
    context.max_cols,
    context.max_cells,
    context.max_line_chars,
    context.debug,
  )
  let parsed = match @parser.registry_parse(registry, source, inner_context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(child_document_from_parse_result(parsed, context.debug))
}

///|
fn merge_diagnostics(
  left : @core.Diagnostics,
  right : @core.Diagnostics,
  dedupe : Bool,
) -> @core.Diagnostics {
  let parser_name = match right.parser_name {
    Some(value) => Some(value)
    None => left.parser_name
  }
  let parser_mode = match right.parser_mode {
    Some(value) => Some(value)
    None => left.parser_mode
  }
  let input_kind = match right.input_kind {
    Some(value) => Some(value)
    None => left.input_kind
  }
  let detected_format = match right.detected_format {
    Some(value) => Some(value)
    None => left.detected_format
  }
  let merged = {
    ..left,
    parser_name,
    parser_mode,
    input_kind,
    detected_format,
    warnings: merge_string_items(left.warnings, right.warnings, dedupe),
    errors: merge_string_items(left.errors, right.errors, dedupe),
    degraded_features: merge_string_items(
      left.degraded_features,
      right.degraded_features,
      dedupe,
    ),
    fallback_trace: merge_string_items(
      left.fallback_trace,
      right.fallback_trace,
      dedupe,
    ),
    pass_trace: merge_string_items(left.pass_trace, right.pass_trace, dedupe),
  }
  for entry in right.metrics.to_array() {
    merged.metrics.set(entry.0, entry.1)
  }
  merged
}

///|
fn merge_string_items(
  left : Array[String],
  right : Array[String],
  dedupe : Bool,
) -> Array[String] {
  if !dedupe {
    return left + right
  }
  let merged : Array[String] = []
  for item in left {
    if !merged.contains(item) {
      merged.push(item)
    }
  }
  for item in right {
    if !merged.contains(item) {
      merged.push(item)
    }
  }
  merged
}

///|
fn child_document_from_parse_result(
  parsed : @parser.ParseResult,
  debug : Bool,
) -> @core.DocumentIR {
  let mut document = @pipeline.build_document_with_default_pipeline(
    parse_result_to_ir_input(parsed),
    @pipeline.make_pass_context(
      debug,
      parsed.mode |> @parser.mode_name,
      pdf_cleanup_enabled=false,
    ),
    trace_builder=false,
    trace_passes=false,
  )
  let merged_diagnostics = merge_diagnostics_append(
    parsed.diagnostics,
    document.diagnostics,
  )
  document = @core.document_with_diagnostics(document, merged_diagnostics)
  document
}
