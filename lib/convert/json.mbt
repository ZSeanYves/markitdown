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
    "detected_format": Json(
      @input.detected_format_name(route_plan.detected_format),
    ),
    "selected_route": Json(route_plan.selected_route),
    "route_reason": Json(route_plan.route_reason),
    "route_probe_summary": Json(route_plan.route_probe_summary),
    "requested_parser_mode": Json(
      route_plan.requested_parser_mode.map(mode => @parser.mode_name(mode)),
    ),
  })
}

///|
pub fn convert_provenance_to_json(provenance : ConvertProvenance) -> Json {
  Json::object({
    "route_plan": route_plan_to_json(provenance.route_plan),
    "fidelity_mode": Json(fidelity_mode_name(provenance.fidelity_mode)),
    "output_mode": Json(output_mode_name(provenance.output_mode)),
    "execution_profile": Json(
      @product.execution_profile_name(provenance.execution_profile),
    ),
    "execution_profile_reason": Json(provenance.execution_profile_reason),
    "lowering_profile": Json(
      @product.lowering_profile_name(provenance.lowering_profile),
    ),
    "render_profile": Json(
      @product.render_profile_name(provenance.render_profile),
    ),
    "profile_trigger_signals": Json(provenance.profile_trigger_signals),
    "effective_parser_mode": Json(
      @parser.mode_name(provenance.effective_parser_mode),
    ),
    "parse_result_kind": Json(provenance.parse_result_kind),
    "pipeline_output_kind": Json(provenance.pipeline_output_kind),
    "render_input_kind": Json(provenance.render_input_kind),
    "route_fidelity_status": Json(provenance.route_fidelity_status),
    "applied_accurate_features": Json(provenance.applied_accurate_features),
    "same_mode_strategy_switches": Json(provenance.same_mode_strategy_switches),
    "requested_fidelity_mode": Json(
      provenance.requested_fidelity_mode.map(mode => fidelity_mode_name(mode)),
    ),
  })
}
