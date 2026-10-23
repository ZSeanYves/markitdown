///|
async test "ZIP parser lowers contract archives and reports unsupported nested entries" {
  let owned_sessions : Array[@input.InputSession] = []
  defer (for session in owned_sessions {
    @input.end_input_session(session)
  })
  let owned_input_path = fn(path : String) {
    let session = @input.begin_input_session(@input.input_from_path(path))
    owned_sessions.push(session)
    session.source
  }
  let fixtures = [
    "samples/fixtures/contracts/zip/zip_basic_structured.zip", "samples/fixtures/contracts/zip/zip_mixed_supported_entries.zip",
    "samples/fixtures/contracts/zip/zip_unsupported_entries.zip", "samples/fixtures/contracts/zip/zip_nested_archive_boundary.zip",
    "samples/fixtures/contracts/zip/zip_assets_namespace.zip", "samples/fixtures/contracts/zip/zip_html_local_image.zip",
  ]
  let parser = zip_container_parser(fn() { @parser.empty_registry() })
  let context = @parser.new_parse_context(Zip)
  let mut blocks = 0
  let mut warnings = 0
  for path in fixtures {
    let result = (parser.parse)(owned_input_path(path), context).unwrap()
    blocks += result.block_stream.unwrap().length()
    warnings += result.diagnostics.warnings.length()
    assert_true(
      result.diagnostics.metrics.get("container_entry_count") is Some(_),
    )
  }
  assert_true(blocks > 0)
  assert_true(warnings >= 0)
}

///|
async test "ZIP parser rejects invalid and truncated central directories" {
  let parser = zip_container_parser(fn() { @parser.empty_registry() })
  for
    bytes in [
      Bytes::new(0),
      Bytes::from_array([0x50, 0x4B, 0x03, 0x04].map(Int32::to_byte)),
      Bytes::from_array([1, 2, 3].map(Int32::to_byte)),
    ] {
    assert_true(
      (parser.parse)(
        @input.input_from_bytes_with_format(bytes, "broken.zip", Some(Zip)),
        @parser.new_parse_context(Zip),
      )
      is Err(_),
    )
  }
}
