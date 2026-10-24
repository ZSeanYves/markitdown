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
