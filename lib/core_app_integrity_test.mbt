///|
async fn core_app_integrity_document(
  app : Bool,
  invalid_utf8 : Bool,
  corrupt_crc : Bool,
) -> Bytes {
  let part = if app { "docProps/app.xml" } else { "docProps/core.xml" }
  let prefix = if app {
    b"<r><Application>kept</Application></wrong>"
  } else {
    b"<r><title>kept</title></wrong>"
  }
  let payload = prefix +
    Bytes::from_array(Array::make(70000, b' ')) +
    (if invalid_utf8 { b"\xff" } else { b"" })
  let raw = @dzip.build_store_zip_bytes([
    (
      "[Content_Types].xml", b"<Types><Default Extension='xml' ContentType='application/xml'/><Override PartName='/word/document.xml' ContentType='application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'/></Types>",
    ),
    (
      "_rels/.rels", b"<Relationships><Relationship Id='main' Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument' Target='word/document.xml'/></Relationships>",
    ),
    (
      "word/document.xml", b"<w:document><w:body><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:body></w:document>",
    ),
    (part, payload),
  ])
  if !corrupt_crc {
    return raw
  }
  let slice = @dzip.read_entry_data_slice(@dzip.open_zip(raw), part)
  let damaged = raw.to_array()
  damaged[slice.data_start + 65537] = b'\t'
  Bytes::from_array(damaged)
}

///|
async test "public core app malformed syntax recovers completed values and document body" {
  for app in [false, true] {
    let raw = core_app_integrity_document(app, false, false)
    let options = @lib.ConvertOptions::default().with_format_hint(Some("docx"))
    let result = @lib.convert(
      @lib.Input::from_bytes(raw, source_name="metadata.docx"),
      options~,
    ).unwrap()
    assert_true(result.content.contains("Body"))
    assert_true(result.metadata_json.contains("kept"))
  }
}

///|
async test "public and nested core app syntax recovery cannot hide tail UTF8 CRC or finish success" {
  for nested in [false, true] {
    for app in [false, true] {
      for invalid_utf8 in [false, true] {
        let child = core_app_integrity_document(
          app,
          invalid_utf8,
          !invalid_utf8,
        )
        let raw = if nested {
          @dzip.build_store_zip_bytes([("child.docx", child)])
        } else {
          child
        }
        let format = if nested { "zip" } else { "docx" }
        assert_eq(
          relationship_integrity_rejected(raw, format),
          (true, true, 0, 0),
        )
      }
    }
  }
}
