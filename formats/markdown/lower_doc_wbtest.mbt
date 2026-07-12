///|
fn markdown_complex_contract_source() -> @input.InputSource {
  @input.input_from_text_with_format(
    (
      #|+++
      #|title = "Contract"
      #|+++
      #|
      #|Setext heading
      #|==============
      #|
      #|Paragraph with [safe](https://example.test), [bad](javascript:alert(1)), `code`, and note[^one].
      #|
      #|1. ordered one
      #|2. ordered two
      #|
      #|* unordered one
      #|* unordered two
      #|
      #|> quote one
      #|> quote two
      #|
      #|| Name | Value |
      #|| --- | --- |
      #|| alpha | one |
      #|
      #|<section>semantic html</section>
      #|
      #|![local](assets/picture.png "Picture")
      #|![remote](https://example.test/picture.png)
      #|
      #|[^one]: first footnote line
      #|    continued line
      #|
      #|    second paragraph
      #|
      #|---
    ),
    "complex.md",
    Some(@input.DetectedFormat::Markdown),
  )
}

///|
test "markdown complex lowering covers grouped DOM and block stream semantics" {
  let source = markdown_complex_contract_source()
  let parser = markdown_parser()
  let dom = (parser.parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
  ).unwrap()
  let document = dom.document.unwrap()
  assert_true(document.blocks.length() >= 9)
  assert_true(
    document.blocks.any(block => block.kind == @core.BlockKind::Heading),
  )
  assert_true(document.blocks.any(block => block.kind == @core.BlockKind::List))
  assert_true(
    document.blocks.any(block => block.kind == @core.BlockKind::BlockQuote),
  )
  assert_true(
    document.blocks.any(block => block.kind == @core.BlockKind::Table),
  )
  assert_true(
    document.blocks.any(block => {
      block.attrs.get("raw_kind") == Some("markdown_footnote_definition")
    }),
  )
  assert_true(document.blocks.any(block => block.attrs.contains("asset_id")))
  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (parser.parse)(source, stream_context).unwrap()
  let blocks = streamed.block_stream.unwrap()
  assert_true(blocks.length() >= 8)
  assert_true(blocks.any(block => block.kind == @core.BlockKind::Raw))
  assert_true(
    streamed.diagnostics.same_mode_degradation.contains(
      "markdown_block_stream_list_literal_preserved",
    ),
  )
  assert_true(
    streamed.diagnostics.same_mode_degradation.contains(
      "markdown_block_stream_blockquote_literal_preserved",
    ),
  )
}

///|
test "markdown large literal lowering preserves source and records strategy" {
  let source = @input.input_from_text_with_format(
    "# Title\n\n- item\n",
    "large.md",
    Some(@input.DetectedFormat::Markdown),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let parsed = markdown_parse_large_literal(
    source, context, "# Title\n\n- item\n", 4,
  )
  let blocks = parsed.block_stream.unwrap()
  assert_eq(blocks.length(), 1)
  assert_eq(blocks[0].text, "# Title\n\n- item\n")
  assert_true(blocks[0].attrs.get("raw_kind") == Some("markdown_literal"))
  assert_true(
    parsed.diagnostics.metrics.get("markdown_lowering_mode") ==
    Some("large_literal"),
  )
}

///|
test "markdown lowering reports unclosed frontmatter and fences without crashing" {
  let source = @input.input_from_text_with_format(
    "---\ntitle: open\nbody without closing marker",
    "unclosed.md",
    Some(@input.DetectedFormat::Markdown),
  )
  let result = (markdown_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
  ).unwrap()
  assert_true(
    result.diagnostics.degraded_features.contains(
      "markdown_frontmatter_unclosed",
    ),
  )
  let fenced = @input.input_from_text_with_format(
    "```moonbit\nfn main {}",
    "fence.md",
    Some(@input.DetectedFormat::Markdown),
  )
  let fenced_result = (markdown_parser().parse)(
    fenced,
    @parser.new_parse_context(@input.DetectedFormat::Markdown),
  ).unwrap()
  assert_true(fenced_result.document.unwrap().blocks.length() == 1)
}
