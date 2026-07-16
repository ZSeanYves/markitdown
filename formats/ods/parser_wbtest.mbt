///|
test "ODS malformed package produces document and block-stream fenced fallbacks" {
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([1, 2, 3].map(Int::to_byte)),
    "broken.ods",
    Some(Ods),
  )
  let document = (ods_parser().parse)(source, @parser.new_parse_context(Ods)).unwrap()
  assert_eq(document.document.unwrap().blocks.length(), 1)
  assert_true(document.diagnostics.errors.length() == 1)
  assert_true(
    document.diagnostics.degraded_features.contains("ods_raw_fenced_fallback"),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Ods),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (ods_parser().parse)(source, context).unwrap()
  assert_eq(streamed.block_stream.unwrap().length(), 1)
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("block_streaming"),
  )
  assert_true(ods_parser_capability().supports_streaming)
}

///|
test "ODS local drawing assets deduplicate payloads and hide hidden-sheet media" {
  let content =
    #|<office:document-content><office:body><office:spreadsheet>
    #|  <table:table table:name="Visible">
    #|    <table:table-row><table:table-cell><text:p>A</text:p></table:table-cell></table:table-row>
    #|    <draw:frame><draw:image xlink:href="Pictures/shared.png"/></draw:frame>
    #|    <draw:frame><draw:image xlink:href="Pictures/shared.png"/></draw:frame>
    #|    <draw:frame><draw:image xlink:href="Pictures/missing.png"/></draw:frame>
    #|  </table:table>
    #|  <table:table table:name="Hidden" table:display="false">
    #|    <draw:frame><draw:image xlink:href="Pictures/hidden.jpg"/></draw:frame>
    #|  </table:table>
    #|</office:spreadsheet></office:body></office:document-content>
  let bytes = @therm.build_store_zip_bytes([
    ("mimetype", @utf8.encode("application/vnd.oasis.opendocument.spreadsheet")),
    ("META-INF/manifest.xml", @utf8.encode("<manifest:manifest/>")),
    ("content.xml", @utf8.encode(content)),
    (
      "Pictures/shared.png",
      Bytes::from_array([(0x89).to_byte(), (0x50).to_byte()]),
    ),
    (
      "Pictures/hidden.jpg",
      Bytes::from_array([(0xFF).to_byte(), (0xD8).to_byte()]),
    ),
  ])
  let result = (ods_parser().parse)(
    @input.input_from_bytes_with_format(bytes, "images.ods", Some(Ods)),
    @parser.new_parse_context(Ods),
  ).unwrap()
  let document = result.document.unwrap()
  assert_eq(document.assets.length(), 1)
  assert_eq(document.blocks.filter(block => block.kind == Image).length(), 2)
  assert_true(document.assets[0].path == Some("assets/ods-image1-shared.png"))
  assert_true(result.diagnostics.metrics.get("asset_count") == Some("1"))
  assert_true(
    document.blocks.any(block => {
      block.kind == BlockQuote &&
      block.text == "Asset unavailable: Pictures/missing.png"
    }),
  )

  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Ods),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (ods_parser().parse)(
    @input.input_from_bytes_with_format(bytes, "images.ods", Some(Ods)),
    stream_context,
  ).unwrap()
  assert_eq(streamed.assets.length(), 1)
  assert_eq(
    streamed.block_stream.unwrap().filter(block => block.kind == Image).length(),
    2,
  )
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("block_streaming"),
  )
}

///|
test "ODS advanced synthetic contract covers repeated merged hidden formula asset and stream paths" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/ods/ods_advanced_synthetic.ods",
  )
  let result = (ods_parser().parse)(source, @parser.new_parse_context(Ods)).unwrap()
  let document = result.document.unwrap()
  assert_true(result.diagnostics.errors.length() == 0)
  assert_true(result.diagnostics.metrics.get("sheet_count") == Some("2"))
  assert_true(result.diagnostics.metrics.get("hidden_sheet_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("hidden_row_count") == Some("1"))
  assert_true(result.diagnostics.metrics.get("covered_cell_count") == Some("1"))
  assert_true(document.metadata.get("title") == Some(String("Advanced ODS")))
  assert_true(
    document.blocks.any(block => {
      block.kind == Heading && block.text == "Metrics"
    }),
  )
  assert_true(document.blocks.any(block => block.kind == Table))
  assert_true(
    !document.blocks.any(block => block.text.contains("Hidden sheet")),
  )
  assert_true(!document.blocks.any(block => block.text.contains("Hidden row")))
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].path.unwrap_or("").has_suffix("red.png"))

  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Ods),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (ods_parser().parse)(source, stream_context).unwrap()
  assert_true(streamed.diagnostics.errors.length() == 0)
  assert_true(streamed.block_stream.unwrap().any(block => block.kind == Table))
  assert_true(streamed.assets.length() == 1)
}
