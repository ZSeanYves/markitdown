///|
/// A destination for rendered output.  The callbacks are deliberately small
/// so native CLI writers, memory buffers, and cancellation-aware callers can
/// share the same conversion entry point without exposing renderer internals.
pub struct OutputSink {
  write : (String) -> Result[Unit, String]
  finish : () -> Result[Unit, String]
}

///|
const OUTPUT_SINK_CHUNK_CHARS : Int = 64 * 1024

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
/// Renderers may still produce a buffered result, but delivery is bounded so
/// sinks can apply backpressure and cancellation between writes.
pub fn convert_input_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult, ConvertError] {
  let result = match convert_input(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let content = result.content
  let content_length = content.length()
  let mut offset = 0
  while offset < content_length {
    let end = if offset + OUTPUT_SINK_CHUNK_CHARS < content_length {
      offset + OUTPUT_SINK_CHUNK_CHARS
    } else {
      content_length
    }
    let chunk = content[offset:end].to_owned()
    match (sink.write)(chunk) {
      Ok(_) => ()
      Err(message) => return Err(RenderFailed("sink write failed: " + message))
    }
    offset = end
  }
  match (sink.finish)() {
    Ok(_) => Ok(result)
    Err(message) => Err(RenderFailed("sink finish failed: " + message))
  }
}
