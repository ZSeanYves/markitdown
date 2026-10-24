///|
test "child product options preserve the parser's explicit temporary capacity" {
  let limits = @product.make_resource_limits(
    200,
    50,
    10000,
    max_temporary_bytes=Some(17L),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Jsonl),
    Some(StreamingEvent),
    Some(200),
    Some(50),
    Some(10000),
    Some(4000),
    false,
    limits~,
  )
  let child = child_product_options(context)
  assert_true(child.limits.max_temporary_bytes == Some(17L))
  assert_eq(child.limits.max_rows, 200)
  assert_eq(child.limits.max_cols, 50)
}
