///|
test "container asset allowance translates asset totals and preserves MIME structural failures" {
  let failures : Array[@input.ResourceLimitFailure] = []
  let parent = @parser.parse_context_with_resource_failure_reporter(
    @parser.parse_context_with_asset_limits(
      @parser.new_parse_context(Eml),
      7L,
      20L,
    ),
    failure => failures.push(failure),
  )
  let child = parse_context_with_remaining_asset_bytes(parent, 5L)
  for
    (kind, observed, limit) in [
      (@input.ResourceLimitKind::MimeNestingDepth, 9L, 8L),
      (MimeMultipartParts, 1025L, 1024L),
      (SingleAssetBytes, 9L, 7L),
      (TotalAssetBytes, 16L, 15L),
    ] {
    (child.report_resource_limit_failure)(
      @input.make_resource_limit_failure(kind, observed, limit),
    )
  }
  assert_eq(failures.length(), 4)
  for
    (index, kind, observed, limit) in [
      (0, @input.ResourceLimitKind::MimeNestingDepth, 9L, 8L),
      (1, MimeMultipartParts, 1025L, 1024L),
      (2, SingleAssetBytes, 9L, 7L),
      (3, TotalAssetBytes, 21L, 20L),
    ] {
    assert_true(failures[index].kind == kind)
    assert_eq(failures[index].observed, observed)
    assert_eq(failures[index].limit, limit)
  }
}
