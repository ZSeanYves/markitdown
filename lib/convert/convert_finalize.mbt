///|
async fn finalize_pipeline_execution(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
  diagnostics : @core.Diagnostics,
  execution_plan : ResolvedExecutionPlan,
  execution_started : UInt64,
  sink : OutputSink?,
) -> Result[ConvertExecution, ConvertError] {
  let route_plan = route_plan_from_execution_plan(execution_plan)
  let effective_options = {
    ..options,
    mode: execution_plan.mode,
    output_mode: execution_plan.output_mode,
    limits: execution_plan.limits,
    rag_options: execution_plan.rag_options,
  }
  let product_options = product_options_from_convert_options(effective_options)
  let pass_context = @pipeline.make_pass_context_with_product_options(
    product_options.mode,
    product_options,
    execution_profile=execution_plan.execution_profile,
    lowering_profile=execution_plan.lowering_profile,
    render_profile=execution_plan.render_profile,
    accurate_features=execution_plan.accurate_feature_profile,
    diagnostics~,
    assets=parsed.assets,
    metadata=parsed.metadata,
    source_map=parsed.source_map,
    assembly=parsed.assembly,
  )
  let parsed_input = match @runtime.parse_result_to_ir_input(parsed) {
    Ok(value) => value
    Err(message) => return Err(ParseFailed(message))
  }
  let pipeline_started = @env.now()
  let pipeline_result = match
    @pipeline.run_default_pipeline(parsed_input, pass_context) {
    Ok(value) => value
    Err(err) => return Err(ParseFailed("pipeline failed: " + err.message))
  }
  pass_context.assets.val = match
    apply_asset_payload_limits(
      pass_context.assets.val,
      execution_plan.limits,
      diagnostics,
    ) {
    Ok(assets) => assets
    Err(error) => return Err(error)
  }
  diagnostics.metrics.set(
    "timing_pipeline_ms",
    (@env.now() - pipeline_started).to_string(),
  )
  let renderer = renderer_for_output(effective_options.output_mode)
  let pipeline_diagnostics = pass_context.diagnostics.val
  pipeline_diagnostics.metrics.set(
    "convert_mode",
    convert_mode_name(effective_options.mode),
  )
  pipeline_diagnostics.metrics.set(
    "fidelity_mode",
    fidelity_mode_name(execution_plan.fidelity_mode),
  )
  pipeline_diagnostics.metrics.set(
    "output_mode",
    output_mode_name(effective_options.output_mode),
  )
  pipeline_diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected_format),
  )
  pipeline_diagnostics.metrics.set(
    "input_kind",
    input_kind_name(@input.input_kind(source)),
  )
  let final_diagnostics = @core.diagnostics_with_mode(
    @core.diagnostics_with_input(
      pipeline_diagnostics,
      Some(input_kind_name(@input.input_kind(source))),
      Some(@input.detected_format_name(detected_format)),
    ),
    Some(parsed.mode |> @parser.mode_name),
    Some(convert_mode_name(effective_options.mode)),
    fidelity_mode=Some(fidelity_mode_name(execution_plan.fidelity_mode)),
    output_mode=Some(output_mode_name(effective_options.output_mode)),
  )
  final_diagnostics.pass_trace.push("render:" + renderer.name)
  let render_input = ir_input_to_render_input(pipeline_result)
  let render_context = @render.make_render_context(
    @product.debug_output_mode(product_options.output_mode),
    fidelity_mode=product_options.fidelity_mode,
    output_mode=product_options.output_mode,
    execution_profile=execution_plan.execution_profile,
    render_profile=execution_plan.render_profile,
    accurate_features=execution_plan.accurate_feature_profile,
    rag_options=execution_plan.rag_options,
    base_diagnostics=Some(final_diagnostics),
    metadata=Some(pass_context.metadata.val),
    source_map=pass_context.source_map.val,
    assets=Some(pass_context.assets.val),
    assembly=pass_context.assembly.val,
  )
  let render_input : @render.RenderInput = match render_input {
    Document(document) =>
      Document({
        ..document,
        metadata: pass_context.metadata.val,
        diagnostics: final_diagnostics,
        assets: pass_context.assets.val,
        source_map: pass_context.source_map.val,
        assembly: pass_context.assembly.val,
      })
    other => other
  }
  let render_started = @env.now()
  let collected = StringBuilder()
  let output_sink = sink.unwrap_or(
    make_output_sink(
      fn(part) {
        collected.write_string(part)
        Ok(())
      },
      fn() { Ok(()) },
    ),
  )
  let confirmed_bytes = Ref(0L)
  let write = async fn(chunk) {
    write_output_sink_bounded(output_sink, chunk, source~, confirmed_bytes~)
  }
  let rendered = match
    (if effective_options.output_mode == Markdown {
      @render.render_markdown_input_to_sink(render_input, render_context, write)
    } else {
      @render.render_json_input_to_sink(render_input, render_context, write)
    }) {
    Ok(value) => value
    Err(message) =>
      return Err(
        input_failure_convert_error(source).unwrap_or(
          RenderFailed("sink write failed: " + message),
        ),
      )
  }
  match sink {
    Some(_) =>
      rendered.diagnostics.metrics.set("sink_renderer_fallback", "false")
    None => {
      rendered.diagnostics.metrics.remove("sink_renderer_fallback")
      rendered.diagnostics.metrics.remove("renderer_stream_mode")
    }
  }
  record_budget_diagnostics(source, rendered.diagnostics, confirmed_bytes.val)
  rendered.diagnostics.metrics.set(
    "timing_render_ms",
    (@env.now() - render_started).to_string(),
  )
  rendered.diagnostics.metrics.set(
    "timing_total_ms",
    (@env.now() - execution_started).to_string(),
  )
  let result : ConvertResult = {
    content: if sink is None {
      collected.to_string()
    } else {
      ""
    },
    fidelity_mode: execution_plan.fidelity_mode,
    output_mode: effective_options.output_mode,
    detected_format,
    parser_mode: parsed.mode,
    convert_mode: effective_options.mode,
    metadata: pass_context.metadata.val,
    diagnostics: rendered.diagnostics,
    assets: pass_context.assets.val,
    source_map: if effective_options.output_mode == Rag &&
      !execution_plan.rag_options.preserve_source_ref {
      None
    } else {
      pass_context.source_map.val
    },
    chunks: rendered.chunks,
    debug_ir: debug_ir_for_render_input(
      effective_options.output_mode,
      render_input,
    ),
  }
  let parse_kind = parse_result_kind(parsed)
  let pipeline_kind = ir_input_kind_name(pipeline_result)
  let render_kind = render_input_kind_name(render_input)
  let provenance : ConvertProvenance = {
    route_plan,
    fidelity_mode: execution_plan.fidelity_mode,
    output_mode: effective_options.output_mode,
    execution_profile: execution_plan.execution_profile,
    execution_profile_reason: execution_plan.execution_profile_reason,
    lowering_profile: execution_plan.lowering_profile,
    render_profile: execution_plan.render_profile,
    profile_trigger_signals: execution_plan.profile_trigger_signals.map(signal => {
      probe_signal_kind_name(signal.kind) + "=" + signal.observed.to_string()
    }),
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
    applied_accurate_features: @product.accurate_feature_profile_names(
      execution_plan.accurate_feature_profile,
    ),
    same_mode_strategy_switches: {
      let switches = execution_plan.same_mode_strategy_switches.copy()
      for strategy_switch in diagnostics.same_mode_strategy_switches {
        if !switches.contains(strategy_switch) {
          switches.push(strategy_switch)
        }
      }
      switches
    },
    requested_fidelity_mode: Some(execution_plan.requested_fidelity_mode),
  }
  Ok({ result, provenance, })
}

///|
fn apply_asset_payload_limits(
  assets : Array[@core.AssetRef],
  limits : ResourceLimits,
  diagnostics : @core.Diagnostics,
) -> Result[Array[@core.AssetRef], ConvertError] {
  let mut total = 0L
  for asset in assets {
    let size = match asset.payload {
      Some(Bytes(bytes)) => Some(bytes.length().to_int64())
      Some(Utf8(text)) => Some(@utf8.encode(text).length().to_int64())
      _ => None
    }
    match size {
      Some(observed) if observed > limits.max_asset_bytes =>
        return Err(
          ResourceLimitExceeded(
            kind="single_asset_bytes",
            observed~,
            limit=limits.max_asset_bytes,
          ),
        )
      Some(observed) if total + observed > limits.max_total_asset_bytes =>
        return Err(
          ResourceLimitExceeded(
            kind="total_asset_bytes",
            observed=total + observed,
            limit=limits.max_total_asset_bytes,
          ),
        )
      Some(observed) => total = total + observed
      None => ()
    }
  }
  diagnostics.metrics.set("asset_payload_bytes", total.to_string())
  diagnostics.metrics.set("asset_payload_skipped", "0")
  Ok(assets)
}

///|
fn ir_input_to_render_input(input : @core.IRInput) -> @render.RenderInput {
  match input {
    Document(document) => Document(document)
    BlockStream(blocks) => BlockStream(blocks)
    EventStream(events) => EventStream(events)
  }
}

///|
fn debug_ir_for_render_input(
  mode : OutputMode,
  input : @render.RenderInput,
) -> @core.DocumentIR? {
  if mode != Debug {
    return None
  }
  match input {
    Document(document) => Some(document)
    _ => None
  }
}

///|
fn renderer_for_output(mode : OutputMode) -> @render.Renderer {
  match mode {
    Markdown => @render.markdown_renderer()
    Rag => @render.rag_json_renderer()
    Debug => @render.debug_json_renderer()
  }
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
    Path => "path"
    Text => "text"
    Bytes => "bytes"
    Reader => "reader"
  }
}
