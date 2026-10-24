///|
test "asset payload checks report typed failures and retain the reporter in context copies" {
  let failures : Array[@input.ResourceLimitFailure] = []
  let context = parse_context_with_resource_failure_reporter(
    parse_context_with_asset_limits(new_parse_context(Docx), 3L, 6L),
    failure => failures.push(failure),
  )
  assert_true(require_asset_payload_within_limits(context, 3L, 3L))
  assert_eq(failures.length(), 0)
  assert_false(require_asset_payload_within_limits(context, 4L, 0L))
  assert_true(failures[0].kind is SingleAssetBytes)
  assert_eq(failures[0].observed, 4L)
  assert_eq(failures[0].limit, 3L)
  let copied = parse_context_with_asset_limits(context, 3L, 5L)
  assert_false(require_asset_payload_within_limits(copied, 3L, 3L))
  assert_true(failures[1].kind is TotalAssetBytes)
  assert_eq(failures[1].observed, 6L)
  assert_eq(failures[1].limit, 5L)
}

///|
test "asset payload total overflow cannot wrap into an allowed amount" {
  let failures : Array[@input.ResourceLimitFailure] = []
  let context = parse_context_with_resource_failure_reporter(
    parse_context_with_asset_limits(
      new_parse_context(Docx),
      1L,
      9223372036854775807L,
    ),
    failure => failures.push(failure),
  )
  assert_false(
    require_asset_payload_within_limits(context, 1L, 9223372036854775807L),
  )
  assert_eq(failures.length(), 1)
  assert_true(failures[0].kind is TotalAssetBytes)
  assert_eq(failures[0].observed, 9223372036854775807L)
}
