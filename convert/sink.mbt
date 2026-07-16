///|
/// A destination for rendered output.  The callbacks are deliberately small
/// so native CLI writers, memory buffers, and cancellation-aware callers can
/// share the same conversion entry point without exposing renderer internals.
pub struct OutputSink {
  write : (String) -> Result[Unit, String]
  finish : () -> Result[Unit, String]
}

///|
/// Build an output sink from write and finish callbacks.
pub fn make_output_sink(
  write : (String) -> Result[Unit, String],
  finish : () -> Result[Unit, String],
) -> OutputSink {
  { write, finish }
}

///|
/// Convert and deliver the rendered Markdown/JSON through `sink`.
///
/// The current renderer contract emits one logical chunk.  Keeping this
/// boundary explicit lets stream-capable renderers switch to multiple chunks
/// later while preserving the same failure and cleanup semantics today.
pub fn convert_input_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult, ConvertError] {
  let result = match convert_input(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match (sink.write)(result.content) {
    Ok(_) => ()
    Err(message) => return Err(RenderFailed("sink write failed: " + message))
  }
  match (sink.finish)() {
    Ok(_) => Ok(result)
    Err(message) => Err(RenderFailed("sink finish failed: " + message))
  }
}
