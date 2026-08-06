///|
test "stable API converts Path, Text, Bytes, and Reader inputs" {
  let text = "# Title\n\nBody\n"
  let text_output = convert(Input::from_text(text, source_name="sample.md"))
  guard text_output is Ok(text_value) else { fail("text conversion failed") }
  assert_eq(text_value.detected_format, "markdown")
  assert_true(text_value.content.contains("Title"))

  let bytes = @utf8.encode(text)
  let bytes_output = convert(Input::from_bytes(bytes, source_name="sample.md"))
  guard bytes_output is Ok(bytes_value) else { fail("bytes conversion failed") }
  assert_true(bytes_value.content.contains("Body"))

  let reader_output = convert(
    Input::from_reader(
      fn(offset, length) {
        let start = offset.to_int()
        if start >= bytes.length() {
          Ok(b"")
        } else {
          let stop = Int::min(start + length, bytes.length())
          Ok(Bytes::from_array(bytes[start:stop].to_array()))
        }
      },
      size=bytes.length().to_int64(),
      source_name="sample.md",
    ),
  )
  guard reader_output is Ok(reader_value) else {
    fail("reader conversion failed")
  }
  assert_true(reader_value.content.contains("Title"))

  let path = "/tmp/markitdown-api-v0_8-test.md"
  @fs.write_string_to_file(path, text, encoding="utf8")
  let path_output = convert(Input::from_path(path))
  guard path_output is Ok(path_value) else { fail("path conversion failed") }
  assert_true(path_value.content.contains("Body"))
  @fs.remove_file(path)
}

///|
test "stable API covers all output modes and preserves provenance" {
  let input = Input::from_text("# Title\n\nBody\n", source_name="sample.md")
  for mode in [Markdown, Debug, Rag] {
    let options = ConvertOptions::default().with_output_mode(mode)
    let result = convert(input, options~)
    guard result is Ok(output) else { fail("output conversion failed") }
    assert_true(output.output_mode == mode)
    assert_eq(output.provenance.detected_format, "markdown")
    assert_true(output.provenance.selected_route != "")
    if mode == Rag {
      assert_true(output.chunks.length() > 0)
    }
  }
}

///|
test "stable API preserves materializable assets and source maps" {
  let result = convert(
    Input::from_path(
      "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
    ),
  )
  guard result is Ok(output) else { fail("asset conversion failed") }
  assert_true(output.assets.length() > 0)
  assert_true(output.assets.any(asset => asset.path is Some(_)))
}

///|
test "stable source and asset projections preserve payload data" {
  let source_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some("input.json"),
    Some("json"),
    Some("/value"),
  )
  let projected_map = stable_source_map(
    Some({
      document_ref: Some(source_ref),
      block_entries: [],
      asset_entries: [],
    }),
  ).unwrap()
  assert_eq(projected_map.document_ref.unwrap().json_pointer, Some("/value"))
  let asset = @core.make_asset_ref(Attachment, "attachment-1", source_ref~)
  asset.payload = Some(Utf8("payload"))
  let projected = stable_assets([asset])
  assert_eq(projected.length(), 1)
  assert_true(projected[0].payload == Some(Utf8("payload")))
}

///|
test "stable errors have versioned codes and process exit mappings" {
  let invalid = {
    ..ConvertOptions::default(),
    format_hint: Some("not-a-format"),
  }
  guard convert(Input::from_text("x"), options=invalid) is Err(error) else {
    fail("invalid format hint should fail")
  }
  assert_eq(error.code().stable_name(), "MID-0002")
  assert_eq(error.exit_code(), 2)
  assert_true(error.to_string().contains("MID-0002"))
}

///|
test "capability and version surfaces are implementation-neutral" {
  let manifest = capabilities()
  assert_true(manifest.length() >= 37)
  assert_true(
    manifest.any(item => {
      item.format == "pdf" && item.convert_modes == [Balanced, Accurate]
    }),
  )
  assert_true(
    manifest.any(item => {
      item.format == "zip" && item.convert_modes == [Balanced]
    }),
  )
  assert_true(
    manifest.any(item => {
      item.format == "md" && item.canonical_format == "markdown"
    }),
  )
  assert_true(
    manifest.any(item => item.format == "msg" && item.status == Experimental),
  )
  assert_true(
    manifest.any(item => item.format == "png" && item.status == ExternalRuntime),
  )
  let migration = api_v0_8().v1_migration()
  assert_eq(migration.source_version, "0.8")
  assert_eq(migration.target_version, "1.0")
}
