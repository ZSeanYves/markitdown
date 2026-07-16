///|
test "TXT parser emits line events metrics and blank lines" {
  let text = "first\n\nthird\n"
  let source = @input.input_from_text_with_format(text, "lines.txt", Some(Txt))
  let result = (txt_parser().parse)(source, @parser.new_parse_context(Txt)).unwrap()
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 3)
  assert_true(events[0].kind == TextLine)
  assert_true(events[1].kind == BlankLine)
  assert_true(events[2].text == "third")
  assert_true(events[0].source_ref.unwrap().line_start == Some(1))
  assert_true(result.diagnostics.metrics.get("newline_style") == Some("lf"))
  assert_true(
    result.diagnostics.metrics.get("invalid_utf8_fallback") == Some("false"),
  )
  assert_eq(result.diagnostics.warnings.length(), 0)
}

///|
test "TXT parser truncates long lines under explicit resource limits" {
  let source = @input.input_from_text_with_format(
    "abcdefghij\nshort",
    "long.txt",
    Some(Txt),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Txt),
    Some(StreamingEvent),
    None,
    None,
    None,
    Some(5),
    false,
  )
  let result = (txt_parser().parse)(source, context).unwrap()
  let events = result.event_stream.unwrap()
  assert_eq(events[0].text, "abcde [truncated]")
  assert_eq(events[1].text, "short")
  assert_true(result.diagnostics.metrics.get("long_line_count") == Some("1"))
  assert_true(
    result.diagnostics.degraded_features.contains("txt_long_line_truncation"),
  )
  assert_true(result.diagnostics.warnings.length() == 1)
}

///|
test "TXT parser invalid UTF8 fails closed with explicit placeholder diagnostics" {
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([0xC3, 0x28].map(Int::to_byte)),
    "invalid.txt",
    Some(Txt),
  )
  let result = (txt_parser().parse)(source, @parser.new_parse_context(Txt)).unwrap()
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 1)
  assert_eq(events[0].text, "[invalid utf8 text input]")
  assert_true(
    result.diagnostics.metrics.get("invalid_utf8_fallback") == Some("true"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("invalid_utf8_text_fallback"),
  )
  assert_true(result.diagnostics.fallback_trace.length() == 1)
}

///|
test "TXT newline and truncation helpers cover all styles and boundaries" {
  assert_eq(text_newline_style_name(None), "none")
  assert_eq(text_newline_style_name(LF), "lf")
  assert_eq(text_newline_style_name(CRLF), "crlf")
  assert_eq(text_newline_style_name(CR), "cr")
  assert_eq(text_newline_style_name(Mixed), "mixed")
  assert_eq(truncate_line("short", 5), "short")
  assert_eq(truncate_line("longer", 4), "long [truncated]")
  assert_eq(truncate_text_lines("abcdef\nxy", 3), "abc [truncated]\nxy")
  let event : @core.CoreEvent = {
    kind: TextLine,
    text: "abcdef",
    source_ref: None,
  }
  assert_eq(truncate_text_event_lines(event, 2).text, "ab [truncated]")
  let capability = txt_parser_capability()
  assert_true(capability.supports_streaming)
  assert_true(capability.produces_text)
}
