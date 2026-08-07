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
/// Deliver one renderer fragment without allowing a large block to bypass
/// the sink's backpressure boundary.
fn write_output_sink_bounded(
  sink : OutputSink,
  chunk : String,
) -> Result[Unit, String] {
  let mut offset = 0
  while offset < chunk.length() {
    let end = if offset + OUTPUT_SINK_CHUNK_CHARS < chunk.length() {
      offset + OUTPUT_SINK_CHUNK_CHARS
    } else {
      chunk.length()
    }
    match (sink.write)(chunk[offset:end].to_owned()) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    offset = end
  }
  Ok(())
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
/// Renderers may still produce a buffered result, but delivery is bounded so
/// sinks can apply backpressure and cancellation between writes.
pub fn convert_input_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult, ConvertError] {
  convert_input_to_sink_with_collection(source, options, sink, true)
}

///|
/// Convert directly into `sink` without retaining a second full output copy.
/// The returned result keeps metadata/assets/diagnostics but has empty
/// `content`; callers that need the rendered text already own it through the
/// sink.
pub fn convert_input_to_sink_unbuffered(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult, ConvertError] {
  convert_input_to_sink_with_collection(source, options, sink, false)
}

///|
fn convert_input_to_sink_with_collection(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
  collect_content : Bool,
) -> Result[ConvertResult, ConvertError] {
  if parser_pull_sink_candidate(source, options) {
    match
      try_convert_event_stream_to_sink(source, options, sink, collect_content) {
      Ok(Some(result)) => return Ok(result)
      Ok(None) => ()
      Err(err) => return Err(err)
    }
  }
  let collected = Ref(StringBuilder::new())
  let streaming_sink = make_output_sink(
    fn(chunk) {
      if collect_content {
        collected.val.write_string(chunk)
      }
      write_output_sink_bounded(sink, chunk)
    },
    fn() { Ok(()) },
  )
  let execution = match
    convert_input_with_image_ocr_provider_and_pdf_rasterizer_and_provenance_sink(
      source,
      options,
      @focr.run_ocr_provider,
      @fpdf.rasterize_pdf_with_pdftoppm_default,
      Some(streaming_sink),
    ) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let result = { ..execution.result, content: collected.val.to_string() }
  result.diagnostics.metrics.set("sink_mode", "incremental_renderer")
  if result.diagnostics.metrics.get("sink_renderer_fallback") == Some("true") {
    result.diagnostics.metrics.set("sink_buffered_fallback", "true")
  } else {
    result.diagnostics.metrics.set("sink_buffered_fallback", "false")
  }
  match (sink.finish)() {
    Ok(_) => Ok(result)
    Err(message) => Err(RenderFailed("sink finish failed: " + message))
  }
}

///|
/// Avoid running the complete route detector twice for formats that cannot
/// expose a parser pull stream. Explicit declarations take precedence; the
/// filename check is only a cheap eligibility filter and never decides the
/// actual conversion route.
fn parser_pull_sink_candidate(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Bool {
  let declared = match options.explicit_format {
    Some(format) => Some(format)
    None => source.explicit_format
  }
  match declared {
    Some(Txt | Csv | Tsv | Srt | Vtt | Jsonl | Ndjson) => return true
    Some(_) => return false
    None => ()
  }
  if @input.input_kind(source) != Path {
    return true
  }
  let name = source.source_name.trim().to_lower()
  name.has_suffix(".txt") ||
  name.has_suffix(".csv") ||
  name.has_suffix(".tsv") ||
  name.has_suffix(".srt") ||
  name.has_suffix(".vtt") ||
  name.has_suffix(".jsonl") ||
  name.has_suffix(".ndjson")
}

///|
/// Use a parser pull stream when the selected route can preserve the line
/// event contract. Complex formats and non-Markdown output intentionally
/// return `None` and use the established buffered renderer above.
fn try_convert_event_stream_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
  collect_content : Bool,
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
  let stream_kind = match detected.format {
    Txt => "line"
    Srt | Vtt => "subtitle"
    Csv | Tsv | Jsonl | Ndjson => "table"
    _ => return Ok(None)
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
      if collect_content {
        content.val.write_string(part)
      }
      match (sink.write)(part) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      offset = end
    }
    Ok(())
  }
  let renderer = match stream_kind {
    "subtitle" => @render.open_markdown_subtitle_event_sink(write_bounded)
    "table" => @render.open_markdown_table_event_sink(write_bounded)
    _ => @render.open_markdown_line_event_sink(write_bounded)
  }
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
