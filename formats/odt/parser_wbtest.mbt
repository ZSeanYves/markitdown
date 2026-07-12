///|
test "ODT malformed package produces document and block-stream fenced fallbacks" {
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([1, 2, 3].map(Int::to_byte)),
    "broken.odt",
    Some(@input.DetectedFormat::Odt),
  )
  assert_true(odt_route_preflight_summary(source) is Err(_))
  let document = (odt_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Odt),
  ).unwrap()
  assert_eq(document.document.unwrap().blocks.length(), 1)
  assert_true(document.diagnostics.errors.length() == 1)
  assert_true(
    document.diagnostics.degraded_features.contains("odt_raw_fenced_fallback"),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Odt),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (odt_parser().parse)(source, context).unwrap()
  assert_eq(streamed.block_stream.unwrap().length(), 1)
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("block_streaming"),
  )
  assert_true(odt_parser_capability().supports_streaming)
}

///|
test "ODT synthetic contracts cover document stream metadata tables links and assets" {
  let fixtures = [
    "samples/fixtures/contracts/odt/odt_basic_sample.odt", "samples/fixtures/contracts/odt/odt_basic_assets.odt",
    "samples/fixtures/contracts/odt/odt_advanced_synthetic.odt",
  ]
  for path in fixtures {
    let source = @input.input_from_path(path)
    let preflight = odt_route_preflight_summary(source).unwrap()
    assert_true(preflight.block_count > 0)
    let document = (odt_parser().parse)(
      source,
      @parser.new_parse_context(@input.DetectedFormat::Odt),
    ).unwrap()
    assert_true(document.document.unwrap().blocks.length() > 0)
    assert_true(document.diagnostics.errors.length() == 0)
    assert_true(
      document.diagnostics.metrics.get("odt_block_count") != Some("0"),
    )

    let stream_context = @parser.parse_context_with_limits(
      @parser.new_parse_context(@input.DetectedFormat::Odt),
      Some(@parser.ParserMode::BlockStreaming),
      None,
      None,
      None,
      None,
      false,
    )
    let streamed = (odt_parser().parse)(source, stream_context).unwrap()
    assert_true(streamed.block_stream.unwrap().length() > 0)
    assert_true(streamed.diagnostics.errors.length() == 0)
  }
  let assets = (odt_parser().parse)(
      @input.input_from_path(
        "samples/fixtures/contracts/odt/odt_basic_assets.odt",
      ),
      @parser.new_parse_context(@input.DetectedFormat::Odt),
    ).unwrap().document.unwrap().assets
  assert_true(assets.length() > 0)
  assert_true(assets[0].path.unwrap_or("").has_suffix(".png"))

  let advanced = (odt_parser().parse)(
    @input.input_from_path(
      "samples/fixtures/contracts/odt/odt_advanced_synthetic.odt",
    ),
    @parser.new_parse_context(@input.DetectedFormat::Odt),
  ).unwrap().document.unwrap()
  assert_true(
    advanced.blocks.any(block => block.kind == @core.BlockKind::Heading),
  )
  assert_true(
    advanced.blocks.any(block => block.kind == @core.BlockKind::Table),
  )
  assert_true(
    advanced.blocks.any(block => block.kind == @core.BlockKind::ListItem),
  )
  assert_true(
    advanced.blocks.any(block => block.text.contains("Footnote body")),
  )
  assert_true(advanced.assets.length() == 1)
}
