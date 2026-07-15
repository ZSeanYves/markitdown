///|
/// Construct the media-pipeline parser used for root audio inputs.
pub fn audio_parser() -> @parser.Parser {
  @parser.make_parser(
    "audio_parser",
    MediaPipeline,
    audio_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      audio_parser_result(source, context.detected_format, context)
    },
  )
}

///|
/// Capability for the audio transcript media pipeline.
pub fn audio_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    MediaPipeline,
    false,
    None,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
/// Parse one audio input by invoking the configured transcript runtime.
pub fn audio_parser_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  match detected_format {
    Audio(_) => ()
    _ =>
      return Err(
        "audio_parser only accepts detected audio formats; got " +
        @input.detected_format_name(detected_format),
      )
  }
  let transcript = match
    run_audio_transcribe_command(
      source,
      detected_format,
      context.audio_options.language,
    ) {
    Ok(value) => value
    Err(error) => return Err(error.to_string())
  }
  audio_parse_result_from_transcript(
    source, detected_format, context, transcript,
  )
}

///|
/// Parse one audio input with an injected transcript runtime, mainly for tests
/// and runtime boundary coverage.
pub fn audio_parser_result_with_runtime(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  context : @parser.ParseContext,
  runtime : (@input.InputSource, @input.DetectedFormat, String?) -> Result[
    AudioTranscriptResult,
    AudioTranscribeError,
  ],
) -> Result[@parser.ParseResult, String] {
  let transcript = match
    runtime(source, detected_format, context.audio_options.language) {
    Ok(value) => value
    Err(error) => return Err(error.to_string())
  }
  audio_parse_result_from_transcript(
    source, detected_format, context, transcript,
  )
}

///|
fn audio_parse_result_from_transcript(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  context : @parser.ParseContext,
  transcript : AudioTranscriptResult,
) -> Result[@parser.ParseResult, String] {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "audio_parser",
    MediaPipeline,
    source,
    @input.detected_format_name(detected_format),
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    @input.detected_format_name(detected_format),
    "audio_parser",
    MediaPipeline,
    MediaPipeline,
    "document",
    None,
    "audio_media_pipeline_document",
  )
  @fshared.apply_product_metrics(
    diagnostics,
    @input.detected_format_name(detected_format),
  )
  diagnostics.metrics.set(
    "audio_backend_transport",
    audio_backend_transport_name(),
  )
  diagnostics.metrics.set("audio_backend_name", transcript.provider_name)
  diagnostics.metrics.set(
    "audio_backend_version",
    transcript.provider_version.unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_duration_ms",
    transcript.metadata.duration_ms
    .map(value => value.to_string())
    .unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_sample_rate_hz",
    transcript.metadata.sample_rate_hz
    .map(value => value.to_string())
    .unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_channel_count",
    transcript.metadata.channel_count
    .map(value => value.to_string())
    .unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_codec",
    transcript.metadata.codec.unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_language",
    transcript.metadata.language.unwrap_or(""),
  )
  diagnostics.metrics.set(
    "audio_segment_count",
    transcript.segments.length().to_string(),
  )
  audio_apply_runtime_diagnostic_metrics(diagnostics, transcript.diagnostics)
  diagnostics.metrics.set("provider_invoked", "true")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")

  let non_empty_segment_count = transcript.segments
    .filter(segment => segment.text.trim() != "")
    .length()
  if non_empty_segment_count == 0 {
    return Err(
      "audio backend produced transcript segments with empty text only",
    )
  }

  let blocks : Array[@core.CoreBlock] = []
  let metadata = audio_document_metadata(source, detected_format, transcript)
  let format_name = @input.detected_format_name(detected_format)
  let file_id = Some(source.source_name)
  let source_format = Some(format_name)

  blocks.push(
    heading_block(
      source.source_name,
      base_audio_source_ref(file_id, source_format),
      1,
    ),
  )
  blocks.push(
    literal_paragraph_block(
      audio_summary_text(transcript),
      base_audio_source_ref(file_id, source_format),
    ),
  )
  blocks.push(
    heading_block(
      "Transcript",
      base_audio_source_ref(file_id, source_format),
      2,
    ),
  )

  let mut last_end = -1
  for segment in transcript.segments {
    if segment.start_ms < 0 ||
      segment.end_ms < 0 ||
      segment.end_ms < segment.start_ms {
      return Err(
        "audio backend emitted malformed transcript segment timestamps",
      )
    }
    if last_end > segment.start_ms {
      return Err(
        "audio backend emitted out-of-order transcript segment timestamps",
      )
    }
    last_end = segment.end_ms
    let trimmed_text = segment.text.trim().to_owned()
    let paragraph = audio_segment_block(
      source, detected_format, segment, trimmed_text,
    )
    blocks.push(paragraph)
  }

  diagnostics.metrics.set("block_count", blocks.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:audio_parser")

  let document = @core.document_with_metadata(
    @core.document_with_diagnostics(
      @core.document_from_blocks(blocks),
      diagnostics,
    ),
    metadata,
  )
  Ok(
    @parser.parse_result_with_document_capability(
      "audio_parser",
      MediaPipeline,
      document,
      diagnostics,
      audio_parser_capability(),
    ),
  )
}

///|
fn audio_apply_runtime_diagnostic_metrics(
  diagnostics : @core.Diagnostics,
  runtime_diagnostics : Array[String],
) -> Unit {
  for entry in runtime_diagnostics {
    if !entry.has_prefix("metric|") {
      continue
    }
    let parts = entry.split("|").to_array().map(fn(part) { part.to_owned() })
    if parts.length() < 3 {
      continue
    }
    diagnostics.metrics.set(parts[1], parts[2:][:].join("|"))
  }
}

///|
fn audio_document_metadata(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  transcript : AudioTranscriptResult,
) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("title", String(source.source_name))
  metadata.set(
    "audio_format",
    String(@input.detected_format_name(detected_format)),
  )
  metadata.set(
    "audio_backend_transport",
    String(audio_backend_transport_name()),
  )
  metadata.set("audio_backend_name", String(transcript.provider_name))
  match transcript.provider_version {
    Some(value) => metadata.set("audio_backend_version", String(value))
    None => ()
  }
  match transcript.metadata.duration_ms {
    Some(value) => metadata.set("audio_duration_ms", Number(value.to_string()))
    None => ()
  }
  match transcript.metadata.language {
    Some(value) => metadata.set("audio_language", String(value))
    None => ()
  }
  match transcript.metadata.codec {
    Some(value) => metadata.set("audio_codec", String(value))
    None => ()
  }
  match transcript.metadata.sample_rate_hz {
    Some(value) =>
      metadata.set("audio_sample_rate_hz", Number(value.to_string()))
    None => ()
  }
  match transcript.metadata.channel_count {
    Some(value) =>
      metadata.set("audio_channel_count", Number(value.to_string()))
    None => ()
  }
  metadata.set(
    "audio_segment_count",
    Number(transcript.segments.length().to_string()),
  )
  metadata
}

///|
fn audio_summary_text(transcript : AudioTranscriptResult) -> String {
  let lines : Array[String] = []
  lines.push(
    "> duration: " +
    transcript.metadata.duration_ms.map(format_duration_ms).unwrap_or("unknown"),
  )
  lines.push("> language: " + transcript.metadata.language.unwrap_or("unknown"))
  lines.push(
    "> transcript backend: " +
    transcript.provider_name +
    transcript.provider_version.map(value => " " + value).unwrap_or(""),
  )
  lines.join("\n")
}

///|
fn base_audio_source_ref(
  file_id : String?,
  format : String?,
) -> @core.SourceRef {
  @core.source_ref_with_time_range(
    @core.empty_source_ref(),
    file_id,
    format,
    None,
    None,
  )
}

///|
fn heading_block(
  text : String,
  source_ref : @core.SourceRef,
  level : Int,
) -> @core.CoreBlock {
  @core.block_with_attr(
    @core.make_block(Heading, text, source_ref~),
    "level",
    level.to_string(),
  )
}

///|
fn literal_paragraph_block(
  text : String,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  @core.make_block(Paragraph, text, source_ref~)
}

///|
fn audio_segment_block(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  segment : AudioTranscriptSegment,
  trimmed_text : String,
) -> @core.CoreBlock {
  let source_ref = audio_segment_source_ref(source, detected_format, segment)
  let text = "[" +
    format_timestamp_ms(segment.start_ms) +
    " - " +
    format_timestamp_ms(segment.end_ms) +
    "] " +
    trimmed_text
  @core.block_with_attr(
    @core.make_block(Paragraph, text, source_ref~),
    "audio_segment",
    "true",
  )
}

///|
fn audio_segment_source_ref(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  segment : AudioTranscriptSegment,
) -> @core.SourceRef {
  let file_id = Some(source.source_name)
  let format = Some(@input.detected_format_name(detected_format))
  let source_ref = @core.source_ref_with_time_range(
    @core.empty_source_ref(),
    file_id,
    format,
    Some(format_timestamp_ms(segment.start_ms)),
    Some(format_timestamp_ms(segment.end_ms)),
  )
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "audio_segment_id",
    segment.segment_id,
  )
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "audio_start_ms",
    segment.start_ms.to_string(),
  )
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "audio_end_ms",
    segment.end_ms.to_string(),
  )
  let source_ref = match segment.confidence {
    Some(value) =>
      @core.source_ref_with_extra(
        source_ref,
        "audio_confidence",
        value.to_string(),
      )
    None => source_ref
  }
  let source_ref = match segment.speaker {
    Some(value) =>
      @core.source_ref_with_extra(source_ref, "audio_speaker", value)
    None => source_ref
  }
  let source_ref = match segment.channel {
    Some(value) =>
      @core.source_ref_with_extra(
        source_ref,
        "audio_channel",
        value.to_string(),
      )
    None => source_ref
  }
  match segment.language {
    Some(value) =>
      @core.source_ref_with_extra(source_ref, "audio_language", value)
    None => source_ref
  }
}

///|
fn format_duration_ms(duration_ms : Int) -> String {
  format_timestamp_ms(duration_ms)
}

///|
fn format_timestamp_ms(total_ms : Int) -> String {
  let hours = total_ms / 3600000
  let minutes = total_ms % 3600000 / 60000
  let seconds = total_ms % 60000 / 1000
  let millis = total_ms % 1000
  pad_int(hours, 2) +
  ":" +
  pad_int(minutes, 2) +
  ":" +
  pad_int(seconds, 2) +
  "." +
  pad_int(millis, 3)
}

///|
fn pad_int(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
  } else {
    "0".repeat(width - text.length()) + text
  }
}
