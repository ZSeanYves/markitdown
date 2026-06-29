///|
fn xlsx_wbtest_sheet_info() -> XlsxSheetInfo {
  {
    sheet_name: "Sheet1",
    sheet_id: Some("1"),
    relationship_id: "rId1",
    part_name: "xl/worksheets/sheet1.xml",
    visibility: @shared.XlsxSheetVisibility::Visible,
  }
}

///|
fn xlsx_wbtest_styles() -> XlsxStyles {
  { xf_numfmts: [], custom_numfmts: Map([]) }
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
