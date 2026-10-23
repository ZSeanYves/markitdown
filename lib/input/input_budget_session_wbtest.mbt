///|
fn input_test_budget(cap : Int64) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      Enforced,
      inflate_bytes=Some(cap),
      parse_work=Some(cap),
      output_utf8_bytes=Some(cap),
      source_metadata_bytes=Some(cap),
      rag_metadata_bytes=Some(cap),
      read_traffic_bytes=Some(cap),
      cache_bytes=Some(cap),
      working_bytes=Some(cap),
      temporary_bytes=Some(cap),
      ir_bytes=Some(cap),
    ).unwrap(),
  )
}

///|
test "new sessions explicitly measure and nested scopes share retained capacity" {
  assert_true(input_source_budget_context(input_from_bytes(b"x")) is None)
  let outer = begin_input_session(input_from_bytes(b"x"))
  let context = input_source_budget_context(outer.source).unwrap()
  assert_true(context.account.snapshot().limits.profile == MeasurementOnly)
  assert_true(context.account.snapshot().limits.inflate_bytes is None)
  (context.retain_resident)(CacheBytes, 5L).unwrap()
  let child = begin_input_session(outer.source)
  let child_context = input_source_budget_context(child.source).unwrap()
  child_context.account.charge(InflateBytes, 7L).unwrap()
  assert_eq(context.account.snapshot().cumulative.inflate_bytes, 7L)
  end_input_session(child)
  assert_false(context.account.snapshot().closed)
  assert_eq(context.account.snapshot().resident.cache_bytes, 5L)
  end_input_session(outer)
  end_input_session(outer)
  assert_true(context.account.snapshot().closed)
  assert_eq(context.account.snapshot().resident.cache_bytes, 0L)
  assert_eq(context.account.snapshot().resident_peak.cache_bytes, 5L)
  assert_eq(context.account.snapshot().active_leases, 0L)
  assert_true((context.retain_resident)(CacheBytes, 0L) is Err(Closed))
}

///|
test "nested sessions reject an explicit replacement without resetting the account" {
  let account = input_test_budget(8L)
  let outer = begin_input_session(input_from_bytes(b"x"), budget=account)
  defer end_input_session(outer)
  account.charge(InflateBytes, 5L).unwrap()
  let replacement = input_test_budget(100L)
  let nested = begin_input_session(outer.source, budget=replacement)
  defer end_input_session(nested)
  let inherited = input_source_budget_context(nested.source).unwrap()
  assert_eq(inherited.account.snapshot().cumulative.inflate_bytes, 5L)
  assert_eq(replacement.snapshot().cumulative.inflate_bytes, 0L)
  assert_true(
    input_source_failure(outer.source) is Some(InputError(message)) &&
    message.contains("cannot replace"),
  )
  assert_false(account.snapshot().closed)
}

///|
async test "beginning a closed session latches failure before another Reader callback" {
  let calls = Ref(0)
  let session = begin_input_session(
    input_from_reader(
      make_input_reader(
        fn(_, _) {
          calls.val += 1
          Ok(b"x")
        },
        size=1L,
      ),
    ),
  )
  assert_eq(read_input_bytes(session.source), Ok(b"x"))
  end_input_session(session)
  let reused = begin_input_session(session.source)
  defer end_input_session(reused)
  assert_true(
    input_source_failure(reused.source)
    is Some(InputError("input session is closed")),
  )
  assert_true(read_input_bytes(reused.source) is Err(_))
  assert_eq(calls.val, 1)
}

///|
test "child session inheritance does not copy parent raw extent or byte ceiling" {
  let outer = begin_input_session(
    with_prepared_text_payload(
      input_from_bytes(b"x"),
      "longer",
      physical_bytes=1L,
    ),
    max_bytes=16L,
  )
  defer end_input_session(outer)
  let child = with_prepared_text_payload(
    input_source_with_reader_limit(input_from_bytes(b"abc"), 8L),
    "ééé",
    physical_bytes=3L,
  )
  let inherited = input_source_inherit_session(child, outer.source)
  assert_eq(inherited.physical_bytes, Some(3L))
  assert_eq(inherited.byte_limit, Some(8L))
  assert_eq(inherited.source_name, child.source_name)
  let context = input_source_budget_context(inherited).unwrap()
  context.account.charge(ParseWork, 3L).unwrap()
  assert_eq(
    input_source_budget_context(outer.source).unwrap().account.snapshot().cumulative.parse_work,
    3L,
  )
}

///|
test "a parent without a session cannot detach a child's account" {
  let child = begin_input_session(input_from_bytes(b"x"))
  defer end_input_session(child)
  let context = input_source_budget_context(child.source).unwrap()
  context.account.charge(ParseWork, 3L).unwrap()
  let inherited = input_source_inherit_session(
    child.source,
    input_from_bytes(b"parent"),
  )
  assert_eq(
    input_source_budget_context(inherited).unwrap().account.snapshot().cumulative.parse_work,
    3L,
  )
  assert_true(
    physical_equal(
      inherited.session.unwrap().closed,
      child.source.session.unwrap().closed,
    ),
  )
}

///|
test "foreign child sessions keep typed failures and consumed counters when adoption is rejected" {
  let child = begin_input_session(input_from_bytes(b"x"))
  defer end_input_session(child)
  let parent = begin_input_session(input_from_bytes(b"parent"))
  defer end_input_session(parent)
  let child_account = input_source_budget_context(child.source).unwrap().account
  child_account.charge(InflateBytes, 7L).unwrap()
  record_input_resource_failure(
    child.source,
    make_resource_limit_failure(SingleAssetBytes, 2L, 1L),
  )
  let inherited = input_source_inherit_session(child.source, parent.source)
  assert_true(
    input_source_failure(inherited) is Some(ResourceLimit(failure)) &&
    failure.observed == 2L,
  )
  assert_true(
    input_source_failure(parent.source) is Some(ResourceLimit(failure)) &&
    failure.observed == 2L,
  )
  assert_true(
    physical_equal(
      inherited.session.unwrap().closed,
      child.source.session.unwrap().closed,
    ),
  )
  assert_eq(
    input_source_budget_context(inherited).unwrap().account.snapshot().cumulative.inflate_bytes,
    7L,
  )
  assert_eq(
    input_source_budget_context(parent.source).unwrap().account.snapshot().cumulative.inflate_bytes,
    0L,
  )
}

///|
async test "a closed child cannot be revived by adopting a healthy parent account" {
  let child = begin_input_session(input_from_bytes(b"x"))
  let child_account = input_source_budget_context(child.source).unwrap().account
  child_account.charge(ParseWork, 3L).unwrap()
  end_input_session(child)
  let parent = begin_input_session(input_from_bytes(b"parent"))
  defer end_input_session(parent)
  let inherited = input_source_inherit_session(child.source, parent.source)
  assert_true(inherited.session.unwrap().closed.val)
  assert_true(child_account.snapshot().closed)
  assert_eq(child_account.snapshot().cumulative.parse_work, 3L)
  assert_true(open_source_cursor(inherited) is Err(_))
  assert_true(
    input_source_failure(parent.source) is Some(InputError(message)) &&
    message.contains("closed child"),
  )
}

///|
test "healthy foreign sessions cannot silently reset their already consumed budget" {
  let child = begin_input_session(input_from_bytes(b"x"))
  defer end_input_session(child)
  let parent = begin_input_session(input_from_bytes(b"parent"))
  defer end_input_session(parent)
  let child_account = input_source_budget_context(child.source).unwrap().account
  child_account.charge(ParseWork, 3L).unwrap()
  let inherited = input_source_inherit_session(child.source, parent.source)
  assert_eq(
    input_source_budget_context(inherited).unwrap().account.snapshot().cumulative.parse_work,
    3L,
  )
  assert_true(
    input_source_failure(inherited) is Some(InputError(message)) &&
    message.contains("existing child"),
  )
  assert_true(
    input_source_failure(parent.source) is Some(InputError(message)) &&
    message.contains("existing child"),
  )
}

///|
test "session cleanup releases scope retained leases after a typed budget failure" {
  let account = input_test_budget(8L)
  let session = begin_input_session(input_from_bytes(b"x"), budget=account)
  let context = input_source_budget_context(session.source).unwrap()
  (context.retain_resident)(CacheBytes, 8L).unwrap()
  assert_true(
    (context.retain_resident)(CacheBytes, 1L)
    is Err(LimitExceeded(Resident(CacheBytes), used=8L, requested=1L, limit=8L)),
  )
  assert_true(
    input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(Resident(CacheBytes), used=8L, requested=1L, limit=8L)
      )
    ),
  )
  end_input_session(session)
  let sample = account.snapshot()
  assert_true(sample.closed)
  assert_eq(sample.resident.cache_bytes, 0L)
  assert_eq(sample.active_leases, 0L)
  assert_true(sample.first_error is Some(LimitExceeded(_, ..)))
}

///|
test "typed budget first failure survives later asset and string reporters" {
  let account = input_test_budget(8L)
  let session = begin_input_session(input_from_bytes(b"x"), budget=account)
  defer end_input_session(session)
  assert_true(account.charge(InflateBytes, 9L) is Err(_))
  record_input_resource_failure(
    session.source,
    make_resource_limit_failure(SingleAssetBytes, 2L, 1L),
  )
  record_input_failure(session.source, "a later I/O error")
  assert_true(
    input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(Cumulative(InflateBytes), used=0L, requested=9L, limit=8L)
      )
    ),
  )
  let earlier_io = begin_input_session(
    input_from_bytes(b"x"),
    budget=input_test_budget(8L),
  )
  defer end_input_session(earlier_io)
  record_input_failure(earlier_io.source, "first I/O error")
  let other = input_source_budget_context(earlier_io.source).unwrap()
  assert_true(other.account.charge(InflateBytes, 9L) is Err(_))
  record_input_budget_failure(
    earlier_io.source,
    other.account.failure().unwrap(),
  )
  assert_true(
    input_source_failure(earlier_io.source)
    is Some(InputError("first I/O error")),
  )
}

///|
async test "read traffic counts short callbacks once and counts repeated ranges" {
  let calls = Ref(0)
  let bytes = b"abcd"
  let session = begin_input_session(
    input_from_reader(
      make_input_reader(
        fn(offset, length) {
          calls.val += 1
          let start = offset.to_int()
          Ok(
            bytes
            .exact_view(start~, end=(start + length.min(2)).min(bytes.length()))
            .to_owned(),
          )
        },
        size=4L,
      ),
    ),
  )
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_eq(source_cursor_read_exact_at(cursor, 0L, 4), Ok(bytes))
  assert_eq(source_cursor_read_at(cursor, 0L, length=2), Ok(b"ab"))
  let sample = input_source_budget_context(session.source).unwrap().account.snapshot()
  assert_eq(calls.val, 3)
  assert_eq(sample.cumulative.read_traffic_bytes, 6L)
}

///|
async test "Text Bytes views and fast reads share UTF8 traffic units without double charging" {
  for
    source in [
      input_from_text("é🙂"),
      input_from_bytes(b"\xc3\xa9\xf0\x9f\x99\x82"),
    ] {
    let session = begin_input_session(source, max_bytes=6L)
    defer end_input_session(session)
    let account = input_source_budget_context(session.source).unwrap().account
    assert_eq(read_input_text(session.source), Ok("é🙂"))
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, 6L)
    assert_eq(read_input_bytes(session.source), Ok(b"\xc3\xa9\xf0\x9f\x99\x82"))
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, 12L)
    let cursor = open_source_cursor(session.source).unwrap()
    assert_eq(source_cursor_view_at(cursor, 0, 2).unwrap().length(), 2)
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, 14L)
    assert_eq(
      source_cursor_read_exact_at(cursor, 2L, 4),
      Ok(b"\xf0\x9f\x99\x82"),
    )
    assert_eq(account.snapshot().cumulative.read_traffic_bytes, 18L)
    assert_eq(input_source_size(session.source), Ok(Some(6L)))
  }
}

///|
async test "traffic exhaustion latches its type and stops the next Reader callback" {
  let calls = Ref(0)
  let account = input_test_budget(3L)
  let session = begin_input_session(
    input_from_reader(
      make_input_reader(fn(_, _) {
        calls.val += 1
        Ok(b"ab")
      }),
    ),
    budget=account,
  )
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_eq(source_cursor_read_at(cursor, 0L, length=2), Ok(b"ab"))
  assert_true(source_cursor_read_at(cursor, 2L, length=2) is Err(_))
  assert_true(source_cursor_read_at(cursor, 4L, length=2) is Err(_))
  assert_eq(calls.val, 2)
  assert_eq(account.snapshot().cumulative.read_traffic_bytes, 2L)
  assert_true(
    input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Cumulative(ReadTrafficBytes),
          used=2L,
          requested=2L,
          limit=3L
        )
      )
    ),
  )
}

///|
async test "a zero-copy view cannot bypass its shared traffic budget" {
  let account = input_test_budget(2L)
  let session = begin_input_session(input_from_bytes(b"abc"), budget=account)
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_true(source_cursor_view_at(cursor, 0, 3) is None)
  assert_true(
    input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Cumulative(ReadTrafficBytes),
          used=0L,
          requested=3L,
          limit=2L
        )
      )
    ),
  )
  assert_true(source_cursor_read_at(cursor, 0L, length=1) is Err(_))
  assert_eq(account.snapshot().cumulative.read_traffic_bytes, 0L)
}

///|
async test "cancellation releases retained session leases and closes the shared account" {
  let account = input_test_budget(8L)
  let entered = Ref(false)
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      @async.handle_cancellation(async fn() {
        let session = begin_input_session(
          input_from_bytes(b"x"),
          budget=account,
        )
        defer end_input_session(session)
        let context = input_source_budget_context(session.source).unwrap()
        (context.retain_resident)(CacheBytes, 8L).unwrap()
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
  assert_true(account.snapshot().closed)
  assert_eq(account.snapshot().resident.cache_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_true(account.failure() is None)
}

///|
async test "derived entry access separates root extent while retaining smaller local requests" {
  let root = begin_input_session(input_from_bytes(b"x"), max_bytes=1L)
  defer end_input_session(root)
  let child = input_from_container_entry_bytes(
    root.source,
    b"abcdef",
    "child.txt",
    entry_limit=6L,
  )
  assert_eq(child.physical_bytes, None)
  assert_eq(input_source_entry_limit(child), Some(6L))
  assert_eq(read_input_bytes(child), Ok(b"abcdef"))
  assert_eq(
    input_source_budget_context(root.source).unwrap().account.snapshot().cumulative.read_traffic_bytes,
    6L,
  )
  assert_true(open_source_cursor(child, max_bytes=5L) is Err(_))
  assert_true(
    input_source_failure(root.source) is Some(InputError(message)) &&
    message.contains("observed=6; limit=5"),
  )
}

///|
async test "derived factories reject entries larger than their explicit entry cap" {
  let root = begin_input_session(input_from_bytes(b"x"), max_bytes=1L)
  defer end_input_session(root)
  let child = input_from_container_entry_bytes(
    root.source,
    b"abcdef",
    "child.txt",
    entry_limit=5L,
  )
  assert_true(read_input_bytes(child) is Err(_))
  assert_true(
    input_source_failure(root.source) is Some(InputError(message)) &&
    message.contains("observed=6; limit=5"),
  )
}

///|
async test "decoded derived text keeps entry raw extent separate from its UTF8 representation" {
  let root = begin_input_session(input_from_bytes(b"x"), max_bytes=1L)
  defer end_input_session(root)
  let child = input_from_container_entry_bytes(
    root.source,
    b"\xe9",
    "child.xml",
    entry_limit=1L,
  )
  let prepared = with_prepared_text_payload(child, "é", physical_bytes=1L)
  assert_eq(input_source_size(prepared), Ok(Some(1L)))
  assert_eq(read_input_text(prepared), Ok("é"))
  let cursor = open_source_cursor(prepared).unwrap()
  assert_eq(cursor.size, Some(2L))
  assert_eq(source_cursor_read_exact_at(cursor, 0L, 2), Ok(b"\xc3\xa9"))
  assert_true(open_source_cursor(prepared, max_bytes=0L) is Err(_))
}
