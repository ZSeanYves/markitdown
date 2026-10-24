///|
fn temporary_profile_account(cap : Int64?) -> @budget.Budget {
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
      working_bytes=None,
      temporary_bytes=cap,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
async test "finite temporary sidecar reports the effective borrowed parent cap rather than the public request" {
  let account = temporary_profile_account(Some(102L))
  let parent = @input.begin_input_session(
    @input.input_from_text_with_format(
      "{\"a\":1}\n",
      "effective.jsonl",
      Some(Jsonl),
    ),
    budget=account,
  )
  defer @input.end_input_session(parent)
  let limits = @product.make_resource_limits(
    200,
    50,
    10000,
    max_temporary_bytes=Some(204L),
  )
  let result = convert_input(
    parent.source,
    make_convert_options(Balanced, Debug, Some(Jsonl), limits),
  ).unwrap()
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_limit_bytes") ==
    Some("102"),
  )
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_payload_peak_bytes") ==
    Some("102"),
  )
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_current_bytes") ==
    Some("0"),
  )
  assert_false(account.snapshot().closed)
}

///|
async test "temporary sidecar preserves shared historical peak and another owner's current credits after tightening" {
  let account = temporary_profile_account(None)
  let historical = account.reserve(TemporaryBytes, 300L).unwrap()
  historical.release()
  let caller_live = account.reserve(TemporaryBytes, 1L).unwrap()
  defer caller_live.release()
  let parent = @input.begin_input_session(
    @input.input_from_text_with_format("text", "history.txt", Some(Txt)),
    budget=account,
  )
  defer @input.end_input_session(parent)
  let limits = @product.make_resource_limits(
    200,
    50,
    10000,
    max_temporary_bytes=Some(102L),
  )
  let result = convert_input(
    parent.source,
    make_convert_options(Balanced, Debug, Some(Txt), limits),
  ).unwrap()
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_limit_bytes") ==
    Some("102"),
  )
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_payload_peak_bytes") ==
    Some("300"),
  )
  assert_true(
    result.diagnostics.metrics.get("budget_temporary_current_bytes") ==
    Some("1"),
  )
  assert_false(account.snapshot().closed)
  assert_true(@input.input_source_failure(parent.source) is None)
  caller_live.release()
}
