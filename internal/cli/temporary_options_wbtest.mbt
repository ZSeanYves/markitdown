///|
test "CLI temporary ceiling accepts exact decimal values and propagates single and batch options" {
  for value in [0L, 1L, 9223372036854775807L] {
    let text = value.to_string()
    let single = parse_cli_options([
      "--max-temporary-bytes", text, "records.jsonl",
    ]).unwrap()
    assert_true(single.max_temporary_bytes == Some(value))
    assert_true(cli_resource_limits(single).max_temporary_bytes == Some(value))
    let normalized = normalize_cli_args([
      "markitdown",
      "--max-temporary-bytes=" + text,
      "records.jsonl",
    ])
    let equal = parse_cli_options(normalized).unwrap()
    assert_true(equal.max_temporary_bytes == Some(value))
    let batch = parse_batch_cli_options(
      ["batch", "--max-temporary-bytes", text, "inputs", "outputs"],
      1,
    ).unwrap()
    assert_true(batch.0.max_temporary_bytes == Some(value))
    assert_true(cli_resource_limits(batch.0).max_temporary_bytes == Some(value))
  }
  let absent = parse_cli_options(["records.jsonl"]).unwrap()
  assert_true(absent.max_temporary_bytes is None)
  assert_true(cli_resource_limits(absent).max_temporary_bytes is None)
  let repeated = parse_cli_options([
    "--max-temporary-bytes", "9", "--max-temporary-bytes", "3", "records.jsonl",
  ]).unwrap()
  assert_true(repeated.max_temporary_bytes == Some(3L))
}

///|
test "CLI temporary ceiling rejects unsupported number syntax and overflow as usage errors" {
  for
    value in [
      "", "-1", "+1", "1_024", "0x10", "1.5", "1KiB", "9223372036854775808",
    ] {
    assert_true(
      parse_cli_options(["--max-temporary-bytes", value, "records.jsonl"])
      is Err(_),
    )
  }
  assert_true(parse_cli_options(["--max-temporary-bytes"]) is Err(_))
  assert_eq(
    cli_failure_exit_code(cli_failure(UsageFailure, "invalid limit")),
    2,
  )
}
