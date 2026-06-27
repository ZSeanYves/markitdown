///|
fn parse_context_with_product_pdf_modes(
  context : @parser.ParseContext,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> @parser.ParseContext {
  if detected_format != @input.DetectedFormat::Pdf {
    return context
  }
  @parser.parse_context_with_pdf_table_reconstruction_policy(
    @parser.parse_context_with_pdf_header_footer_filter_policy(
      context,
      pdf_cleanup_mode_to_filter_policy(options.pdf_cleanup_mode),
    ),
    pdf_table_mode_to_reconstruction_policy(options.pdf_table_mode),
  )
}

///|
fn pdf_cleanup_mode_to_filter_policy(
  mode : PdfCleanupMode,
) -> @parser.PdfHeaderFooterFilterPolicy {
  match mode {
    PdfCleanupMode::Disabled => @parser.PdfHeaderFooterFilterPolicy::Disabled
    PdfCleanupMode::Conservative =>
      @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly
  }
}

///|
fn pdf_table_mode_to_reconstruction_policy(
  mode : PdfTableMode,
) -> @parser.PdfTableReconstructionPolicy {
  match mode {
    PdfTableMode::Disabled => @parser.PdfTableReconstructionPolicy::Disabled
    PdfTableMode::Simple =>
      @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly
  }
}

///|
fn finalize_image_convert_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
) -> ConvertResult {
  finalize_pipeline_convert_result(
    source,
    detected_format,
    options,
    parsed,
    parsed.diagnostics,
  )
}

///|
fn finalize_image_convert_execution(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
  route_plan : RoutePlan,
) -> ConvertExecution {
  finalize_pipeline_convert_execution(
    source,
    detected_format,
    options,
    parsed,
    parsed.diagnostics,
    route_plan,
  )
}

///|
fn finalize_pipeline_convert_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
  diagnostics : @core.Diagnostics,
) -> ConvertResult {
  finalize_pipeline_convert_execution(
    source,
    detected_format,
    options,
    parsed,
    diagnostics,
    {
      detected_format,
      selected_route: "unknown",
      route_reason: "legacy_finalize_without_route_plan",
      route_probe_summary: "route_probe:unknown",
      requested_parser_mode: None,
    },
  ).result
}

///|
fn finalize_pipeline_convert_execution(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
  diagnostics : @core.Diagnostics,
  route_plan : RoutePlan,
) -> ConvertExecution {
  let product_options = product_options_from_convert_options(options)
  let pass_context = @pipeline.make_pass_context_with_product_options(
    product_options.mode,
    product_options,
    diagnostics~,
    assets=parsed.assets,
    metadata=parsed.metadata,
    source_map=parsed.source_map,
    assembly=parsed.assembly,
  )
  let pipeline_result = match
    @pipeline.run_default_pipeline(
      @runtime.parse_result_to_ir_input(parsed),
      pass_context,
    ) {
    Ok(value) => value
    Err(err) => abort(err.message)
  }
  let renderer = renderer_for_output(options.output_format)
  let pipeline_diagnostics = pass_context.diagnostics.val
  pipeline_diagnostics.metrics.set(
    "convert_mode",
    convert_mode_name(options.mode),
  )
  pipeline_diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected_format),
  )
  pipeline_diagnostics.metrics.set("input_kind", input_kind_name(source.kind))
  let final_diagnostics = @core.diagnostics_with_mode(
    @core.diagnostics_with_input(
      pipeline_diagnostics,
      Some(input_kind_name(source.kind)),
      Some(@input.detected_format_name(detected_format)),
    ),
    Some(parsed.mode |> @parser.mode_name),
    Some(convert_mode_name(options.mode)),
  )
  apply_pdf_product_option_metrics(final_diagnostics, detected_format, options)
  final_diagnostics.pass_trace.push("render:" + renderer.name)
  let render_input = ir_input_to_render_input(pipeline_result)
  let render_context = @render.make_render_context(
    @product.debug_mode(product_options.mode),
    rag_options=options.rag_options,
    base_diagnostics=Some(final_diagnostics),
    metadata=Some(pass_context.metadata.val),
    source_map=pass_context.source_map.val,
    assets=Some(pass_context.assets.val),
    assembly=pass_context.assembly.val,
  )
  let rendered = match render_input {
    @render.RenderInput::Document(document) => {
      let prepared = {
        ..document,
        metadata: pass_context.metadata.val,
        diagnostics: final_diagnostics,
        assets: pass_context.assets.val,
        source_map: pass_context.source_map.val,
        assembly: pass_context.assembly.val,
      }
      (renderer.render)(prepared, render_context)
    }
    _ => (renderer.render_input)(render_input, render_context)
  }
  let result : ConvertResult = {
    content: rendered.content,
    output_format: options.output_format,
    detected_format,
    parser_mode: parsed.mode,
    convert_mode: options.mode,
    metadata: pass_context.metadata.val,
    diagnostics: rendered.diagnostics,
    assets: pass_context.assets.val,
    source_map: if options.output_format == OutputFormat::RagJson &&
      !options.rag_options.preserve_source_ref {
      None
    } else {
      pass_context.source_map.val
    },
    chunks: rendered.chunks,
    debug_ir: debug_ir_for_render_input(options.output_format, render_input),
  }
  let parse_kind = parse_result_kind(parsed)
  let pipeline_kind = ir_input_kind_name(pipeline_result)
  let render_kind = render_input_kind_name(render_input)
  let provenance : ConvertProvenance = {
    route_plan,
    effective_parser_mode: parsed.mode,
    parse_result_kind: parse_kind,
    pipeline_output_kind: pipeline_kind,
    render_input_kind: render_kind,
    route_fidelity_status: route_fidelity_status(
      route_plan,
      parsed.mode,
      parse_kind,
      pipeline_kind,
      render_kind,
    ),
  }
  { result, provenance }
}

///|
fn ir_input_to_render_input(input : @core.IRInput) -> @render.RenderInput {
  match input {
    @core.IRInput::Document(document) => @render.RenderInput::Document(document)
    @core.IRInput::BlockStream(blocks) =>
      @render.RenderInput::BlockStream(blocks)
    @core.IRInput::EventStream(events) =>
      @render.RenderInput::EventStream(events)
  }
}

///|
fn debug_ir_for_render_input(
  format : OutputFormat,
  input : @render.RenderInput,
) -> @core.DocumentIR? {
  if format != OutputFormat::DebugJson {
    return None
  }
  match input {
    @render.RenderInput::Document(document) => Some(document)
    _ => None
  }
}

///|
fn renderer_for_output(format : OutputFormat) -> @render.Renderer {
  match format {
    OutputFormat::Markdown => @render.markdown_renderer()
    OutputFormat::Json => @render.debug_json_renderer()
    OutputFormat::RagJson => @render.rag_json_renderer()
    OutputFormat::DebugJson => @render.debug_json_renderer()
  }
}

///|
fn apply_pdf_product_option_metrics(
  diagnostics : @core.Diagnostics,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> Unit {
  if detected_format != @input.DetectedFormat::Pdf {
    return
  }
  diagnostics.metrics.set(
    "pdf_cleanup_mode",
    pdf_cleanup_mode_name(options.pdf_cleanup_mode),
  )
  diagnostics.metrics.set(
    "pdf_cleanup_enabled",
    if options.pdf_cleanup_mode == PdfCleanupMode::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_cleanup_default_mode",
    pdf_cleanup_mode_name(default_pdf_cleanup_mode()),
  )
  diagnostics.metrics.set(
    "pdf_cleanup_opt_in_mode",
    pdf_cleanup_mode_name(pdf_cleanup_opt_in_mode()),
  )
  diagnostics.metrics.set(
    "pdf_table_mode",
    pdf_table_mode_name(options.pdf_table_mode),
  )
  diagnostics.metrics.set(
    "pdf_table_enabled",
    if options.pdf_table_mode == PdfTableMode::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_table_default_mode",
    pdf_table_mode_name(default_pdf_table_mode()),
  )
  diagnostics.metrics.set(
    "pdf_table_opt_in_mode",
    pdf_table_mode_name(pdf_table_opt_in_mode()),
  )
}

///|
fn format_detection_trace(result : @input.FormatDetectionResult) -> String {
  let parts : Array[String] = [@input.detected_format_name(result.format)]
  if result.used_explicit_format {
    parts.push("explicit")
  }
  if result.used_extension {
    parts.push("extension")
  }
  if result.notes.length() > 0 {
    parts.push(result.notes.join("+"))
  }
  parts.join(":")
}

///|
fn input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}
