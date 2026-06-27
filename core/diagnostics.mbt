///|
pub fn empty_diagnostics() -> Diagnostics {
  {
    parser_name: None,
    parser_mode: None,
    convert_mode: None,
    input_kind: None,
    detected_format: None,
    warnings: [],
    errors: [],
    degraded_features: [],
    same_mode_degradation: [],
    fallback_trace: [],
    pass_trace: [],
    metrics: Map([]),
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
) -> Diagnostics {
  { ..diagnostics, parser_mode, convert_mode }
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
