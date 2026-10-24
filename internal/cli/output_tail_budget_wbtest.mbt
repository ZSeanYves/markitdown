///|
fn output_tail_account(limit : Int64) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=Some(limit),
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=Some(4096L),
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
async test "Atomic tail confirmation augments only the CLI metric after converter body confirmation" {
  let root = test_tmp_root() + "/output-tail-confirmation"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let account = output_tail_account(4L)
  let source = @input.begin_input_session(
    @input.input_from_text_with_format("abc", "body.txt", Some(Txt)),
    budget=account,
  )
  defer @input.end_input_session(source)
  let options = atomic_test_options(4096L, Txt)
  let owner = open_budgeted_atomic_writer(
    source.source,
    options.limits,
    root + "/out.md",
  ).unwrap()
  let output = open_cli_atomic_output(owner)
  let result = @convert.convert_input_to_sink_unbuffered(
    source.source,
    options,
    output.sink,
  ).unwrap()
  assert_eq(result.content, "")
  assert_true(
    result.diagnostics.metrics.get("budget_output_confirmed_utf8_bytes") ==
    Some("3"),
  )
  let tail = output.tail.val.unwrap()
  assert_true(tail.confirmed.val)
  assert_eq(account.snapshot().cumulative.output_utf8_bytes, 4L)
  budgeted_atomic_commit(owner).unwrap()
  apply_cli_file_tail(tail, result.diagnostics).unwrap()
  apply_cli_file_tail(tail, result.diagnostics).unwrap()
  assert_true(
    result.diagnostics.metrics.get("budget_output_confirmed_utf8_bytes") ==
    Some("4"),
  )
  assert_true(
    result.diagnostics.metrics.get("budget_output_admitted_utf8_bytes") ==
    Some("4"),
  )
  assert_eq(result.content, "")
  assert_eq(read_utf8_text(root + "/out.md"), "abc\n")
}

///|
async test "file tail confirmation requires actual successful writing" {
  let root = test_tmp_root() + "/output-tail-write-error"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output_path = root + "/directory-output"
  @asset_fs.mkdir(output_path)
  let account = output_tail_account(4L)
  let source = @input.begin_input_session(
    @input.input_from_text_with_format("abc", "body.txt", Some(Txt)),
    budget=account,
  )
  defer @input.end_input_session(source)
  let options = atomic_test_options(4096L, Txt)
  let execution = @convert.convert_input_with_provenance(source.source, options).unwrap()
  let result = cli_render_convert_result(
    cli_options("body.txt", Some(output_path), Some(Txt), Markdown),
    execution.result,
    source.source,
    options.limits,
  )
  assert_true(result is Err(failure) && failure.kind == OutputFailure)
  assert_eq(account.snapshot().cumulative.output_utf8_bytes, 4L)
  assert_true(
    execution.result.diagnostics.metrics.get(
      "budget_output_confirmed_utf8_bytes",
    ) ==
    Some("3"),
  )
  assert_eq(execution.result.content, "abc")
}

///|
async test "already terminated file content and an empty callback do not admit a second LF" {
  let root = test_tmp_root() + "/output-tail-already-terminated"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let account = output_tail_account(2L)
  let source = @input.begin_input_session(
    @input.input_from_text("source"),
    budget=account,
  )
  defer @input.end_input_session(source)
  let owner = open_budgeted_atomic_writer(
    source.source,
    atomic_test_options(4096L, Txt).limits,
    root + "/out.md",
  ).unwrap()
  let output = open_cli_atomic_output(owner)
  account.charge(OutputUtf8Bytes, 2L).unwrap()
  (output.sink.write)("x\n").unwrap()
  (output.sink.write)("").unwrap()
  (output.sink.finish)().unwrap()
  assert_eq(output.tail.val.unwrap().added_bytes, 0L)
  assert_true((output.sink.finish)() is Err(_))
  assert_eq(account.snapshot().cumulative.output_utf8_bytes, 2L)
  budgeted_atomic_commit(owner).unwrap()
  assert_eq(read_utf8_text(root + "/out.md"), "x\n")
  assert_eq(normalized_written_content(""), "")
  assert_eq(normalized_written_content("x\n"), "x\n")
}

///|
async test "CLI added LF must fail before file mutation when OutputUtf8Bytes has only body capacity" {
  for streamed in [false, true] {
    let root = test_tmp_root() + "/output-tail-reject-" + streamed.to_string()
    recreate_clean_dir(root)
    defer cleanup_temp_dir(root)
    let output = root + "/out.md"
    write_utf8_text(output, "previous target")
    let account = output_tail_account(3L)
    let source = @input.begin_input_session(
      @input.input_from_text_with_format("abc", "body.txt", Some(Txt)),
      budget=account,
    )
    defer @input.end_input_session(source)
    let options = atomic_test_options(4096L, Txt)
    let opts = cli_options("body.txt", Some(output), Some(Txt), Markdown)
    let result = if streamed {
      cli_convert_to_atomic_stream_file(opts, options, false, source.source)
    } else {
      let execution = @convert.convert_input_with_provenance(
        source.source,
        options,
      ).unwrap()
      assert_eq(execution.result.content, "abc")
      cli_render_convert_result(
        opts,
        execution.result,
        source.source,
        options.limits,
      )
    }
    guard result is Err(failure) else {
      fail("CLI LF bypassed OutputUtf8Bytes")
    }
    assert_true(failure.kind == ResourceFailure)
    assert_eq(cli_failure_exit_code(failure), 5)
    assert_true(
      failure.message.contains(
        "resource limit exceeded: output_utf8_bytes; observed=4; limit=3",
      ),
    )
    assert_eq(read_utf8_text(output), "previous target")
    assert_eq(account.snapshot().cumulative.output_utf8_bytes, 3L)
    assert_eq(account.snapshot().resident.temporary_bytes, 0L)
    assert_eq(@asset_fs.readdir(root).length(), 1)
  }
}

///|
async test "CLI successful LF counts one transport byte while converter content keeps body semantics" {
  for streamed in [false, true] {
    let root = test_tmp_root() + "/output-tail-success-" + streamed.to_string()
    recreate_clean_dir(root)
    defer cleanup_temp_dir(root)
    let output = root + "/out.md"
    let account = output_tail_account(4L)
    let source = @input.begin_input_session(
      @input.input_from_text_with_format("abc", "body.txt", Some(Txt)),
      budget=account,
    )
    defer @input.end_input_session(source)
    let options = atomic_test_options(4096L, Txt)
    let opts = cli_options("body.txt", Some(output), Some(Txt), Markdown)
    if streamed {
      assert_true(
        cli_convert_to_atomic_stream_file(opts, options, false, source.source)
        is Ok("abc\n"),
      )
    } else {
      let execution = @convert.convert_input_with_provenance(
        source.source,
        options,
      ).unwrap()
      assert_eq(execution.result.content, "abc")
      assert_true(
        execution.result.diagnostics.metrics.get(
          "budget_output_confirmed_utf8_bytes",
        ) ==
        Some("3"),
      )
      assert_true(
        cli_render_convert_result(
          opts,
          execution.result,
          source.source,
          options.limits,
        )
        is Ok("abc\n"),
      )
      assert_eq(execution.result.content, "abc")
      assert_true(
        execution.result.diagnostics.metrics.get(
          "budget_output_confirmed_utf8_bytes",
        ) ==
        Some("4"),
      )
      assert_true(
        execution.result.diagnostics.metrics.get(
          "budget_output_admitted_utf8_bytes",
        ) ==
        Some("4"),
      )
    }
    assert_eq(read_utf8_text(output), "abc\n")
    assert_eq(account.snapshot().cumulative.output_utf8_bytes, 4L)
    assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  }
}
