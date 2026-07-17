///|
test "VTT event lowering preserves headers directives settings and malformed cues" {
  let source = @input.input_from_text_with_format(
    "\u{FEFF}WEBVTT Demo\r\n\r\nNOTE editor note\r\nkeep this\r\n\r\nSTYLE\r\n::cue { color: lime }\r\n\r\nREGION\r\nid:bottom\r\n\r\ncue-a\r\n00:00:01.000 --> 00:00:03.500 line:90% align:start\r\n<v Speaker>Hello &amp; welcome</v>\r\nsecond line\r\n\r\nbroken\r\nnot a timestamp\r\nrecover me\r\n",
    "features.vtt",
    Some(Vtt),
  )
  let result = parse_vtt_result(source, @parser.new_parse_context(Vtt)).unwrap()
  let events = result.event_stream.unwrap()
  assert_true(events.length() >= 8)
  assert_true(
    events.any(event => event.text.contains("Speaker: Hello & welcome")),
  )
  assert_true(events.any(event => event.text.contains("keep this")))
  assert_true(events.any(event => event.text.contains("color: lime")))
  assert_true(events.any(event => event.text.contains("id:bottom")))
  assert_true(events.any(event => event.text.contains("recover me")))
  let refs = events.filter_map(event => event.source_ref)
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_inline_markup") == Some("true")
    }),
  )
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_identifier") == Some("cue-a")
    }),
  )
  assert_true(
    refs.any(source_ref => {
      source_ref.extra.get("subtitle_cue_settings") ==
      Some("line:90% align:start")
    }),
  )
  assert_true(
    result.diagnostics.metrics.get("recovered_cue_count") == Some("1"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("vtt_malformed_cue_recovered"),
  )
}

///|
test "VTT fail-closed result retains original text and complete diagnostics" {
  let source = @input.input_from_text_with_format(
    "not a webvtt document\nsecond line",
    "broken.vtt",
    Some(Vtt),
  )
  let diagnostics = @fshared.empty_parser_diagnostics(
    "vtt_parser",
    StreamingEvent,
    source,
    "vtt",
  )
  let result = subtitle_malformed_parse_result(
    source,
    @input.input_text(source).unwrap(),
    diagnostics,
    "missing WEBVTT header",
  )
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 1)
  assert_eq(events[0].text, "not a webvtt document\nsecond line")
  assert_true(
    result.diagnostics.degraded_features.contains("vtt_raw_fenced_fallback"),
  )
  assert_true(result.diagnostics.metrics.get("line_count") == Some("2"))
  assert_true(result.diagnostics.metrics.get("syntax_error_count") == Some("1"))
  assert_eq(count_subtitle_lines(""), 0)
  assert_eq(count_subtitle_lines("a\nb\n"), 3)
  assert_eq(count_subtitle_event_blocks(events), 1)
}

///|
test "VTT large streaming path preserves cue metadata directives and recovery" {
  let source = @input.input_from_text_with_format(
    "WEBVTT\n\nSTYLE\n::cue { color: lime }\n\ncue-a\n00:00:01.000 --> 00:00:03.000 align:start\n<v Ada><b>Hello</b></v>\n\nWEBVTT duplicate\n\nbroken\nraw",
    "large.vtt",
    Some(Vtt),
  )
  let result = parse_large_vtt_result(
    source,
    @input.input_text(source).unwrap(),
    @parser.new_parse_context(Vtt),
  )
  assert_true(
    result.diagnostics.metrics.get("large_streaming_path") == Some("true"),
  )
  assert_true(
    result.diagnostics.metrics.get("recovered_cue_count") == Some("1"),
  )
  let events = result.event_stream.unwrap()
  assert_true(events.any(event => event.text.contains("Ada: **Hello**")))
  assert_true(events.any(event => event.text.contains("color: lime")))
  assert_true(events.any(event => event.text.contains("raw")))
  assert_true(!events.any(event => event.text.contains("WEBVTT duplicate")))
}

///|
test "VTT pull stream covers directives malformed cues and truncation" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Vtt),
    None,
    None,
    None,
    None,
    Some(12),
    false,
  )
  let stream = open_vtt_event_stream(
      @input.input_from_text_with_format(
        "WEBVTT\n\nNOTE note\nbody\n\nSTYLE\n::cue { color: lime }\n\nREGION\nid:bottom\n\nbroken\nnot a timestamp\nraw payload that truncates",
        "pull.vtt",
        Some(Vtt),
      ),
      context,
    )
    .unwrap()
    .unwrap()
  let events : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => events.push(event)
      None => break
    }
  }
  let summary = (stream.finish)().unwrap()
  assert_true(events.any(event => event.kind == StartBlock(Raw)))
  assert_true(summary.diagnostics.metrics.get("note_count") == Some("3"))
  assert_true(summary.diagnostics.metrics.get("style_count") == Some("1"))
  assert_true(summary.diagnostics.metrics.get("region_count") == Some("1"))
  assert_true(
    summary.diagnostics.degraded_features.contains(
      "vtt_malformed_cue_recovered",
    ),
  )
  assert_true(
    summary.diagnostics.degraded_features.contains("vtt_record_truncation"),
  )
}
