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
