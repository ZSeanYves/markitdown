///|
fn cleanup_conversion_source(
  callback : async () -> Result[Unit, @input.InputFailure],
  source_name~ : String = "cleanup.txt",
) -> @input.InputSession {
  let source_seen : Ref[@input.InputSource?] = Ref(None)
  let registered = Ref(false)
  let bytes = b"hello"
  let source = @input.input_from_reader(
    @input.make_async_input_reader(
      fn(offset, length) {
        if !registered.val {
          registered.val = true
          @input.register_input_temporary_cleanup(
            source_seen.val.unwrap(),
            callback,
          ).unwrap()
        }
        let start = offset.to_int()
        let end = (start + length).min(bytes.length())
        Ok(bytes.exact_view(start~, end~).to_owned())
      },
      size=bytes.length().to_int64(),
    ),
    source_name~,
  )
  let caller = @input.begin_input_session(source)
  source_seen.val = Some(caller.source)
  caller
}

///|
async test "pull and renderer sinks drain before finish without closing their caller session" {
  for pull in [true, false] {
    let cleaned = Ref(false)
    let finishes = Ref(0)
    let caller = cleanup_conversion_source(async fn() {
      @async.pause()
      cleaned.val = true
      Ok(())
    })
    defer @input.end_input_session(caller)
    let options = make_convert_options(
      Balanced,
      if pull {
        Markdown
      } else {
        Debug
      },
      Some(Txt),
      default_resource_limits(),
    )
    let result = convert_input_to_sink_unbuffered(
      caller.source,
      options,
      make_output_sink(fn(_) { Ok(()) }, fn() {
        finishes.val += 1
        if cleaned.val {
          Ok(())
        } else {
          Err("cleanup did not precede finish")
        }
      }),
    )
    assert_true(result is Ok(_))
    assert_true(cleaned.val)
    assert_eq(finishes.val, 1)
    assert_false(
      @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
    )
  }
}

///|
async test "cleanup failure after rendered writes returns error and never calls public finish" {
  let cleanups = Ref(0)
  let caller = cleanup_conversion_source(fn() {
    cleanups.val += 1
    if cleanups.val == 1 {
      Err(InputError("delete denied"))
    } else {
      Ok(())
    }
  })
  defer @input.end_input_session(caller)
  let writes = Ref(0)
  let finishes = Ref(0)
  let result = convert_input_to_sink_unbuffered(
    caller.source,
    make_convert_options(
      Balanced,
      Markdown,
      Some(Txt),
      default_resource_limits(),
    ),
    make_output_sink(
      fn(_) {
        writes.val += 1
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
  )
  assert_true(result is Err(ParseFailed("delete denied")))
  assert_true(writes.val > 0)
  assert_eq(finishes.val, 0)
  assert_eq(cleanups.val, 2)
}

///|
async test "sink write error remains first when deferred cleanup also fails" {
  let cleanups = Ref(0)
  let caller = cleanup_conversion_source(fn() {
    cleanups.val += 1
    if cleanups.val == 1 {
      Err(InputError("late cleanup denied"))
    } else {
      Ok(())
    }
  })
  let finishes = Ref(0)
  let result = convert_input_to_sink_unbuffered(
    caller.source,
    make_convert_options(
      Balanced,
      Markdown,
      Some(Txt),
      default_resource_limits(),
    ),
    make_output_sink(fn(_) { Err("write denied") }, fn() {
      finishes.val += 1
      Ok(())
    }),
  )
  assert_true(
    result is Err(RenderFailed(message)) && message.contains("write denied"),
  )
  assert_eq(finishes.val, 0)
  let retry = @input.begin_input_cleanup_scope(caller)
  assert_true(@input.cleanup_input_scope(retry) is Err(_))
  @input.end_input_session(caller)
  assert_eq(cleanups.val, 2)
}

///|
async test "cancelled sink write still drains its async scope and never calls finish" {
  let cleaned = Ref(false)
  let caller = cleanup_conversion_source(async fn() {
    @async.pause()
    cleaned.val = true
    Ok(())
  })
  defer @input.end_input_session(caller)
  let entered = Ref(false)
  let finishes = Ref(0)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        convert_input_to_sink_unbuffered(
          caller.source,
          make_convert_options(
            Balanced,
            Markdown,
            Some(Txt),
            default_resource_limits(),
          ),
          make_output_sink(
            async fn(_) {
              entered.val = true
              @async.sleep(60000)
              Ok(())
            },
            fn() {
              finishes.val += 1
              Ok(())
            },
          ),
        )
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(cleaned.val)
  assert_eq(finishes.val, 0)
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
}
