///|
fn spool_test_account(cap : Int64, working~ : Int64 = 4096L) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=Some(working),
      temporary_bytes=Some(cap),
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
fn spool_test_context(cap : Int64) -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.new_parse_context(Jsonl),
    Some(StreamingEvent),
    Some(200),
    Some(50),
    Some(10000),
    Some(4000),
    false,
    limits=@product.make_resource_limits(
      200,
      50,
      10000,
      max_temporary_bytes=Some(cap),
    ),
  )
}

///|
async test "JSONL codec preserves raw UTF8 values and physical frame accounting with bounded workspace" {
  let account = spool_test_account(89L)
  let session = @input.begin_input_session(
    @input.input_from_text("codec"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let budget = @input.input_source_budget_context(session.source).unwrap()
  let owner = create_line_json_spool_owner(session.source, account, 89L).unwrap()
  let text = "\u{FEFF}😀\r\nX"
  append_line_json_spool_frame(
    owner,
    session.source,
    account,
    b'\x00',
    7,
    3,
    text,
  ).unwrap()
  append_line_json_spool_frame(
    owner,
    session.source,
    account,
    b'\x01',
    7,
    3,
    "",
  ).unwrap()
  append_line_json_spool_frame(
    owner,
    session.source,
    account,
    b'\x02',
    8,
    4,
    "null",
  ).unwrap()
  assert_eq(owner.length(), 89L)
  owner.seal().unwrap()
  let cursor : LineJsonSpoolCursor = {
    owner,
    range: owner.range(0L, 89L).unwrap(),
    offset: 0L,
  }
  let first = next_line_json_spool_frame(cursor, session.source, budget)
    .unwrap()
    .unwrap()
  assert_eq(first.text, text)
  assert_eq(first.line, 7)
  assert_eq(first.record, 3)
  assert_eq(first.tag, b'\x00')
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  let second = next_line_json_spool_frame(cursor, session.source, budget)
    .unwrap()
    .unwrap()
  assert_eq(second.text, "")
  assert_eq(second.tag, b'\x01')
  let third = next_line_json_spool_frame(cursor, session.source, budget)
    .unwrap()
    .unwrap()
  assert_eq(third.text, "null")
  assert_eq(third.tag, b'\x02')
  assert_true(
    next_line_json_spool_frame(cursor, session.source, budget) is Ok(None),
  )
  assert_eq(first.text, text)
  let sample = account.snapshot()
  assert_eq(sample.resident.temporary_bytes, 89L)
  assert_eq(sample.resident_peak.temporary_bytes, 89L)
  assert_eq(sample.resident.working_bytes, 0L)
  assert_eq(sample.resident_peak.working_bytes, 65L)
  assert_eq(sample.resident.cache_bytes, 20L)
  assert_eq(sample.cumulative.read_traffic_bytes, 89L)
  assert_eq(sample.cumulative.parse_work, 178L)
  @input.cleanup_input_scope(cleanup).unwrap()
  assert_true(owner.cleanup_complete())
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "JSONL codec rejects a complete frame before allocation or file growth at the shared cap" {
  let account = spool_test_account(34L)
  let session = @input.begin_input_session(
    @input.input_from_text("codec"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let owner = create_line_json_spool_owner(session.source, account, 34L).unwrap()
  assert_true(
    append_line_json_spool_frame(
      owner,
      session.source,
      account,
      b'\x00',
      1,
      0,
      "0123456789",
    )
    is Err(_),
  )
  assert_eq(owner.length(), 0L)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().resident_peak.working_bytes, 0L)
  assert_true(
    @input.input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Resident(TemporaryBytes),
          used=0L,
          requested=35L,
          limit=34L
        )
      )
    ),
  )
  assert_true(@input.cleanup_input_scope(cleanup) is Err(_))
  assert_true(owner.cleanup_complete())
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "JSONL codec invalid UTF8 and truncated frame extents remain hard failures" {
  for invalid_utf8 in [true, false] {
    let account = spool_test_account(26L)
    let session = @input.begin_input_session(
      @input.input_from_text("codec"),
      budget=account,
    )
    defer @input.end_input_session(session)
    let cleanup = @input.begin_input_cleanup_scope(session)
    defer ignore(@input.cleanup_input_scope(cleanup))
    let budget = @input.input_source_budget_context(session.source).unwrap()
    let owner = create_line_json_spool_owner(session.source, account, 26L).unwrap()
    let header = FixedArray::make(25, b'\x00')
    line_json_spool_put_int64(header, 1, 1L)
    line_json_spool_put_int64(header, 17, if invalid_utf8 { 1L } else { 2L })
    owner.append(Bytes::from_array(header[:])).unwrap()
    owner.append(b"\xff").unwrap()
    owner.seal().unwrap()
    let cursor : LineJsonSpoolCursor = {
      owner,
      range: owner.range(0L, 26L).unwrap(),
      offset: 0L,
    }
    assert_true(
      next_line_json_spool_frame(cursor, session.source, budget) is Err(_),
    )
    assert_true(
      @input.input_source_failure(session.source) is Some(InputError(_)),
    )
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    assert_true(@input.cleanup_input_scope(cleanup) is Err(_))
    assert_true(owner.cleanup_complete())
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "JSONL spool consumes one short-read input pass and replays table before code" {
  let text = "0\n{\"a\":\"😀\"}\n{\"b\":2}\n{\"a\":\"z\"}\n"
  let bytes = @utf8.encode(text)
  let read_bytes = Ref(0)
  let reader = @input.make_input_reader(
    fn(offset, length) {
      let start = offset.to_int()
      let count = length.min(3).min(bytes.length() - start)
      read_bytes.val += count
      Ok(bytes[start:start + count].to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let session = @input.begin_input_session(
    @input.input_from_reader(reader, source_name="mixed.jsonl"),
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let stream = open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      session.source,
      spool_test_context(214L),
      jsonl_parser_capability(),
    )
    .unwrap()
    .unwrap()
  defer ignore(stream.close())
  assert_eq(read_bytes.val, bytes.length())
  let events : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => events.push(event)
      None => break
    }
    assert_eq(read_bytes.val, bytes.length())
  }
  assert_eq(events.map(event => event.text), [
    "a", "", "😀", "", "z", "", "0", "{\"b\":2}",
  ])
  assert_true(events[2].source_ref.unwrap().line_start == Some(2))
  assert_true(events[2].source_ref.unwrap().json_pointer is None)
  assert_true(events[6].source_ref.unwrap().json_pointer == Some("/0"))
  assert_true(events[7].source_ref.unwrap().json_pointer == Some("/2"))
  let summary = (stream.finish)().unwrap()
  assert_true(
    summary.diagnostics.metrics.get("jsonl_spool_records_parsed") == Some("4"),
  )
  let budget = @input.input_source_budget_context(session.source).unwrap().account
  assert_eq(budget.snapshot().resident_peak.temporary_bytes, 214L)
  assert_eq(budget.snapshot().resident.temporary_bytes, 0L)
  assert_eq(read_bytes.val, bytes.length())
  assert_true((stream.next)() is Ok(None))
}

///|
async test "JSONL collect spool retains full table sources and both source phases use actual ordinals" {
  let text = "0\n{\"a\":1}\n{\"b\":2}\n{\"a\":3}\n"
  let session = @input.begin_input_session(
    @input.input_from_text_with_format(text, "mixed.jsonl", Some(Jsonl)),
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let parsed = parse_line_delimited_json_result(
    "jsonl_parser",
    "jsonl",
    session.source,
    spool_test_context(1024L),
  ).unwrap()
  let events = parsed.event_stream.unwrap()
  let cells = events.filter(event => event.kind == Cell)
  assert_eq(cells.map(event => event.text), ["a", "1", "3"])
  assert_true(
    cells[0].source_ref.unwrap().extra.get("synthetic_header") == Some("true"),
  )
  for (at, ordinal, line, cell) in [(1, 1, 2, "R2C1"), (2, 3, 4, "R3C1")] {
    let reference = cells[at].source_ref.unwrap()
    assert_eq(reference.line_start.unwrap_or(-1), line)
    assert_eq(
      reference.json_pointer.unwrap_or("MISSING"),
      "/" + ordinal.to_string(),
    )
    assert_true(reference.cell_range == Some(cell))
    assert_true(
      reference.extra.get("record_index") == Some(ordinal.to_string()),
    )
  }
  assert_eq(
    @input.input_source_budget_context(session.source).unwrap().account.snapshot().resident.temporary_bytes,
    0L,
  )
}

///|
async test "JSONL source IO errors and encoding errors cannot take raw syntax recovery" {
  for malformed in [false, true] {
    let source = if malformed {
      @input.input_from_bytes(b"{\"a\":1}\n\xff\n", source_name="broken.jsonl")
    } else {
      @input.input_from_reader(
        @input.make_input_reader(fn(_, _) { Err("real reader failure") }),
        source_name="broken.jsonl",
      )
    }
    let session = @input.begin_input_session(source)
    defer @input.end_input_session(session)
    let cleanup = @input.begin_input_cleanup_scope(session)
    defer ignore(@input.cleanup_input_scope(cleanup))
    assert_true(
      open_line_json_event_stream(
        "jsonl_parser",
        "jsonl",
        session.source,
        spool_test_context(1024L),
        jsonl_parser_capability(),
      )
      is Err(_),
    )
    assert_true(
      @input.input_source_failure(session.source) is Some(InputError(_)),
    )
    assert_true(@input.cleanup_input_scope(cleanup) is Err(_))
    let sample = @input.input_source_budget_context(session.source).unwrap().account.snapshot()
    assert_eq(sample.resident.temporary_bytes, 0L)
    assert_eq(sample.active_leases, 0L)
  }
}

///|
async test "JSONL codec working admission precedes buffer allocation and keeps its typed first error" {
  let account = spool_test_account(100L, working=0L)
  let session = @input.begin_input_session(
    @input.input_from_text("codec"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let owner = create_line_json_spool_owner(session.source, account, 100L).unwrap()
  assert_true(
    append_line_json_spool_frame(
      owner,
      session.source,
      account,
      b'\x00',
      1,
      0,
      "0123456789",
    )
    is Err(_),
  )
  assert_eq(owner.length(), 0L)
  assert_true(
    @input.input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(Resident(WorkingBytes), used=0L, requested=60L, limit=0L)
      )
    ),
  )
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(@input.cleanup_input_scope(cleanup) is Err(_))
  assert_true(owner.cleanup_complete())
}

///|
async test "nested JSONL spool shares live temporary storage and never replaces its parent's cap" {
  let account = spool_test_account(102L)
  let parent = @input.begin_input_session(
    @input.input_from_text("parent"),
    budget=account,
  )
  defer @input.end_input_session(parent)
  let cleanup = @input.begin_input_cleanup_scope(parent)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let existing = create_line_json_spool_owner(parent.source, account, 102L).unwrap()
  existing.append(b"x").unwrap()
  let child = @input.input_source_inherit_session(
    @input.input_from_text_with_format(
      "{\"a\":1}\n",
      "child.jsonl",
      Some(Jsonl),
    ),
    parent.source,
  )
  assert_true(
    open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      child,
      spool_test_context(204L),
      jsonl_parser_capability(),
    )
    is Err(_),
  )
  assert_true(account.snapshot().limits.temporary_bytes == Some(102L))
  assert_true(
    @input.input_source_failure(parent.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Resident(TemporaryBytes),
          used=78L,
          requested=25L,
          limit=102L
        )
      )
    ),
  )
  assert_true(@input.cleanup_input_scope(cleanup) is Err(_))
  assert_true(existing.cleanup_complete())
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_false(account.snapshot().closed)
}

///|
async test "cancellation while JSONL input awaits cleans both registered real files without closing its caller" {
  let entered = Ref(false)
  let resumed = Ref(false)
  let calls = Ref(0)
  let reader = @input.make_async_input_reader(async fn(_, _) {
    calls.val += 1
    if calls.val == 1 {
      return Ok(b"{\"a\":1}\n")
    }
    entered.val = true
    @async.sleep(60000)
    resumed.val = true
    Ok(b"")
  })
  let parent = @input.begin_input_session(
    @input.input_from_reader(reader, source_name="cancel.jsonl"),
  )
  defer @input.end_input_session(parent)
  let cleanup = @input.begin_input_cleanup_scope(parent)
  defer ignore(@input.cleanup_input_scope(cleanup))
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        defer ignore(@input.cleanup_input_scope(cleanup))
        ignore(
          open_line_json_event_stream(
            "jsonl_parser",
            "jsonl",
            parent.source,
            spool_test_context(1024L),
            jsonl_parser_capability(),
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
  assert_false(resumed.val)
  assert_eq(calls.val, 2)
  let sample = @input.input_source_budget_context(parent.source).unwrap().account.snapshot()
  assert_eq(sample.resident.temporary_bytes, 0L)
  assert_eq(sample.resident.working_bytes, 0L)
  assert_eq(sample.active_leases, 0L)
  assert_false(sample.closed)
}

///|
async test "JSONL frame positions cross byte boundaries without narrowing the stored ordinal" {
  let account = spool_test_account(26L)
  let session = @input.begin_input_session(
    @input.input_from_text("codec"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let owner = create_line_json_spool_owner(session.source, account, 26L).unwrap()
  append_line_json_spool_frame(
    owner,
    session.source,
    account,
    b'\x00',
    70001,
    65539,
    "x",
  ).unwrap()
  owner.seal().unwrap()
  let cursor : LineJsonSpoolCursor = {
    owner,
    range: owner.range(0L, 26L).unwrap(),
    offset: 0L,
  }
  let frame = next_line_json_spool_frame(
      cursor,
      session.source,
      @input.input_source_budget_context(session.source).unwrap(),
    )
    .unwrap()
    .unwrap()
  assert_eq(frame.line, 70001)
  assert_eq(frame.record, 65539)
  assert_eq(frame.text, "x")
}

///|
async test "JSONL admitted prefix adds no tail read after the existing bounded input chunk" {
  let prefix = b"{\"a\":1}\n" + Bytes::make(64 * 1024 - 8, b' ')
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(offset, length) {
      calls.val += 1
      if offset >= prefix.length().to_int64() {
        return Err("unadmitted tail must not be read")
      }
      let start = offset.to_int()
      Ok(prefix[start:(start + length).min(prefix.length())].to_owned())
    },
    size=prefix.length().to_int64() + 1L,
  )
  let session = @input.begin_input_session(
    @input.input_from_reader(reader, source_name="prefix.jsonl"),
  )
  defer @input.end_input_session(session)
  let cleanup = @input.begin_input_cleanup_scope(session)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let initial = spool_test_context(102L)
  let context = @parser.parse_context_with_limits(
    initial,
    Some(StreamingEvent),
    Some(1),
    Some(50),
    Some(10000),
    Some(4000),
    false,
  )
  let stream = open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      session.source,
      context,
      jsonl_parser_capability(),
    )
    .unwrap()
    .unwrap()
  defer ignore(stream.close())
  let texts : Array[String] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => texts.push(event.text)
      None => break
    }
  }
  assert_eq(texts, ["a", "", "1", ""])
  ignore((stream.finish)().unwrap())
  assert_eq(calls.val, 1)
  assert_true(@input.input_source_failure(session.source) is None)
}
