///|
async test "Latin1 XML prepared UTF8 preserves an exact physical input byte ceiling" {
  // The single Latin1 E9 byte expands to two UTF8 bytes after the XML probe.
  // Balanced DOM consumption must reuse that decoded value without charging
  // the expanded representation against the physical input byte limit.
  let raw = b"<?xml version=\"1.0\" encoding=\"iso-8859-1\"?><r>\xE9</r>"
  let options = @lib.ConvertOptions::default().with_format_hint(Some("xml"))
  let expected = @lib.convert(
    @lib.Input::from_bytes(raw, source_name="latin1.xml"),
    options~,
  ).unwrap()
  assert_true(expected.content.contains("é"))
  assert_false(expected.content.contains("Ã©"))
  let limits = @lib.ResourceLimits::default().with_max_input_bytes(
    raw.length().to_int64(),
  )
  let options = options.with_limits(limits)
  let actual = @lib.convert(
    @lib.Input::from_bytes(raw, source_name="latin1.xml"),
    options~,
  ).unwrap()
  assert_eq(actual.content, expected.content)
  let fragments : Array[String] = []
  let finishes = Ref(0)
  let summary = @lib.convert_to_sink(
    @lib.Input::from_bytes(raw, source_name="latin1.xml"),
    @lib.OutputSink::new(
      fn(fragment) {
        fragments.push(fragment)
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  ).unwrap()
  assert_eq(summary.detected_format, "xml")
  assert_eq(fragments.join(""), expected.content)
  assert_eq(finishes.val, 1)
}

///|
async test "decoded XML does not relax a smaller physical byte limit" {
  let raw = b"<?xml version=\"1.0\" encoding=\"iso-8859-1\"?><r>\xE9</r>"
  let limit = raw.length().to_int64() - 1L
  let options = @lib.ConvertOptions::default()
    .with_format_hint(Some("xml"))
    .with_limits(@lib.ResourceLimits::default().with_max_input_bytes(limit))
  let result = @lib.convert(
    @lib.Input::from_bytes(raw, source_name="latin1.xml"),
    options~,
  )
  match result {
    Err(@lib.ConvertError::ResourceLimitExceeded(kind~, observed~, limit~)) => {
      assert_eq(kind, "input_bytes")
      assert_eq(observed, raw.length().to_int64())
      assert_eq(limit, raw.length().to_int64() - 1L)
    }
    Err(_) => fail("known physical size must report an input byte limit error")
    Ok(_) => fail("decoded payload must not bypass the original byte ceiling")
  }
  // An unknown-size source must enforce the same ceiling while reading,
  // before a decoder can create any prepared-payload proof.
  let writes = Ref(0)
  let finishes = Ref(0)
  let result = @lib.convert_to_sink(
    @lib.Input::from_async_reader(
      async fn(offset, length) {
        @async.pause()
        let start = offset.to_int()
        let end = (start + length.min(3)).min(raw.length())
        Ok(raw.exact_view(start~, end~).to_owned())
      },
      source_name="latin1.xml",
    ),
    @lib.OutputSink::new(
      fn(_fragment) {
        writes.val += 1
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  )
  match result {
    Err(error) =>
      assert_true(error.message().contains("input byte limit exceeded"))
    Ok(_) => fail("unknown-size input must not manufacture a decoded exemption")
  }
  assert_eq(writes.val, 0)
  assert_eq(finishes.val, 0)
}

///|
async test "invalid UTF16 Text returns controlled conversion and sink errors" {
  let invalid_values = [
    String::from_array([(0xD800).unsafe_to_char(), 'A']),
    String::from_array(['A', (0xDC00).unsafe_to_char()]),
    String::from_array([(0xD800).unsafe_to_char()]),
  ]
  let options = @lib.ConvertOptions::default().with_format_hint(Some("txt"))
  for invalid in invalid_values {
    match @lib.convert(@lib.Input::from_text(invalid), options~) {
      Err(error) =>
        assert_true(error.message().contains("invalid UTF16 surrogate"))
      Ok(_) => fail("invalid UTF16 input must not abort or replace characters")
    }
    let writes = Ref(0)
    let finishes = Ref(0)
    let result = @lib.convert_to_sink(
      @lib.Input::from_text(invalid),
      @lib.OutputSink::new(
        fn(_fragment) {
          writes.val += 1
          Ok(())
        },
        fn() {
          finishes.val += 1
          Ok(())
        },
      ),
      options~,
    )
    match result {
      Err(error) =>
        assert_true(error.message().contains("invalid UTF16 surrogate"))
      Ok(_) => fail("invalid UTF16 input must stop before sink delivery")
    }
    assert_eq(writes.val, 0)
    assert_eq(finishes.val, 0)
  }
}

///|
async test "explicit input ceilings propagate through nested reader helpers" {
  // No large allocation: the declared extent crosses the default ceiling,
  // then the reader deliberately fails its first actual request.
  let size = 512L * 1024L * 1024L + 1L
  let calls = Ref(0)
  let input = @lib.Input::from_reader(
    fn(_, _) {
      calls.val += 1
      Err("reached the explicitly permitted reader")
    },
    size~,
    source_name="large.txt",
  )
  let defaults = @lib.ConvertOptions::default().with_format_hint(Some("txt"))
  assert_true(
    @lib.convert(input, options=defaults) is Err(ResourceLimitExceeded(_)),
  )
  assert_eq(calls.val, 0)
  let options = defaults.with_limits(
    @lib.ResourceLimits::default().with_max_input_bytes(1024L * 1024L * 1024L),
  )
  match @lib.convert(input, options~) {
    Err(error) =>
      assert_true(
        error.message().contains("reached the explicitly permitted reader"),
      )
    Ok(_) => fail("the deliberate callback error must remain a hard failure")
  }
  assert_eq(calls.val, 1)
}
