///|
async test "async cleanup borrows a synchronous caller session and keeps its Path and account alive" {
  let directory = @async_fs.tmpdir(prefix="markitdown-scope")
  let path = directory + "/payload"
  let file = @async_fs.open(
    path,
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  file.write(b"ok")
  defer file.close()
  defer (@async_fs.remove(path) catch { _ => () })
  defer (@async_fs.rmdir(directory) catch { _ => () })
  let caller = begin_input_session(input_from_path("lib/input/README.md"))
  defer end_input_session(caller)
  let account = input_source_budget_context(caller.source).unwrap().account
  let cursor = open_source_cursor(caller.source).unwrap()
  let scope = begin_input_cleanup_scope(caller)
  defer ignore(cleanup_input_scope(scope))
  let lease = account.reserve(TemporaryBytes, 2L).unwrap()
  let calls = Ref(0)
  register_input_temporary_cleanup(caller.source, async fn() {
    calls.val += 1
    @async.pause()
    file.close()
    @async_fs.remove(path)
    @async_fs.rmdir(directory)
    lease.release()
    Ok(())
  }).unwrap()
  let nested = begin_input_session(caller.source)
  let borrowed = begin_input_cleanup_scope(nested)
  assert_false(borrowed.owner)
  cleanup_input_scope(borrowed).unwrap()
  end_input_session(nested)
  assert_eq(calls.val, 0)
  assert_true(@async_fs.exists(path))
  cleanup_input_scope(scope).unwrap()
  assert_eq(calls.val, 1)
  assert_false(@async_fs.exists(path))
  assert_false(@async_fs.exists(directory))
  assert_false(account.snapshot().closed)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(source_cursor_read_at(cursor, 0L, length=4) is Ok(_))
  end_input_session(caller)
  assert_true(account.snapshot().closed)
  assert_true(source_cursor_read_at(cursor, 0L, length=4) is Err(_))
}

///|
test "temporary registration requires an installed async guard" {
  let caller = begin_input_session(input_from_text("caller"))
  defer end_input_session(caller)
  assert_true(
    register_input_temporary_cleanup(caller.source, fn() { Ok(()) })
    is Err(
      InputError("temporary cleanup requires an active async cleanup scope")
    ),
  )
  assert_true(input_source_failure(caller.source) is Some(InputError(_)))
}

///|
async test "premature synchronous end cannot close Path under an active async cleanup scope" {
  let caller = begin_input_session(input_from_path("lib/input/README.md"))
  let scope = begin_input_cleanup_scope(caller)
  defer end_input_session(caller)
  defer ignore(cleanup_input_scope(scope))
  let cursor = open_source_cursor(caller.source).unwrap()
  let account = input_source_budget_context(caller.source).unwrap().account
  end_input_session(caller)
  assert_false((cursor.is_closed)())
  assert_false(account.snapshot().closed)
  assert_true(cleanup_input_scope(scope) is Err(InputError(_)))
  end_input_session(caller)
  assert_true((cursor.is_closed)())
  assert_true(account.snapshot().closed)
}

///|
async test "concurrent drains run callbacks once and a later phase can install a fresh scope" {
  let caller = begin_input_session(input_from_text("caller"))
  defer end_input_session(caller)
  let scope = begin_input_cleanup_scope(caller)
  defer ignore(cleanup_input_scope(scope))
  let calls = Ref(0)
  register_input_temporary_cleanup(caller.source, async fn() {
    calls.val += 1
    @async.sleep(1)
    Ok(())
  }).unwrap()
  @async.with_task_group(group => {
    let first = group.spawn(() => cleanup_input_scope(scope))
    let second = group.spawn(() => cleanup_input_scope(scope))
    first.wait().unwrap()
    second.wait().unwrap()
  })
  assert_eq(calls.val, 1)
  let later = begin_input_cleanup_scope(caller)
  defer ignore(cleanup_input_scope(later))
  assert_true(later.owner)
  register_input_temporary_cleanup(caller.source, fn() {
    calls.val += 1
    Ok(())
  }).unwrap()
  cleanup_input_scope(later).unwrap()
  assert_eq(calls.val, 2)
}

///|
async test "cancellation awaits cleanup defer before returning and does not close a caller Reader" {
  let reader_calls = Ref(0)
  let source = input_from_reader(
    make_input_reader(
      fn(_, _) {
        reader_calls.val += 1
        Ok(b"x")
      },
      size=1L,
    ),
  )
  let caller = begin_input_session(source)
  defer end_input_session(caller)
  let entered = Ref(false)
  let cleaned = Ref(false)
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        let scope = begin_input_cleanup_scope(caller)
        defer ignore(cleanup_input_scope(scope))
        register_input_temporary_cleanup(caller.source, async fn() {
          @async.pause()
          cleaned.val = true
          Ok(())
        }).unwrap()
        entered.val = true
        @async.sleep(60000)
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(cleaned.val)
  assert_false(caller.source.session.unwrap().closed.val)
  assert_true(read_input_bytes(caller.source) is Ok(b"x"))
  assert_eq(reader_calls.val, 1)
}

///|
async test "failed deletion retains retryable credit after ordinary Path and account shutdown" {
  let caller = begin_input_session(input_from_path("lib/input/README.md"))
  let scope = begin_input_cleanup_scope(caller)
  let cursor = open_source_cursor(caller.source).unwrap()
  let account = input_source_budget_context(caller.source).unwrap().account
  let lease = account.reserve(TemporaryBytes, 4L).unwrap()
  let calls = Ref(0)
  let retired = Ref(0)
  register_input_temporary_cleanup(caller.source, fn() {
    calls.val += 1
    if calls.val == 1 {
      Err(InputError("delete denied"))
    } else {
      lease.release()
      Ok(())
    }
  }).unwrap()
  register_input_temporary_cleanup(caller.source, fn() {
    retired.val += 1
    Ok(())
  }).unwrap()
  assert_true(cleanup_input_scope(scope) is Err(InputError("delete denied")))
  assert_eq(retired.val, 1)
  assert_eq(account.snapshot().resident.temporary_bytes, 4L)
  end_input_session(caller)
  assert_true((cursor.is_closed)())
  assert_true(account.snapshot().closed)
  assert_true(
    input_source_failure(caller.source) is Some(InputError("delete denied")),
  )
  let retry = begin_input_cleanup_scope(caller)
  assert_true(cleanup_input_scope(retry) is Err(InputError("delete denied")))
  assert_eq(calls.val, 2)
  assert_eq(retired.val, 1)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(retry.state.drained)
}

///|
async test "typed first failure survives callback Error and every cleanup callback is attempted" {
  let caller = begin_input_session(input_from_text("caller"))
  defer end_input_session(caller)
  let scope = begin_input_cleanup_scope(caller)
  defer ignore(cleanup_input_scope(scope))
  let calls = Ref(0)
  let attempted = Ref(false)
  register_input_temporary_cleanup(caller.source, fn() raise {
    calls.val += 1
    if calls.val == 1 {
      raise Failure("late cleanup Error")
    }
    Ok(())
  }).unwrap()
  register_input_temporary_cleanup(caller.source, fn() {
    attempted.val = true
    Ok(())
  }).unwrap()
  record_input_resource_failure(
    caller.source,
    make_resource_limit_failure(SingleAssetBytes, 2L, 1L),
  )
  assert_true(
    cleanup_input_scope(scope) is Err(ResourceLimit(failure)) &&
    failure.observed == 2L,
  )
  assert_true(attempted.val)
  assert_true(cleanup_input_scope(scope) is Err(ResourceLimit(_)))
  assert_true(scope.state.drained)
  assert_eq(calls.val, 2)
}
