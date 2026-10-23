///|
async test "public asynchronous sink preserves output side channels for all modes" {
  for mode in [@lib.OutputMode::Markdown, Debug, Rag] {
    let input = @lib.Input::from_text(
      "# Title\n\nBody one\n\nBody two",
      source_name="sink.md",
    )
    let options = @lib.ConvertOptions::default().with_output_mode(mode)
    let collected = @lib.convert(input, options~).unwrap()
    let fragments : Array[String] = []
    let pending = Ref(false)
    let finishes = Ref(0)
    let sink = @lib.OutputSink::new(
      async fn(fragment) {
        assert_false(pending.val)
        pending.val = true
        @async.pause()
        fragments.push(fragment)
        pending.val = false
        Ok(())
      },
      async fn() {
        assert_false(pending.val)
        @async.pause()
        finishes.val += 1
        Ok(())
      },
    )
    let summary : @lib.ConversionSummary = @lib.convert_to_sink(
      input,
      sink,
      options~,
    ).unwrap()
    assert_eq(summary.detected_format, collected.detected_format)
    assert_true(summary.convert_mode == collected.convert_mode)
    assert_true(summary.output_mode == collected.output_mode)
    assert_eq(summary.metadata_json, collected.metadata_json)
    assert_eq(summary.assets, collected.assets)
    assert_eq(summary.source_map, collected.source_map)
    assert_eq(summary.chunk_count, collected.chunks.length())
    assert_eq(finishes.val, 1)
    assert_true(fragments.length() > 1)
    let content = fragments.join("")
    if mode == Markdown {
      assert_eq(content, collected.content)
    } else {
      assert_true(content.has_prefix("{"))
      assert_true(content.has_suffix("}"))
      assert_true(content.contains("Body one"))
    }
  }
}

///|
async test "public sink failures stop writes and never finish after read or write failure" {
  let writes = Ref(0)
  let finishes = Ref(0)
  let sink = @lib.OutputSink::new(
    async fn(_fragment) {
      @async.pause()
      writes.val += 1
      Err("write stopped")
    },
    fn() {
      finishes.val += 1
      Ok(())
    },
  )
  let result = @lib.convert_to_sink(@lib.Input::from_text("one\n\ntwo"), sink)
  assert_true(result is Err(RenderFailed(_)))
  assert_eq(writes.val, 1)
  assert_eq(finishes.val, 0)
  let result = @lib.convert_to_sink(
    @lib.Input::from_async_reader(async fn(_offset, _length) {
      @async.pause()
      Err("read stopped")
    }),
    sink,
  )
  assert_true(result is Err(DetectionFailed(_)))
  assert_eq(writes.val, 1)
  assert_eq(finishes.val, 0)
  let finish_error = @lib.convert_to_sink(
    @lib.Input::from_text("body"),
    @lib.OutputSink::new(fn(_fragment) { Ok(()) }, async fn() {
      @async.pause()
      Err("finish stopped")
    }),
  )
  assert_true(finish_error is Err(RenderFailed(_)))
}

///|
async test "public sink cancellation stops delivery without finishing" {
  let started = Ref(false)
  let writes = Ref(0)
  let finished = Ref(false)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        @lib.convert_to_sink(
          @lib.Input::from_text("one\n\ntwo"),
          @lib.OutputSink::new(
            async fn(_fragment) {
              writes.val += 1
              started.val = true
              @async.sleep(60000)
              Ok(())
            },
            fn() {
              finished.val = true
              Ok(())
            },
          ),
        )
      })
    })
    while !started.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(writes.val, 1)
  assert_false(finished.val)
}

///|
async test "public sink rejects a Reader ending before its declared size" {
  let finished = Ref(false)
  let input = @lib.Input::from_reader(
    fn(offset, length) {
      if offset >= 4L {
        Ok(b"")
      } else {
        let start = offset.to_int()
        Ok(b"body".exact_view(start~, end=(start + length).min(4)).to_owned())
      }
    },
    size=8L,
    source_name="truncated.txt",
  )
  let result = @lib.convert_to_sink(
    input,
    @lib.OutputSink::new(fn(_fragment) { Ok(()) }, fn() {
      finished.val = true
      Ok(())
    }),
  )
  match result {
    Err(error) =>
      assert_true(error.message().contains("reader ended before declared size"))
    Ok(_) => fail("stream delivery must not silently accept a truncated Reader")
  }
  assert_false(finished.val)
}
