///|
pub fn empty_diagnostics() -> Diagnostics {
  {
    parser_name: None,
    parser_mode: None,
    convert_mode: None,
    fidelity_mode: None,
    output_mode: None,
    input_kind: None,
    detected_format: None,
    warnings: [],
    errors: [],
    degraded_features: [],
    same_mode_degradation: [],
    same_mode_strategy_switches: [],
    fallback_trace: [],
    pass_trace: [],
    metrics: Map([]),
    dependency_diagnostics: [],
  }
}

///|
pub fn diagnostics_with_parser(
  diagnostics : Diagnostics,
  parser_name : String?,
  parser_mode : String?,
) -> Diagnostics {
  { ..diagnostics, parser_name, parser_mode }
}

///|
pub fn diagnostics_with_mode(
  diagnostics : Diagnostics,
  parser_mode : String?,
  convert_mode : String?,
  fidelity_mode? : String? = None,
  output_mode? : String? = None,
) -> Diagnostics {
  { ..diagnostics, parser_mode, convert_mode, fidelity_mode, output_mode }
}

///|
pub fn diagnostics_with_input(
  diagnostics : Diagnostics,
  input_kind : String?,
  detected_format : String?,
) -> Diagnostics {
  { ..diagnostics, input_kind, detected_format }
}

///|
pub fn diagnostics_add_metric(
  diagnostics : Diagnostics,
  key : String,
  value : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.metrics.set(key, value)
  next
}

///|
pub fn diagnostics_add_warning(
  diagnostics : Diagnostics,
  warning : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.warnings.push(warning)
  next
}

///|
pub fn diagnostics_add_error(
  diagnostics : Diagnostics,
  error : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.errors.push(error)
  next
}

///|
pub fn diagnostics_add_degraded_feature(
  diagnostics : Diagnostics,
  feature : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.degraded_features.push(feature)
  next
}

///|
pub fn diagnostics_add_same_mode_degradation(
  diagnostics : Diagnostics,
  degradation : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.same_mode_degradation.push(degradation)
  next
}

///|
pub fn diagnostics_add_same_mode_strategy_switch(
  diagnostics : Diagnostics,
  strategy_switch : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.same_mode_strategy_switches.push(strategy_switch)
  next
}

///|
pub fn diagnostics_add_fallback_trace(
  diagnostics : Diagnostics,
  trace : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.fallback_trace.push(trace)
  next
}

///|
pub fn diagnostics_add_pass_trace(
  diagnostics : Diagnostics,
  trace : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.pass_trace.push(trace)
  next
}

///|
pub fn dependency_diagnostic_status_name(
  status : DependencyDiagnosticStatus,
) -> String {
  match status {
    Missing => "missing"
    Available => "available"
    Degraded => "degraded"
  }
}

///|
pub fn make_dependency_diagnostic(
  kind : String,
  title : String,
  summary : String,
  status : DependencyDiagnosticStatus,
  macos_commands : Array[String],
  ubuntu_commands : Array[String],
  footer? : String? = None,
) -> DependencyDiagnostic {
  { kind, title, summary, status, macos_commands, ubuntu_commands, footer }
}

///|
pub fn diagnostics_add_dependency_diagnostic(
  diagnostics : Diagnostics,
  dependency : DependencyDiagnostic,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.dependency_diagnostics.push(dependency)
  next
}
