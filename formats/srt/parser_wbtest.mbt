///|
test "large SRT record lowering preserves cue metadata and recovery" {
  let source = @input.input_from_text_with_format(
    "cue-a\n00:00:00,000 --> 00:00:02,000 align:start\nHello\nSecond\n\nbad\nnot a time\nraw\n",
    "large.srt",
    Some(@input.DetectedFormat::Srt),
  )
  let result = parse_large_srt_result(
    source,
    @input.input_text(source).unwrap(),
    @parser.new_parse_context(@input.DetectedFormat::Srt),
  )
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 2)
  assert_eq(events[0].text, "00:00:00,000 --> 00:00:02,000\nHello\nSecond")
  let cue_ref = events[0].source_ref.unwrap()
  assert_true(cue_ref.extra.get("subtitle_identifier") == Some("cue-a"))
  assert_true(cue_ref.extra.get("subtitle_cue_settings") == Some("align:start"))
  assert_true(cue_ref.time_start == Some("00:00:00,000"))
  assert_true(cue_ref.time_end == Some("00:00:02,000"))
  assert_true(
    events[1].kind == @core.EventKind::StartBlock(@core.BlockKind::Raw),
  )
  assert_true(
    result.diagnostics.metrics.get("recovered_cue_count") != Some("0"),
  )
}

///|
test "standard SRT event lowering preserves BOM CRLF identifiers settings and bad cues" {
  let source = @input.input_from_text_with_format(
    "\u{FEFF}cue-a\r\n00:00:00,000 --> 00:00:02,000 align:start\r\n<b>Hello</b>\r\n<i>Second</i>\r\n\r\nbad\r\nnot a time\r\nraw text\r\n",
    "features.srt",
    Some(@input.DetectedFormat::Srt),
  )
  let result = parse_subtitle_result(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Srt),
    "srt",
  ).unwrap()
  let events = result.event_stream.unwrap()
  assert_true(events.length() >= 7)
  assert_true(events.any(event => event.text.contains("**Hello**")))
  assert_true(events.any(event => event.text.contains("*Second*")))
  assert_true(events.any(event => event.text.contains("raw text")))
  let refs = events.filter_map(event => event.source_ref)
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_identifier") == Some("cue-a")
    }),
  )
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_inline_markup") == Some("true")
    }),
  )
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_cue_settings") == Some("align:start")
    }),
  )
  assert_true(
    result.diagnostics.metrics.get("recovered_cue_count") != Some("0"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("srt_malformed_cue_recovered"),
  )
}

///|
test "SRT raw fallback and large scanner edge branches retain source bytes" {
  let source = @input.input_from_text_with_format(
    "raw\nsubtitle",
    "broken.srt",
    Some(@input.DetectedFormat::Srt),
  )
  let diagnostics = @fshared.empty_parser_diagnostics(
    "srt_parser",
    @parser.ParserMode::StreamingEvent,
    source,
    "srt",
  )
  let fallback = subtitle_malformed_parse_result(
    source,
    @input.input_text(source).unwrap(),
    diagnostics,
    "invalid timestamps",
    "srt",
  )
  assert_eq(fallback.event_stream.unwrap()[0].text, "raw\nsubtitle")
  assert_true(
    fallback.diagnostics.degraded_features.contains("srt_raw_fenced_fallback"),
  )
  assert_true(
    fallback.diagnostics.metrics.get("syntax_error_count") == Some("1"),
  )

  let normalized = large_srt_normalized_text(
    "\u{FEFF}00:00:00,000 --> 00:00:01,000\r\nbody",
  )
  assert_true(!normalized.has_prefix("\u{FEFF}"))
  assert_true(!normalized.contains("\r"))
  let (range, settings, start, finish) = large_srt_time_range(
    "00:00:00,000 --> 00:00:01,000",
  )
  assert_eq(range, "00:00:00,000 --> 00:00:01,000")
  assert_true(settings is None)
  assert_true(start == Some("00:00:00,000"))
  assert_true(finish == Some("00:00:01,000"))
  assert_true(large_srt_time_range("invalid").2 is None)
  assert_eq(count_subtitle_lines(""), 0)

  let stats : LargeSrtStats = {
    cue_count: 0,
    invalid_count: 0,
    multiline_count: 0,
    char_count: 0,
    max_lines_per_cue: 0,
    line_count: 0,
  }
  let events : Array[@core.CoreEvent] = []
  append_large_srt_block(
    events,
    source,
    ["00:00:00,000 --> 00:00:01,000", "body"],
    1,
    stats,
  )
  assert_eq(events.length(), 1)
  assert_eq(stats.cue_count, 1)
  assert_true(
    events[0].source_ref.unwrap().extra.get("subtitle_identifier") is None,
  )
}
