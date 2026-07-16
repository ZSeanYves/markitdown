///|
fn xlsx_wbtest_sheet_info() -> XlsxSheetInfo {
  {
    sheet_name: "Sheet1",
    sheet_id: Some("1"),
    relationship_id: "rId1",
    part_name: "xl/worksheets/sheet1.xml",
    visibility: Visible,
  }
}

///|
fn xlsx_wbtest_styles() -> XlsxStyles {
  { xf_numfmts: [], custom_numfmts: Map([]) }
}

///|
fn xlsx_wbtest_relationships() -> Array[@ox.OoxmlRelationship] {
  []
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
fn crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
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
  let central_offset = out.length()
  for item in central {
    let (name, size, local_offset, crc32) = item
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
  let central_size = out.length() - central_offset
  append_u32_le(out, 0x06054b50)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, central.length())
  append_u16_le(out, central.length())
  append_u32_le(out, central_size)
  append_u32_le(out, central_offset)
  append_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
fn xlsx_wbtest_preflight_package() -> @ox.OoxmlPackage raise {
  @ox.open_ooxml_package(
    build_store_zip([
      (
        "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/></Types>",
      ),
      (
        "_rels/.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
      ),
      (
        "xl/workbook.xml", "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Visible\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"Hidden\" sheetId=\"2\" state=\"hidden\" r:id=\"rId2\"/><sheet name=\"VeryHidden\" sheetId=\"3\" state=\"veryHidden\" r:id=\"rId3\"/></sheets></workbook>",
      ),
      (
        "xl/_rels/workbook.xml.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet2.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet3.xml\"/></Relationships>",
      ),
      (
        "xl/worksheets/sheet1.xml", "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><dimension ref=\"B2:D11\"/><sheetData><row r=\"2\"><c r=\"B2\"><v>1</v></c></row></sheetData></worksheet>",
      ),
      (
        "xl/worksheets/sheet2.xml", "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><dimension ref=\"A1:A1\"/></worksheet>",
      ),
      (
        "xl/worksheets/sheet3.xml", "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><dimension ref=\"A1:A1\"/></worksheet>",
      ),
    ]),
  )
}

///|
test "xlsx parser capability and preflight budget helpers cover boundaries" {
  let capability = xlsx_parser_capability()
  assert_true(capability.supports_streaming)
  assert_true(capability.produces_tables)
  assert_eq(xlsx_parser().name, "xlsx_parser")
  assert_eq(xlsx_preflight_sheet_probe_byte_limit(1, 1, 1), 1048576)
  assert_eq(xlsx_preflight_sheet_probe_byte_limit(1000, 1000, 1), 32000000)
  assert_eq(xlsx_preflight_sheet_probe_byte_limit(0, 0, 40000), 1280000)
  assert_eq(xlsx_preflight_estimated_cells_from_sheet_xml_bytes(0), 0)
  assert_eq(xlsx_preflight_estimated_cells_from_sheet_xml_bytes(32), 1)
  assert_eq(xlsx_preflight_estimated_cells_from_sheet_xml_bytes(33), 2)
}

///|
test "xlsx compact worksheet stream keeps budgeted rows and trailing metadata" {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet><dimension ref=\"A1:B3\"/><sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Cäsar</t></is></c></row>" +
    "<row r=\"2\"><c r=\"A2\"><v>2</v></c></row>" +
    "<row r=\"3\"><c r=\"A3\"><v>3</v></c></row>" +
    "</sheetData><mergeCells><mergeCell ref=\"A1:B1\"/></mergeCells>" +
    "<hyperlinks><hyperlink ref=\"A2\" r:id=\"rIdLink\"/></hyperlinks>" +
    "</worksheet>"
  let pkg = @ox.open_ooxml_package(
    build_store_zip([
      (
        "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>",
      ),
      ("xl/worksheets/sheet1.xml", xml),
    ]),
  ) catch {
    err => fail("open compact stream fixture failed: " + err.to_string())
  }
  let compact = match
    xlsx_compact_sheet_xml_stream(pkg, "xl/worksheets/sheet1.xml", 2) {
    Ok(value) => xlsx_decode_sheet_xml(value)
    Err(err) => fail("compact stream failed: " + err)
  }
  assert_true(compact.contains("Cäsar"))
  assert_true(compact.contains("r=\"A2\""))
  assert_true(!compact.contains("r=\"A3\""))
  assert_true(compact.contains("mergeCell ref=\"A1:B1\""))
  assert_true(compact.contains("hyperlink ref=\"A2\""))
}

///|
test "xlsx preflight counts visibility dimensions and route estimates" {
  let pkg = xlsx_wbtest_preflight_package()
  match xlsx_preflight_summary_with_package(pkg) {
    Ok(summary) => {
      assert_eq(summary.sheet_count, 3)
      assert_eq(summary.visible_sheet_count, 1)
      assert_eq(summary.hidden_sheet_count, 1)
      assert_eq(summary.very_hidden_sheet_count, 1)
      assert_eq(summary.max_sheet_rows, 10)
      assert_eq(summary.max_sheet_cols, 3)
      assert_eq(summary.estimated_cells, 30)
    }
    Err(error) => fail(error)
  }
  match xlsx_route_preflight_summary_with_package(pkg, 100, 20, 2000) {
    Ok(summary) => {
      assert_eq(summary.visible_sheet_count, 1)
      assert_eq(summary.estimated_cells, 30)
    }
    Err(error) => fail(error)
  }
}

///|
test "xlsx parser invalid package paths return controlled diagnostics" {
  let source = @input.input_from_bytes_with_format(
    @utf8.encode("not-a-zip"),
    "broken.xlsx",
    Some(Xlsx),
  )
  assert_true(xlsx_workbook_metric(source) is Err(_))
  assert_true(xlsx_first_sheet_metric(source) is Err(_))
  assert_true(xlsx_preflight_summary(source) is Err(_))
  let context = @parser.new_parse_context(Xlsx)
  match xlsx_parse_document_result(source, context, xlsx_parser_capability()) {
    Ok(result) => {
      assert_true(result.diagnostics.errors.length() > 0)
      assert_true(result.diagnostics.degraded_features.length() > 0)
    }
    Err(error) => fail("malformed package should become diagnostics: " + error)
  }
}

///|
test "xlsx prepared package parses document and block stream routes" {
  let pkg = xlsx_wbtest_preflight_package()
  let source = @input.input_from_bytes_with_format(
    Bytes::new(0),
    "prepared.xlsx",
    Some(Xlsx),
  )
  let document_result = xlsx_parse_with_package(
    source,
    @parser.new_parse_context(Xlsx),
    pkg,
  )
  assert_eq(document_result.diagnostics.errors.length(), 0)
  assert_true(
    document_result.diagnostics.metrics.get("probe_artifact_reused") ==
    Some("true"),
  )
  assert_true(document_result.diagnostics.metrics.get("block_count") is Some(_))
  let block_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Xlsx),
    Some(BlockStreaming),
    Some(100),
    Some(20),
    Some(2000),
    Some(100),
    false,
  )
  let block_result = xlsx_parse_with_package(source, block_context, pkg)
  assert_eq(block_result.diagnostics.errors.length(), 0)
  assert_true(
    block_result.diagnostics.metrics.get("effective_mode") ==
    Some("block_streaming"),
  )
  assert_true(
    block_result.diagnostics.pass_trace.contains(
      "parse:xlsx_parser:block_stream_route",
    ),
  )
}

///|
test "xlsx parser lowers repository formula hidden table merge and hyperlink fixtures" {
  let fixtures = [
    "samples/fixtures/contracts/xlsx/xlsx_formula_missing_cache.xlsx", "samples/fixtures/contracts/xlsx/xlsx_hidden_sheets_policy.xlsx",
    "samples/fixtures/contracts/xlsx/xlsx_multi_sheet_mixed.xlsx", "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
  ]
  for path in fixtures {
    let result = (xlsx_parser().parse)(
      @input.input_from_path(path),
      @parser.new_parse_context(Xlsx),
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    assert_true(result.document.unwrap().blocks.length() > 0)
    assert_true(result.diagnostics.metrics.get("xlsx_sheet_count") != Some("0"))
  }
}

///|
test "xlsx advanced synthetic contract covers shared styles formulas comments tables drawings and streams" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/xlsx/xlsx_advanced_synthetic.xlsx",
  )
  let balanced = (xlsx_parser().parse)(source, @parser.new_parse_context(Xlsx)).unwrap()
  let document = balanced.document.unwrap()
  assert_true(balanced.diagnostics.errors.length() == 0)
  assert_true(balanced.diagnostics.metrics.get("xlsx_sheet_count") == Some("2"))
  assert_true(
    document.blocks.any(block => block.kind == Heading && block.text == "Data"),
  )
  assert_true(document.blocks.any(block => block.kind == Table))
  assert_true(document.blocks.any(block => block.kind == Image))
  assert_true(
    !document.blocks.any(block => block.text.contains("Hidden value")),
  )
  assert_true(document.assets.length() == 1)

  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Xlsx),
    Some(BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (xlsx_parser().parse)(source, stream_context).unwrap()
  assert_true(streamed.diagnostics.errors.length() == 0)
  assert_true(streamed.block_stream.unwrap().length() > 0)
  assert_true(streamed.assets.length() == 1)
}

///|
test "xlsx parser treats merge-only placeholder cells as an empty sheet" {
  let sheet_xml = "<worksheet><dimension ref=\"A1:C50000\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"1\"/><c r=\"B1\" s=\"1\"/><c r=\"C1\" s=\"1\"/></row><row r=\"50000\"><c r=\"A50000\" s=\"1\"/><c r=\"B50000\" s=\"1\"/><c r=\"C50000\" s=\"1\"/></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:C50000\"/></mergeCells></worksheet>"
  let parsed = xlsx_parse_sheet_xml_bytes(
    xlsx_wbtest_sheet_info(),
    @utf8.encode(sheet_xml),
    [],
    xlsx_wbtest_styles(),
    false,
    xlsx_wbtest_relationships(),
  )
  let mut non_empty_cell_count = 0
  let mut formula_count = 0
  for cell in parsed.cells {
    if cell.display_text.trim() != "" {
      non_empty_cell_count += 1
    }
    match cell.formula_text {
      Some(_) => formula_count += 1
      None => ()
    }
  }
  assert_eq(parsed.cells.length(), 6)
  assert_eq(non_empty_cell_count, 0)
  assert_eq(formula_count, 0)
  assert_true(
    xlsx_sheet_is_effectively_empty(false, non_empty_cell_count, formula_count),
  )
}

///|
test "xlsx parser shared sheet scan extracts dimension hidden rows merges and cells" {
  let sheet_xml = "<worksheet><dimension ref=\"A1:B4\"/><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row><row r=\"2\" hidden=\"1\"><c r=\"B2\"><v>42</v></c></row><row r=\"4\"><c r=\"A4\"><f>SUM(A1:A3)</f><v>6</v></c></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>"
  let parsed = xlsx_parse_sheet_xml_bytes(
    xlsx_wbtest_sheet_info(),
    @utf8.encode(sheet_xml),
    ["Header"],
    xlsx_wbtest_styles(),
    false,
    xlsx_wbtest_relationships(),
  )
  assert_true(parsed.dimension_ref == Some("A1:B4"))
  assert_true(parsed.hidden_rows.get(2) == Some(true))
  assert_eq(parsed.merged_ranges.length(), 1)
  assert_eq(parsed.merged_ranges[0], "A1:B1")
  assert_eq(parsed.cells.length(), 3)
  assert_eq(parsed.cells[0].row_index, 1)
  assert_eq(parsed.cells[0].column_index, 1)
  assert_eq(parsed.cells[1].row_index, 2)
  assert_eq(parsed.cells[1].column_index, 2)
  assert_eq(parsed.cells[2].row_index, 4)
  assert_eq(parsed.cells[2].column_index, 1)
  assert_eq(parsed.cells[0].display_text, "Header")
  assert_eq(parsed.cells[1].display_text, "42")
  assert_true(parsed.cells[2].formula_text == Some("SUM(A1:A3)"))
}

///|
test "xlsx parser worksheet scan handles merge-only sparse sheets" {
  let sheet_xml = "<worksheet><dimension ref=\"A1:C50000\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"1\"/><c r=\"B1\" s=\"1\"/><c r=\"C1\" s=\"1\"/></row><row r=\"50000\"><c r=\"A50000\" s=\"1\"/><c r=\"B50000\" s=\"1\"/><c r=\"C50000\" s=\"1\"/></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:C50000\"/></mergeCells></worksheet>"
  let parsed = xlsx_parse_sheet_xml_bytes(
    xlsx_wbtest_sheet_info(),
    @utf8.encode(sheet_xml),
    [],
    xlsx_wbtest_styles(),
    false,
    xlsx_wbtest_relationships(),
  )
  assert_true(parsed.dimension_ref == Some("A1:C50000"))
  assert_eq(parsed.cells.length(), 6)
  assert_eq(parsed.merged_ranges.length(), 1)
  assert_eq(parsed.merged_ranges[0], "A1:C50000")
}

///|
test "xlsx parser worksheet scan keeps multiple merge ranges aligned" {
  let sheet_xml = "<worksheet><dimension ref=\"A1:C50000\"/><sheetData><row r=\"1\"><c r=\"A1\" s=\"1\"/><c r=\"B1\" s=\"1\"/><c r=\"C1\" s=\"1\"/></row><row r=\"50000\"><c r=\"A50000\" s=\"1\"/><c r=\"B50000\" s=\"1\"/><c r=\"C50000\" s=\"1\"/></row></sheetData><mergeCells count=\"2\"><mergeCell ref=\"A1:C49999\"/><mergeCell ref=\"A50000:C50000\"/></mergeCells></worksheet>"
  let parsed = xlsx_parse_sheet_xml_bytes(
    xlsx_wbtest_sheet_info(),
    @utf8.encode(sheet_xml),
    [],
    xlsx_wbtest_styles(),
    false,
    xlsx_wbtest_relationships(),
  )
  assert_eq(parsed.merged_ranges.length(), 2)
  assert_eq(parsed.merged_ranges[0], "A1:C49999")
  assert_eq(parsed.merged_ranges[1], "A50000:C50000")
}

///|
test "xlsx parser worksheet scan keeps formula rows" {
  let sheet_xml = "<worksheet><dimension ref=\"A1:B4\"/><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row><row r=\"2\" hidden=\"1\"><c r=\"B2\"><v>42</v></c></row><row r=\"4\"><c r=\"A4\"><f>SUM(A1:A3)</f><v>6</v></c></row></sheetData><mergeCells count=\"1\"><mergeCell ref=\"A1:B1\"/></mergeCells></worksheet>"
  let parsed = xlsx_parse_sheet_xml_bytes(
    xlsx_wbtest_sheet_info(),
    @utf8.encode(sheet_xml),
    ["Header"],
    xlsx_wbtest_styles(),
    false,
    xlsx_wbtest_relationships(),
  )
  assert_true(parsed.dimension_ref == Some("A1:B4"))
  assert_true(parsed.hidden_rows.get(2) == Some(true))
  assert_eq(parsed.merged_ranges.length(), 1)
  assert_eq(parsed.merged_ranges[0], "A1:B1")
  assert_eq(parsed.cells.length(), 3)
  assert_eq(parsed.cells[0].row_index, 1)
  assert_eq(parsed.cells[0].column_index, 1)
  assert_eq(parsed.cells[1].row_index, 2)
  assert_eq(parsed.cells[1].column_index, 2)
  assert_eq(parsed.cells[2].row_index, 4)
  assert_eq(parsed.cells[2].column_index, 1)
  assert_eq(parsed.cells[0].display_text, "Header")
  assert_eq(parsed.cells[1].display_text, "42")
  assert_true(parsed.cells[2].formula_text == Some("SUM(A1:A3)"))
}

///|
test "xlsx parser keeps visible cells and formulas from being reclassified empty" {
  assert_true(!xlsx_sheet_is_effectively_empty(false, 1, 0))
  assert_true(!xlsx_sheet_is_effectively_empty(false, 0, 1))
  assert_true(xlsx_sheet_is_effectively_empty(true, 1, 1))
}

///|
test "xlsx parser expands hyperlink ranges onto covered cells" {
  let sheet_xml = "<worksheet><hyperlinks><hyperlink ref=\"A1:A3\" r:id=\"rIdLink\"/></hyperlinks></worksheet>"
  let pkg = @ox.open_ooxml_package(
    build_store_zip([
      (
        "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>",
      ),
      (
        "xl/worksheets/_rels/sheet1.xml.rels", "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com\" TargetMode=\"External\"/></Relationships>",
      ),
    ]),
  ) catch {
    e => fail("open hyperlink wbtest package failed: " + e.to_string())
  }
  let hyperlinks = xlsx_parse_sheet_hyperlinks(
    sheet_xml,
    @ox.read_part_relationships(pkg, "xl/worksheets/sheet1.xml") catch {
      e => fail("read hyperlink wbtest relationships failed: " + e.to_string())
    },
  )
  assert_eq(hyperlinks.length(), 1)
  let hit_a1 = xlsx_lookup_sheet_hyperlink(hyperlinks, 1, 1)
  let hit_a2 = xlsx_lookup_sheet_hyperlink(hyperlinks, 2, 1)
  let hit_a3 = xlsx_lookup_sheet_hyperlink(hyperlinks, 3, 1)
  let miss_a4 = xlsx_lookup_sheet_hyperlink(hyperlinks, 4, 1)
  assert_true(hit_a1 == (Some("https://example.com"), Some("rIdLink")))
  assert_true(hit_a2 == (Some("https://example.com"), Some("rIdLink")))
  assert_true(hit_a3 == (Some("https://example.com"), Some("rIdLink")))
  assert_true(miss_a4 == (None, None))
}

///|
test "xlsx effective bounds can include hidden-row semantic cells for accurate fidelity" {
  let cells = [
    {
      row_index: 8,
      column_index: 1,
      display_text: "inner",
      hyperlink_target: None,
      hyperlink_relationship_id: None,
      formula_text: None,
      is_shared_formula: false,
      is_array_formula: false,
      source_ref: None,
    },
    {
      row_index: 12,
      column_index: 1,
      display_text: "collapsed",
      hyperlink_target: None,
      hyperlink_relationship_id: None,
      formula_text: None,
      is_shared_formula: false,
      is_array_formula: false,
      source_ref: None,
    },
  ]
  let hidden_rows : Map[Int, Bool] = Map([(8, true)])
  let balanced = xlsx_effective_bounds(
    None,
    cells,
    hidden_rows,
    false,
    2000,
    50,
    100000,
  )
  let accurate = xlsx_effective_bounds(
    None,
    cells,
    hidden_rows,
    true,
    2000,
    50,
    100000,
  )
  let (
    balanced_min_row,
    balanced_min_col,
    balanced_max_row,
    balanced_max_col,
    balanced_clipped,
    balanced_empty,
  ) = balanced
  let (
    accurate_min_row,
    accurate_min_col,
    accurate_max_row,
    accurate_max_col,
    accurate_clipped,
    accurate_empty,
  ) = accurate
  assert_eq(balanced_min_row, 12)
  assert_eq(balanced_min_col, 1)
  assert_eq(balanced_max_row, 12)
  assert_eq(balanced_max_col, 1)
  assert_eq(balanced_clipped, false)
  assert_eq(balanced_empty, false)
  assert_eq(accurate_min_row, 8)
  assert_eq(accurate_min_col, 1)
  assert_eq(accurate_max_row, 12)
  assert_eq(accurate_max_col, 1)
  assert_eq(accurate_clipped, false)
  assert_eq(accurate_empty, false)
  assert_eq(xlsx_effective_row_count(hidden_rows, false, 8, 12), 4)
  assert_eq(xlsx_effective_row_count(hidden_rows, true, 8, 12), 5)
}

///|
test "xlsx direct sheet scanner helpers cover tag formula value inline and window boundaries" {
  for ch in ['>', ' ', '\n', '\r', '\t', '/'] {
    assert_true(xlsx_is_xml_name_boundary(ch))
  }
  assert_true(!xlsx_is_xml_name_boundary('x'))
  let tags = "<dimension ref=\"A1\"/><row r=\"1\"><c r=\"A1\"><f t=\"array\">SUM(A1)</f><v>1</v></c></row><mergeCell ref=\"A1:B1\"/>"
  assert_true(xlsx_is_dimension_tag(tags, 0, tags.length()))
  let row_at = xlsx_find_sub(tags, "<row", 0).unwrap()
  let cell_at = xlsx_find_sub(tags, "<c ", 0).unwrap()
  let merge_at = xlsx_find_sub(tags, "<mergeCell", 0).unwrap()
  assert_true(xlsx_is_row_tag(tags, row_at, tags.length()))
  assert_true(xlsx_is_cell_tag(tags, cell_at, tags.length()))
  assert_true(xlsx_is_merge_cell_tag(tags, merge_at, tags.length()))
  assert_true(!xlsx_is_row_tag("<rows>", 0, 6))
  assert_true(!xlsx_is_cell_tag("<cell>", 0, 6))
  assert_true(xlsx_find_tag_end(tags, 0, tags.length()) is Some(_))
  assert_true(xlsx_find_tag_end("<tag", 0, 4) is None)
  assert_true(xlsx_find_cell_close(tags, cell_at, tags.length()) is Some(_))
  assert_true(xlsx_find_cell_close("<c>", 0, 3) is None)
  assert_true(xlsx_tag_is_self_closing("<c />", 0, 4))
  assert_true(!xlsx_tag_is_self_closing("<c >", 0, 3))
  assert_true(
    xlsx_find_named_open_tag_range(tags, "f", 0, tags.length()) is Some(_),
  )
  assert_true(xlsx_find_named_open_tag_range("<foo/>", "f", 0, 6) is None)
  assert_true(
    xlsx_tag_text_range("<v>42&amp;1</v>", 0, 16, "v") == Some("42&1"),
  )
  assert_true(xlsx_tag_text_range("<v/>", 0, 4, "v") == Some(""))
  assert_true(xlsx_tag_text_range("<v>", 0, 3, "v") is None)
  let formula = xlsx_extract_formula_info_range(tags, 0, tags.length()).unwrap()
  assert_true(formula.formula_type == Some("array"))
  assert_eq(formula.text, "SUM(A1)")
  assert_true(
    xlsx_extract_formula_info_range("<f t=\"shared\"/>", 0, 15).unwrap().text ==
    "",
  )
  assert_true(xlsx_extract_formula_info_range("<v>1</v>", 0, 8) is None)

  let styles = xlsx_wbtest_styles()
  assert_true(
    xlsx_resolve_cell_display(
      "s",
      Some("0"),
      None,
      None,
      0,
      ["Shared"],
      styles,
      false,
    ) ==
    ("Shared", "string", Some(0)),
  )
  assert_true(
    xlsx_resolve_cell_display(
      "s",
      Some("9"),
      None,
      None,
      0,
      ["Shared"],
      styles,
      false,
    ) ==
    ("", "string", None),
  )
  assert_true(
    xlsx_resolve_cell_display(
      "inlineStr",
      None,
      Some("Inline"),
      None,
      0,
      [],
      styles,
      false,
    ).0 ==
    "Inline",
  )
  assert_true(
    xlsx_resolve_cell_display("b", Some("1"), None, None, 0, [], styles, false).0 ==
    "TRUE",
  )
  assert_true(
    xlsx_resolve_cell_display("b", Some("0"), None, None, 0, [], styles, false).0 ==
    "FALSE",
  )
  assert_true(
    xlsx_resolve_cell_display(
      "e",
      Some("#N/A"),
      None,
      None,
      0,
      [],
      styles,
      false,
    ).1 ==
    "error",
  )
  assert_true(
    xlsx_resolve_cell_display(
      "str",
      Some("A&amp;B"),
      None,
      None,
      0,
      [],
      styles,
      false,
    ).0 ==
    "A&B",
  )
  assert_true(
    xlsx_resolve_cell_display("n", None, None, None, 0, [], styles, false).1 ==
    "blank",
  )
  assert_true(
    xlsx_resolve_cell_display(
      "n",
      None,
      None,
      Some("SUM(A1)"),
      0,
      [],
      styles,
      false,
    ).1 ==
    "formula_missing_cache",
  )
  assert_true(
    xlsx_resolve_cell_display(
      "n",
      Some("1"),
      None,
      Some("SUM(A1)"),
      0,
      [],
      styles,
      false,
    ).1 ==
    "formula_cached_value",
  )
  assert_true(xlsx_semantic_type_for_style("1", -1, styles) == "number")

  let inline_xml = "<is><r><t>A&amp;</t></r><r><t>B</t></r></is>"
  assert_true(
    xlsx_parse_inline_string_range(inline_xml, 0, inline_xml.length()) ==
    Some("A&B"),
  )
  assert_true(
    xlsx_parse_inline_string_range("<t>fallback</t>", 0, 15) == Some("fallback"),
  )
  assert_true(xlsx_parse_inline_string_range("<is></is>", 0, 9) is None)
  assert_eq(
    xlsx_concat_text_runs("<t>A</t><tx>skip</tx><t>B&amp;C</t>"),
    "AB&C",
  )
  assert_eq(xlsx_concat_text_runs("<t>broken"), "")
  assert_true(
    xlsx_comment_authors(
      "<authors><author>Ada</author><author>A&amp;B</author></authors>",
    ) ==
    ["Ada", "A&B"],
  )
  assert_eq(
    xlsx_comment_strip_author_prefix(Some("Ada"), " Ada: review "),
    "review",
  )
  assert_eq(
    xlsx_comment_strip_author_prefix(Some("Ada"), "Bob: review"),
    "Bob: review",
  )
  assert_eq(xlsx_comment_strip_author_prefix(None, " review "), "review")
  assert_true(xlsx_cell_outside_window(0, 1, Some((1, 1, 2, 2))))
  assert_true(xlsx_cell_outside_window(1, 3, Some((1, 1, 2, 2))))
  assert_true(!xlsx_cell_outside_window(1, 1, Some((1, 1, 2, 2))))
  assert_true(!xlsx_cell_outside_window(99, 99, None))
  assert_true(xlsx_row_exceeds_window(3, Some((1, 1, 2, 2))))
  assert_true(!xlsx_row_exceeds_window(3, None))
}
