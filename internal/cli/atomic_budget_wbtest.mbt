///|
fn atomic_test_options(
  cap : Int64,
  format : @input.DetectedFormat,
) -> @convert.ConvertOptions {
  @convert.make_convert_options(
    Balanced,
    Markdown,
    Some(format),
    @product.make_resource_limits(
      2000,
      50,
      100000,
      max_temporary_bytes=Some(cap),
    ),
  )
}

///|
async test "atomic tiny writes grow one shared credit and confirmed rename refunds it once" {
  let root = test_tmp_root() + "/atomic-budget-grow"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let session = @input.begin_input_session(@input.input_from_text("source"))
  defer @input.end_input_session(session)
  let account = @input.input_source_budget_context(session.source).unwrap().account
  let owner = open_budgeted_atomic_writer(
    session.source,
    atomic_test_options(1000L, Txt).limits,
    root + "/out.md",
  ).unwrap()
  assert_true(owner.credit.val is None)
  assert_eq(account.snapshot().active_leases, 0L)
  for _ in 0..<1000 {
    budgeted_atomic_write(owner, "x").unwrap()
  }
  assert_eq(account.snapshot().resident.temporary_bytes, 1000L)
  assert_eq(account.snapshot().active_leases, 1L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  budgeted_atomic_commit(owner).unwrap()
  assert_true(owner.credit.val is None)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 1000L)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_eq(read_utf8_text(root + "/out.md").length(), 1000)
  assert_true(budgeted_atomic_write(owner, "after close") is Err(_))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  budgeted_atomic_abort(owner).unwrap()
}

///|
async test "atomic file shares sibling credit and rejects full growth before the failing write" {
  let root = test_tmp_root() + "/atomic-budget-peer"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let session = @input.begin_input_session(@input.input_from_text("source"))
  defer @input.end_input_session(session)
  let account = @input.input_source_budget_context(session.source).unwrap().account
  let peer = account.reserve(TemporaryBytes, 5L).unwrap()
  defer peer.release()
  let owner = open_budgeted_atomic_writer(
    session.source,
    atomic_test_options(10L, Txt).limits,
    root + "/out.md",
  ).unwrap()
  budgeted_atomic_write(owner, "12345").unwrap()
  assert_true(budgeted_atomic_write(owner, "6") is Err(_))
  assert_eq(atomic_writer_last_write_count_ffi(owner.writer), 5L)
  assert_true(
    @input.input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Resident(TemporaryBytes),
          used=10L,
          requested=1L,
          limit=10L
        )
      )
    ),
  )
  budgeted_atomic_abort(owner).unwrap()
  assert_eq(account.snapshot().resident.temporary_bytes, 5L)
  peer.release()
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(@asset_fs.readdir(root).length(), 0)
}

///|
async test "real JSONL parser spool and atomic output reject their aggregate before publishing an old target" {
  let root = test_tmp_root() + "/atomic-budget-parser-shared"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output = root + "/out.md"
  write_utf8_text(output, "previous target")
  let session = @input.begin_input_session(
    @input.input_from_text_with_format("{\"a\":1}\n", "one.jsonl", Some(Jsonl)),
  )
  defer @input.end_input_session(session)
  let opts = cli_options("one.jsonl", Some(output), Some(Jsonl), Markdown)
  let result = cli_convert_to_atomic_stream_file(
    opts,
    atomic_test_options(102L, Jsonl),
    false,
    session.source,
  )
  assert_true(result is Err(failure) && failure.kind == ResourceFailure)
  assert_true(
    @input.input_source_failure(session.source)
    is Some(
      BudgetFailure(
        LimitExceeded(
          Resident(TemporaryBytes),
          used=102L,
          requested=more,
          limit=102L
        )
      )
    ) &&
    more > 0L,
  )
  assert_eq(read_utf8_text(output), "previous target")
  assert_eq(@asset_fs.readdir(root).length(), 1)
  let sample = @input.input_source_budget_context(session.source).unwrap().account.snapshot()
  assert_eq(sample.resident.temporary_bytes, 0L)
  assert_false(sample.closed)
}

///|
async test "atomic final newline is admitted on the same cap and preserves canonical resource failure" {
  for (cap, success) in [(3L, false), (4L, true)] {
    let root = test_tmp_root() + "/atomic-budget-newline-" + cap.to_string()
    recreate_clean_dir(root)
    defer cleanup_temp_dir(root)
    let output = root + "/out.md"
    write_utf8_text(output, "old target")
    let session = @input.begin_input_session(
      @input.input_from_text_with_format("abc", "abc.txt", Some(Txt)),
    )
    defer @input.end_input_session(session)
    let result = cli_convert_to_atomic_stream_file(
      cli_options("abc.txt", Some(output), Some(Txt), Markdown),
      atomic_test_options(cap, Txt),
      false,
      session.source,
    )
    if success {
      assert_true(result is Ok("abc\n"))
      assert_eq(read_utf8_text(output), "abc\n")
    } else {
      guard result is Err(failure) else {
        fail("newline bypassed shared capacity")
      }
      assert_true(failure.kind == ResourceFailure)
      assert_eq(cli_failure_exit_code(failure), 5)
      assert_true(
        failure.message.contains(
          "resource limit exceeded: temporary_bytes; observed=4; limit=3",
        ),
      )
      assert_eq(read_utf8_text(output), "old target")
    }
    assert_eq(
      @input.input_source_budget_context(session.source).unwrap().account.snapshot().resident.temporary_bytes,
      0L,
    )
    assert_eq(@asset_fs.readdir(root).length(), 1)
  }
}

///|
async test "real JSONL and atomic shared peak is an exact boundary without resetting the parent account" {
  let peak = Ref(0L)
  let body = Ref("")
  for attempt in 0..<3 {
    let cap = if attempt == 0 {
      4096L
    } else if attempt == 1 {
      peak.val
    } else {
      peak.val - 1L
    }
    let root = test_tmp_root() +
      "/atomic-budget-shared-exact-" +
      attempt.to_string()
    recreate_clean_dir(root)
    defer cleanup_temp_dir(root)
    let output = root + "/out.md"
    write_utf8_text(output, "old target")
    let session = @input.begin_input_session(
      @input.input_from_text_with_format(
        "{\"a\":1}\n",
        "one.jsonl",
        Some(Jsonl),
      ),
    )
    defer @input.end_input_session(session)
    let account = @input.input_source_budget_context(session.source).unwrap().account
    let result = cli_convert_to_atomic_stream_file(
      cli_options("one.jsonl", Some(output), Some(Jsonl), Markdown),
      atomic_test_options(cap, Jsonl),
      false,
      session.source,
    )
    if attempt == 0 {
      body.val = result.unwrap()
      peak.val = account.snapshot().resident_peak.temporary_bytes
      assert_true(peak.val > 102L)
      println("atomic parser/output shared peak bytes=" + peak.val.to_string())
    } else if attempt == 1 {
      assert_true(result is Ok(text) && text == body.val)
      assert_eq(account.snapshot().resident_peak.temporary_bytes, peak.val)
    } else {
      assert_true(result is Err(failure) && failure.kind == ResourceFailure)
      assert_eq(read_utf8_text(output), "old target")
    }
    assert_eq(account.snapshot().resident.temporary_bytes, 0L)
    assert_false(account.snapshot().closed)
    assert_eq(@asset_fs.readdir(root).length(), 1)
  }
}

///|
async test "atomic cleanup retry keeps live credit and the typed budget failure until removal is certain" {
  let root = test_tmp_root() + "/atomic-budget-remove-retry"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let session = @input.begin_input_session(@input.input_from_text("source"))
  defer @input.end_input_session(session)
  let account = @input.input_source_budget_context(session.source).unwrap().account
  let owner = open_budgeted_atomic_writer(
    session.source,
    atomic_test_options(3L, Txt).limits,
    root + "/out.md",
  ).unwrap()
  budgeted_atomic_write(owner, "abc").unwrap()
  assert_true(budgeted_atomic_write(owner, "x") is Err(_))
  let original = cli_atomic_failure(session.source, "must use typed data")
  let sibling = root + "/" + @asset_fs.readdir(root)[0]
  let parked = root + "/parked"
  @asset_fs.rename(sibling, parked)
  @asset_fs.mkdir(sibling)
  let combined = cli_abort_budgeted_atomic_failure(owner, original)
  assert_true(combined.kind == ResourceFailure)
  assert_true(combined.message.contains("atomic cleanup remove failed"))
  assert_eq(account.snapshot().resident.temporary_bytes, 3L)
  assert_true(owner.credit.val is Some(_))
  assert_false(atomic_writer_reclamation_certain_ffi(owner.writer))
  @asset_fs.rmdir(sibling)
  @asset_fs.rename(parked, sibling)
  assert_true(budgeted_atomic_abort(owner) is Err(_))
  assert_true(owner.credit.val is None)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(
    account.failure()
    is Some(
      LimitExceeded(Resident(TemporaryBytes), used=3L, requested=1L, limit=3L)
    ),
  )
}
