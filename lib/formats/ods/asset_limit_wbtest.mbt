///|
fn ods_two_small_asset_source() -> @input.InputSource {
  let content =
    #|<office:document-content><office:body><office:spreadsheet><table:table table:name="Assets">
    #|<draw:frame><draw:image xlink:href="Pictures/one.png"/></draw:frame>
    #|<draw:frame><draw:image xlink:href="Pictures/two.png"/></draw:frame>
    #|</table:table></office:spreadsheet></office:body></office:document-content>
  @input.input_from_bytes_with_format(
    @dzip.build_store_zip_bytes([
      (
        "mimetype",
        @utf8.encode("application/vnd.oasis.opendocument.spreadsheet"),
      ),
      ("META-INF/manifest.xml", @utf8.encode("<manifest:manifest/>")),
      ("content.xml", @utf8.encode(content)),
      ("Pictures/one.png", b"abc"),
      ("Pictures/two.png", b"def"),
    ]),
    "small-assets.ods",
    Some(Ods),
  )
}

///|
async test "ODS prepared document reports collective asset failure through its bound reporter" {
  let source = ods_two_small_asset_source()
  let prepared = @dodf.prepare_ods_document_from_source(source).unwrap()
  let modes : Array[@parser.ParserMode?] = [None, Some(BlockStreaming)]
  for mode in modes {
    let failures : Array[@input.ResourceLimitFailure] = []
    let context = @parser.parse_context_with_resource_failure_reporter(
      @parser.parse_context_with_asset_limits(
        @parser.parse_context_with_limits(
          @parser.new_parse_context(Ods),
          mode,
          None,
          None,
          None,
          None,
          false,
        ),
        3L,
        5L,
      ),
      failure => failures.push(failure),
    )
    ignore(ods_parse_with_prepared_document(source, context, prepared))
    assert_eq(failures.length(), 1)
    assert_true(failures[0].kind is TotalAssetBytes)
    assert_eq(failures[0].observed, 6L)
    assert_eq(failures[0].limit, 5L)
  }
}

///|
async test "ODS prepared document retains both assets at exact request byte ceilings" {
  let source = ods_two_small_asset_source()
  let prepared = @dodf.prepare_ods_document_from_source(source).unwrap()
  let failures : Array[@input.ResourceLimitFailure] = []
  let context = @parser.parse_context_with_resource_failure_reporter(
    @parser.parse_context_with_asset_limits(
      @parser.new_parse_context(Ods),
      3L,
      6L,
    ),
    failure => failures.push(failure),
  )
  let result = ods_parse_with_prepared_document(source, context, prepared)
  assert_eq(failures.length(), 0)
  assert_eq(result.assets.length(), 2)
  assert_true(result.assets[0].payload == Some(Bytes(b"abc")))
  assert_true(result.assets[1].payload == Some(Bytes(b"def")))
}
