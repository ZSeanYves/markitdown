///|
async test "TXT UTF16 line ceiling never splits a non-BMP scalar or resumes after truncation" {
  let bytes = b"a\xf0\x9f\x98\x80z"
  let inputs = [
    @lib.Input::from_text("a😀z", source_name="scalar.txt"),
    @lib.Input::from_bytes(bytes, source_name="scalar.txt"),
    @lib.Input::from_reader(
      fn(offset, _length) {
        if offset >= bytes.length().to_int64() {
          Ok(b"")
        } else {
          let start = offset.to_int()
          Ok(bytes[start:start + 1].to_owned())
        }
      },
      size=bytes.length().to_int64(),
      source_name="scalar.txt",
    ),
  ]
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_line_chars(2),
  )
  for input in inputs {
    let result = match @lib.convert(input, options~) {
      Ok(value) => value
      Err(error) =>
        fail("collect rejected valid boundary input: " + error.to_string())
    }
    assert_eq(result.content, "a \\[truncated\\]")
    let fragments : Array[String] = []
    let streamed = @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        fn(part) {
          fragments.push(part)
          Ok(())
        },
        fn() { Ok(()) },
      ),
      options~,
    )
    match streamed {
      Ok(_) => ()
      Err(error) =>
        fail("Sink rejected valid boundary input: " + error.to_string())
    }
    assert_eq(fragments.join(""), result.content)
  }
}

///|
async test "TXT exact UTF16 ceiling retains the complete final non-BMP scalar" {
  let input = @lib.Input::from_text("a😀", source_name="scalar.txt")
  for mode in [@lib.ConvertMode::Balanced, Stream] {
    let options = @lib.ConvertOptions::default()
      .with_mode(mode)
      .with_limits(@lib.ResourceLimits::default().with_max_line_chars(3))
    let collected = match @lib.convert(input, options~) {
      Ok(value) => value
      Err(error) => fail("exact scalar boundary rejected: " + error.to_string())
    }
    let fragments : Array[String] = []
    let result = @lib.convert_to_sink(
      input,
      @lib.OutputSink::new(
        fn(part) {
          fragments.push(part)
          Ok(())
        },
        fn() { Ok(()) },
      ),
      options~,
    )
    assert_true(result is Ok(_))
    assert_eq(fragments.join(""), collected.content)
    // The Markdown renderer's established non-BMP representation is a
    // complete numeric character reference, including in Stream mode.
    assert_eq(collected.content, "a&#128512;")
  }
}
