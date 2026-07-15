///|
fn route_plan_from_execution_plan(
  execution_plan : ResolvedExecutionPlan,
) -> RoutePlan {
  {
    detected_format: execution_plan.detected_format,
    selected_route: canonical_route_name(execution_plan.selected_route),
    route_reason: execution_plan.reason,
    route_probe_summary: format_route_probe_summary(
      execution_plan.probe_summary_format,
      execution_plan.probe_summary_parts,
    ),
    requested_parser_mode: execution_plan.requested_parser_mode,
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
  }
}

///|
fn parse_result_kind(result : @parser.ParseResult) -> String {
  if result.document is Some(_) {
    "document"
  } else if result.block_stream is Some(_) {
    "block_stream"
  } else if result.event_stream is Some(_) {
    "event_stream"
  } else {
    "empty"
  }
}

///|
fn ir_input_kind_name(input : @core.IRInput) -> String {
  match input {
    Document(_) => "document"
    BlockStream(_) => "block_stream"
    EventStream(_) => "event_stream"
  }
}

///|
fn render_input_kind_name(input : @render.RenderInput) -> String {
  match input {
    Document(_) => "document"
    BlockStream(_) => "block_stream"
    EventStream(_) => "event_stream"
  }
}

///|
fn route_fidelity_status(
  route_plan : RoutePlan,
  effective_parser_mode : @parser.ParserMode,
  parse_result_kind : String,
  pipeline_output_kind : String,
  render_input_kind : String,
) -> String {
  let expected_mode = route_plan.requested_parser_mode
  let mode_ok = match expected_mode {
    Some(mode) => mode == effective_parser_mode
    None => true
  }
  let output_ok = pipeline_output_kind == render_input_kind
  let parse_ok = parse_result_kind != "empty"
  if mode_ok && output_ok && parse_ok {
    "matched"
  } else if !parse_ok {
    "missing_parse_result_kind"
  } else if !mode_ok {
    "parser_mode_mismatch"
  } else {
    "ir_shape_mismatch"
  }
}

///|
pub fn route_plan_to_json(route_plan : RoutePlan) -> Json {
  Json::object({
    "detected_format": @input.detected_format_name(route_plan.detected_format).to_json(),
    "selected_route": route_plan.selected_route.to_json(),
    "route_reason": route_plan.route_reason.to_json(),
    "route_probe_summary": route_plan.route_probe_summary.to_json(),
    "requested_parser_mode": route_plan.requested_parser_mode
    .map(mode => @parser.mode_name(mode))
    .to_json(),
    "ocr_provider_selection_target": route_plan.ocr_provider_selection_target.to_json(),
    "ocr_provider_requested_kind": route_plan.ocr_provider_requested_kind.to_json(),
    "ocr_provider_resolved_kind": route_plan.ocr_provider_resolved_kind.to_json(),
  })
}

///|
pub fn convert_provenance_to_json(provenance : ConvertProvenance) -> Json {
  Json::object({
    "route_plan": route_plan_to_json(provenance.route_plan),
    "fidelity_mode": fidelity_mode_name(provenance.fidelity_mode).to_json(),
    "output_mode": output_mode_name(provenance.output_mode).to_json(),
    "execution_profile": @product.execution_profile_name(
      provenance.execution_profile,
    ).to_json(),
    "execution_profile_reason": provenance.execution_profile_reason.to_json(),
    "lowering_profile": @product.lowering_profile_name(
      provenance.lowering_profile,
    ).to_json(),
    "render_profile": @product.render_profile_name(provenance.render_profile).to_json(),
    "profile_trigger_signals": provenance.profile_trigger_signals.to_json(),
    "effective_parser_mode": @parser.mode_name(provenance.effective_parser_mode).to_json(),
    "parse_result_kind": provenance.parse_result_kind.to_json(),
    "pipeline_output_kind": provenance.pipeline_output_kind.to_json(),
    "render_input_kind": provenance.render_input_kind.to_json(),
    "route_fidelity_status": provenance.route_fidelity_status.to_json(),
    "applied_accurate_features": provenance.applied_accurate_features.to_json(),
    "same_mode_strategy_switches": provenance.same_mode_strategy_switches.to_json(),
    "ocr_provider_selection_target": provenance.ocr_provider_selection_target.to_json(),
    "ocr_provider_requested_kind": provenance.ocr_provider_requested_kind.to_json(),
    "ocr_provider_resolved_kind": provenance.ocr_provider_resolved_kind.to_json(),
    "audio_backend_transport": provenance.audio_backend_transport.to_json(),
    "audio_backend_name": provenance.audio_backend_name.to_json(),
    "audio_backend_version": provenance.audio_backend_version.to_json(),
    "requested_fidelity_mode": provenance.requested_fidelity_mode
    .map(mode => fidelity_mode_name(mode))
    .to_json(),
  })
}
