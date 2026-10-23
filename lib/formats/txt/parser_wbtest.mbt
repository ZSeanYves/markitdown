///|
async test "TXT parser emits line events metrics and blank lines" {
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
async test "TXT parser truncates long lines under explicit resource limits" {
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
async test "TXT parser rejects invalid UTF8 without emitting placeholder events" {
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([0xC3, 0x28].map(Int32::to_byte)),
    "invalid.txt",
    Some(Txt),
  )
  match (txt_parser().parse)(source, @parser.new_parse_context(Txt)) {
    Err(message) => assert_eq(message, "utf8 decode failed")
    Ok(_) =>
      fail("invalid encoding must be rejected, not rendered as a placeholder")
  }
}

///|
async test "TXT parser preserves a legal UTF16 surrogate pair and UTF8 text" {
  for bytes in [b"\xff\xfe\x3d\xd8\x00\xdeA\x00", @utf8.encode("😀A")] {
    let source = @input.input_from_bytes_with_format(
      bytes,
      "valid-unicode.txt",
      Some(Txt),
    )
    let result = (txt_parser().parse)(source, @parser.new_parse_context(Txt)).unwrap()
    assert_eq(result.event_stream.unwrap()[0].text, "😀A")
  }
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

///|
async test "TXT pull stream preserves reader chunk boundaries and CRLF" {
  let bytes = @utf8.encode("alpha\r\nemoji 😀\r\n\r\nomega")
  let largest_read = Ref(0)
  let reader = @input.make_input_reader(
    fn(offset, requested) {
      largest_read.val = largest_read.val.max(requested)
      let start = offset.to_int()
      if start >= bytes.length() {
        return Ok(Bytes::new(0))
      }
      let end = (start + requested.min(3)).min(bytes.length())
      Ok(bytes.exact_view(start~, end~).to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let stream = open_txt_event_stream(
      @input.input_from_reader_with_format(reader, "chunked.txt", Some(Txt)),
      @parser.new_parse_context(Txt),
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
  assert_eq(events.length(), 4)
  assert_eq(events[0].text, "alpha")
  assert_eq(events[1].text, "emoji 😀")
  assert_true(events[2].kind == BlankLine)
  assert_eq(events[3].text, "omega")
  assert_eq(summary.diagnostics.metrics.get("newline_style"), Some("crlf"))
  assert_eq(summary.diagnostics.metrics.get("stream_event_count"), Some("4"))
  assert_true(largest_read.val <= 64 * 1024)
}

///|
async test "TXT parser propagates a missing source as a hard input error" {
  let result = (txt_parser().parse)(
    @input.input_from_path("/definitely/missing/txt-parser.txt"),
    @parser.new_parse_context(Txt),
  )
  // The upgrade plan permits decoding/syntax recovery, but a failed open
  // must not become an invalid-UTF8 placeholder or successful empty events.
  match result {
    Err(message) => assert_true(message.contains("open input path failed"))
    Ok(_) => fail("missing source must fail before producing parser events")
  }
}

///|
async test "TXT pull stream covers UTF16 fallback BOM bare CR and reader errors" {
  let utf16 = @input.input_from_bytes_with_format(
    Bytes::from_array([0xFF, 0xFE, 0x41, 0x00].map(Int32::to_byte)),
    "utf16.txt",
    Some(Txt),
  )
  assert_true(
    open_txt_event_stream(utf16, @parser.new_parse_context(Txt)).unwrap()
    is None,
  )
  assert_true(
    open_txt_event_stream(
      @input.input_from_path("/definitely/missing/pull.txt"),
      @parser.new_parse_context(Txt),
    )
    is Err(_),
  )

  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Txt),
    None,
    None,
    None,
    None,
    Some(5),
    false,
  )
  let stream = open_txt_event_stream(
      @input.input_from_text_with_format(
        "\u{FEFF}abcdﬃ\rnext\rlast\r",
        "bare-cr.txt",
        Some(Txt),
      ),
      context,
    )
    .unwrap()
    .unwrap()
  let values : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => values.push(event)
      None => break
    }
  }
  let summary = (stream.finish)().unwrap()
  assert_eq(values.length(), 3)
  assert_eq(values[0].text, "abcdf [truncated]")
  assert_eq(summary.diagnostics.metrics.get("newline_style"), Some("cr"))

  let calls = Ref(0)
  let failing_reader = @input.make_input_reader(
    fn(_offset, _length) {
      calls.val += 1
      if calls.val == 1 {
        Ok(@utf8.encode("a"))
      } else {
        Err("reader stopped")
      }
    },
    size=1L,
  )
  let failing_stream = open_txt_event_stream(
      @input.input_from_reader_with_format(
        failing_reader,
        "failing.txt",
        Some(Txt),
      ),
      @parser.new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  match (failing_stream.next)() {
    Err(message) => assert_eq(message, "reader stopped")
    Ok(_) => fail("reader failure should stop the pull stream")
  }
}
