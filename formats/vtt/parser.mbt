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
  let text_payload = match @sourceio.read_source_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  if text_payload.text.length() >= 1_048_576 {
    return Ok(
      parse_large_vtt_result(
        text_payload.prepared_source,
        text_payload.text,
        context,
      ),
    )
  }
  let prepared = match
    @dsub.prepare_vtt_document_from_source(text_payload.prepared_source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
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
          "vtt recovered " +
          invalid_cue_count.to_string() +
          " malformed cue block(s)",
        )
        diagnostics.degraded_features.push("vtt_malformed_cue_recovered")
      }
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
    None =>
      Ok(
        subtitle_malformed_parse_result(
          source,
          text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
        ),
      )
  }
}

///|
priv struct LargeVttStats {
  mut cue_count : Int
  mut invalid_count : Int
  mut note_count : Int
  mut style_count : Int
  mut region_count : Int
  mut multiline_count : Int
  mut char_count : Int
  mut max_lines_per_cue : Int
  mut line_count : Int
}

///|
fn parse_large_vtt_result(
  source : @input.InputSource,
  original_text : String,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  let text = large_vtt_normalized_text(original_text)
  let events : Array[@core.CoreEvent] = []
  let stats : LargeVttStats = {
    cue_count: 0,
    invalid_count: 0,
    note_count: 0,
    style_count: 0,
    region_count: 0,
    multiline_count: 0,
    char_count: 0,
    max_lines_per_cue: 0,
    line_count: 0,
  }
  let block : Array[String] = []
  let mut block_start = 1
  for line_view in text.split("\n") {
    stats.line_count += 1
    let line = line_view.to_owned()
    if stats.line_count == 1 && line.trim().has_prefix("WEBVTT") {
      block_start = 2
      continue
    }
    if line.trim() == "" {
      if block.length() > 0 {
        append_large_vtt_block(events, source, block, block_start, stats)
        block.clear()
      }
      block_start = stats.line_count + 1
    } else {
      block.push(line)
    }
  }
  if block.length() > 0 {
    append_large_vtt_block(events, source, block, block_start, stats)
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
  if stats.invalid_count > 0 {
    diagnostics.warnings.push(
      "vtt recovered " +
      stats.invalid_count.to_string() +
      " malformed cue block(s)",
    )
    diagnostics.degraded_features.push("vtt_malformed_cue_recovered")
  }
  diagnostics.metrics.set("cue_count", stats.cue_count.to_string())
  diagnostics.metrics.set("note_count", stats.note_count.to_string())
  diagnostics.metrics.set("style_count", stats.style_count.to_string())
  diagnostics.metrics.set("region_count", stats.region_count.to_string())
  diagnostics.metrics.set(
    "multiline_cue_count",
    stats.multiline_count.to_string(),
  )
  diagnostics.metrics.set("blank_line_count", "0")
  diagnostics.metrics.set("line_count", stats.line_count.to_string())
  diagnostics.metrics.set("char_count", stats.char_count.to_string())
  diagnostics.metrics.set(
    "max_lines_per_cue",
    stats.max_lines_per_cue.to_string(),
  )
  diagnostics.metrics.set("block_count", events.length().to_string())
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "recovered_cue_count",
    stats.invalid_count.to_string(),
  )
  diagnostics.metrics.set("event_count", events.length().to_string())
  diagnostics.metrics.set("large_streaming_path", "true")
  diagnostics.pass_trace.push("parse:vtt_parser:large_streaming")
  diagnostics.pass_trace.push("parse:vtt_parser")
  @parser.parse_result_with_events_capability(
    "vtt_parser",
    @parser.ParserMode::StreamingEvent,
    events,
    diagnostics,
    subtitle_parser_capability(),
  )
}

///|
fn append_large_vtt_block(
  events : Array[@core.CoreEvent],
  source : @input.InputSource,
  block : Array[String],
  line_start : Int,
  stats : LargeVttStats,
) -> Unit {
  let first = block[0].trim().to_owned()
  if first.has_prefix("WEBVTT") {
    return
  }
  if first == "STYLE" ||
    first == "REGION" ||
    first == "NOTE" ||
    first.has_prefix("NOTE ") {
    let kind = if first == "STYLE" {
      "style"
    } else if first == "REGION" {
      "region"
    } else {
      "note"
    }
    if kind == "style" {
      stats.style_count += 1
    }
    if kind == "region" {
      stats.region_count += 1
    }
    stats.note_count += 1
    let payload = if block.length() > 1 { block[1:].join("\n") } else { "" }
    let source_ref = subtitle_source_ref(
      source,
      "vtt",
      stats.cue_count,
      line_start,
      line_start + block.length() - 1,
      None,
      None,
    )
    let raw_ref = subtitle_generic_block_ref(source_ref, @core.BlockKind::Raw, [
      ("raw_kind", "subtitle_" + kind),
      ("info", "vtt"),
      ("literal", "true"),
    ])
    append_large_vtt_generic_block(
      events,
      @core.BlockKind::Raw,
      payload,
      raw_ref,
    )
    stats.cue_count += 1
    return
  }
  let mut time_index = 0
  let mut identifier : String? = None
  if !first.contains(" --> ") {
    if block.length() < 2 || !block[1].contains(" --> ") {
      append_large_vtt_invalid(events, source, block, line_start, stats)
      return
    }
    identifier = Some(first)
    time_index = 1
  }
  let time_line = block[time_index].trim().to_owned()
  let marker_index = match time_line.find(" --> ") {
    Some(value) => value
    None => {
      append_large_vtt_invalid(events, source, block, line_start, stats)
      return
    }
  }
  let start = time_line[:marker_index].trim().to_owned()
  let right = time_line[marker_index + " --> ".length():].trim().to_owned()
  let (finish, settings) = match right.find(" ") {
    Some(space) =>
      (right[:space].to_owned(), Some(right[space + 1:].trim().to_owned()))
    None => (right, None)
  }
  let raw_body = block[time_index + 1:].join("\n")
  let lowered = @fshared.lower_subtitle_inline_markup(raw_body)
  let body_lines = block.length() - time_index - 1
  if body_lines > 1 {
    stats.multiline_count += 1
  }
  if body_lines > stats.max_lines_per_cue {
    stats.max_lines_per_cue = body_lines
  }
  stats.char_count += raw_body.length()
  let cue_ref = subtitle_source_ref(
    source,
    "vtt",
    stats.cue_count,
    line_start,
    line_start + block.length() - 1,
    Some(start),
    Some(finish),
  )
  match identifier {
    Some(value) => cue_ref.extra.set("subtitle_identifier", value)
    None => ()
  }
  match settings {
    Some(value) => cue_ref.extra.set("subtitle_cue_settings", value)
    None => ()
  }
  if lowered.1 {
    cue_ref.extra.set("subtitle_inline_markup", "true")
    cue_ref.extra.set("subtitle_inline_source", raw_body)
  }
  cue_ref.extra.set("subtitle_event_layout", "record_v2")
  events.push({
    kind: @core.EventKind::StartBlock(@core.BlockKind::BlockQuote),
    text: start +
    " --> " +
    finish +
    (if lowered.0 == "" { "" } else { "\n" + lowered.0 }),
    source_ref: Some(cue_ref),
  })
  stats.cue_count += 1
}

///|
fn append_large_vtt_invalid(
  events : Array[@core.CoreEvent],
  source : @input.InputSource,
  block : Array[String],
  line_start : Int,
  stats : LargeVttStats,
) -> Unit {
  let source_ref = subtitle_source_ref(
    source,
    "vtt",
    stats.cue_count,
    line_start,
    line_start + block.length() - 1,
    None,
    None,
  )
  let raw_ref = subtitle_generic_block_ref(source_ref, @core.BlockKind::Raw, [
    ("raw_kind", "subtitle_invalid"),
    ("info", "vtt"),
    ("literal", "true"),
  ])
  append_large_vtt_generic_block(
    events,
    @core.BlockKind::Raw,
    block.join("\n"),
    raw_ref,
  )
  stats.invalid_count += 1
  stats.cue_count += 1
}

///|
fn append_large_vtt_generic_block(
  events : Array[@core.CoreEvent],
  kind : @core.BlockKind,
  text : String,
  source_ref : @core.SourceRef,
) -> Unit {
  events.push({
    kind: @core.EventKind::StartBlock(kind),
    text,
    source_ref: Some(source_ref),
  })
  events.push({
    kind: @core.EventKind::EndBlock(kind),
    text: "",
    source_ref: Some(source_ref),
  })
}

///|
fn large_vtt_normalized_text(text : String) -> String {
  let without_bom = if text.has_prefix("\u{FEFF}") {
    text[1:].to_owned()
  } else {
    text
  }
  if !without_bom.contains("\r") {
    return without_bom
  }
  without_bom.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
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
    let raw_text = cue.text_lines.join("\n")
    let lowered_text = @fshared.lower_subtitle_inline_markup(raw_text)
    if lowered_text.1 {
      paragraph_ref.extra.set("subtitle_inline_markup", "true")
      paragraph_ref.extra.set("subtitle_inline_source", raw_text)
    }
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      text: lowered_text.0,
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
