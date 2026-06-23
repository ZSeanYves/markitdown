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
  let cells = xlsx_parse_sheet_cells(
    xlsx_wbtest_sheet_info(),
    sheet_xml,
    [],
    xlsx_wbtest_styles(),
    false,
  )
  let mut non_empty_cell_count = 0
  let mut formula_count = 0
  for cell in cells {
    if cell.display_text.trim() != "" {
      non_empty_cell_count += 1
    }
    match cell.formula_text {
      Some(_) => formula_count += 1
      None => ()
    }
  }
  assert_eq(cells.length(), 6)
  assert_eq(non_empty_cell_count, 0)
  assert_eq(formula_count, 0)
  assert_true(
    xlsx_sheet_is_effectively_empty(false, non_empty_cell_count, formula_count),
  )
}

///|
test "xlsx parser keeps visible cells and formulas from being reclassified empty" {
  assert_true(!xlsx_sheet_is_effectively_empty(false, 1, 0))
  assert_true(!xlsx_sheet_is_effectively_empty(false, 0, 1))
  assert_true(xlsx_sheet_is_effectively_empty(true, 1, 1))
}
