///|
test "temporary capacity is an optional immutable public limit including zero" {
  let defaults = @lib.ResourceLimits::default()
  assert_true(defaults.max_temporary_bytes is None)
  let zero = defaults.with_max_temporary_bytes(Some(0L))
  assert_true(zero.max_temporary_bytes == Some(0L))
  assert_true(defaults.max_temporary_bytes is None)
  let bounded = zero.with_max_temporary_bytes(Some(123L))
  assert_true(bounded.max_temporary_bytes == Some(123L))
  assert_true(
    bounded.with_max_temporary_bytes(None).max_temporary_bytes is None,
  )
  assert_eq(bounded.max_input_bytes, defaults.max_input_bytes)
  assert_eq(bounded.max_asset_bytes, defaults.max_asset_bytes)
  assert_eq(bounded.max_total_asset_bytes, defaults.max_total_asset_bytes)
}

///|
async test "negative public temporary capacity rejects before source or sink callbacks" {
  let reads = Ref(0)
  let writes = Ref(0)
  let finishes = Ref(0)
  let source = @lib.Input::from_async_reader(
    fn(_, _) {
      reads.val += 1
      Ok(b"{\"a\":1}\n")
    },
    source_name="records.jsonl",
  )
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_temporary_bytes(Some(-1L)),
  )
  assert_true(@lib.convert(source, options~) is Err(InvalidOption(_)))
  let sink = @lib.OutputSink::new(
    fn(_) {
      writes.val += 1
      Ok(())
    },
    fn() {
      finishes.val += 1
      Ok(())
    },
  )
  assert_true(
    @lib.convert_to_sink(source, sink, options~) is Err(InvalidOption(_)),
  )
  assert_eq(reads.val, 0)
  assert_eq(writes.val, 0)
  assert_eq(finishes.val, 0)
}

///|
async test "public JSONL temporary limit has an exact physical frame boundary for collect and Sink" {
  let input = @lib.Input::from_text("{\"a\":1}\n", source_name="one.jsonl")
  let ordinary = @lib.convert(input).unwrap()
  // Two one-cell rows (header and value), each with a Cell and RowBreak frame:
  // four 25-byte headers plus two UTF8 bytes. No side index or raw copy exists.
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_temporary_bytes(Some(102L)),
  )
  let output = @lib.convert(input, options~).unwrap()
  assert_eq(output.content, ordinary.content)
  let body = StringBuilder()
  let finished = Ref(0)
  let sink = @lib.OutputSink::new(
    fn(text) {
      body.write_string(text)
      Ok(())
    },
    fn() {
      finished.val += 1
      Ok(())
    },
  )
  ignore(@lib.convert_to_sink(input, sink, options~).unwrap())
  assert_eq(body.to_string(), output.content)
  assert_eq(finished.val, 1)
}

///|
async test "public JSONL temporary exhaustion cannot fall back to memory or finish either output path" {
  for (limit, observed) in [(0L, 26L), (101L, 102L)] {
    let input = @lib.Input::from_text("{\"a\":1}\n", source_name="one.jsonl")
    let options = @lib.ConvertOptions::default().with_limits(
      @lib.ResourceLimits::default().with_max_temporary_bytes(Some(limit)),
    )
    assert_true(
      @lib.convert(input, options~)
      is Err(
        ResourceLimitExceeded(
          kind="temporary_bytes",
          observed=actual,
          limit=actual_limit
        )
      ) &&
      actual == observed &&
      actual_limit == limit,
    )
    let writes = Ref(0)
    let finishes = Ref(0)
    let sink = @lib.OutputSink::new(
      fn(_) {
        writes.val += 1
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    )
    assert_true(
      @lib.convert_to_sink(input, sink, options~)
      is Err(
        ResourceLimitExceeded(
          kind="temporary_bytes",
          observed=actual,
          limit=actual_limit
        )
      ) &&
      actual == observed &&
      actual_limit == limit,
    )
    assert_eq(writes.val, 0)
    assert_eq(finishes.val, 0)
  }
}

///|
async test "public JSONL spool keeps ordinary grammar recovery while consumed encoding errors remain hard" {
  let input = @lib.Input::from_text(
    "{broken json\n",
    source_name="broken.jsonl",
  )
  let ordinary = @lib.convert(input).unwrap()
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_temporary_bytes(Some(4096L)),
  )
  let recovered = @lib.convert(input, options~).unwrap()
  assert_eq(recovered.content, ordinary.content)
  let finishes = Ref(0)
  let bad = @lib.Input::from_bytes(
    b"{\"a\":1}\n\xff",
    source_name="broken.jsonl",
  )
  let sink = @lib.OutputSink::new(fn(_) { Ok(()) }, fn() {
    finishes.val += 1
    Ok(())
  })
  assert_true(@lib.convert_to_sink(bad, sink, options~) is Err(_))
  assert_eq(finishes.val, 0)
}

///|
async test "nested archive JSONL cannot drop the public temporary cap or translate it to asset units" {
  let archive = @dzip.build_store_zip_bytes([
    ("a.png", b"image"),
    ("b.jsonl", b"{\"a\":1}\n"),
  ])
  let input = @lib.Input::from_bytes(archive, source_name="nested.zip")
  assert_true(@lib.convert(input) is Ok(_))
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_temporary_bytes(Some(1L)),
  )
  assert_true(
    @lib.convert(input, options~)
    is Err(
      ResourceLimitExceeded(kind="temporary_bytes", observed=26L, limit=1L)
    ),
  )
}

///|
async test "cancelled public JSONL Sink releases the real spool and stops polling during backpressure" {
  let bytes = b"{\"a\":1}\n{\"a\":2}\n"
  let read_calls = Ref(0)
  let entered = Ref(false)
  let resumed = Ref(false)
  let finishes = Ref(0)
  let input = @lib.Input::from_async_reader(
    async fn(offset, length) {
      @async.pause()
      read_calls.val += 1
      let start = offset.to_int().min(bytes.length())
      let end = (start + length).min(bytes.length())
      Ok(bytes[start:end].to_owned())
    },
    size=bytes.length().to_int64(),
    source_name="await.jsonl",
  )
  let sink = @lib.OutputSink::new(
    async fn(_) {
      entered.val = true
      @async.sleep(60000)
      resumed.val = true
      Ok(())
    },
    fn() {
      finishes.val += 1
      Ok(())
    },
  )
  let options = @lib.ConvertOptions::default().with_limits(
    @lib.ResourceLimits::default().with_max_temporary_bytes(Some(1024L)),
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        ignore(@lib.convert_to_sink(input, sink, options~))
      })
    })
    while !entered.val {
      @async.pause()
    }
    let at_write = read_calls.val
    @async.pause()
    @async.pause()
    assert_eq(read_calls.val, at_write)
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_false(resumed.val)
  assert_eq(finishes.val, 0)
}
