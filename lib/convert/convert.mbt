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
pub fn plan_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[RoutePlan, ConvertError] {
  match detect_and_resolve_execution_plan(source, options) {
    Ok((_effective_source, _detected, execution_plan)) =>
      Ok(route_plan_from_execution_plan(execution_plan))
    Err(err) => Err(err)
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
