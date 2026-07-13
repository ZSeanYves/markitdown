///|
/// Convert a parser result into the single public IR shape it actually exposes.
///
/// This helper enforces the product contract that exactly one of document,
/// block stream, or event stream should be populated.
pub fn parse_result_to_ir_input(result : @parser.ParseResult) -> @core.IRInput {
  match result.document {
    Some(document) => @core.IRInput::Document(document)
    None =>
      match result.block_stream {
        Some(blocks) => @core.IRInput::BlockStream(blocks)
        None =>
          match result.event_stream {
            Some(events) => @core.IRInput::EventStream(events)
            None =>
              abort(
                "parse result must expose exactly one public ir shape: " +
                result.parser_name,
              )
          }
      }
  }
}

///|
/// Merge diagnostics while deduplicating repeated arrays such as warnings and
/// fallback traces.
pub fn merge_diagnostics_unique(
  left : @core.Diagnostics,
  right : @core.Diagnostics,
) -> @core.Diagnostics {
  merge_diagnostics(left, right, true)
}

///|
/// Merge diagnostics while preserving repeated entries in order.
pub fn merge_diagnostics_append(
  left : @core.Diagnostics,
  right : @core.Diagnostics,
) -> @core.Diagnostics {
  merge_diagnostics(left, right, false)
}

///|
/// Result of parsing a child document when the caller only needs blocks,
/// assets, and merged diagnostics.
///
/// This is the common shape used by container and embedded-document callers
/// that want to splice child content into a parent document.
pub struct ChildBlockProduct {
  blocks : Array[@core.CoreBlock]
  assets : Array[@core.AssetRef]
  diagnostics : @core.Diagnostics
}

///|
priv struct ChildParsePlan {
  context : @parser.ParseContext
  preference : String
  preferred_format : String
  predecoded_text_used : Bool
}

///|
/// Parse a nested/child source and normalize it into blocks plus merged
/// diagnostics for the parent document.
///
/// The function reuses the root parser registry and, when necessary, the
/// default pipeline so nested content follows the same product rules as a
/// top-level document.
pub fn parse_child_to_block_product(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[ChildBlockProduct, String] {
  let child_plan = child_parse_plan(format, source, context)
  let inner_context = child_plan.context
  let product_options = child_product_options(context)
  let parsed = match @parser.registry_parse(registry, source, inner_context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match parsed.document {
    Some(document) => {
      let diagnostics = merge_diagnostics_append(
        parsed.diagnostics,
        document.diagnostics,
      )
      record_child_parse_preference_metrics(diagnostics, child_plan, true)
      Ok({ blocks: document.blocks, assets: document.assets, diagnostics })
    }
    None =>
      match parsed.block_stream {
        Some(blocks) => {
          let diagnostics = parsed.diagnostics
          record_child_parse_preference_metrics(diagnostics, child_plan, true)
          Ok({ blocks, assets: parsed.assets, diagnostics })
        }
        None => {
          let built = @pipeline.build_document_with_default_pipeline(
            parse_result_to_ir_input(parsed),
            child_pass_context(
              product_options,
              context,
              parsed.diagnostics,
              parsed.assets,
              parsed.metadata,
              parsed.source_map,
              parsed.assembly,
            ),
            trace_builder=false,
            trace_passes=false,
          )
          let diagnostics = merge_diagnostics_append(
            parsed.diagnostics,
            built.diagnostics,
          )
          record_child_parse_preference_metrics(diagnostics, child_plan, false)
          Ok({ blocks: built.blocks, assets: built.assets, diagnostics })
        }
      }
  }
}

///|
/// Parse a nested/child source and normalize it all the way to `DocumentIR`.
pub fn parse_child_to_document(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[@core.DocumentIR, String] {
  let inner_context = child_parse_context(format, source, context)
  let parsed = match @parser.registry_parse(registry, source, inner_context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(child_document_from_parse_result(parsed, context))
}

///|
fn child_parse_plan(
  format : @input.DetectedFormat,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> ChildParsePlan {
  let requested_mode = resolved_child_requested_mode(format, source, context)
  {
    context: child_parse_context_from_mode(format, context, requested_mode),
    preference: child_parse_preference_name(format, source, requested_mode),
    preferred_format: @input.detected_format_name(format),
    predecoded_text_used: @input.input_text(source) is Some(_),
  }
}

///|
fn child_parse_context(
  format : @input.DetectedFormat,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @parser.ParseContext {
  child_parse_context_from_mode(
    format,
    context,
    resolved_child_requested_mode(format, source, context),
  )
}

///|
fn child_parse_context_from_mode(
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
  requested_mode : @parser.ParserMode?,
) -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.parse_context_with_pdf_table_reconstruction_policy(
      @parser.parse_context_with_pdf_header_footer_filter_policy(
        @parser.parse_context_with_pdf_native_runtime_policy(
          @parser.parse_context_with_ocr_options(
            @parser.parse_context_with_execution_profiles(
              @parser.parse_context_with_product_modes(
                @parser.new_parse_context(format),
                context.fidelity_mode,
                context.output_mode,
              ),
              context.execution_profile,
              context.lowering_profile,
              context.render_profile,
              context.accurate_features,
            ),
            context.ocr_options,
          ),
          context.pdf_native_runtime_policy,
        ),
        context.pdf_header_footer_filter_policy,
      ),
      context.pdf_table_reconstruction_policy,
    ),
    requested_mode,
    context.max_rows,
    context.max_cols,
    context.max_cells,
    context.max_line_chars,
    context.debug,
  )
}

///|
fn resolved_child_requested_mode(
  format : @input.DetectedFormat,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @parser.ParserMode? {
  if @input.input_text(source) is Some(_) &&
    child_format_prefers_block_stream_text_markup(format) {
    Some(@parser.ParserMode::BlockStreaming)
  } else {
    context.requested_mode
  }
}

///|
fn child_parse_preference_name(
  format : @input.DetectedFormat,
  source : @input.InputSource,
  _requested_mode : @parser.ParserMode?,
) -> String {
  if @input.input_text(source) is Some(_) &&
    child_format_prefers_block_stream_text_markup(format) {
    "prefer_block_stream_text_markup"
  } else {
    "default"
  }
}

///|
fn child_format_prefers_block_stream_text_markup(
  format : @input.DetectedFormat,
) -> Bool {
  match format {
    @input.DetectedFormat::Html => true
    @input.DetectedFormat::Markdown => true
    _ => false
  }
}

///|
fn record_child_parse_preference_metrics(
  diagnostics : @core.Diagnostics,
  child_plan : ChildParsePlan,
  fast_path_hit : Bool,
) -> Unit {
  diagnostics.metrics.set("child_parse_preference", child_plan.preference)
  diagnostics.metrics.set(
    "child_parse_preferred_format",
    child_plan.preferred_format,
  )
  diagnostics.metrics.set(
    "child_parse_fast_path_used",
    if fast_path_hit {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "child_parse_predecoded_text_used",
    if child_plan.predecoded_text_used {
      "true"
    } else {
      "false"
    },
  )
}

///|
fn child_product_options(
  context : @parser.ParseContext,
) -> @product.ProductOptions {
  @product.make_product_options(
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      @product.ConvertMode::Stream
    } else {
      match context.fidelity_mode {
        @product.FidelityMode::Accurate => @product.ConvertMode::Accurate
        @product.FidelityMode::Balanced => @product.ConvertMode::Balanced
      }
    },
    @product.make_resource_limits(
      context.max_rows.unwrap_or(2000),
      context.max_cols.unwrap_or(50),
      context.max_cells.unwrap_or(100000),
      max_line_chars=context.max_line_chars.unwrap_or(4000),
    ),
    fidelity_mode=context.fidelity_mode,
    output_mode=context.output_mode,
    stream_requested=context.requested_mode ==
      Some(@parser.ParserMode::BlockStreaming) ||
      context.requested_mode == Some(@parser.ParserMode::StreamingEvent),
  )
}

///|
fn child_pass_context(
  product_options : @product.ProductOptions,
  context : @parser.ParseContext,
  parsed_diagnostics : @core.Diagnostics,
  assets : Array[@core.AssetRef],
  metadata : @core.DocumentMetadata,
  source_map : @core.SourceMap?,
  assembly : @core.DocumentAssembly?,
) -> @pipeline.PassContext {
  @pipeline.make_pass_context_with_product_options(
    product_options.mode,
    product_options,
    execution_profile=context.execution_profile,
    lowering_profile=context.lowering_profile,
    render_profile=context.render_profile,
    accurate_features=context.accurate_features,
    diagnostics=parsed_diagnostics,
    assets~,
    metadata~,
    source_map~,
    assembly~,
  )
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
    convert_mode: match right.convert_mode {
      Some(value) => Some(value)
      None => left.convert_mode
    },
    fidelity_mode: match right.fidelity_mode {
      Some(value) => Some(value)
      None => left.fidelity_mode
    },
    output_mode: match right.output_mode {
      Some(value) => Some(value)
      None => left.output_mode
    },
    input_kind,
    detected_format,
    warnings: merge_string_items(left.warnings, right.warnings, dedupe),
    errors: merge_string_items(left.errors, right.errors, dedupe),
    degraded_features: merge_string_items(
      left.degraded_features,
      right.degraded_features,
      dedupe,
    ),
    same_mode_degradation: merge_string_items(
      left.same_mode_degradation,
      right.same_mode_degradation,
      dedupe,
    ),
    same_mode_strategy_switches: merge_string_items(
      left.same_mode_strategy_switches,
      right.same_mode_strategy_switches,
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
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let mut document = match parsed.document {
    Some(existing) => existing
    None => {
      let product_options = child_product_options(context)
      let built = @pipeline.build_document_with_default_pipeline(
        parse_result_to_ir_input(parsed),
        child_pass_context(
          product_options,
          context,
          parsed.diagnostics,
          parsed.assets,
          parsed.metadata,
          parsed.source_map,
          parsed.assembly,
        ),
        trace_builder=false,
        trace_passes=false,
      )
      {
        ..built,
        metadata: parsed.metadata,
        assets: parsed.assets,
        source_map: parsed.source_map,
        assembly: parsed.assembly,
      }
    }
  }
  let merged_diagnostics = merge_diagnostics_append(
    parsed.diagnostics,
    document.diagnostics,
  )
  document = @core.document_with_diagnostics(document, merged_diagnostics)
  document
}
