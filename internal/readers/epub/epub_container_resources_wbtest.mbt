///|
// Candidate-only resource contracts follow the preserved original-v11 run.
fn container_test_budget(
  parse~ : Int64? = None,
  metadata~ : Int64? = None,
) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=parse,
      output_utf8_bytes=None,
      source_metadata_bytes=metadata,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
fn container_test_archive(
  bytes : Bytes,
  budget : @budget.Budget,
) -> (@zip.ZipArchive, @input.InputSession) raise {
  let session = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget~,
  )
  let context = @input.input_source_budget_context(session.source).unwrap()
  let archive = @zip.open_zip(bytes, budget_context=context)
  @zip.set_hard_failure_reporter(archive, message => {
    @input.record_input_failure(session.source, message)
  })
  (archive, session)
}

///|
fn container_test_bytes(xml : Bytes) -> Bytes {
  @zip.build_store_zip_bytes([(EPUB_CONTAINER_PART, xml)])
}

///|
fn container_test_index() -> Map[String, String] {
  let index : Map[String, String] = { "OPS/content.opf": "OPS/content.opf" }
  index[EPUB_CONTAINER_PART] = EPUB_CONTAINER_PART
  index
}

///|
// These fixtures use STORE entries and an otherwise fresh account. The ZIP
// visitor deliberately scope-retains every delivered chunk as WorkingBytes;
// its admitted payload equals the cumulative InflateBytes here, even on
// replay. Every additional cursor/replay private lease must already be gone.
fn container_test_private_workspace_retired(
  budget : @budget.Budget,
  session : @input.InputSession,
) -> Unit raise {
  let snapshot = budget.snapshot()
  assert_eq(snapshot.resident.working_bytes, snapshot.cumulative.inflate_bytes)
  @input.end_input_session(session)
  assert_eq(budget.snapshot().resident.working_bytes, 0L)
  assert_eq(budget.snapshot().resident.cache_bytes, 0L)
  assert_true(budget.snapshot().closed)
}

///|
async test "container cursor chunk boundaries and deep ignored elements preserve existing unlimited depth policy" {
  let deep = StringBuilder()
  deep.write_string("<container>")
  for _ in 0..<300 {
    deep.write_string("<unknown>")
  }
  for _ in 0..<300 {
    deep.write_string("</unknown>")
  }
  deep.write_string(
    "<rootfiles><rootfile full-path='OPS/content&#x2e;opf'/></rootfiles></container>",
  )
  let xml = @utf8.encode(deep.to_string())
  for size in [1, 2, 3, 7, 65536] {
    let budget = container_test_budget()
    let (archive, session) = container_test_archive(
      container_test_bytes(xml),
      budget,
    )
    defer @input.end_input_session(session)
    let rows = read_container_rootfiles(
      archive,
      container_test_index(),
      chunk_size=size,
    )
    assert_eq(rows.length(), 1)
    assert_eq(rows[0].full_path, "OPS/content.opf")
    assert_true(rows[0].is_primary)
    container_test_private_workspace_retired(budget, session)
    assert_true(budget.snapshot().cumulative.parse_work > 0L)
  }
}

///|
async test "container cursor zero ParseWork retains typed account first error and releases private workspace" {
  let budget = container_test_budget(parse=Some(0L))
  let bytes = container_test_bytes(
    b"<container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
  )
  let (archive, session) = container_test_archive(bytes, budget)
  defer @input.end_input_session(session)
  let result = Ok(
    read_container_rootfiles(archive, container_test_index(), chunk_size=7),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(_))
  assert_true(
    @input.input_source_failure(session.source) is Some(BudgetFailure(_)),
  )
  assert_true(
    budget.failure() is Some(LimitExceeded(Cumulative(ParseWork), ..)),
  )
  container_test_private_workspace_retired(budget, session)
}

///|
async test "container selected rootfile metadata admission is hard and publishes no rows" {
  let budget = container_test_budget(metadata=Some(0L))
  let (archive, session) = container_test_archive(
    container_test_bytes(
      b"<container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
    ),
    budget,
  )
  defer @input.end_input_session(session)
  let published : Ref[Array[EpubRootfileInfo]?] = Ref(None)
  let result = try {
    published.val = Some(
      read_container_rootfiles(archive, container_test_index(), chunk_size=3),
    )
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_true(result is Err(_))
  assert_true(published.val is None)
  assert_true(
    @input.input_source_failure(session.source) is Some(BudgetFailure(_)),
  )
  container_test_private_workspace_retired(budget, session)
}

///|
async test "container malformed prefix cannot hide late invalid UTF8" {
  let tail = StringBuilder()
  tail.write_string("<wrong/>")
  for _ in 0..<200 {
    tail.write_char(' ')
  }
  let budget = container_test_budget()
  let (archive, session) = container_test_archive(
    container_test_bytes(@utf8.encode(tail.to_string()) + b"\xff"),
    budget,
  )
  defer @input.end_input_session(session)
  let result = Ok(
    read_container_rootfiles(archive, container_test_index(), chunk_size=8),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(InvalidEncoding(_)))
  assert_true(@zip.archive_hard_failure(archive) is Some(_))
  container_test_private_workspace_retired(budget, session)
}

///|
async test "container malformed prefix cannot hide same-entry CRC failure" {
  let bytes = container_test_bytes(b"<wrong/>            ").to_array()
  bytes[30 + EPUB_CONTAINER_PART.length() + 1] = b'v'
  let budget = container_test_budget()
  let (archive, session) = container_test_archive(
    Bytes::from_array(bytes),
    budget,
  )
  defer @input.end_input_session(session)
  let result = Ok(
    read_container_rootfiles(archive, container_test_index(), chunk_size=8),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(ZipError(_)))
  assert_true(@zip.archive_hard_failure(archive) is Some(_))
  container_test_private_workspace_retired(budget, session)
}

///|
async test "container prior budget failure stops before another Reader callback" {
  let data = container_test_bytes(b"<container/>")
  let budget = container_test_budget(parse=Some(0L))
  let session = @input.begin_input_session(
    @input.input_from_bytes(data),
    budget~,
  )
  defer @input.end_input_session(session)
  let context = @input.input_source_budget_context(session.source).unwrap()
  let calls = Ref(0)
  let archive = @zip.open_zip_reader(
    data.length(),
    fn(offset, length) {
      calls.val += 1
      Ok(data.exact_view(start=offset, end=offset + length).to_owned())
    },
    budget_context=context,
  )
  @zip.set_hard_failure_reporter(archive, message => {
    @input.record_input_failure(session.source, message)
  })
  let before = calls.val
  assert_true(budget.charge(ParseWork, 1L) is Err(_))
  let result = Ok(read_container_rootfiles(archive, container_test_index())) catch {
    error => Err(error)
  }
  assert_true(result is Err(_))
  assert_eq(calls.val, before)
  assert_true(
    @input.input_source_failure(session.source) is Some(BudgetFailure(_)),
  )
}

///|
async test "container pending Reader cancellation releases cursor workspace without closing caller account" {
  let data = container_test_bytes(
    b"<container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>",
  )
  let budget = container_test_budget()
  let session = @input.begin_input_session(
    @input.input_from_bytes(data),
    budget~,
  )
  defer @input.end_input_session(session)
  let context = @input.input_source_budget_context(session.source).unwrap()
  let pending = Ref(false)
  let started = Ref(false)
  let archive = @zip.open_zip_reader(
    data.length(),
    async fn(offset, length) {
      if pending.val && offset == 30 + EPUB_CONTAINER_PART.length() {
        started.val = true
        @async.sleep(200)
      }
      Ok(data.exact_view(start=offset, end=offset + length).to_owned())
    },
    budget_context=context,
  )
  pending.val = true
  let result = @async.with_timeout_opt(5, async fn() {
    read_container_rootfiles(archive, container_test_index(), chunk_size=8)
  })
  assert_true(started.val)
  assert_true(result is None)
  assert_eq(budget.snapshot().resident.working_bytes, 0L)
  assert_true(budget.failure() is None)
  assert_false(budget.snapshot().closed)
  pending.val = false
  assert_eq(
    read_container_rootfiles(archive, container_test_index(), chunk_size=8).length(),
    1,
  )
}
