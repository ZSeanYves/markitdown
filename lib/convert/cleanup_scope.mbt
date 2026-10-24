///|
/// A caller's CLI/session owner may already hold this ledger. Never replace it
/// or reopen a larger nested allowance when the request enables finite spooling.
fn apply_conversion_temporary_limit(
  source : @input.InputSource,
  limits : ResourceLimits,
) -> Result[Unit, ConvertError] {
  guard limits.max_temporary_bytes is Some(limit) else { return Ok(()) }
  guard @input.input_source_budget_context(source) is Some(context) else {
    return Err(ParseFailed("temporary limit requires an input session"))
  }
  match context.account.tighten_resident_limit(TemporaryBytes, limit) {
    Ok(_) => Ok(())
    Err(error) => {
      @input.record_input_budget_failure(source, error)
      Err(
        input_failure_convert_error(source).unwrap_or(
          budget_convert_error(error),
        ),
      )
    }
  }
}

///|
async fn finish_conversion_cleanup(
  scope : @input.InputCleanupScope,
  source : @input.InputSource,
  detect~ : Bool = false,
) -> Result[Unit, ConvertError] noraise + nocancel {
  match @input.cleanup_input_scope(scope) {
    Ok(_) => Ok(())
    Err(_) =>
      Err(
        input_failure_convert_error(source, detect~).unwrap_or(
          ParseFailed("input asynchronous cleanup failed"),
        ),
      )
  }
}
