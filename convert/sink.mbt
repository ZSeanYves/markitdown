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
  match try_convert_event_stream_to_sink(source, options, sink) {
    Ok(Some(result)) => return Ok(result)
    Ok(None) => ()
    Err(err) => return Err(err)
  }
  let result = match convert_input(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  result.diagnostics.metrics.set("sink_mode", "buffered_result_chunking")
  result.diagnostics.metrics.set("sink_buffered_fallback", "true")
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

///|
/// Use a parser pull stream when the selected route can preserve the line
/// event contract. Complex formats and non-Markdown output intentionally
/// return `None` and use the established buffered renderer above.
fn try_convert_event_stream_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult?, ConvertError] {
  if options.output_mode != Markdown {
    return Ok(None)
  }
  let execution_started = @env.now()
  let (effective_source, detected, execution_plan) = match
    detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if detected.format != Txt {
    return Ok(None)
  }
  let context = parse_context_from_execution_plan(
    detected.format,
    execution_plan,
  )
  let stream = match
    @parser.registry_open_event_stream(
      @formats.builtin_registry(),
      effective_source,
      context,
    ) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(None)
    Err(message) => return Err(ParseFailed(message))
  }
  let content = Ref(StringBuilder::new())
  let write_bounded = fn(chunk : String) -> Result[Unit, String] {
    let mut offset = 0
    while offset < chunk.length() {
      let end = if offset + OUTPUT_SINK_CHUNK_CHARS < chunk.length() {
        offset + OUTPUT_SINK_CHUNK_CHARS
      } else {
        chunk.length()
      }
      let part = chunk[offset:end].to_owned()
      content.val.write_string(part)
      match (sink.write)(part) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      offset = end
    }
    Ok(())
  }
  let renderer = @render.open_markdown_line_event_sink(write_bounded)
  while true {
    match (stream.next)() {
      Ok(Some(event)) =>
        match (renderer.push)(event) {
          Ok(_) => ()
          Err(message) =>
            return Err(RenderFailed("sink write failed: " + message))
        }
      Ok(None) => break
      Err(message) => return Err(ParseFailed(message))
    }
  }
  match (renderer.finish)() {
    Ok(_) => ()
    Err(message) => return Err(RenderFailed(message))
  }
  let summary = match (stream.finish)() {
    Ok(value) => value
    Err(message) => return Err(ParseFailed(message))
  }
  let diagnostics = inject_preparse_diagnostics(
    summary.diagnostics,
    @input.detected_format_name(detected.format),
    execution_plan,
    detected,
  )
  diagnostics.metrics.set("sink_mode", "parser_to_renderer_event_stream")
  diagnostics.metrics.set("sink_buffered_fallback", "false")
  diagnostics.metrics.set("parser_to_renderer_stream", "true")
  diagnostics.metrics.set(
    "timing_total_ms",
    (@env.now() - execution_started).to_string(),
  )
  match (sink.finish)() {
    Ok(_) => ()
    Err(message) => return Err(RenderFailed("sink finish failed: " + message))
  }
  Ok(
    Some({
      content: content.val.to_string(),
      fidelity_mode: execution_plan.fidelity_mode,
      output_mode: Markdown,
      detected_format: detected.format,
      parser_mode: summary.mode,
      convert_mode: execution_plan.mode,
      metadata: summary.metadata,
      diagnostics,
      assets: summary.assets,
      source_map: summary.source_map,
      chunks: None,
      debug_ir: None,
    }),
  )
}
