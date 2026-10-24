///|
/// A destination for rendered output.  The callbacks are deliberately small
/// so native CLI writers, memory buffers, and cancellation-aware callers can
/// share the same conversion entry point without exposing renderer internals.
pub struct OutputSink {
  write : async (String) -> Result[Unit, String]
  finish : async () -> Result[Unit, String]
}

///|
const OUTPUT_SINK_CHUNK_CHARS : Int32 = 64 * 1024

///|
fn output_sink_chunk_end(chunk : String, offset : Int32) -> Int32 {
  let end = (offset + OUTPUT_SINK_CHUNK_CHARS).min(chunk.length())
  if end < chunk.length() && chunk.at(end - 1).is_leading_surrogate() {
    end - 1
  } else {
    end
  }
}

///|
/// Deliver one renderer fragment without allowing a large block to bypass
/// the sink's backpressure boundary.
async fn write_output_sink_bounded(
  sink : OutputSink,
  chunk : String,
  source? : @input.InputSource,
  confirmed_bytes? : Ref[Int64],
) -> Result[Unit, String] {
  let mut offset = 0
  while offset < chunk.length() {
    let end = output_sink_chunk_end(chunk, offset)
    let part = chunk[offset:end].to_owned()
    let bytes = if source is Some(_) || confirmed_bytes is Some(_) {
      match @input.validated_text_utf8_size(part) {
        Ok(value) => value
        Err(message) => return Err("invalid output encoding: " + message)
      }
    } else {
      0L
    }
    match source.bind(@input.input_source_budget_context) {
      Some(context) =>
        match context.account.charge(OutputUtf8Bytes, bytes) {
          Ok(_) => ()
          Err(error) => {
            if source is Some(source) {
              @input.record_input_budget_failure(source, error)
            }
            return Err(@budget.budget_error_message(error))
          }
        }
      None => ()
    }
    match (sink.write)(part) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if confirmed_bytes is Some(confirmed) {
      confirmed.val += bytes
    }
    offset = end
  }
  Ok(())
}

///|
/// Build an output sink from write and finish callbacks.
pub fn make_output_sink(
  write : async (String) -> Result[Unit, String],
  finish : async () -> Result[Unit, String],
) -> OutputSink {
  { write, finish, }
}

///|
/// Convert and deliver the rendered Markdown/JSON through `sink`.
///
/// Rendering advances one fragment at a time and waits for each sink write.
/// This collecting variant additionally retains the delivered body.
pub async fn convert_input_to_sink(
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
pub async fn convert_input_to_sink_unbuffered(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
) -> Result[ConvertResult, ConvertError] {
  convert_input_to_sink_with_collection(source, options, sink, false)
}

///|
async fn convert_input_to_sink_with_collection(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
  collect_content : Bool,
) -> Result[ConvertResult, ConvertError] {
  let session = @input.begin_input_session(
    source,
    max_bytes=options.limits.max_input_bytes,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let source = session.source
  match apply_conversion_temporary_limit(source, options.limits) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if parser_pull_sink_candidate(source, options) {
    match
      try_convert_event_stream_to_sink(source, options, sink, collect_content) {
      Ok(Some(result)) => {
        match finish_conversion_cleanup(cleanup, source) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
        refresh_budget_diagnostics(source, result.diagnostics)
        return match (sink.finish)() {
          Ok(_) => Ok(result)
          Err(message) => Err(RenderFailed("sink finish failed: " + message))
        }
      }
      Ok(None) => ()
      Err(err) => return Err(err)
    }
  }
  let collected = Ref(StringBuilder())
  let streaming_sink = make_output_sink(
    async fn(chunk) {
      if collect_content {
        collected.val.write_string(chunk)
      }
      write_output_sink_bounded(sink, chunk)
    },
    fn() { Ok(()) },
  )
  let execution = match
    execute_conversion(source, options, Some(streaming_sink)) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let result = { ..execution.result, content: collected.val.to_string(), }
  result.diagnostics.metrics.set("sink_mode", "incremental_renderer")
  if result.diagnostics.metrics.get("sink_renderer_fallback") == Some("true") {
    result.diagnostics.metrics.set("sink_buffered_fallback", "true")
  } else {
    result.diagnostics.metrics.set("sink_buffered_fallback", "false")
  }
  match finish_conversion_cleanup(cleanup, source) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  refresh_budget_diagnostics(source, result.diagnostics)
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
/// event contract. Other routes return `None` and use the canonical parser
/// and incremental output renderer above. Their parsed IR/chunks may still
/// remain resident; renderer delivery does not make those parsers streaming.
async fn try_convert_event_stream_to_sink(
  source : @input.InputSource,
  options : ConvertOptions,
  sink : OutputSink,
  collect_content : Bool,
) -> Result[ConvertResult?, ConvertError] {
  if options.output_mode != Markdown {
    return Ok(None)
  }
  let session = @input.begin_input_session(
    source,
    max_bytes=options.limits.max_input_bytes,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let source = session.source
  match apply_conversion_temporary_limit(source, options.limits) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let execution_started = @env.now()
  let (effective_source, detected, execution_plan) = match
    detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value
    Err(err) =>
      return Err(
        input_failure_convert_error(source, detect=true).unwrap_or(err),
      )
  }
  if input_failure_convert_error(source, detect=true) is Some(error) {
    return Err(error)
  }
  let stream_kind = match detected.format {
    Txt => "line"
    Srt | Vtt => "subtitle"
    Csv | Tsv | Jsonl | Ndjson => "table"
    _ => return Ok(None)
  }
  let context = @parser.parse_context_with_input_source(
    parse_context_from_execution_plan(detected.format, execution_plan),
    effective_source,
  )
  let stream = match
    @parser.registry_open_event_stream(
      @formats.builtin_registry(),
      effective_source,
      context,
    ) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(None)
    Err(message) =>
      return Err(
        input_failure_convert_error(source).unwrap_or(ParseFailed(message)),
      )
  }
  defer ignore(stream.close())
  let content = Ref(StringBuilder())
  let confirmed_bytes = Ref(0L)
  let collecting_sink = make_output_sink(
    async fn(part) {
      match (sink.write)(part) {
        Err(message) => return Err(message)
        Ok(_) => ()
      }
      if collect_content {
        content.val.write_string(part)
      }
      Ok(())
    },
    fn() { Ok(()) },
  )
  let write_bounded = async fn(chunk : String) -> Result[Unit, String] {
    write_output_sink_bounded(collecting_sink, chunk, source~, confirmed_bytes~)
  }
  let renderer = match stream_kind {
    "subtitle" => @render.open_markdown_subtitle_event_sink(write_bounded)
    "table" => @render.open_markdown_table_event_sink(write_bounded)
    _ => @render.open_markdown_line_event_sink(write_bounded)
  }
  while true {
    match (stream.next)() {
      Ok(Some(event)) => {
        if input_failure_convert_error(source) is Some(error) {
          return Err(error)
        }
        match (renderer.push)(event) {
          Ok(_) => ()
          Err(message) =>
            return Err(
              input_failure_convert_error(source).unwrap_or(
                RenderFailed("sink write failed: " + message),
              ),
            )
        }
      }
      Ok(None) => break
      Err(message) =>
        return Err(
          input_failure_convert_error(source).unwrap_or(ParseFailed(message)),
        )
    }
  }
  if input_failure_convert_error(source) is Some(error) {
    return Err(error)
  }
  match (renderer.finish)() {
    Ok(_) => ()
    Err(message) =>
      return Err(
        input_failure_convert_error(source).unwrap_or(RenderFailed(message)),
      )
  }
  let summary = match (stream.finish)() {
    Ok(value) => value
    Err(message) =>
      return Err(
        input_failure_convert_error(source).unwrap_or(ParseFailed(message)),
      )
  }
  if input_failure_convert_error(source) is Some(error) {
    return Err(error)
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
  record_budget_diagnostics(source, diagnostics, confirmed_bytes.val)
  diagnostics.metrics.set(
    "timing_total_ms",
    (@env.now() - execution_started).to_string(),
  )
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
