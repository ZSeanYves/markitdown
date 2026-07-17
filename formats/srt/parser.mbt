///|
pub fn srt_parser() -> @parser.Parser {
  @parser.make_parser(
    "srt_parser",
    StreamingEvent,
    subtitle_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_subtitle_result(source, context, "srt")
    },
    stream_events=Some(open_srt_event_stream),
  )
}

///|
fn open_srt_event_stream(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseEventStream?, String] {
  let blocks = match
    @sourceio.open_source_text_block_reader(
      source,
      max_bytes=@parser.max_input_bytes(context),
      max_line_chars=@parser.max_line_chars(context),
    ) {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let stats : LargeSrtStats = {
    cue_count: 0,
    invalid_count: 0,
    multiline_count: 0,
    char_count: 0,
    max_lines_per_cue: 0,
    line_count: 0,
  }
  let queued : Array[@core.CoreEvent] = []
  let queued_index = Ref(0)
  let event_count = Ref(0)
  let truncated_blocks = Ref(0)
  let diagnostics = @fshared.empty_parser_diagnostics(
    "srt_parser",
    StreamingEvent,
    source,
    "srt",
  )
  Ok(
    Some(
      @parser.make_parse_event_stream(
        fn() {
          while true {
            if queued_index.val < queued.length() {
              let event = queued[queued_index.val]
              queued_index.val += 1
              event_count.val += 1
              return Ok(Some(event))
            }
            queued.clear()
            queued_index.val = 0
            match (blocks.next)() {
              Ok(Some(block)) => {
                stats.line_count = stats.line_count.max(block.line_end)
                if block.truncated {
                  truncated_blocks.val += 1
                }
                append_large_srt_block(
                  queued,
                  source,
                  block.lines,
                  block.line_start,
                  stats,
                )
              }
              Ok(None) => return Ok(None)
              Err(message) => return Err(message)
            }
          }
          Ok(None)
        },
        fn() {
          diagnostics.metrics.set("parser_name", "srt_parser")
          diagnostics.metrics.set("parser_mode", "streaming_event")
          diagnostics.metrics.set("detected_format", "srt")
          diagnostics.metrics.set("effective_mode", "streaming_event")
          diagnostics.metrics.set("ir_input_kind", "event_stream")
          diagnostics.metrics.set("event_granularity", "record")
          diagnostics.metrics.set(
            "event_semantics", "subtitle_record_event_stream",
          )
          diagnostics.metrics.set("subtitle_lowering_mode", "pull_record_v2")
          diagnostics.metrics.set("cue_count", stats.cue_count.to_string())
          diagnostics.metrics.set("line_count", stats.line_count.to_string())
          diagnostics.metrics.set("char_count", stats.char_count.to_string())
          diagnostics.metrics.set(
            "multiline_cue_count",
            stats.multiline_count.to_string(),
          )
          diagnostics.metrics.set(
            "max_lines_per_cue",
            stats.max_lines_per_cue.to_string(),
          )
          diagnostics.metrics.set(
            "recovered_cue_count",
            stats.invalid_count.to_string(),
          )
          diagnostics.metrics.set("block_count", stats.cue_count.to_string())
          diagnostics.metrics.set("event_count", event_count.val.to_string())
          diagnostics.metrics.set("stream_parser_to_renderer", "true")
          if stats.invalid_count > 0 {
            diagnostics.warnings.push(
              "srt recovered " +
              stats.invalid_count.to_string() +
              " malformed cue block(s)",
            )
            diagnostics.degraded_features.push("srt_malformed_cue_recovered")
          }
          if truncated_blocks.val > 0 {
            diagnostics.warnings.push("srt record truncated by resource limits")
            diagnostics.degraded_features.push("srt_record_truncation")
          }
          @fshared.apply_product_metrics(diagnostics, "srt")
          diagnostics.pass_trace.push("parse:srt_parser:pull_stream")
          diagnostics.pass_trace.push("parse:srt_parser")
          Ok(
            @parser.parse_stream_summary(
              "srt_parser",
              StreamingEvent,
              subtitle_parser_capability(),
              diagnostics,
            ),
          )
        },
      ),
    ),
  )
}

///|
fn subtitle_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    StreamingEvent,
    true,
    Record,
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
fn parse_subtitle_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  format_name : String,
) -> Result[@parser.ParseResult, String] {
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  if text_payload.text.length() >= 1_048_576 {
    return Ok(
      parse_large_srt_result(
        text_payload.prepared_source,
        text_payload.text,
        context,
      ),
    )
  }
  let normalized_text = large_srt_normalized_text(text_payload.text)
  let normalized_source = @input.with_text_payload(
    text_payload.prepared_source,
    normalized_text,
  )
  let prepared = match
    @dsub.prepare_srt_document_from_source(normalized_source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let diagnostics = @fshared.empty_parser_diagnostics(
    format_name + "_parser",
    StreamingEvent,
    source,
    format_name,
  )
  diagnostics.metrics.set("parser_name", format_name + "_parser")
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", format_name)
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "subtitle_record_event_stream")
  @fshared.apply_product_metrics(diagnostics, format_name)
  match prepared.document {
    Some(parsed) => {
      let inspect = prepared.inspect.unwrap_or(
        @dsub.inspect_subtitle_document(parsed),
      )
      let invalid_cue_count = parsed.cues
        .filter(cue => cue.note_kind == Some("invalid"))
        .length()
      if invalid_cue_count > 0 {
        diagnostics.warnings.push(
          format_name +
          " recovered " +
          invalid_cue_count.to_string() +
          " malformed cue block(s)",
        )
        diagnostics.degraded_features.push(
          format_name + "_malformed_cue_recovered",
        )
      }
      let events = subtitle_events_from_document(parsed, source, format_name)
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
      diagnostics.metrics.set(
        "recovered_cue_count",
        invalid_cue_count.to_string(),
      )
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
      diagnostics.pass_trace.push("parse:" + format_name + "_parser")
      Ok(
        @parser.parse_result_with_events_capability(
          format_name + "_parser",
          StreamingEvent,
          events,
          diagnostics,
          subtitle_parser_capability(),
        ),
      )
    }
    None =>
      Ok(
        subtitle_malformed_parse_result(
          source,
          text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
          format_name,
        ),
      )
  }
}

///|
priv struct LargeSrtStats {
  mut cue_count : Int
  mut invalid_count : Int
  mut multiline_count : Int
  mut char_count : Int
  mut max_lines_per_cue : Int
  mut line_count : Int
}

///|
fn parse_large_srt_result(
  source : @input.InputSource,
  original_text : String,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  let text = large_srt_normalized_text(original_text)
  let events : Array[@core.CoreEvent] = []
  let stats : LargeSrtStats = {
    cue_count: 0,
    invalid_count: 0,
    multiline_count: 0,
    char_count: 0,
    max_lines_per_cue: 0,
    line_count: 0,
  }
  let block : Array[String] = []
  let mut block_start = 1
  for line_view in text.split("\n") {
    stats.line_count += 1
    if line_view.trim() == "" {
      if block.length() > 0 {
        append_large_srt_block(events, source, block, block_start, stats)
        block.clear()
      }
      block_start = stats.line_count + 1
    } else {
      block.push(line_view.to_owned())
    }
  }
  if block.length() > 0 {
    append_large_srt_block(events, source, block, block_start, stats)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    "srt_parser",
    StreamingEvent,
    source,
    "srt",
  )
  diagnostics.metrics.set("parser_name", "srt_parser")
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "srt")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "subtitle_record_event_stream")
  diagnostics.metrics.set("subtitle_lowering_mode", "large_record_v2")
  diagnostics.metrics.set("cue_count", stats.cue_count.to_string())
  diagnostics.metrics.set("line_count", stats.line_count.to_string())
  diagnostics.metrics.set("char_count", stats.char_count.to_string())
  diagnostics.metrics.set(
    "multiline_cue_count",
    stats.multiline_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_lines_per_cue",
    stats.max_lines_per_cue.to_string(),
  )
  diagnostics.metrics.set(
    "recovered_cue_count",
    stats.invalid_count.to_string(),
  )
  diagnostics.metrics.set("block_count", stats.cue_count.to_string())
  diagnostics.metrics.set("event_count", events.length().to_string())
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("syntax_error_count", stats.invalid_count.to_string())
  if stats.invalid_count > 0 {
    diagnostics.warnings.push(
      "srt recovered " +
      stats.invalid_count.to_string() +
      " malformed cue block(s)",
    )
    diagnostics.degraded_features.push("srt_malformed_cue_recovered")
  }
  @fshared.apply_product_metrics(diagnostics, "srt")
  diagnostics.pass_trace.push("parse:srt_parser")
  @parser.parse_result_with_events_capability(
    "srt_parser",
    StreamingEvent,
    events,
    diagnostics,
    subtitle_parser_capability(),
  )
}

///|
fn append_large_srt_block(
  events : Array[@core.CoreEvent],
  source : @input.InputSource,
  block : Array[String],
  line_start : Int,
  stats : LargeSrtStats,
) -> Unit {
  let first = block[0].trim().to_owned()
  let (identifier, time_index) = if first.contains(" --> ") {
    (None, 0)
  } else {
    (Some(first), 1)
  }
  if time_index >= block.length() || !block[time_index].contains(" --> ") {
    let raw_ref = subtitle_source_ref(
      source,
      "srt",
      stats.cue_count,
      line_start,
      line_start + block.length() - 1,
      None,
      None,
    )
    events.push({
      kind: StartBlock(Raw),
      text: block.join("\n"),
      source_ref: Some(raw_ref),
    })
    stats.invalid_count += 1
    stats.cue_count += 1
    return
  }
  let (time_range, settings, time_start, time_end) = large_srt_time_range(
    block[time_index].trim().to_owned(),
  )
  let record = StringBuilder::new()
  let raw_body = StringBuilder::new()
  let mut inline_changed = false
  record.write_string(time_range)
  let body_lines = block.length() - time_index - 1
  for index in (time_index + 1)..<block.length() {
    record.write_char('\n')
    if index > time_index + 1 {
      raw_body.write_char('\n')
    }
    raw_body.write_string(block[index])
    let lowered = @fshared.lower_subtitle_inline_markup(block[index])
    record.write_string(lowered.0)
    inline_changed = inline_changed || lowered.1
    stats.char_count += block[index].length()
  }
  if body_lines > 1 {
    stats.multiline_count += 1
  }
  if body_lines > stats.max_lines_per_cue {
    stats.max_lines_per_cue = body_lines
  }
  let cue_ref = subtitle_source_ref(
    source,
    "srt",
    stats.cue_count,
    line_start,
    line_start + block.length() - 1,
    time_start,
    time_end,
  )
  match identifier {
    Some(value) => cue_ref.extra.set("subtitle_identifier", value)
    None => ()
  }
  match settings {
    Some(value) => cue_ref.extra.set("subtitle_cue_settings", value)
    None => ()
  }
  if inline_changed {
    cue_ref.extra.set("subtitle_inline_markup", "true")
    cue_ref.extra.set("subtitle_inline_source", raw_body.to_string())
  }
  events.push({
    kind: StartBlock(BlockQuote),
    text: record.to_string(),
    source_ref: Some(cue_ref),
  })
  stats.cue_count += 1
}

///|
fn large_srt_normalized_text(text : String) -> String {
  let without_bom = if text.has_prefix("\u{FEFF}") {
    text[1:].to_owned()
  } else {
    text
  }
  if without_bom.contains("\r") {
    without_bom
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  } else {
    without_bom
  }
}

///|
fn large_srt_time_range(
  time_line : String,
) -> (String, String?, String?, String?) {
  let marker = " --> "
  let marker_index = match time_line.find(marker) {
    Some(value) => value
    None => return (time_line, None, None, None)
  }
  let start = time_line[:marker_index].trim().to_owned()
  let right = time_line[marker_index + marker.length():].trim().to_owned()
  let (end, settings) = match right.find(" ") {
    Some(space) =>
      (
        right[:space].trim().to_owned(),
        Some(right[space + 1:].trim().to_owned()),
      )
    None => (right, None)
  }
  (start + " --> " + end, settings, Some(start), Some(end))
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
      let block_ref = subtitle_generic_block_ref(base_ref, Raw, [
        ("raw_kind", "subtitle_" + kind),
        ("info", format_name),
        ("literal", "true"),
      ])
      events.push({
        kind: StartBlock(Raw),
        text: cue.note_payload.unwrap_or(""),
        source_ref: Some(block_ref),
      })
      events.push({ kind: EndBlock(Raw), text: "", source_ref: Some(block_ref) })
      continue
    }
    let quote_ref = subtitle_generic_block_ref(base_ref, BlockQuote, [
      ("literal", "true"),
      ("cue_index", (cue.index + 1).to_string()),
      ("time_range", cue.time_range),
    ])
    if cue.identifier is Some(identifier) {
      quote_ref.extra.set("subtitle_identifier", identifier)
    }
    if cue.cue_settings is Some(settings) {
      quote_ref.extra.set("subtitle_cue_settings", settings)
    }
    let heading_ref = subtitle_generic_block_ref(base_ref, Heading, [
      ("level", "6"),
      ("literal", "true"),
    ])
    events.push({
      kind: StartBlock(BlockQuote),
      text: "",
      source_ref: Some(quote_ref),
    })
    events.push({
      kind: StartBlock(Heading),
      text: cue.time_range,
      source_ref: Some(heading_ref),
    })
    events.push({
      kind: EndBlock(Heading),
      text: "",
      source_ref: Some(heading_ref),
    })
    let paragraph_ref = subtitle_generic_block_ref(base_ref, Paragraph, [
      ("literal", "true"),
    ])
    let raw_text = cue.text_lines.join("\n")
    let lowered_text = @fshared.lower_subtitle_inline_markup(raw_text)
    if lowered_text.1 {
      paragraph_ref.extra.set("subtitle_inline_markup", "true")
      paragraph_ref.extra.set("subtitle_inline_source", raw_text)
    }
    events.push({
      kind: StartBlock(Paragraph),
      text: lowered_text.0,
      source_ref: Some(paragraph_ref),
    })
    events.push({
      kind: EndBlock(Paragraph),
      text: "",
      source_ref: Some(paragraph_ref),
    })
    events.push({
      kind: EndBlock(BlockQuote),
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
  next.extra.set("ir_event_family", "subtitle")
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
      StartBlock(_) => count += 1
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
  format_name : String,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some(format_name),
    Some(1),
    Some(count_subtitle_lines(text)),
  )
  let raw_ref = subtitle_generic_block_ref(source_ref, Raw, [
    ("raw_kind", format_name + "_fail_closed"),
    ("info", format_name),
    ("literal", "true"),
  ])
  let event : @core.CoreEvent = {
    kind: StartBlock(Raw),
    text,
    source_ref: Some(raw_ref),
  }
  diagnostics.warnings.push(format_name + " parse warning: " + err)
  diagnostics.degraded_features.push(format_name + "_raw_fenced_fallback")
  diagnostics.fallback_trace.push(
    format_name + " parse failed -> raw event-stream fallback",
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
  diagnostics.pass_trace.push("parse:" + format_name + "_parser")
  @parser.parse_result_with_events_capability(
    format_name + "_parser",
    StreamingEvent,
    [event],
    diagnostics,
    subtitle_parser_capability(),
  )
}
