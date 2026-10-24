///|
async test "async TXT starts sink delivery before reading the whole input and obeys backpressure" {
  // Each line and the line count fit the unchanged default limits. The input
  // exceeds three source chunks, so a complete-input adapter fails this test.
  let line_width = 512
  let line_count = 512
  let text = ("x".repeat(line_width) + "\n").repeat(line_count)
  let values = Array::make((line_width + 1) * line_count, b'x')
  for row in 0..<line_count {
    values[row * (line_width + 1) + line_width] = b'\n'
  }
  let bytes = Bytes::from_array(values)
  assert_true(bytes.length() > 3 * 64 * 1024)
  let options = @lib.ConvertOptions::default().with_format_hint(Some("txt"))
  let expected = @lib.convert(
    @lib.Input::from_text(text, source_name="large.txt"),
    options~,
  ).unwrap()
  let reads = Ref(0)
  let furthest_read = Ref(0)
  let writing = Ref(false)
  let writes = Ref(0)
  let finishes = Ref(0)
  let fragments : Array[String] = []
  let input = @lib.Input::from_async_reader(
    async fn(offset, length) {
      assert_false(writing.val)
      reads.val += 1
      @async.pause()
      let start = offset.to_int()
      let end = (start + length.min(4096)).min(bytes.length())
      furthest_read.val = furthest_read.val.max(end)
      Ok(bytes.exact_view(start~, end~).to_owned())
    },
    size=bytes.length().to_int64(),
    source_name="large.txt",
  )
  let summary = @lib.convert_to_sink(
    input,
    @lib.OutputSink::new(
      async fn(fragment) {
        if writes.val == 0 {
          assert_true(furthest_read.val < bytes.length())
        }
        writing.val = true
        let reads_before = reads.val
        @async.pause()
        @async.pause()
        assert_eq(reads.val, reads_before)
        fragments.push(fragment)
        writes.val += 1
        writing.val = false
        Ok(())
      },
      () => {
        assert_false(writing.val)
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  ).unwrap()
  assert_eq(summary.detected_format, "txt")
  assert_true(writes.val > 1)
  assert_eq(finishes.val, 1)
  assert_eq(fragments.join(""), expected.content)
}

///|
async test "async TXT short reads preserve UTF8 and UTF16 BOM CRLF and non BMP text" {
  let fixtures : Array[(Bytes, String)] = [
    (
      b"\xEF\xBB\xBFalpha\r\nemoji \xF0\x9F\x98\x80\r\n\r\nomega", "alpha emoji &#128512;\n\nomega",
    ),
    (b"\xFF\xFEA\x00\r\x00\n\x00B\x00", "A B"),
  ]
  let options = @lib.ConvertOptions::default().with_format_hint(Some("txt"))
  for fixture in fixtures {
    let bytes = fixture.0
    let collected = @lib.convert(
      @lib.Input::from_bytes(bytes, source_name="short.txt"),
      options~,
    ).unwrap()
    assert_eq(collected.content, fixture.1)
    for max_chunk in [1, 3] {
      let fragments : Array[String] = []
      let finishes = Ref(0)
      let input = @lib.Input::from_async_reader(
        async fn(offset, length) {
          @async.pause()
          let start = offset.to_int()
          let end = (start + length.min(max_chunk)).min(bytes.length())
          Ok(bytes.exact_view(start~, end~).to_owned())
        },
        size=bytes.length().to_int64(),
        source_name="short.txt",
      )
      let summary = @lib.convert_to_sink(
        input,
        @lib.OutputSink::new(
          async fn(fragment) {
            @async.pause()
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
      assert_eq(summary.detected_format, "txt")
      assert_eq(finishes.val, 1)
      assert_eq(fragments.join(""), fixture.1)
      assert_eq(fragments.join(""), collected.content)
    }
  }
}

///|
async test "cancelling an awaiting async Reader stops reads and never finishes the sink" {
  let entered = Ref(false)
  let resumed = Ref(false)
  let reads = Ref(0)
  let writes = Ref(0)
  let finishes = Ref(0)
  let options = @lib.ConvertOptions::default().with_format_hint(Some("txt"))
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @lib.convert_to_sink(
          @lib.Input::from_async_reader(
            async fn(_offset, _length) {
              reads.val += 1
              entered.val = true
              @async.sleep(60000)
              resumed.val = true
              Ok(b"body")
            },
            size=4L,
            source_name="cancelled.txt",
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
      })
    })
    while !entered.val {
      @async.pause()
    }
    assert_eq(reads.val, 1)
    task.cancel()
    assert_true(task.wait() is None)
  })
  @async.pause()
  assert_eq(reads.val, 1)
  assert_false(resumed.val)
  assert_eq(writes.val, 0)
  assert_eq(finishes.val, 0)
}
