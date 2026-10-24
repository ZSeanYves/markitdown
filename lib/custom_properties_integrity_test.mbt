///|
async fn custom_integrity_document(
  invalid_utf8 : Bool,
  corrupt_crc : Bool,
) -> Bytes {
  let part = "docProps/custom.xml"
  let payload = b"<Properties><property name='kept'><vt:lpwstr>kept</vt:lpwstr></property></wrong>" +
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
async test "public custom syntax recovery retains completed property and document body" {
  let result = @lib.convert(
    @lib.Input::from_bytes(
      custom_integrity_document(false, false),
      source_name="custom.docx",
    ),
    options=@lib.ConvertOptions::default().with_format_hint(Some("docx")),
  ).unwrap()
  assert_true(result.content.contains("Body"))
  assert_true(result.metadata_json.contains("kept"))
}

///|
async test "public direct and nested custom syntax recovery cannot hide tail CRC UTF8 or finish" {
  for nested in [false, true] {
    for invalid_utf8 in [false, true] {
      let child = custom_integrity_document(invalid_utf8, !invalid_utf8)
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

///|
async test "public custom complex projection preserves wrapper attributes in collect and Sink summaries" {
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
    (
      "docProps/custom.xml", b"<Properties xmlns:vt='urn:vt'><property name='complex'><vt:vector baseType='lpwstr' size='2'><vt:lpwstr>One</vt:lpwstr><vt:lpwstr>Two</vt:lpwstr></vt:vector></property></Properties>",
    ),
  ])
  let input = @lib.Input::from_bytes(raw, source_name="complex.docx")
  let options = @lib.ConvertOptions::default().with_format_hint(Some("docx"))
  let collected = @lib.convert(input, options~).unwrap()
  assert_true(collected.metadata_json.contains("baseType"))
  assert_true(collected.metadata_json.contains("<vt:lpwstr>One</vt:lpwstr>"))
  assert_true(collected.metadata_json.contains("</vt:vector>"))
  let fragments : Array[String] = []
  let finishes = Ref(0)
  let summary = @lib.convert_to_sink(
    input,
    @lib.OutputSink::new(
      fragment => {
        fragments.push(fragment)
        Ok(())
      },
      () => {
        finishes.val += 1
        Ok(())
      },
    ),
    options~,
  ).unwrap()
  assert_eq(summary.metadata_json, collected.metadata_json)
  assert_eq(fragments.join(""), collected.content)
  assert_eq(finishes.val, 1)
}
