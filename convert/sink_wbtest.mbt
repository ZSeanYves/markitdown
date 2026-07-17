///|
test "sink output is equivalent to buffered conversion" {
  let source = @input.input_from_text("# Sink\n\nbody")
  let options = default_convert_options()
  let buffered = match convert_input(source, options) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  let chunks : Array[String] = []
  let sink = make_output_sink(
    fn(chunk) {
      chunks.push(chunk)
      Ok(())
    },
    fn() { Ok(()) },
  )
  let streamed = match convert_input_to_sink(source, options, sink) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_eq(chunks.join(""), buffered.content)
  assert_eq(streamed.content, buffered.content)
  assert_eq(
    streamed.diagnostics.metrics.get("sink_mode"),
    Some("parser_to_renderer_event_stream"),
  )
  assert_eq(streamed.assets.length(), buffered.assets.length())
  assert_eq(
    streamed.diagnostics.warnings.length(),
    buffered.diagnostics.warnings.length(),
  )
}

///|
test "sink pull stream matches buffered TXT across CRLF emoji and truncation" {
  let source = @input.input_from_text_with_format(
    "alpha\r\nemoji 😀\r\n\r\n1234567890",
    "stream.txt",
    Some(Txt),
  )
  let limits = @product.make_resource_limits(2000, 50, 100000, max_line_chars=5)
  let options = { ..default_convert_options(), limits, }
  let buffered = convert_input(source, options).unwrap()
  let chunks : Array[String] = []
  let streamed = convert_input_to_sink(
    source,
    options,
    make_output_sink(
      fn(chunk) {
        chunks.push(chunk)
        Ok(())
      },
      fn() { Ok(()) },
    ),
  ).unwrap()
  assert_eq(chunks.join(""), buffered.content)
  assert_eq(streamed.content, buffered.content)
  assert_eq(
    streamed.diagnostics.metrics.get("long_line_count"),
    buffered.diagnostics.metrics.get("long_line_count"),
  )
  assert_eq(
    streamed.diagnostics.warnings.length(),
    buffered.diagnostics.warnings.length(),
  )
}

///|
test "sink uses bounded chunks for large output" {
  let source = @input.input_from_text("line\n\n".repeat(40_000))
  let chunks : Array[String] = []
  let sink = make_output_sink(
    fn(chunk) {
      chunks.push(chunk)
      Ok(())
    },
    fn() { Ok(()) },
  )
  let result = match
    convert_input_to_sink(source, default_convert_options(), sink) {
    Ok(value) => value
    Err(err) => fail(err.to_string())
  }
  assert_true(chunks.length() > 1)
  for chunk in chunks {
    assert_true(chunk.length() <= 64 * 1024)
  }
  assert_eq(chunks.join(""), result.content)
}

///|
test "sink write failure stops before finish" {
  let finished = Ref(false)
  let sink = make_output_sink(fn(_chunk) { Err("cancelled") }, fn() {
    finished.val = true
    Ok(())
  })
  let result = convert_input_to_sink(
    @input.input_from_text("body"),
    default_convert_options(),
    sink,
  )
  match result {
    Err(RenderFailed(message)) =>
      assert_true(message.contains("sink write failed"))
    Err(other) => fail(other.to_string())
    Ok(_) => fail("write failure should fail conversion")
  }
  assert_false(finished.val)
}
