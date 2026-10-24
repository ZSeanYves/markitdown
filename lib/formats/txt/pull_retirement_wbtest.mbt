///|
async test "TXT early close retires buffered lines while retaining a borrowed session" {
  let caller = @input.begin_input_session(
    @input.input_from_text("first\nsecond😀\n"),
  )
  defer @input.end_input_session(caller)
  let stream = open_txt_event_stream(
      caller.source,
      @parser.new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  let first = (stream.next)().unwrap().unwrap()
  assert_eq(first.text, "first")
  stream.close().unwrap()
  stream.close().unwrap()
  assert_true((stream.next)() is Ok(None))
  assert_eq(first.text, "first")
  assert_true(first.source_ref.unwrap().line_start == Some(1))
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
  assert_true(
    @input.read_input_text(caller.source) is Ok("first\nsecond😀\n"),
  )
}

///|
async test "TXT cancellation closes the actual factory without publishing a partial line" {
  let entered = Ref(false)
  let calls = Ref(0)
  let bytes = b"first\npartial"
  let reader = @input.make_async_input_reader(async fn(offset, length) {
    calls.val += 1
    if offset < bytes.length().to_int64() {
      let start = offset.to_int()
      let end = (start + length).min(bytes.length())
      Ok(bytes.exact_view(start~, end~).to_owned())
    } else {
      entered.val = true
      @async.sleep(60000)
      Ok(b"")
    }
  })
  let source = @input.input_from_reader(reader)
  let raw : Ref[@parser.ParseEventStream?] = Ref(None)
  let parser = @parser.make_parser(
    "txt-retirement-cancel",
    StreamingEvent,
    txt_parser_capability(),
    fn(_, _) { Err("unused collector") },
    open_stream=Some(async fn(source, context) {
      let stream = open_txt_event_stream(source, context)
      if stream is Ok(Some(value)) {
        raw.val = Some(value)
      }
      stream
    }),
  )
  let stream = parser.open_stream.unwrap()(
      source,
      @parser.new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  assert_eq((stream.next)().unwrap().unwrap().text, "first")
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => (stream.next)())
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  let reads = calls.val
  assert_true((raw.val.unwrap().next)() is Ok(None))
  assert_eq(calls.val, reads)
  assert_true((stream.next)() is Err(_))
  assert_true((stream.finish)() is Err(_))
}

///|
async test "TXT full consumption preserves final-line events source refs and metrics" {
  let stream = open_txt_event_stream(
      @input.input_from_text("first\r\nsecond😀\rthird"),
      @parser.new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  defer ignore(stream.close())
  let events : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => events.push(event)
      None => break
    }
  }
  assert_eq(events.map(event => event.text), ["first", "second😀", "third"])
  for index in 0..<events.length() {
    assert_true(events[index].kind == TextLine)
    assert_true(events[index].source_ref.unwrap().line_start == Some(index + 1))
  }
  let summary = (stream.finish)().unwrap()
  assert_true(summary.diagnostics.metrics.get("line_count") == Some("3"))
  assert_true(summary.diagnostics.metrics.get("event_count") == Some("3"))
  assert_true(summary.diagnostics.metrics.get("char_count") == Some("18"))
}
