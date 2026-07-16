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
  assert_eq(streamed.assets.length(), buffered.assets.length())
  assert_eq(
    streamed.diagnostics.warnings.length(),
    buffered.diagnostics.warnings.length(),
  )
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
