///|
async test "direct stream close drains cleanup without inventing a successful finish" {
  let source_seen : Ref[@input.InputSource?] = Ref(None)
  let cleanups = Ref(0)
  let closes = Ref(0)
  let finishes = Ref(0)
  let parser = make_parser(
    "owned-close",
    StreamingEvent,
    default_parser_capability(),
    fn(_, _) { Err("unused collector") },
    open_stream=Some(fn(source, _) {
      source_seen.val = Some(source)
      @input.register_input_temporary_cleanup(source, async fn() {
        @async.pause()
        cleanups.val += 1
        Ok(())
      }).unwrap()
      Ok(
        Some(
          make_parse_event_stream(
            fn() {
              Ok(Some({ kind: TextLine, text: "body", source_ref: None, }))
            },
            fn() {
              finishes.val += 1
              Ok(
                parse_stream_summary(
                  "owned-close",
                  StreamingEvent,
                  default_parser_capability(),
                  @core.empty_diagnostics(),
                ),
              )
            },
            close=fn() {
              closes.val += 1
              Ok(())
            },
          ),
        ),
      )
    }),
  )
  let stream = parser.open_stream.unwrap()(
      @input.input_from_path("internal/parser/README.md"),
      new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  // No format read is required to establish independent stream ownership.
  stream.close().unwrap()
  stream.close().unwrap()
  assert_eq(cleanups.val, 1)
  assert_eq(closes.val, 1)
  assert_eq(finishes.val, 0)
  assert_true((stream.next)() is Err(_))
  assert_true((stream.finish)() is Err(_))
  assert_eq(finishes.val, 0)
  assert_true(
    @input.input_source_budget_context(source_seen.val.unwrap()).unwrap().account.snapshot().closed,
  )
}

///|
async test "successful direct stream finish closes once while preserving a caller session" {
  let caller = @input.begin_input_session(@input.input_from_text("caller"))
  defer @input.end_input_session(caller)
  let cleanups = Ref(0)
  let closes = Ref(0)
  let finishes = Ref(0)
  let parser = make_parser(
    "owned-finish",
    StreamingEvent,
    default_parser_capability(),
    fn(_, _) { Err("unused") },
    open_stream=Some(fn(source, _) {
      @input.register_input_temporary_cleanup(source, fn() {
        cleanups.val += 1
        Ok(())
      }).unwrap()
      Ok(
        Some(
          make_parse_event_stream(
            fn() { Ok(None) },
            fn() {
              finishes.val += 1
              Ok(
                parse_stream_summary(
                  "owned-finish",
                  StreamingEvent,
                  default_parser_capability(),
                  @core.empty_diagnostics(),
                ),
              )
            },
            close=fn() {
              closes.val += 1
              Ok(())
            },
          ),
        ),
      )
    }),
  )
  let stream = parser.open_stream.unwrap()(
      caller.source,
      new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  assert_true((stream.next)() is Ok(None))
  assert_eq((stream.finish)().unwrap().parser_name, "owned-finish")
  stream.close().unwrap()
  assert_eq(finishes.val, 1)
  assert_eq(closes.val, 1)
  assert_eq(cleanups.val, 1)
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
  assert_true(@input.read_input_text(caller.source) is Ok("caller"))
}

///|
async test "cancelled next aborts a direct stream and never calls successful finish" {
  let entered = Ref(false)
  let nexts = Ref(0)
  let closes = Ref(0)
  let cleanups = Ref(0)
  let finishes = Ref(0)
  let parser = make_parser(
    "owned-cancel",
    StreamingEvent,
    default_parser_capability(),
    fn(_, _) { Err("unused") },
    open_stream=Some(fn(source, _) {
      @input.register_input_temporary_cleanup(source, async fn() {
        @async.pause()
        cleanups.val += 1
        Ok(())
      }).unwrap()
      Ok(
        Some(
          make_parse_event_stream(
            async fn() {
              nexts.val += 1
              entered.val = true
              @async.sleep(60000)
              Ok(None)
            },
            fn() {
              finishes.val += 1
              Err("cancel must not finish")
            },
            close=fn() {
              closes.val += 1
              Ok(())
            },
          ),
        ),
      )
    }),
  )
  let stream = parser.open_stream.unwrap()(
      @input.input_from_text("x"),
      new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
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
  assert_eq(nexts.val, 1)
  assert_eq(closes.val, 1)
  assert_eq(cleanups.val, 1)
  assert_eq(finishes.val, 0)
  assert_true((stream.next)() is Err(_))
  assert_true(stream.close() is Err(_))
}

///|
async test "collecting and absent-stream cleanup failures cannot publish successful results" {
  for absent in [false, true] {
    let calls = Ref(0)
    let register = fn(source : @input.InputSource) {
      @input.register_input_temporary_cleanup(source, fn() {
        calls.val += 1
        if calls.val == 1 {
          Err(InputError("cleanup denied"))
        } else {
          Ok(())
        }
      }).unwrap()
    }
    let parser = make_parser(
      "cleanup-error",
      StreamingEvent,
      default_parser_capability(),
      fn(source, _) {
        register(source)
        Ok(
          parse_result_with_events(
            "cleanup-error",
            StreamingEvent,
            [],
            @core.empty_diagnostics(),
          ),
        )
      },
      open_stream=Some(fn(source, _) {
        register(source)
        Ok(None)
      }),
    )
    let source = @input.input_from_text("x")
    if absent {
      assert_true(
        parser.open_stream.unwrap()(source, new_parse_context(Txt))
        is Err("cleanup denied"),
      )
    } else {
      assert_true(
        (parser.parse)(source, new_parse_context(Txt)) is Err("cleanup denied"),
      )
    }
    assert_eq(calls.val, 2)
  }
}

///|
async test "direct close waits for an in-flight next and does not finish or close borrowed input" {
  let caller = @input.begin_input_session(@input.input_from_text("caller"))
  defer @input.end_input_session(caller)
  let entered = Ref(false)
  let release = Ref(false)
  let busy = Ref(false)
  let overlap = Ref(false)
  let closes = Ref(0)
  let finishes = Ref(0)
  let parser = make_parser(
    "concurrent-close",
    StreamingEvent,
    default_parser_capability(),
    fn(_, _) { Err("unused") },
    open_stream=Some(fn(_, _) {
      Ok(
        Some(
          make_parse_event_stream(
            async fn() {
              busy.val = true
              entered.val = true
              while !release.val {
                @async.pause()
              }
              busy.val = false
              Ok(None)
            },
            fn() {
              finishes.val += 1
              Err("must not finish")
            },
            close=fn() {
              overlap.val = busy.val
              closes.val += 1
              Ok(())
            },
          ),
        ),
      )
    }),
  )
  let stream = parser.open_stream.unwrap()(
      caller.source,
      new_parse_context(Txt),
    )
    .unwrap()
    .unwrap()
  @async.with_task_group(group => {
    let next = group.spawn(() => (stream.next)())
    while !entered.val {
      @async.pause()
    }
    let close = group.spawn(() => stream.close())
    @async.pause()
    assert_eq(closes.val, 0)
    release.val = true
    assert_true(next.wait() is Ok(None))
    close.wait().unwrap()
  })
  assert_false(overlap.val)
  assert_eq(closes.val, 1)
  assert_eq(finishes.val, 0)
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
}
