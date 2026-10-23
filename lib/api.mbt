///|
/// Convert one input through the stable 0.8 product API.
/// Errors are values in the frozen 0.8 contract.
#warnings("-result_error_return")
pub async fn convert(
  input : Input,
  options~ : ConvertOptions = ConvertOptions::default(),
) -> Result[Output, ConvertError] {
  let legacy = match legacy_options(options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match @convert.convert_input_with_provenance(input.source, legacy) {
    Ok(execution) => Ok(stable_output(execution))
    Err(error) => Err(convert_error_from_legacy(error))
  }
}

///|
/// Construct an asynchronous destination owned by the caller.
pub fn OutputSink::new(
  write : async (String) -> Result[Unit, String],
  finish : async () -> Result[Unit, String],
) -> OutputSink {
  { write, finish, }
}

///|
/// Convert into an asynchronous sink with backpressure at every write.
/// Failed reads or writes stop delivery without calling finish.
#warnings("-result_error_return")
pub async fn convert_to_sink(
  input : Input,
  sink : OutputSink,
  options~ : ConvertOptions = ConvertOptions::default(),
) -> Result[ConversionSummary, ConvertError] {
  let legacy = match legacy_options(options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match
    @convert.convert_input_to_sink_unbuffered(
      input.source,
      legacy,
      @convert.make_output_sink(sink.write, sink.finish),
    ) {
    Ok(result) => Ok(stable_conversion_summary(result))
    Err(error) => Err(convert_error_from_legacy(error))
  }
}

///|
/// Return the marker for the frozen 0.8 compatibility surface.
pub fn api_v0_8() -> ApiV0_8 {
  { marker: (), }
}

///|
/// Convert through an explicitly versioned 0.8 handle.
#warnings("-result_error_return")
pub async fn ApiV0_8::convert(
  self : ApiV0_8,
  input : Input,
  options~ : ConvertOptions = ConvertOptions::default(),
) -> Result[Output, ConvertError] {
  ignore(self.marker)
  convert(input, options~)
}

///|
/// Describe the supported migration direction without committing a 1.0 API.
pub fn ApiV0_8::v1_migration(self : ApiV0_8) -> ApiV1Migration {
  ignore(self.marker)
  {
    source_version: "0.8",
    target_version: "1.0",
    stable_package: "ZSeanYves/markitdown/lib",
    breaking_changes_allowed_before_target: true,
  }
}
