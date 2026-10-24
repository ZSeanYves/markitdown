///|
fn integrity_odt_bytes(part : String, payload : Bytes) -> Bytes {
  @dzip.build_store_zip_bytes([
    ("mimetype", b"application/vnd.oasis.opendocument.text"),
    ("META-INF/manifest.xml", b"<manifest:manifest/>"),
    (
      "content.xml", b"<office:document-content><office:body><office:text><text:p>Body</text:p></office:text></office:body></office:document-content>",
    ),
    (part, payload),
  ])
}

///|
async fn require_integrity_failure(bytes : Bytes) -> Unit {
  let source = @input.input_from_bytes_with_format(
    bytes,
    "integrity.odt",
    Some(Odt),
  )
  let options = @convert.default_convert_options()
  let collected = @convert.convert_input(source, options)
  let writes = Ref(0)
  let finishes = Ref(0)
  let delivered = @convert.convert_input_to_sink_unbuffered(
    source,
    options,
    @convert.make_output_sink(
      fn(_chunk) {
        writes.val += 1
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
  )
  assert_eq(
    (collected is Err(_), delivered is Err(_), writes.val, finishes.val),
    (true, true, 0, 0),
  )
}

///|
async test "ODF optional metadata CRC corruption stops conversion before output" {
  let bytes = integrity_odt_bytes(
    "meta.xml", b"<office:document-meta><dc:title>Title</dc:title></office:document-meta>",
  )
  let archive = @dzip.open_zip(bytes)
  let slice = @dzip.read_entry_data_slice(archive, "meta.xml")
  let corrupted = Bytes::makei(bytes.length(), i => {
    if i == slice.data_start + 1 {
      b'X'
    } else {
      bytes[i]
    }
  })
  require_integrity_failure(corrupted)
}

///|
async test "ODF optional metadata and styles invalid UTF8 stop conversion" {
  for part in ["meta.xml", "styles.xml"] {
    require_integrity_failure(integrity_odt_bytes(part, b"<r>\xff</r>"))
  }
}

///|
async test "ODF missing optional metadata and recoverable XML syntax remain supported" {
  for
    bytes in [
      integrity_odt_bytes("unrelated.txt", b"unrelated"),
      integrity_odt_bytes("meta.xml", b"<broken"),
    ] {
    let source = @input.input_from_bytes_with_format(
      bytes,
      "optional.odt",
      Some(Odt),
    )
    let result = @convert.convert_input(
      source,
      @convert.default_convert_options(),
    ).unwrap()
    assert_true(result.content.contains("Body"))
  }
}

///|
async test "nested ZIP preserves a child Office asset resource failure through recovery" {
  let office = container_test_read_sample_bytes(
    "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
  )
  let bytes = @dzip.build_store_zip_bytes([("child.docx", office)])
  let source = @input.input_from_bytes_with_format(
    bytes,
    "nested.zip",
    Some(Zip),
  )
  let defaults = @product.default_resource_limits()
  let options = @convert.make_convert_options(
    Balanced,
    Markdown,
    Some(Zip),
    @product.make_resource_limits(
      defaults.max_rows,
      defaults.max_cols,
      defaults.max_cells,
      max_line_chars=defaults.max_line_chars,
      max_input_bytes=defaults.max_input_bytes,
      max_asset_bytes=1L,
      max_total_asset_bytes=defaults.max_total_asset_bytes,
    ),
  )
  let collected = @convert.convert_input(source, options)
  let writes = Ref(0)
  let finishes = Ref(0)
  let delivered = @convert.convert_input_to_sink_unbuffered(
    source,
    options,
    @convert.make_output_sink(
      fn(_part) {
        writes.val += 1
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
  )
  for result in [collected, delivered] {
    match result {
      Err(ResourceLimitExceeded(kind="single_asset_bytes", observed~, limit=1L)) =>
        assert_true(observed > 1L)
      _ =>
        fail("nested Office error must preserve its typed resource dimension")
    }
  }
  assert_eq((writes.val, finishes.val), (0, 0))
}
