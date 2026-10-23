///|
// The existing STORE fixture builder maps one scalar to one wire byte and
// computes CRC32 over those bytes. Preserve arbitrary worksheet bytes here,
// including deliberately invalid UTF8, instead of encoding a replacement char.
async fn xlsx_encoding_wbtest_package(xml : Bytes) -> @ox.OoxmlPackage {
  let wire_text = String::from_array(
    xml.to_array().map(byte => Int32::unsafe_to_char(byte.to_int())),
  )
  let archive = @dzip.open_zip(
    build_store_zip([
      (
        "[Content_Types].xml", "<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
      ),
      ("xl/worksheets/sheet1.xml", wire_text),
    ]),
  )
  // Read the complete member first: its actual length and CRC must validate.
  // A later rejection must therefore come from text validation, not ZIP damage.
  assert_eq(@dzip.read_entry(archive, "xl/worksheets/sheet1.xml"), xml)
  @ox.open_ooxml_archive(archive)
}

///|
async fn xlsx_encoding_wbtest_rejects_row(
  invalid_row : Int32,
  prefer_streaming_scan : Bool,
) -> Unit {
  let row1 = b"<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>" +
    (if invalid_row == 1 { b"\xff" } else { b"valid" }) +
    b"</t></is></c></row>"
  let row2 = b"<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>" +
    (if invalid_row == 2 { b"\xff" } else { b"valid" }) +
    b"</t></is></c></row>"
  let pkg = xlsx_encoding_wbtest_package(
    b"<worksheet><sheetData>" + row1 + row2 + b"</sheetData></worksheet>",
  )
  let rejected = try {
    ignore(
      xlsx_parse_sheet_view(
        pkg,
        xlsx_wbtest_sheet_info(),
        [],
        xlsx_parse_styles(""),
        false,
        true,
        true,
        1,
        10,
        10,
        @core.empty_diagnostics(),
        prefer_streaming_scan~,
      ),
    )
    false
  } catch {
    @ox.OoxmlError::InvalidEncoding(message) => message.contains("utf8")
    _ => false
  }
  assert_true(
    rejected,
    msg="invalid UTF8 must fail before row cropping: row=" +
      invalid_row.to_string() +
      ", streaming=" +
      prefer_streaming_scan.to_string(),
  )
  match @dzip.archive_hard_failure(pkg.archive) {
    Some(message) => assert_true(message.contains("utf8"))
    None => fail("the worksheet encoding failure must survive parser recovery")
  }
}

///|
async test "XLSX whole sheet rejects invalid UTF8 in the retained first row" {
  xlsx_encoding_wbtest_rejects_row(1, false)
}

///|
async test "XLSX streaming sheet rejects invalid UTF8 in the retained first row" {
  xlsx_encoding_wbtest_rejects_row(1, true)
}

///|
async test "XLSX whole sheet rejects invalid UTF8 beyond max_rows" {
  xlsx_encoding_wbtest_rejects_row(2, false)
}

///|
async test "XLSX streaming sheet rejects invalid UTF8 beyond max_rows" {
  xlsx_encoding_wbtest_rejects_row(2, true)
}

///|
async test "XLSX streaming sheet flushes an incomplete UTF8 sequence at EOF" {
  let pkg = xlsx_encoding_wbtest_package(
    b"<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><v>1</v></c></row></sheetData></worksheet>\xf0\x9f\x98",
  )
  match xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", 1) {
    Err(InvalidEncoding(message)) => assert_true(message.contains("utf8"))
    _ => fail("an incomplete UTF8 tail must fail after the ZIP CRC check")
  }
  assert_true(@dzip.archive_hard_failure(pkg.archive) is Some(_))
}

///|
async test "XLSX streaming sheet carries a valid UTF8 scalar across a chunk boundary" {
  let prefix = @utf8.encode(
    "<worksheet><sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>",
  )
  // Place the emoji lead byte at the final byte of a default 64KiB ZIP chunk.
  let padding = Bytes::make(64 * 1024 - prefix.length() - 1, b' ')
  let pkg = xlsx_encoding_wbtest_package(
    prefix +
    padding +
    @utf8.encode("😀") +
    b"</t></is></c></row><row r=\"2\"><c r=\"A2\"><v>2</v></c></row></sheetData></worksheet>",
  )
  let compact = match
    xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", 1) {
    Ok(bytes) => xlsx_decode_sheet_xml(bytes)
    Err(
      ReadFailed(message)
      | UnsupportedShape(message)
      | InvalidEncoding(message)
    ) => fail("valid chunk boundary failed: " + message)
  }
  assert_true(compact.contains("😀"))
  assert_true(!compact.contains("r=\"A2\""))
  assert_true(@dzip.archive_hard_failure(pkg.archive) is None)
}

///|
async test "XLSX unsupported streaming shape keeps syntax fallback without a hard failure" {
  let pkg = xlsx_encoding_wbtest_package(
    b"<worksheet><dimension ref=\"A1:A1\"/><sheetData/></worksheet>",
  )
  let diagnostics = @core.empty_diagnostics()
  ignore(
    xlsx_parse_sheet_view(
      pkg,
      xlsx_wbtest_sheet_info(),
      [],
      xlsx_parse_styles(""),
      false,
      true,
      true,
      1,
      10,
      10,
      diagnostics,
      prefer_streaming_scan=true,
    ),
  )
  assert_true(
    diagnostics.fallback_trace.any(message => {
      message.contains("stream shape fallback")
    }),
  )
  assert_true(@dzip.archive_hard_failure(pkg.archive) is None)
}
