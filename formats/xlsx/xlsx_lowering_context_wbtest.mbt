///|
test "XLSX range and cell reference helpers cover absolute and invalid inputs" {
  assert_true(xlsx_parse_range_ref("A1") == Some((1, 1, 1, 1)))
  assert_true(xlsx_parse_range_ref(" $b$2 : AA10 ") == Some((2, 2, 10, 27)))
  assert_true(xlsx_parse_range_ref("") is None)
  assert_true(xlsx_parse_range_ref("A0:B2") is None)
  assert_true(xlsx_parse_range_ref("A1:bad!") is None)
  assert_true(xlsx_cell_ref_to_rc_range(" zz99 ", 0, 6) == (99, 702))
  assert_true(xlsx_cell_ref_to_rc_range("A-1", 0, 3) == (0, 0))
  assert_eq(xlsx_rc_to_cell_ref(1, 1), "A1")
  assert_eq(xlsx_rc_to_cell_ref(9, 26), "Z9")
  assert_eq(xlsx_rc_to_cell_ref(10, 27), "AA10")
  assert_eq(xlsx_rc_to_cell_ref(3, 702), "ZZ3")
  assert_eq(xlsx_rc_to_cell_ref(0, 1), "")
  assert_eq(xlsx_rc_to_cell_ref(1, 0), "")
  assert_eq(xlsx_merged_cell_area(["A1:B2", "C3", "bad"]), 5)
  assert_eq(xlsx_lookup_key(12, 4), "12,4")
}

///|
test "XLSX bounded scanners and attribute helpers cover all boundary outcomes" {
  let xml = "xx<c r=\"B2\" s=\"3\">value</c>yy"
  assert_true(xlsx_find_char(xml, '<', -5, 999) == Some(2))
  assert_true(xlsx_find_char(xml, '!', 0, xml.length()) is None)
  assert_true(xlsx_find_sub(xml, "<c", 0) == Some(2))
  assert_true(xlsx_find_sub_range(xml, "", 4, 7) == Some(4))
  assert_true(xlsx_find_sub_range(xml, "<c", -1, 7) is None)
  assert_true(xlsx_find_sub_range(xml, "missing", 0, 4) is None)
  assert_true(xlsx_find_sub_range(xml, "value", 0, xml.length()) == Some(18))
  assert_true(xlsx_get_attr("<c r=\"B2\" s=\"3\">", "r") == Some("B2"))
  assert_true(xlsx_get_attr("<c r=\"B2>", "r") is None)
  assert_true(xlsx_get_attr("<c>", "r") is None)
  assert_true(xlsx_attr_value_bounds(xml, 2, 17, "r") == Some((8, 10)))
  assert_true(xlsx_attr_value_bounds(xml, 2, 9, "r") is None)
  assert_true(xlsx_attr_value_bounds(xml, 2, 17, "z") is None)
  assert_true(xlsx_get_attr_range(xml, 2, 17, "s") == Some("3"))
  assert_true(xlsx_get_attr_range(xml, 2, 17, "z") is None)
  assert_true(xlsx_trimmed_slice_bounds(" \t abc \r\n", -1, 99) == (3, 6))
}

///|
test "XLSX integer XML and whitespace helpers reject malformed input" {
  assert_eq(xlsx_parse_int("  +42 "), 42)
  assert_eq(xlsx_parse_int(" -7 "), -7)
  assert_eq(xlsx_parse_int(""), -1)
  assert_eq(xlsx_parse_int("+"), -1)
  assert_eq(xlsx_parse_int("12x"), -1)
  assert_eq(xlsx_parse_int_range("xx 17 yy", 2, 6), 17)
  assert_true(xlsx_contains_char("abc&def", '&'))
  assert_true(!xlsx_contains_char("abcdef", '&'))
  assert_true(xlsx_is_blank_text(" \n\r\t"))
  assert_true(!xlsx_is_blank_text("  x"))
  for ch in [' ', '\n', '\r', '\t'] {
    assert_true(xlsx_is_ascii_whitespace(ch))
  }
  assert_true(!xlsx_is_ascii_whitespace('x'))
  assert_eq(xlsx_xml_unescape("plain"), "plain")
  assert_eq(
    xlsx_xml_unescape("&lt;&gt;&amp;&quot;&apos;&#65;&#x42;"),
    "<>&\"'AB",
  )
  assert_eq(xlsx_decode_numeric_entities("x&#bad;y&#12"), "x&#bad;y&#12")
  assert_true(xlsx_parse_dec_int("") is None)
  assert_true(xlsx_parse_dec_int("12x") is None)
  assert_true(xlsx_parse_dec_int("123") == Some(123))
  assert_true(xlsx_parse_hex_int("") is None)
  assert_true(xlsx_parse_hex_int("g") is None)
  assert_true(xlsx_parse_hex_int("aF10") == Some(44816))
}

///|
test "XLSX number format and Excel serial helpers cover date systems" {
  let styles : XlsxStyles = {
    xf_numfmts: [14, 164],
    custom_numfmts: { 164: "yyyy-mm-dd hh:mm:ss" },
  }
  assert_eq(xlsx_style_numfmt(styles, -1), -1)
  assert_eq(xlsx_style_numfmt(styles, 2), -1)
  assert_eq(xlsx_style_numfmt(styles, 0), 14)
  assert_true(xlsx_numfmt_is_datetime_like(14, styles))
  assert_true(xlsx_numfmt_is_datetime_like(164, styles))
  assert_true(!xlsx_numfmt_is_datetime_like(999, styles))
  assert_true(xlsx_builtin_datetime_numfmt(47))
  assert_true(!xlsx_builtin_datetime_numfmt(13))
  assert_true(xlsx_datetime_code_like("[h]:mm"))
  assert_true(xlsx_datetime_code_like("yyyy-mm-dd"))
  assert_true(!xlsx_datetime_code_like("0.00"))
  assert_true(xlsx_parse_excel_serial("") is None)
  assert_true(xlsx_parse_excel_serial("-1") is None)
  assert_true(xlsx_parse_excel_serial("abc") is None)
  assert_true(xlsx_parse_excel_serial("1x") is None)
  assert_true(xlsx_parse_excel_serial(".") is None)
  assert_true(xlsx_parse_excel_serial("2") == Some((2, 0, 1)))
  assert_true(xlsx_parse_excel_serial(".5") == Some((0, 5, 10)))
  assert_true(
    xlsx_parse_excel_serial("1.1234567") == Some((1, 123456, 1000000)),
  )
  assert_true(xlsx_frac_to_hms(0, 1) == (0, 0, 0, 0))
  assert_true(xlsx_frac_to_hms(1, 0) == (0, 0, 0, 0))
  assert_true(xlsx_frac_to_hms(1, 2) == (0, 12, 0, 0))
  assert_true(xlsx_frac_to_hms(999999, 1000000) == (1, 0, 0, 0))
  assert_eq(xlsx_format_excel_datetime("bad", 14, None, false), "bad")
  assert_eq(xlsx_format_excel_datetime("1", 14, None, false), "1900-01-01")
  assert_eq(xlsx_format_excel_datetime(".5", 18, None, false), "12:00:00")
  assert_eq(
    xlsx_format_excel_datetime("1.5", 22, None, false),
    "1900-01-01 12:00:00",
  )
  assert_eq(
    xlsx_format_excel_datetime("0", 164, Some("yyyy-mm-dd"), true),
    "1904-01-01",
  )
  assert_eq(
    xlsx_format_excel_datetime("0.25", 164, Some("hh:mm:ss"), true),
    "06:00:00",
  )
}

///|
test "XLSX calendar helpers cover leap boundaries and padding" {
  assert_true(xlsx_excel_serial_to_ymd(0, false) == (1899, 12, 30))
  assert_true(xlsx_excel_serial_to_ymd(60, false) == (1900, 2, 29))
  assert_true(xlsx_excel_serial_to_ymd(61, false) == (1900, 3, 1))
  assert_true(xlsx_excel_serial_to_ymd(43890, false) == (2020, 2, 29))
  assert_true(xlsx_excel_serial_to_ymd(-1, true) == (1903, 12, 31))
  assert_true(xlsx_excel_serial_to_ymd(0, true) == (1904, 1, 1))
  assert_true(xlsx_excel_serial_to_ymd(1461, true) == (1908, 1, 1))
  assert_true(xlsx_is_leap_year(2000))
  assert_true(!xlsx_is_leap_year(1900))
  assert_true(xlsx_is_leap_year(2024))
  assert_true(!xlsx_is_leap_year(2023))
  assert_eq(xlsx_days_in_month(2024, 2), 29)
  assert_eq(xlsx_days_in_month(2023, 2), 28)
  assert_eq(xlsx_days_in_month(2023, 4), 30)
  assert_eq(xlsx_days_in_month(2023, 12), 31)
  assert_eq(xlsx_pad2(3), "03")
  assert_eq(xlsx_pad2(12), "12")
  assert_eq(xlsx_pad4(7), "0007")
  assert_eq(xlsx_pad4(42), "0042")
  assert_eq(xlsx_pad4(999), "0999")
  assert_eq(xlsx_pad4(2024), "2024")
}

///|
test "XLSX comments and source refs preserve optional provenance" {
  let anonymous : XlsxComment = { cell_ref: "A1", author: None, text: "note" }
  let blank : XlsxComment = { cell_ref: "A1", author: Some("  "), text: "note" }
  let authored : XlsxComment = {
    cell_ref: "A1",
    author: Some("Ada"),
    text: "note",
  }
  assert_eq(xlsx_comment_item_text(anonymous), "A1: note")
  assert_eq(xlsx_comment_item_text(blank), "A1: note")
  assert_eq(xlsx_comment_item_text(authored), "A1 (Ada): note")
  let info : XlsxSheetInfo = {
    sheet_name: "Data",
    sheet_id: Some("7"),
    relationship_id: "rId1",
    part_name: "xl/worksheets/sheet1.xml",
    visibility: @shared.XlsxSheetVisibility::Visible,
  }
  let source_ref = xlsx_cell_source_ref(
    info,
    "B2",
    2,
    2,
    Some("SUM(A1:A2)"),
    Some("3"),
    Some(4),
    Some("B2:C3"),
  )
  assert_true(source_ref.extra.get("cell_ref") == Some("B2"))
  assert_true(source_ref.extra.get("sheet_id") == Some("7"))
  assert_true(source_ref.extra.get("formula_ref") == Some("B2"))
  assert_true(source_ref.extra.get("style_id") == Some("3"))
  assert_true(source_ref.extra.get("shared_string_index") == Some("4"))
  assert_true(source_ref.extra.get("merge_range") == Some("B2:C3"))
  let minimal = xlsx_cell_source_ref(
    { ..info, sheet_id: None },
    "A1",
    1,
    1,
    None,
    Some(" "),
    None,
    None,
  )
  assert_true(minimal.extra.get("sheet_id") is None)
  assert_true(minimal.extra.get("style_id") is None)
}

///|
test "XLSX workbook lowering covers tables residual cells merges comments and empty sheets" {
  let cells : Map[String, XlsxCell] = Map([])
  cells.set("1,1", {
    row_index: 1,
    column_index: 1,
    display_text: "Name",
    hyperlink_target: None,
    hyperlink_relationship_id: None,
    formula_text: None,
    is_shared_formula: false,
    is_array_formula: false,
    source_ref: None,
  })
  cells.set("1,2", {
    row_index: 1,
    column_index: 2,
    display_text: "Value",
    hyperlink_target: None,
    hyperlink_relationship_id: None,
    formula_text: None,
    is_shared_formula: false,
    is_array_formula: false,
    source_ref: None,
  })
  cells.set("2,1", {
    row_index: 2,
    column_index: 1,
    display_text: "Ada",
    hyperlink_target: Some("https://example.test/ada"),
    hyperlink_relationship_id: Some("rIdLink1"),
    formula_text: None,
    is_shared_formula: false,
    is_array_formula: false,
    source_ref: None,
  })
  cells.set("2,2", {
    row_index: 2,
    column_index: 2,
    display_text: "42",
    hyperlink_target: None,
    hyperlink_relationship_id: None,
    formula_text: Some("SUM(B3:B4)"),
    is_shared_formula: true,
    is_array_formula: false,
    source_ref: None,
  })
  cells.set("4,4", {
    row_index: 4,
    column_index: 4,
    display_text: "Residual | cell\nline",
    hyperlink_target: None,
    hyperlink_relationship_id: None,
    formula_text: None,
    is_shared_formula: false,
    is_array_formula: true,
    source_ref: None,
  })
  let sheet : XlsxSheet = {
    sheet_name: "Data",
    sheet_id: Some("1"),
    relationship_id: "rId1",
    part_name: "xl/worksheets/sheet1.xml",
    visibility: @shared.XlsxSheetVisibility::Visible,
    include_hidden_rows: false,
    dimension_ref: Some("A1:D4"),
    min_row: 1,
    min_col: 1,
    max_row: 4,
    max_col: 4,
    cell_lookup: cells,
    hidden_rows: Map([(3, true)]),
    merged_lookup: Map([("1,1", "A1:B1"), ("1,2", "A1:B1")]),
    merged_ranges: ["A1:B1"],
    include_merge_layout: true,
    row_count: 4,
    cell_count: 5,
    non_empty_cell_count: 5,
    formula_count: 1,
    shared_formula_count: 1,
    array_formula_count: 1,
    drawing_count: 1,
    image_count: 1,
    external_link_count: 1,
    comments: [{ cell_ref: "D4", author: Some("Ada"), text: "Review" }],
    tables: [
      {
        table_name: Some("Table1"),
        display_name: Some("People"),
        range_ref: "A1:B2",
        part_name: "xl/tables/table1.xml",
        relationship_id: "rIdTable1",
        column_names: ["Name", "Value"],
      },
    ],
    is_empty: false,
  }
  let empty : XlsxSheet = {
    ..sheet,
    sheet_name: "Empty",
    sheet_id: Some("2"),
    relationship_id: "rId2",
    part_name: "xl/worksheets/sheet2.xml",
    cell_lookup: Map([]),
    min_row: 0,
    min_col: 0,
    max_row: 0,
    max_col: 0,
    row_count: 0,
    cell_count: 0,
    non_empty_cell_count: 0,
    comments: [],
    tables: [],
    is_empty: true,
  }
  let workbook : XlsxWorkbook = {
    workbook_part: "xl/workbook.xml",
    sheets: [sheet, empty],
    shared_strings: ["Name", "Value"],
    sheet_count: 2,
    visible_sheet_count: 2,
    hidden_sheet_count: 0,
    very_hidden_sheet_count: 0,
    row_count: 4,
    cell_count: 5,
    non_empty_cell_count: 5,
    merged_cell_count: 2,
    formula_count: 1,
    shared_formula_count: 1,
    array_formula_count: 1,
    style_count: 2,
    drawing_count: 1,
    image_count: 1,
    external_link_count: 1,
  }
  let diagnostics = @core.empty_diagnostics()
  let lowered = xlsx_lower_workbook_document(
    @input.input_from_bytes_with_format(
      Bytes::from_array([]),
      "synthetic.xlsx",
      Some(@input.DetectedFormat::Xlsx),
    ),
    workbook,
    diagnostics,
  )
  assert_true(lowered.blocks.length() >= 6)
  assert_true(lowered.blocks.any(block => block.kind == @core.BlockKind::Table))
  assert_true(lowered.blocks.any(block => block.text == "(empty sheet)"))
  assert_true(lowered.blocks.any(block => block.text.contains("Review")))
  assert_true(diagnostics.metrics.get("xlsx_formula_count") == Some("1"))
  let covered : Map[String, Bool] = Map([])
  for row in 1..<=2 {
    for col in 1..<=2 {
      covered.set(xlsx_lookup_key(row, col), true)
    }
  }
  assert_true(xlsx_collect_residual_sheet_ranges(sheet, covered).length() > 0)
  assert_eq(xlsx_range_ref_from_bounds(1, 1, 4, 4), "A1:D4")
  assert_true(xlsx_should_skip_hidden_row(false, sheet.hidden_rows, 3))
  assert_true(!xlsx_should_skip_hidden_row(true, sheet.hidden_rows, 3))
}
