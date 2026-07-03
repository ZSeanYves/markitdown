///|
pub fn vtt_parser() -> @parser.Parser {
  @parser.make_parser(
    "vtt_parser",
    @parser.ParserMode::StreamingEvent,
    subtitle_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_vtt_result(source, context)
    },
  )
}

///|
fn subtitle_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::StreamingEvent,
    true,
    @parser.StreamingGranularity::Record,
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
fn parse_vtt_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    "vtt_parser",
    @parser.ParserMode::StreamingEvent,
    source,
    "vtt",
  )
  diagnostics.metrics.set("parser_name", "vtt_parser")
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set("input_kind", @fshared.input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "vtt")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "subtitle_record_event_stream")
  @fshared.apply_product_metrics(diagnostics, "vtt")
  let parsed = try @dsub.parse_vtt_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(parsed) => {
      let inspect = @dsub.inspect_subtitle_document(parsed)
      let events = subtitle_events_from_document(parsed, source, "vtt")
      diagnostics.metrics.set("cue_count", inspect.cue_count.to_string())
      diagnostics.metrics.set("note_count", inspect.note_count.to_string())
      diagnostics.metrics.set("style_count", inspect.style_count.to_string())
      diagnostics.metrics.set("region_count", inspect.region_count.to_string())
      diagnostics.metrics.set(
        "multiline_cue_count",
        inspect.multiline_cue_count.to_string(),
      )
      diagnostics.metrics.set(
        "blank_line_count",
        inspect.blank_line_count.to_string(),
      )
      diagnostics.metrics.set(
        "line_count",
        count_subtitle_lines(text).to_string(),
      )
      diagnostics.metrics.set("char_count", inspect.char_count.to_string())
      diagnostics.metrics.set(
        "max_lines_per_cue",
        inspect.max_lines_per_cue.to_string(),
      )
      diagnostics.metrics.set(
        "block_count",
        count_subtitle_event_blocks(events).to_string(),
      )
      diagnostics.metrics.set("table_count", "0")
      diagnostics.metrics.set("asset_count", "0")
      diagnostics.metrics.set("syntax_error_count", "0")
      diagnostics.metrics.set("event_count", events.length().to_string())
      diagnostics.metrics.set(
        "warning_count",
        diagnostics.warnings.length().to_string(),
      )
      diagnostics.metrics.set(
        "degraded_feature_count",
        diagnostics.degraded_features.length().to_string(),
      )
      diagnostics.metrics.set(
        "fallback_count",
        diagnostics.fallback_trace.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:vtt_parser")
      Ok(
        @parser.parse_result_with_events_capability(
          "vtt_parser",
          @parser.ParserMode::StreamingEvent,
          events,
          diagnostics,
          subtitle_parser_capability(),
        ),
      )
    }
    Err(err) =>
      Ok(subtitle_malformed_parse_result(source, text, diagnostics, err))
  }
}

///|
fn subtitle_events_from_document(
  doc : @dsub.SubtitleDocument,
  source : @input.InputSource,
  format_name : String,
) -> Array[@core.CoreEvent] {
  let events : Array[@core.CoreEvent] = []
  for cue in doc.cues {
    let base_ref = subtitle_source_ref(
      source,
      format_name,
      cue.index,
      cue.line_start,
      cue.line_end,
      cue.time_start,
      cue.time_end,
    )
    if cue.note_kind is Some(kind) {
      let block_ref = subtitle_generic_block_ref(
        base_ref,
        @core.BlockKind::Raw,
        [
          ("raw_kind", "subtitle_" + kind),
          ("info", format_name),
          ("literal", "true"),
        ],
      )
      events.push({
        kind: @core.EventKind::StartBlock(@core.BlockKind::Raw),
        text: cue.note_payload.unwrap_or(""),
        source_ref: Some(block_ref),
      })
      events.push({
        kind: @core.EventKind::EndBlock(@core.BlockKind::Raw),
        text: "",
        source_ref: Some(block_ref),
      })
      continue
    }
    let quote_ref = subtitle_generic_block_ref(
      base_ref,
      @core.BlockKind::BlockQuote,
      [
        ("literal", "true"),
        ("cue_index", (cue.index + 1).to_string()),
        ("time_range", cue.time_range),
      ],
    )
    if cue.identifier is Some(identifier) {
      quote_ref.extra.set("subtitle_identifier", identifier)
    }
    if cue.cue_settings is Some(settings) {
      quote_ref.extra.set("subtitle_cue_settings", settings)
    }
    let heading_ref = subtitle_generic_block_ref(
      base_ref,
      @core.BlockKind::Heading,
      [("level", "6"), ("literal", "true")],
    )
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::BlockQuote),
      text: "",
      source_ref: Some(quote_ref),
    })
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::Heading),
      text: cue.time_range,
      source_ref: Some(heading_ref),
    })
    events.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::Heading),
      text: "",
      source_ref: Some(heading_ref),
    })
    let paragraph_ref = subtitle_generic_block_ref(
      base_ref,
      @core.BlockKind::Paragraph,
      [("literal", "true")],
    )
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      text: cue.text_lines.join("\n"),
      source_ref: Some(paragraph_ref),
    })
    events.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
      text: "",
      source_ref: Some(paragraph_ref),
    })
    events.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::BlockQuote),
      text: "",
      source_ref: Some(quote_ref),
    })
  }
  events
}

///|
fn subtitle_source_ref(
  source : @input.InputSource,
  format_name : String,
  cue_index : Int,
  line_start : Int,
  line_end : Int,
  time_start : String?,
  time_end : String?,
) -> @core.SourceRef {
  @core.source_ref_with_extra(
    @core.source_ref_with_time_range(
      @core.source_ref_with_lines(
        @core.empty_source_ref(),
        Some(source.source_name),
        Some(format_name),
        Some(line_start),
        Some(line_end),
      ),
      Some(source.source_name),
      Some(format_name),
      time_start,
      time_end,
    ),
    "subtitle_cue_index",
    cue_index.to_string(),
  )
}

///|
fn subtitle_generic_block_ref(
  source_ref : @core.SourceRef,
  kind : @core.BlockKind,
  attrs : Array[(String, String)],
) -> @core.SourceRef {
  let next = source_ref
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_block_kind", @core.block_kind_name(kind))
  for entry in attrs {
    next.extra.set("ir_block_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn count_subtitle_event_blocks(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    match event.kind {
      @core.EventKind::StartBlock(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn count_subtitle_lines(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut count = 1
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  count
}

///|
fn subtitle_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("vtt"),
    Some(1),
    Some(count_subtitle_lines(text)),
  )
  let raw_ref = subtitle_generic_block_ref(source_ref, @core.BlockKind::Raw, [
    ("raw_kind", "vtt_fail_closed"),
    ("info", "vtt"),
    ("literal", "true"),
  ])
  let event : @core.CoreEvent = {
    kind: @core.EventKind::StartBlock(@core.BlockKind::Raw),
    text,
    source_ref: Some(raw_ref),
  }
  diagnostics.warnings.push("vtt parse warning: " + err)
  diagnostics.degraded_features.push("vtt_raw_fenced_fallback")
  diagnostics.fallback_trace.push(
    "vtt parse failed -> raw event-stream fallback",
  )
  diagnostics.metrics.set("cue_count", "0")
  diagnostics.metrics.set("note_count", "0")
  diagnostics.metrics.set("style_count", "0")
  diagnostics.metrics.set("region_count", "0")
  diagnostics.metrics.set("multiline_cue_count", "0")
  diagnostics.metrics.set("blank_line_count", "0")
  diagnostics.metrics.set("line_count", count_subtitle_lines(text).to_string())
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("max_lines_per_cue", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set("event_count", "1")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("builder_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "subtitle_record_event_stream")
  diagnostics.pass_trace.push("parse:vtt_parser")
  @parser.parse_result_with_events_capability(
    "vtt_parser",
    @parser.ParserMode::StreamingEvent,
    [event],
    diagnostics,
    subtitle_parser_capability(),
  )
}
