///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn open_sample_package(path : String) -> @ox.OoxmlPackage raise {
  let bytes = @fs.read_file_to_bytes(resolve_sample_path(path)) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @ox.open_ooxml_package(bytes) catch {
    e => fail("open sample package failed: " + e.to_string())
  }
}

///|
fn bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i = i + 1
  }
  acc
}

///|
fn add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)
  let crc32 = crc32_of_string(data)

  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u32_le(out, crc32)
  append_u32_le(out, data_bytes.length())
  append_u32_le(out, data_bytes.length())
  append_u16_le(out, name_bytes.length())
  append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, crc32)
    append_u32_le(out, size)
    append_u32_le(out, size)
    append_u16_le(out, name_bytes.length())
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  append_u32_le(out, 0x06054b50)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, central.length())
  append_u16_le(out, central.length())
  append_u32_le(out, cd_size)
  append_u32_le(out, cd_offset)
  append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
fn minimal_content_types_xml(overrides : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  overrides +
  "</Types>"
}

///|
fn minimal_rels_xml(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn workbook_pkg_from_parts(
  workbook_xml : String,
  workbook_rels_xml : String,
  extra_entries : Array[(String, String)],
  content_type_overrides : String,
) -> @ox.OoxmlPackage raise {
  let entries : Array[(String, String)] = [
    ("[Content_Types].xml", minimal_content_types_xml(content_type_overrides)),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
  ]
  for entry in extra_entries {
    entries.push(entry)
  }
  @ox.open_ooxml_package(build_store_zip(entries)) catch {
    e => fail("open generated workbook package failed: " + e.to_string())
  }
}

///|
fn generated_xlsx_workbook_date1904_pkg() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<workbookPr date1904=\"1\"/>" +
    "<sheets><sheet name=\"Date1904\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\"><v>1</v></c></row></sheetData>" +
    "</worksheet>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [("xl/worksheets/sheet1.xml", sheet_xml)],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_hidden_rows() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"HiddenRows\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row>" +
    "<row r=\"2\" hidden=\"1\"><c r=\"A2\" t=\"s\"><v>1</v></c></row>" +
    "<row r=\"3\"><c r=\"A3\" t=\"s\"><v>2</v></c></row>" +
    "</sheetData>" +
    "</worksheet>"
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"3\" uniqueCount=\"3\">" +
    "<si><t>Visible Header</t></si>" +
    "<si><t>Hidden Secret</t></si>" +
    "<si><t>Visible Public</t></si>" +
    "</sst>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/sharedStrings.xml", shared_strings_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_comments() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Comments\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c><c r=\"B1\" t=\"s\"><v>1</v></c></row>" +
    "<row r=\"2\"><c r=\"A2\" t=\"s\"><v>2</v></c><c r=\"B2\" t=\"s\"><v>3</v></c></row>" +
    "</sheetData>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments1.xml\"/>",
  )
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"4\" uniqueCount=\"4\">" +
    "<si><t>Name</t></si>" +
    "<si><t>Value</t></si>" +
    "<si><t>Row A</t></si>" +
    "<si><t>Row B</t></si>" +
    "</sst>"
  let comments_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<authors><author>Analyst</author></authors>" +
    "<commentList>" +
    "<comment ref=\"B1\" authorId=\"0\"><text><r><t>Analyst:</t></r><r><t xml:space=\"preserve\"> First insight</t></r></text></comment>" +
    "<comment ref=\"A2\" authorId=\"0\"><text><r><t>Second insight</t></r></text></comment>" +
    "</commentList>" +
    "</comments>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
      ("xl/sharedStrings.xml", shared_strings_xml),
      ("xl/comments1.xml", comments_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>" +
    "<Override PartName=\"/xl/comments1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_self_closing_blank_cells() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"SharedLinks\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<dimension ref=\"A1:B5\"/>" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" s=\"1\" t=\"s\"><v>0</v></c><c r=\"B1\" s=\"1\"/></row>" +
    "<row r=\"2\"><c r=\"A2\" s=\"1\"/><c r=\"B2\" s=\"1\"/></row>" +
    "<row r=\"3\"><c r=\"A3\" s=\"1\" t=\"s\"><v>0</v></c><c r=\"B3\" s=\"1\"/></row>" +
    "<row r=\"4\"><c r=\"A4\" s=\"1\" t=\"s\"><v>0</v></c></row>" +
    "<row r=\"5\"><c r=\"A5\" s=\"1\" t=\"s\"><v>0</v></c></row>" +
    "</sheetData>" +
    "</worksheet>"
  let styles_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<fonts count=\"1\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>" +
    "<fills count=\"1\"><fill><patternFill patternType=\"none\"/></fill></fills>" +
    "<borders count=\"1\"><border/></borders>" +
    "<cellStyleXfs count=\"1\"><xf/></cellStyleXfs>" +
    "<cellXfs count=\"2\"><xf/><xf/></cellXfs>" +
    "</styleSheet>"
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"4\" uniqueCount=\"1\">" +
    "<si><t>http://www.apache.org</t></si>" +
    "</sst>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/sharedStrings.xml", shared_strings_xml),
      ("xl/styles.xml", styles_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>" +
    "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_validation_edges() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets>" +
    "<sheet name=\"Dup\" sheetId=\"1\" r:id=\"rId1\"/>" +
    "<sheet name=\"BrokenRefs\" sheetId=\"2\" r:id=\"rId2\"/>" +
    "<sheet name=\"Dup\" sheetId=\"3\" r:id=\"rId3\"/>" +
    "<sheet name=\"MissingTarget\" sheetId=\"4\" r:id=\"rId4\"/>" +
    "</sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>" +
    "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/>" +
    "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet3.xml\"/>" +
    "<Relationship Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/missing.xml\"/>",
  )
  let sheet1_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>ok</t></is></c></row></sheetData>" +
    "</worksheet>"
  let sheet2_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A0\"><v>1</v></c></row>" +
    "<row r=\"2\"><c r=\"B2\" t=\"s\"><v>3</v></c></row>" +
    "</sheetData>" +
    "<mergeCells count=\"1\"><mergeCell ref=\"A1:\"/></mergeCells>" +
    "</worksheet>"
  let sheet3_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>dup</t></is></c></row></sheetData>" +
    "</worksheet>"
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"1\" uniqueCount=\"1\">" +
    "<si><t>only one</t></si>" +
    "</sst>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet1_xml),
      ("xl/worksheets/sheet2.xml", sheet2_xml),
      ("xl/worksheets/sheet3.xml", sheet3_xml),
      ("xl/sharedStrings.xml", shared_strings_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet3.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
  )
}

///|
test "xlsx semantic workbook preserves sheet order, targets, and visibility" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
  )
  assert_eq(workbook.sheets.length(), 2)
  assert_eq(workbook.sheets[0].name, "Sheet1")
  assert_eq(workbook.sheets[1].name, "Data")
  if workbook.sheets[0].part_target != Some("xl/worksheets/sheet1.xml") {
    fail("expected first sheet target xl/worksheets/sheet1.xml")
  }

  let hidden = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  match hidden.sheets[2].state {
    @xlsx.XlsxSheetState::VeryHidden => ()
    _ => fail("third sheet should preserve veryHidden state")
  }
}

///|
test "xlsx semantic package parse matches path open and keeps shared strings" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let pkg = open_sample_package(
    "samples/main_process/xlsx/xlsx_cell_types.xlsx",
  )
  let parsed = @xlsx.parse_xlsx_workbook_from_package(pkg)
  assert_eq(parsed.sheets.length(), workbook.sheets.length())
  assert_eq(parsed.sheets[0].name, workbook.sheets[0].name)
  assert_true(parsed.shared_strings.length() > 0)
}

///|
test "xlsx semantic facade remains stable across open parse inspect collect validate classify" {
  let input_path = resolve_sample_path(
    "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
  )
  let workbook = @xlsx.open_xlsx_workbook(input_path)
  let package_workbook = @xlsx.parse_xlsx_workbook_from_package(
    open_sample_package(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let inspect = @xlsx.inspect_xlsx_workbook(workbook)
  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let report = @xlsx.validate_xlsx_workbook(workbook)
  let info = @xlsx.classify_xlsx_error(
    @xlsx.XlsxError::ParseError("invalid cell reference: A0"),
  )

  assert_eq(package_workbook.sheets.length(), workbook.sheets.length())
  assert_eq(inspect.sheet_count, workbook.sheets.length())
  assert_eq(report.issue_count, issues.length())
  if info.kind != @xlsx.XlsxErrorKind::InvalidCellReference {
    fail("classifier should preserve invalid cell reference classification")
  }
}

///|
test "xlsx semantic cells preserve kinds semantic types and raw formulas" {
  let typed = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let mut saw_shared = false
  let mut saw_bool = false
  let mut saw_error = false
  let mut saw_number = false
  for cell in typed.sheets[0].cells {
    match cell.kind {
      @xlsx.XlsxCellKind::SharedString =>
        if cell.display_text == "inline ok" {
          saw_shared = true
        }
      @xlsx.XlsxCellKind::Boolean => saw_bool = true
      @xlsx.XlsxCellKind::Error => saw_error = true
      @xlsx.XlsxCellKind::Number =>
        if cell.display_text == "42" {
          saw_number = true
        }
      _ => ()
    }
  }
  assert_true(saw_shared)
  assert_true(saw_bool)
  assert_true(saw_error)
  assert_true(saw_number)

  let formula = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let mut saw_formula = false
  for cell in formula.sheets[0].cells {
    match cell.formula_text {
      Some(text) =>
        if text.trim() != "" {
          saw_formula = true
          break
        }
      None => ()
    }
  }
  assert_true(saw_formula)
}

///|
test "xlsx semantic formula trace captures cached evaluated and unsupported policies" {
  let cached = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let mut saw_cached = false
  for cell in cached.sheets[0].cells {
    match cell.formula_trace {
      Some(trace) =>
        if trace.policy == @xlsx.XlsxFormulaPolicy::Cached {
          saw_cached = true
        }
      None => ()
    }
  }
  assert_true(saw_cached)

  let evaluated = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
  )
  let mut saw_evaluated = false
  for cell in evaluated.sheets[0].cells {
    match cell.formula_trace {
      Some(trace) =>
        if trace.policy == @xlsx.XlsxFormulaPolicy::EvaluatedMissingCache &&
          trace.evaluated_value == Some("high") {
          saw_evaluated = true
        }
      None => ()
    }
  }
  assert_true(saw_evaluated)

  let unsupported = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
  )
  let unsupported_report = @xlsx.validate_xlsx_workbook(unsupported)
  let mut saw_unsupported_issue = false
  for issue in unsupported_report.issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedFormulaEvaluation {
      saw_unsupported_issue = true
    }
  }
  assert_true(saw_unsupported_issue)
}

///|
test "xlsx semantic style and datetime boundaries stay conservative" {
  let built_in_date = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/xlsx_builtin_date_14.xlsx"),
  )
  let mut date_cell : @xlsx.XlsxCell? = None
  for cell in built_in_date.sheets[0].cells {
    if cell.reference == "B3" {
      date_cell = Some(cell)
      break
    }
  }
  let date_cell = date_cell.unwrap_or_else(() => fail("expected B3 date cell"))
  assert_eq(date_cell.style_index, 2)
  assert_eq(date_cell.num_format_id, 14)
  if date_cell.semantic_type != @xlsx.XlsxCellSemanticType::Date {
    fail("built-in date sample should preserve Date semantic type")
  }
  assert_eq(date_cell.display_text, "2024-03-14")

  let built_in_datetime = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_builtin_datetime_22.xlsx",
    ),
  )
  let mut datetime_cell : @xlsx.XlsxCell? = None
  for cell in built_in_datetime.sheets[0].cells {
    if cell.reference == "B3" {
      datetime_cell = Some(cell)
      break
    }
  }
  let datetime_cell = datetime_cell.unwrap_or_else(() => {
    fail("expected B3 datetime cell")
  })
  assert_eq(datetime_cell.num_format_id, 22)
  if datetime_cell.semantic_type != @xlsx.XlsxCellSemanticType::DateTime {
    fail("built-in datetime sample should preserve DateTime semantic type")
  }
  assert_eq(datetime_cell.display_text, "2024-03-14 15:30:00")

  let generated = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_workbook_date1904_pkg(),
  )
  assert_true(generated.uses_date_1904)
}

///|
test "xlsx semantic validation ordering is deterministic and workbook boundaries are preserved" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_validation_edges(),
  )
  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let report = @xlsx.validate_xlsx_workbook(workbook)

  assert_eq(issues.length(), report.issues.length())
  assert_eq(issues.length(), 5)
  if issues[0].kind != @xlsx.XlsxValidationIssueKind::DuplicateSheetName {
    fail("first validation issue should be duplicate sheet name")
  }
  if issues[1].kind != @xlsx.XlsxValidationIssueKind::InvalidMergedRange {
    fail("second validation issue should be invalid merged range")
  }
  if issues[2].kind != @xlsx.XlsxValidationIssueKind::InvalidCellReference {
    fail("third validation issue should be invalid cell reference")
  }
  if issues[3].kind != @xlsx.XlsxValidationIssueKind::MissingSharedString {
    fail("fourth validation issue should be missing shared string")
  }
  if issues[4].kind != @xlsx.XlsxValidationIssueKind::MissingWorksheetPart {
    fail("fifth validation issue should be missing worksheet part")
  }

  for i in 0..<issues.length() {
    if report.issues[i].kind != issues[i].kind {
      fail("validation report issue ordering should stay deterministic")
    }
    assert_eq(report.issues[i].message, issues[i].message)
  }

  let inspect = @xlsx.inspect_xlsx_workbook(workbook)
  assert_eq(inspect.sheet_count, 4)
  assert_eq(inspect.shared_string_count, 1)
  assert_eq(inspect.error_count, 3)
  assert_eq(inspect.warning_count, 2)
}

///|
test "xlsx semantic inspect counts hidden sheets merged ranges and formulas" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
  )
  let inspect = @xlsx.inspect_xlsx_workbook(workbook)
  assert_true(inspect.sheet_count > 0)
  assert_true(inspect.merged_range_count > 0)

  let hidden = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  let hidden_inspect = @xlsx.inspect_xlsx_workbook(hidden)
  assert_true(hidden_inspect.hidden_sheet_count > 0)

  let hidden_rows = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_hidden_rows(),
  )
  let hidden_rows_inspect = @xlsx.inspect_xlsx_workbook(hidden_rows)
  assert_eq(hidden_rows_inspect.hidden_row_count, 1)

  let formula = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx",
    ),
  )
  let formula_inspect = @xlsx.inspect_xlsx_workbook(formula)
  assert_true(formula_inspect.formula_cell_count > 0)
}

///|
test "xlsx semantic merged range and formula trace boundaries stay explicit" {
  let merged = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
  )
  assert_eq(merged.sheets[0].merged_ranges.length(), 3)
  assert_eq(merged.sheets[0].merged_ranges[0].range_ref, "B2:C2")

  let cached = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let mut saw_cached = false
  let mut saw_missing_cache = false
  for cell in cached.sheets[0].cells {
    match cell.formula_trace {
      Some(trace) =>
        if trace.policy == @xlsx.XlsxFormulaPolicy::Cached &&
          cell.formula_text == Some("1+2") {
          saw_cached = true
          if cell.source_value != Some("3") {
            fail("cached numeric formula should preserve cached source value")
          }
        } else if trace.policy == @xlsx.XlsxFormulaPolicy::EvaluatedMissingCache {
          saw_missing_cache = true
          if trace.evaluated_value != Some("5") {
            fail("evaluated missing-cache formula should preserve value 5")
          }
        }
      None => ()
    }
  }
  assert_true(saw_cached)
  assert_true(saw_missing_cache)
}

///|
test "xlsx classifier is stable for open and parse failures" {
  let open_info = @xlsx.classify_xlsx_error(
    @xlsx.XlsxError::OpenFailed("missing.xlsx"),
  )
  if open_info.kind != @xlsx.XlsxErrorKind::OpenFailed {
    fail("expected OpenFailed classification")
  }

  let parse_info = @xlsx.classify_xlsx_error(
    @xlsx.XlsxError::ParseError("invalid cell reference: A0"),
  )
  if parse_info.kind != @xlsx.XlsxErrorKind::InvalidCellReference {
    fail("expected InvalidCellReference classification")
  }
}

///|
test "xlsx semantic workbook preserves hidden row numbers without dropping cells" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_hidden_rows(),
  )
  assert_eq(workbook.sheets.length(), 1)
  assert_true(workbook.sheets[0].hidden_rows == [2])
  let mut saw_hidden_cell = false
  for cell in workbook.sheets[0].cells {
    if cell.reference == "A2" && cell.display_text == "Hidden Secret" {
      saw_hidden_cell = true
    }
  }
  assert_true(saw_hidden_cell)
}

///|
test "xlsx semantic workbook preserves worksheet comments with author and cell refs" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_comments(),
  )
  assert_eq(workbook.sheets.length(), 1)
  assert_eq(workbook.sheets[0].comments.length(), 2)
  assert_eq(workbook.sheets[0].comments[0].reference, "B1")
  match workbook.sheets[0].comments[0].author_name {
    Some(author) => assert_eq(author, "Analyst")
    None => fail("expected author name on first worksheet comment")
  }
  assert_eq(workbook.sheets[0].comments[0].text, "First insight")
  assert_eq(workbook.sheets[0].comments[1].reference, "A2")
  assert_eq(workbook.sheets[0].comments[1].row, 2)
  assert_eq(workbook.sheets[0].comments[1].column, 1)
  assert_eq(workbook.sheets[0].comments[1].text, "Second insight")
}

///|
test "xlsx semantic parser keeps self-closing blank cells blank" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_self_closing_blank_cells(),
  )
  assert_eq(workbook.sheets.length(), 1)
  let sheet = workbook.sheets[0]
  assert_eq(sheet.used_min_row, 1)
  assert_eq(sheet.used_min_col, 1)
  assert_eq(sheet.used_max_row, 5)
  assert_eq(sheet.used_max_col, 1)

  let mut saw_a1 = false
  let mut saw_b1 = false
  let mut saw_b3 = false
  for cell in sheet.cells {
    if cell.reference == "A1" {
      saw_a1 = true
      assert_eq(cell.display_text, "http://www.apache.org")
    } else if cell.reference == "B1" {
      saw_b1 = true
      if cell.kind != @xlsx.XlsxCellKind::Blank {
        fail("B1 should stay blank for self-closing styled cell")
      }
      assert_eq(cell.display_text, "")
    } else if cell.reference == "B3" {
      saw_b3 = true
      if cell.kind != @xlsx.XlsxCellKind::Blank {
        fail("B3 should stay blank for self-closing styled cell")
      }
      assert_eq(cell.display_text, "")
    }
  }
  assert_true(saw_a1)
  assert_true(saw_b1)
  assert_true(saw_b3)
}
