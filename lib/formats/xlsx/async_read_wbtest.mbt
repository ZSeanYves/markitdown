///|
async test "XLSX streaming I/O failure is not retried through a whole-part fallback" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml", "<Types><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
    ),
    (
      "xl/worksheets/sheet1.xml", "<worksheet><sheetData><row r=\"1\"><c r=\"A1\"><v>1</v></c></row></sheetData></worksheet>",
    ),
  ])
  let reject_payload = Ref(false)
  let payload_offset = Ref(-1)
  let rejected_reads = Ref(0)
  let archive = @dzip.open_zip_reader(bytes.length(), async fn(offset, length) {
    @async.sleep(0)
    if reject_payload.val && offset == payload_offset.val {
      rejected_reads.val += 1
      return Err("injected worksheet read failure")
    }
    Ok(bytes[offset:(offset + length).min(bytes.length())].to_owned())
  })
  let slice = @dzip.read_entry_data_slice(archive, "xl/worksheets/sheet1.xml")
  payload_offset.val = slice.data_start
  let pkg = @ox.open_ooxml_archive(archive)
  reject_payload.val = true
  let parsed = try
    xlsx_parse_sheet_view(
      pkg,
      xlsx_wbtest_sheet_info(),
      [],
      xlsx_parse_styles(""),
      false,
      true,
      true,
      10,
      10,
      100,
      @core.empty_diagnostics(),
      prefer_streaming_scan=true,
    )
    |> Ok
  catch {
    error => Err(error)
  }
  match parsed {
    Err(ZipError(message)) =>
      assert_true(message.contains("injected worksheet read failure"))
    _ =>
      fail("a source read failure must propagate out of the streaming scanner")
  }
  assert_eq(rejected_reads.val, 1)
}
