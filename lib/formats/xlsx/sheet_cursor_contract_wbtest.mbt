///|
async fn sheet_cursor_contract_compact(xml : Bytes, rows : Int32) -> String {
  let pkg = xlsx_encoding_wbtest_package(xml)
  match xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", rows) {
    Err(BudgetExceeded(error)) => fail(@budget.budget_error_message(error))
    Ok(bytes) => xlsx_decode_sheet_xml(bytes)
    Err(
      ReadFailed(message)
      | UnsupportedShape(message)
      | InvalidEncoding(message)
    ) => fail("worksheet compaction failed: " + message)
  }
}

///|
async test "XLSX stream row window ignores XML comments containing row delimiters" {
  let real = "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>real</t></is></c></row>"
  let tail = "</sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>"
  let actual = sheet_cursor_contract_compact(
    @utf8.encode(
      "<worksheet><sheetData><!-- <row r=\"fake\"></row> -->" + real + tail,
    ),
    1,
  )
  assert_eq(actual, "<worksheet><sheetData>" + real + tail)
}

///|
async test "XLSX stream row window counts self-closing rows before later content" {
  let actual = sheet_cursor_contract_compact(
    b"<worksheet><sheetData><row r=\"1\"/><row r=\"2\"><c r=\"A2\"><v>99</v></c></row></sheetData><pageMargins left=\"1\"/></worksheet>",
    1,
  )
  assert_eq(
    actual, "<worksheet><sheetData><row r=\"1\"/></sheetData><pageMargins left=\"1\"/></worksheet>",
  )
}

///|
async test "XLSX stream boundaries preserve quoted greater-than and ignore comment closing tags" {
  let real = "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>real &amp; 😀</t></is></c></row>"
  let actual = sheet_cursor_contract_compact(
    @utf8.encode(
      "<worksheet><sheetData note=\"a>b\"><!-- </sheetData> -->" +
      real +
      "</sheetData></worksheet>",
    ),
    1,
  )
  assert_eq(
    actual,
    "<worksheet><sheetData note=\"a>b\">" + real + "</sheetData></worksheet>",
  )
}

///|
async test "XLSX cursor syntax recovery cannot hide invalid UTF8 in an unread chunk" {
  let pkg = xlsx_encoding_wbtest_package(
    b"<worksheet><broken></wrong>" +
    Bytes::make(70_000, b' ') +
    b"\xff</worksheet>",
  )
  match xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", 1) {
    Err(InvalidEncoding(message)) => assert_true(message.contains("utf8"))
    _ => fail("later invalid UTF8 must override recoverable XML syntax")
  }
  assert_true(@dzip.archive_hard_failure(pkg.archive) is Some(_))
}

///|
async test "XLSX cursor syntax recovery cannot hide later ZIP CRC failure" {
  let xml = "<worksheet><broken></wrong>" +
    String::make(70_000, ' ') +
    "CRC_TAIL</worksheet>"
  let archive_bytes = build_store_zip([
    (
      "[Content_Types].xml", "<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
    ),
    ("xl/worksheets/sheet1.xml", xml),
  ])
  let offset = archive_bytes.find(b"CRC_TAIL").unwrap()
  let corrupt = archive_bytes.to_array()
  corrupt[offset] = b'X'
  let archive = @dzip.open_zip(Bytes::from_array(corrupt))
  let pkg = @ox.open_ooxml_archive(archive)
  match xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", 1) {
    Err(ReadFailed(_)) => ()
    _ =>
      fail(
        "later CRC failure must stop recovery before any whole-part fallback",
      )
  }
  assert_true(@dzip.archive_hard_failure(pkg.archive) is Some(_))
}
