///|
/// Convert one input through the canonical product path and return only the
/// end-user result payload.
pub async fn convert_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertResult, ConvertError] {
  match convert_input_with_provenance(source, options) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}

///|
/// Resolve routing without fully executing conversion.
pub async fn plan_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[RoutePlan, ConvertError] {
  let session = @input.begin_input_session(
    source,
    max_bytes=options.limits.max_input_bytes,
  )
  defer @input.end_input_session(session)
  let source = session.source
  match detect_and_resolve_execution_plan(source, options) {
    Ok((_effective_source, _detected, execution_plan)) =>
      match input_failure_convert_error(source, detect=true) {
        Some(error) => Err(error)
        None => Ok(route_plan_from_execution_plan(execution_plan))
      }
    Err(err) =>
      Err(input_failure_convert_error(source, detect=true).unwrap_or(err))
  }
}

///|
/// Convert one input and return both the result payload and execution
/// provenance.
pub async fn convert_input_with_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertExecution, ConvertError] {
  execute_conversion(source, options, None)
}
