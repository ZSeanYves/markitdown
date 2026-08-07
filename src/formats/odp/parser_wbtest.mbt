///|
test "ODP malformed package produces document and block-stream fenced fallbacks" {
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([1, 2, 3].map(Int::to_byte)),
    "broken.odp",
    Some(Odp),
  )
  let document = (odp_parser().parse)(source, @parser.new_parse_context(Odp)).unwrap()
  assert_eq(document.document.unwrap().blocks.length(), 1)
  assert_true(document.diagnostics.errors.length() == 1)
  assert_true(
    document.diagnostics.degraded_features.contains("odp_raw_fenced_fallback"),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Odp),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (odp_parser().parse)(source, context).unwrap()
  assert_eq(streamed.block_stream.unwrap().length(), 1)
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("block_streaming"),
  )
  assert_true(odp_parser_capability().supports_streaming)
}

///|
test "ODP advanced synthetic contract covers groups table notes images raw and stream paths" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/odp/odp_advanced_synthetic.odp",
  )
  let result = (odp_parser().parse)(source, @parser.new_parse_context(Odp)).unwrap()
  let document = result.document.unwrap()
  assert_true(result.diagnostics.errors.length() == 0)
  assert_true(result.diagnostics.metrics.get("slide_count") == Some("2"))
  assert_true(result.diagnostics.metrics.get("table_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("image_count") == Some("2"))
  assert_true(result.diagnostics.metrics.get("notes_count") == Some("1"))
  assert_true(document.metadata.get("title") == Some(String("Advanced ODP")))
  assert_true(
    document.blocks.any(block => {
      block.kind == Heading && block.text == "Overview"
    }),
  )
  assert_true(document.blocks.any(block => block.kind == Table))
  assert_true(
    document.blocks.any(block => {
      block.kind == Code && block.text.contains("Speaker notes")
    }),
  )
  assert_true(
    document.blocks.any(block => {
      block.kind == Raw && block.text.contains("Unframed shape")
    }),
  )
  assert_true(
    document.blocks.any(block => {
      block.kind == BlockQuote && block.text.contains("Pictures/missing.png")
    }),
  )
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].path.unwrap_or("").has_suffix("red.png"))

  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Odp),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (odp_parser().parse)(source, stream_context).unwrap()
  assert_true(streamed.diagnostics.errors.length() == 0)
  assert_true(
    streamed.block_stream.unwrap().length() == document.blocks.length(),
  )
  assert_true(streamed.assets.length() == 1)
}

///|
test "ODP asset budget skips payload before creating an asset reference" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/odp/odp_advanced_synthetic.odp",
  )
  let context = @parser.parse_context_with_asset_limits(
    @parser.new_parse_context(Odp),
    1L,
    1L,
  )
  let result = (odp_parser().parse)(source, context).unwrap()
  let document = result.document.unwrap()
  assert_eq(document.assets.length(), 0)
  assert_true(
    result.diagnostics.degraded_features.contains("asset_payload_limit_skip"),
  )
  assert_true(
    result.diagnostics.warnings.any(w => w.contains("asset payload skipped")),
  )
}
