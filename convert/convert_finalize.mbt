///|
fn finalize_pipeline_execution(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
  diagnostics : @core.Diagnostics,
  execution_plan : ResolvedExecutionPlan,
  execution_started : UInt64,
) -> ConvertExecution {
  let route_plan = route_plan_from_execution_plan(execution_plan)
  let effective_options = {
    ..options,
    mode: execution_plan.mode,
    fidelity_mode: execution_plan.fidelity_mode,
    output_mode: execution_plan.output_mode,
    stream_requested: execution_plan.stream_requested,
    output_format: execution_plan.output_format,
    ocr_options: execution_plan.ocr_options,
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
  let pipeline_started = @env.now()
  let pipeline_result = match
    @pipeline.run_default_pipeline(
      @runtime.parse_result_to_ir_input(parsed),
      pass_context,
    ) {
    Ok(value) => value
    Err(err) => abort(err.message)
  }
  let limited_assets = apply_asset_payload_limits(
    pass_context.assets.val,
    execution_plan.limits,
    diagnostics,
  )
  pass_context.assets.val = limited_assets.0
  diagnostics.metrics.set(
    "timing_pipeline_ms",
    (@env.now() - pipeline_started).to_string(),
  )
  let renderer = renderer_for_output(options.output_format)
  let pipeline_diagnostics = pass_context.diagnostics.val
  pipeline_diagnostics.metrics.set(
    "convert_mode",
    convert_mode_name(effective_options.mode),
  )
  pipeline_diagnostics.metrics.set(
    "fidelity_mode",
    fidelity_mode_name(effective_options.fidelity_mode),
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
    fidelity_mode=Some(fidelity_mode_name(effective_options.fidelity_mode)),
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
  let render_started = @env.now()
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
  rendered.diagnostics.metrics.set(
    "timing_render_ms",
    (@env.now() - render_started).to_string(),
  )
  rendered.diagnostics.metrics.set(
    "timing_total_ms",
    (@env.now() - execution_started).to_string(),
  )
  let final_content = if effective_options.output_format ==
    OutputFormat::Markdown {
    remove_skipped_asset_references(rendered.content, limited_assets.1)
  } else {
    rendered.content
  }
  let result : ConvertResult = {
    content: final_content,
    output_format: effective_options.output_format,
    fidelity_mode: effective_options.fidelity_mode,
    output_mode: effective_options.output_mode,
    detected_format,
    parser_mode: parsed.mode,
    convert_mode: effective_options.mode,
    metadata: pass_context.metadata.val,
    diagnostics: rendered.diagnostics,
    assets: pass_context.assets.val,
    source_map: if effective_options.output_format == OutputFormat::RagJson &&
      !execution_plan.rag_options.preserve_source_ref {
      None
    } else {
      pass_context.source_map.val
    },
    chunks: rendered.chunks,
    debug_ir: debug_ir_for_render_input(
      effective_options.output_format,
      render_input,
    ),
  }
  let parse_kind = parse_result_kind(parsed)
  let pipeline_kind = ir_input_kind_name(pipeline_result)
  let render_kind = render_input_kind_name(render_input)
  let provenance : ConvertProvenance = {
    route_plan,
    fidelity_mode: effective_options.fidelity_mode,
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
    ocr_provider_selection_target: execution_plan.ocr_provider_selection_target.map(target => {
        @focr.ocr_provider_selection_target_name(target)
      },
    ),
    ocr_provider_requested_kind: execution_plan.ocr_provider_requested_kind.map(kind => {
        @focr.ocr_provider_kind_name(kind)
      },
    ),
    ocr_provider_resolved_kind: execution_plan.ocr_provider_resolved_kind.map(kind => {
      @focr.ocr_provider_kind_name(kind)
    }),
    audio_backend_transport: parsed.metadata
    .get("audio_backend_transport")
    .map(value => {
      match value {
        @core.JsonValue::String(text) => text
        _ => execution_plan.audio_backend_transport.unwrap_or("")
      }
    }),
    audio_backend_name: parsed.metadata
    .get("audio_backend_name")
    .map(value => {
      match value {
        @core.JsonValue::String(text) => text
        _ => execution_plan.audio_backend_name.unwrap_or("")
      }
    }),
    audio_backend_version: parsed.metadata
    .get("audio_backend_version")
    .map(value => {
      match value {
        @core.JsonValue::String(text) => text
        _ => execution_plan.audio_backend_version.unwrap_or("")
      }
    }),
    requested_fidelity_mode: Some(execution_plan.requested_fidelity_mode),
  }
  { result, provenance }
}

///|
fn apply_asset_payload_limits(
  assets : Array[@core.AssetRef],
  limits : ResourceLimits,
  diagnostics : @core.Diagnostics,
) -> (Array[@core.AssetRef], Array[@core.AssetRef]) {
  let limited : Array[@core.AssetRef] = []
  let skipped : Array[@core.AssetRef] = []
  let mut total = 0L
  for asset in assets {
    let size = match asset.payload {
      Some(@core.AssetPayload::Bytes(bytes)) => Some(bytes.length().to_int64())
      Some(@core.AssetPayload::Utf8(text)) =>
        Some(@utf8.encode(text).length().to_int64())
      _ => None
    }
    match size {
      Some(observed) if observed > limits.max_asset_bytes => {
        let next = { ..asset, payload: None }
        next.attrs.set("payload_skipped", "single_asset_limit")
        limited.push(next)
        skipped.push(next)
        record_asset_payload_limit(
          diagnostics,
          asset,
          "single_asset_bytes",
          observed,
          limits.max_asset_bytes,
        )
      }
      Some(observed) if total + observed > limits.max_total_asset_bytes => {
        let next = { ..asset, payload: None }
        next.attrs.set("payload_skipped", "total_asset_limit")
        limited.push(next)
        skipped.push(next)
        record_asset_payload_limit(
          diagnostics,
          asset,
          "total_asset_bytes",
          total + observed,
          limits.max_total_asset_bytes,
        )
      }
      Some(observed) => {
        total = total + observed
        limited.push(asset)
      }
      None => limited.push(asset)
    }
  }
  diagnostics.metrics.set("asset_payload_bytes", total.to_string())
  diagnostics.metrics.set("asset_payload_skipped", skipped.length().to_string())
  (limited, skipped)
}

///|
fn record_asset_payload_limit(
  diagnostics : @core.Diagnostics,
  asset : @core.AssetRef,
  kind : String,
  observed : Int64,
  limit : Int64,
) -> Unit {
  diagnostics.warnings.push(
    "asset payload skipped: " +
    asset.asset_id +
    "; kind=" +
    kind +
    "; observed=" +
    observed.to_string() +
    "; limit=" +
    limit.to_string(),
  )
  if !diagnostics.degraded_features.contains("asset_payload_limit_skip") {
    diagnostics.degraded_features.push("asset_payload_limit_skip")
  }
}

///|
fn remove_skipped_asset_references(
  content : String,
  skipped : Array[@core.AssetRef],
) -> String {
  let rendered = Ref(content)
  for asset in skipped {
    match asset.path {
      Some(path) =>
        rendered.val = remove_markdown_image_target(rendered.val, path)
      None => ()
    }
  }
  rendered.val
}

///|
fn remove_markdown_image_target(content : String, path : String) -> String {
  if path == "" {
    return content
  }
  let close_marker = "](" + path + ")"
  let rendered = Ref(content)
  while true {
    let close_index = match rendered.val.find(close_marker) {
      Some(value) => value
      None => break
    }
    let mut cursor = 0
    let mut open_index : Int? = None
    while cursor < close_index {
      match rendered.val[cursor:close_index].find("![") {
        Some(relative) => {
          let absolute = cursor + relative
          open_index = Some(absolute)
          cursor = absolute + 2
        }
        None => break
      }
    }
    let open_index = match open_index {
      Some(value) => value
      None => break
    }
    let alt = rendered.val[open_index + 2:close_index].to_owned()
    rendered.val = rendered.val[:open_index].to_owned() +
      alt +
      rendered.val[close_index + close_marker.length():].to_owned()
  }
  rendered.val
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
    OutputFormat::RagJson => @render.rag_json_renderer()
    OutputFormat::DebugJson => @render.debug_json_renderer()
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
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
    @input.InputKind::Reader => "reader"
  }
}
