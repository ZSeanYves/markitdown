///|
test "phase2 representative cases preserve path bytes reader and hint contracts" {
  let fixtures : Array[(String, @input.DetectedFormat, String)] = [
    (
      "samples/fixtures/contracts/docx/docx_advanced_synthetic.docx",
      Docx,
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ),
    (
      "samples/fixtures/contracts/pptx/pptx_chart_cache_synthetic.pptx",
      Pptx,
      "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ),
    (
      "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
      Xlsx,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ),
    ("samples/fixtures/contracts/pdf/text_simple.pdf", Pdf, "application/pdf"),
    ("samples/fixtures/contracts/html/html_entities.html", Html, "text/html"),
    ("samples/fixtures/contracts/csv/csv_basic.csv", Csv, "text/csv"),
    (
      "samples/fixtures/contracts/json/json_object_basic.json",
      Json,
      "application/json",
    ),
    ("samples/fixtures/contracts/xml/xml_basic.xml", Xml, "application/xml"),
    (
      "samples/fixtures/contracts/ipynb/ipynb_markdown_basic.ipynb",
      Ipynb,
      "application/x-ipynb+json",
    ),
    (
      "samples/fixtures/contracts/zip/zip_basic_structured.zip",
      Zip,
      "application/zip",
    ),
    (
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
      Epub,
      "application/epub+zip",
    ),
  ]
  for fixture in fixtures {
    let (path, format, mime) = fixture
    let bytes = @fs.read_file_to_bytes(path) catch {
      err => fail("phase2 fixture read failed: " + err.to_string())
    }
    let name = path.split("/").last().unwrap_or(path).to_owned()
    let path_result = convert_binary_source_for_equivalence(
      @input.input_from_path(path),
      format,
    )
    let bytes_result = convert_binary_source_for_equivalence(
      @input.input_from_bytes(bytes, source_name=name),
      format,
    )
    let mime_result = convert_binary_source_for_equivalence(
      @input.with_mime_type(
        @input.input_from_bytes(bytes, source_name="phase2-payload"),
        Some(mime),
      ),
      format,
    )
    let reader = @input.make_input_reader(
      fn(offset, length) {
        let start = offset.to_int()
        let end_ = (start + length.min(4096)).min(bytes.length())
        Ok(bytes.view(start~, end=end_).to_owned())
      },
      size=bytes.length().to_int64(),
    )
    let reader_result = convert_binary_source_for_equivalence(
      @input.input_from_reader(reader, source_name=name),
      format,
    )
    assert_eq(path_result.content, bytes_result.content)
    assert_eq(path_result.content, mime_result.content)
    assert_eq(path_result.content, reader_result.content)
    assert_true(path_result.content.trim() != "")
  }
}

///|
test "phase2 records OMML and PPTX chart compatibility decisions" {
  let docx = inprocess_convert_fixture(
    "samples/fixtures/contracts/docx/docx_advanced_synthetic.docx",
    Docx,
    Balanced,
  )
  assert_true(docx.content.contains("x \\+ y"))
  assert_true(docx.content.contains("math") || docx.content.contains("x \\+ y"))
  let pptx = inprocess_convert_fixture(
    "samples/fixtures/contracts/pptx/pptx_chart_cache_synthetic.pptx",
    Pptx,
    Balanced,
  )
  assert_true(pptx.content.contains("Quarterly revenue"))
  assert_true(pptx.content.contains("| North |"))
  assert_true(!pptx.content.contains("[Unsupported PPTX chart"))
}
