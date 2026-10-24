///|
test "remaining asset context preserves temporary policy as an independent resource domain" {
  let limits = @product.make_resource_limits(
    200,
    50,
    10000,
    max_temporary_bytes=Some(17L),
  )
  let context = parse_context_with_limits(
    new_parse_context(Jsonl),
    Some(StreamingEvent),
    Some(200),
    Some(50),
    Some(10000),
    Some(4000),
    false,
    limits~,
  )
  let child = parse_context_with_asset_limits(context, 1L, 2L)
  assert_true(child.limits.max_temporary_bytes == Some(17L))
  assert_eq(child.limits.max_asset_bytes, 1L)
  assert_eq(child.limits.max_total_asset_bytes, 2L)
}
