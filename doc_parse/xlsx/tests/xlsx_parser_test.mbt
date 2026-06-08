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
fn generated_xlsx_pkg_with_hyperlinks() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Links\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Example</t></is></c></row>" +
    "<row r=\"2\"><c r=\"B2\" t=\"inlineStr\"><is><t>Jump</t></is></c></row>" +
    "<row r=\"3\"><c r=\"C3\" t=\"inlineStr\"><is><t>Broken</t></is></c></row>" +
    "</sheetData>" +
    "<hyperlinks>" +
    "<hyperlink ref=\"A1\" r:id=\"rIdLink\" tooltip=\"Open\" display=\"Example\"/>" +
    "<hyperlink ref=\"B2\" location=\"Links!A1\" display=\"Jump\"/>" +
    "<hyperlink ref=\"C3\" r:id=\"rIdMissing\"/>" +
    "</hyperlinks>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com\" TargetMode=\"External\"/>",
  )
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_unsupported_relationships() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<workbookProtection lockStructure=\"1\"/>" +
    "<sheets><sheet name=\"Unsupported\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>" +
    "<Relationship Id=\"rIdExternal\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink\" Target=\"externalLinks/externalLink1.xml\"/>" +
    "<Relationship Id=\"rIdVba\" Type=\"http://schemas.microsoft.com/office/2006/relationships/vbaProject\" Target=\"vbaProject.bin\"/>" +
    "<Relationship Id=\"rIdOle\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject\" Target=\"embeddings/oleObject1.bin\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetProtection sheet=\"1\"/>" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>ok</t></is></c></row></sheetData>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdDrawing\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing\" Target=\"../drawings/drawing1.xml\"/>" +
    "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>" +
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/>" +
    "<Relationship Id=\"rIdPivot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotTable\" Target=\"../pivotTables/pivotTable1.xml\"/>" +
    "<Relationship Id=\"rIdThreaded\" Type=\"http://schemas.microsoft.com/office/2017/10/relationships/threadedComment\" Target=\"../threadedComments/threadedComment1.xml\"/>",
  )
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
      ("xl/externalLinks/externalLink1.xml", "<externalLink/>"),
      ("xl/vbaProject.bin", "vba"),
      ("xl/embeddings/oleObject1.bin", "ole"),
      ("xl/drawings/drawing1.xml", "<drawing/>"),
      ("xl/charts/chart1.xml", "<chartSpace/>"),
      ("xl/media/image1.png", "png"),
      ("xl/pivotTables/pivotTable1.xml", "<pivotTableDefinition/>"),
      ("xl/threadedComments/threadedComment1.xml", "<threadedComments/>"),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Default Extension=\"bin\" ContentType=\"application/octet-stream\"/>" +
    "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/externalLinks/externalLink1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.externalLink+xml\"/>" +
    "<Override PartName=\"/xl/drawings/drawing1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"/>" +
    "<Override PartName=\"/xl/charts/chart1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/>" +
    "<Override PartName=\"/xl/pivotTables/pivotTable1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.pivotTable+xml\"/>" +
    "<Override PartName=\"/xl/threadedComments/threadedComment1.xml\" ContentType=\"application/vnd.ms-excel.threadedcomments+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_tables_and_defined_names() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Data Sheet\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "<definedNames>" +
    "<definedName name=\"SalesRange\">'Data Sheet'!$A$1:$B$3</definedName>" +
    "<definedName name=\"LocalRange\" localSheetId=\"0\">'Data Sheet'!$A$2:$A$3</definedName>" +
    "<definedName name=\"_xlnm.Print_Area\" localSheetId=\"0\">'Data Sheet'!$A$1:$B$3</definedName>" +
    "<definedName name=\"ComplexFormula\" hidden=\"1\">SUM('Data Sheet'!$B$2:$B$3)</definedName>" +
    "</definedNames>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Name</t></is></c><c r=\"B1\" t=\"inlineStr\"><is><t>Amount</t></is></c></row>" +
    "<row r=\"2\"><c r=\"A2\" t=\"inlineStr\"><is><t>Ada</t></is></c><c r=\"B2\"><v>10</v></c></row>" +
    "<row r=\"3\"><c r=\"A3\" t=\"inlineStr\"><is><t>Lin</t></is></c><c r=\"B3\"><v>20</v></c></row>" +
    "</sheetData>" +
    "<tableParts count=\"1\"><tablePart r:id=\"rIdTable1\"/></tableParts>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdTable1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/table\" Target=\"../tables/table1.xml\"/>",
  )
  let table_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<table xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" id=\"1\" name=\"SalesTable\" displayName=\"SalesTable\" ref=\"A1:B3\" headerRowCount=\"1\" totalsRowCount=\"1\">" +
    "<autoFilter ref=\"A1:B3\"/>" +
    "<tableColumns count=\"2\">" +
    "<tableColumn id=\"1\" name=\"Name\" totalsRowLabel=\"Total\"/>" +
    "<tableColumn id=\"2\" name=\"Amount\" totalsRowFunction=\"sum\"/>" +
    "</tableColumns>" +
    "<tableStyleInfo name=\"TableStyleMedium2\" showFirstColumn=\"0\" showLastColumn=\"0\" showRowStripes=\"1\" showColumnStripes=\"0\"/>" +
    "</table>"
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
      ("xl/tables/table1.xml", table_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/tables/table1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_with_broken_table_relationship() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"BrokenTable\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>ok</t></is></c></row></sheetData>" +
    "<tableParts count=\"1\"><tablePart r:id=\"rIdMissingTable\"/></tableParts>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdMissingTable\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/table\" Target=\"../tables/missing.xml\"/>",
  )
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
  )
}

///|
fn repeated_shared_strings(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    if i == 0 {
      items.push("<si><t>" + repeat_text("x", 1001) + "</t></si>")
    } else {
      items.push("<si><t>shared-string-" + i.to_string() + "-payload</t></si>")
    }
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"" +
  count.to_string() +
  "\" uniqueCount=\"" +
  count.to_string() +
  "\">" +
  items.join("") +
  "</sst>"
}

///|
fn repeat_text(piece : String, count : Int) -> String {
  let parts : Array[String] = []
  for _ in 0..<count {
    parts.push(piece)
  }
  parts.join("")
}

///|
fn repeated_defined_names(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    items.push(
      "<definedName name=\"Name" +
      i.to_string() +
      "\">Sheet1!$A$1</definedName>",
    )
  }
  "<definedNames>" + items.join("") + "</definedNames>"
}

///|
fn repeated_inline_rows(count : Int) -> String {
  let rows : Array[String] = []
  for i in 0..<count {
    let row = i + 1
    rows.push(
      "<row r=\"" +
      row.to_string() +
      "\"><c r=\"A" +
      row.to_string() +
      "\" t=\"inlineStr\"><is><t>v" +
      row.to_string() +
      "</t></is></c></row>",
    )
  }
  rows.join("")
}

///|
fn repeated_internal_hyperlinks(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let row = i + 1
    items.push(
      "<hyperlink ref=\"A" + row.to_string() + "\" location=\"Sheet1!A1\"/>",
    )
  }
  "<hyperlinks>" + items.join("") + "</hyperlinks>"
}

///|
fn repeated_merge_cells(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let row = i + 1
    items.push(
      "<mergeCell ref=\"A" +
      row.to_string() +
      ":B" +
      row.to_string() +
      "\"/>",
    )
  }
  "<mergeCells count=\"" + count.to_string() + "\">" + items.join("") +
  "</mergeCells>"
}

///|
fn repeated_comment_xml(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let row = i + 1
    items.push(
      "<comment ref=\"A" +
      row.to_string() +
      "\" authorId=\"0\"><text><r><t>Comment " +
      row.to_string() +
      "</t></r></text></comment>",
    )
  }
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
  "<authors><author>Analyst</author></authors><commentList>" +
  items.join("") +
  "</commentList></comments>"
}

///|
fn repeated_workbook_sheets(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let n = i + 1
    items.push(
      "<sheet name=\"S" +
      n.to_string() +
      "\" sheetId=\"" +
      n.to_string() +
      "\" r:id=\"rId" +
      n.to_string() +
      "\"/>",
    )
  }
  "<sheets>" + items.join("") + "</sheets>"
}

///|
fn repeated_workbook_sheet_relationships(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let n = i + 1
    items.push(
      "<Relationship Id=\"rId" +
      n.to_string() +
      "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet" +
      n.to_string() +
      ".xml\"/>",
    )
  }
  items.join("")
}

///|
fn repeated_external_hyperlink_relationships(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let n = i + 1
    items.push(
      "<Relationship Id=\"rIdExtra" +
      n.to_string() +
      "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com/" +
      n.to_string() +
      "\" TargetMode=\"External\"/>",
    )
  }
  items.join("")
}

///|
fn repeated_table_relationships(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let n = i + 1
    items.push(
      "<Relationship Id=\"rIdTable" +
      n.to_string() +
      "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/table\" Target=\"../tables/table" +
      n.to_string() +
      ".xml\"/>",
    )
  }
  items.join("")
}

///|
fn repeated_table_entries(count : Int) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  for i in 0..<count {
    let n = i + 1
    let table_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<table xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" id=\"" +
      n.to_string() +
      "\" name=\"T" +
      n.to_string() +
      "\" displayName=\"T" +
      n.to_string() +
      "\" ref=\"A1:A1\"><tableColumns count=\"1\"><tableColumn id=\"1\" name=\"Value\"/></tableColumns></table>"
    entries.push(("xl/tables/table" + n.to_string() + ".xml", table_xml))
  }
  entries
}

///|
fn repeated_table_overrides(count : Int) -> String {
  let items : Array[String] = []
  for i in 0..<count {
    let n = i + 1
    items.push(
      "<Override PartName=\"/xl/tables/table" +
      n.to_string() +
      ".xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.table+xml\"/>",
    )
  }
  items.join("")
}

///|
fn generated_xlsx_pkg_over_hard_budgets() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"HardCaps\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    repeated_defined_names(520) +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    repeated_inline_rows(2010) +
    "</sheetData>" +
    repeated_internal_hyperlinks(2010) +
    "</worksheet>"
  let long_shared = repeated_shared_strings(2010)
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    [
      ("xl/worksheets/sheet1.xml", sheet_xml),
      ("xl/sharedStrings.xml", long_shared),
    ],
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
  )
}

///|
fn generated_xlsx_pkg_over_sheet_hard_budgets() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    repeated_workbook_sheets(260) +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    repeated_workbook_sheet_relationships(260),
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<dimension ref=\"A1:ALL2000\"/>" +
    "<sheetData>" +
    repeated_inline_rows(80) +
    "</sheetData>" +
    repeated_merge_cells(2010) +
    "<hyperlinks><hyperlink ref=\"A1:ALL2000\" location=\"S1!A1\"/></hyperlinks>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments1.xml\"/>" +
    repeated_table_relationships(520) +
    repeated_external_hyperlink_relationships(1050),
  )
  let extra_entries : Array[(String, String)] = [
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
    ("xl/comments1.xml", repeated_comment_xml(2010)),
  ]
  extra_entries.append(repeated_table_entries(520))
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    extra_entries,
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/comments1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml\"/>" +
    repeated_table_overrides(520),
  )
}

///|
fn generated_xlsx_pkg_over_total_cell_budget() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    repeated_workbook_sheets(11) +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    repeated_workbook_sheet_relationships(11),
  )
  let extra_entries : Array[(String, String)] = []
  for i in 0..<11 {
    let n = i + 1
    let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
      "<sheetData>" +
      repeated_inline_rows(2000) +
      "</sheetData></worksheet>"
    extra_entries.push(("xl/worksheets/sheet" + n.to_string() + ".xml", sheet_xml))
  }
  let overrides : Array[String] = []
  for i in 0..<11 {
    let n = i + 1
    overrides.push(
      "<Override PartName=\"/xl/worksheets/sheet" +
      n.to_string() +
      ".xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
    )
  }
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    extra_entries,
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    overrides.join(""),
  )
}

///|
fn generated_xlsx_pkg_with_guard_edges() -> @ox.OoxmlPackage raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    repeated_defined_names(101) +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let table_count = 101
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<dimension ref=\"A1:ALL2000\"/>" +
    "<sheetData>" +
    repeated_inline_rows(1001) +
    "</sheetData>" +
    repeated_internal_hyperlinks(1001) +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    repeated_table_relationships(table_count),
  )
  let extra_entries : Array[(String, String)] = [
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
    ("xl/sharedStrings.xml", repeated_shared_strings(1001)),
  ]
  extra_entries.append(repeated_table_entries(table_count))
  workbook_pkg_from_parts(
    workbook_xml,
    workbook_rels_xml,
    extra_entries,
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
    "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
    "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>" +
    repeated_table_overrides(table_count),
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
test "xlsx semantic parser owns workbook document properties" {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Meta\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"str\"><v>ok</v></c></row></sheetData>" +
    "</worksheet>"
  let core_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\">" +
    "<dc:title>Quarterly Workbook</dc:title>" +
    "<dc:subject>Forecast</dc:subject>" +
    "<dc:creator>Ada</dc:creator>" +
    "<cp:lastModifiedBy>Grace</cp:lastModifiedBy>" +
    "<dcterms:created>2026-01-02T03:04:05Z</dcterms:created>" +
    "<dcterms:modified>2026-02-03T04:05:06Z</dcterms:modified>" +
    "<cp:keywords>finance;ops</cp:keywords>" +
    "<dc:description>Board packet</dc:description>" +
    "<cp:category>Planning</cp:category>" +
    "</cp:coreProperties>"
  let app_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\">" +
    "<Application>MoonSheet</Application>" +
    "<Company>Example Co</Company>" +
    "<Manager>Lin</Manager>" +
    "<Worksheets>1</Worksheets>" +
    "</Properties>"
  let custom_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/custom-properties\" xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">" +
    "<property fmtid=\"{D5CDD505-2E9C-101B-9397-08002B2CF9AE}\" pid=\"2\" name=\"Audience\"><vt:lpwstr>Finance</vt:lpwstr></property>" +
    "</Properties>"
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    workbook_pkg_from_parts(
      workbook_xml,
      workbook_rels_xml,
      [
        ("xl/worksheets/sheet1.xml", sheet_xml),
        ("docProps/core.xml", core_xml),
        ("docProps/app.xml", app_xml),
        ("docProps/custom.xml", custom_xml),
      ],
      "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
      "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
      "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>" +
      "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>" +
      "<Override PartName=\"/docProps/custom.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.custom-properties+xml\"/>",
    ),
  )

  if workbook.metadata.core.title != Some("Quarterly Workbook") {
    fail("expected core title")
  }
  if workbook.metadata.core.subject != Some("Forecast") {
    fail("expected core subject")
  }
  if workbook.metadata.core.creator != Some("Ada") {
    fail("expected core creator")
  }
  if workbook.metadata.core.last_modified_by != Some("Grace") {
    fail("expected core lastModifiedBy")
  }
  if workbook.metadata.core.created != Some("2026-01-02T03:04:05Z") {
    fail("expected core created")
  }
  if workbook.metadata.core.modified != Some("2026-02-03T04:05:06Z") {
    fail("expected core modified")
  }
  if workbook.metadata.core.keywords != Some("finance;ops") {
    fail("expected core keywords")
  }
  if workbook.metadata.core.description != Some("Board packet") {
    fail("expected core description")
  }
  if workbook.metadata.core.category != Some("Planning") {
    fail("expected core category")
  }
  if workbook.metadata.app.application != Some("MoonSheet") {
    fail("expected app application")
  }
  if workbook.metadata.app.company != Some("Example Co") {
    fail("expected app company")
  }
  if workbook.metadata.app.manager != Some("Lin") {
    fail("expected app manager")
  }
  if workbook.metadata.app.sheets != Some("1") {
    fail("expected app worksheet count")
  }
  assert_eq(workbook.metadata.custom_properties.length(), 1)
  assert_eq(workbook.metadata.custom_properties[0].name, "Audience")
  assert_eq(workbook.metadata.custom_properties[0].value, "Finance")
  if workbook.metadata.custom_properties[0].value_type != Some("lpwstr") {
    fail("expected lpwstr custom property type")
  }
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
test "xlsx semantic workbook preserves worksheet hyperlink facts" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_hyperlinks(),
  )
  assert_eq(workbook.sheets.length(), 1)
  let sheet = workbook.sheets[0]
  assert_eq(sheet.hyperlinks.length(), 3)

  let external = sheet.hyperlinks[0]
  assert_eq(external.reference, "A1")
  if external.kind != @xlsx.XlsxHyperlinkKind::External {
    fail("A1 hyperlink should be external")
  }
  if external.target != Some("https://example.com") {
    fail("A1 hyperlink should preserve external target")
  }
  if external.relationship_id != Some("rIdLink") {
    fail("A1 hyperlink should preserve relationship id")
  }
  if external.tooltip != Some("Open") {
    fail("A1 hyperlink should preserve tooltip")
  }

  let internal = sheet.hyperlinks[1]
  assert_eq(internal.reference, "B2")
  if internal.kind != @xlsx.XlsxHyperlinkKind::Internal {
    fail("B2 hyperlink should be internal")
  }
  if internal.location != Some("Links!A1") {
    fail("B2 hyperlink should preserve internal location")
  }

  let mut saw_a1_cell_link = false
  let mut saw_b2_cell_link = false
  for cell in sheet.cells {
    if cell.reference == "A1" {
      match cell.hyperlink {
        Some(link) =>
          if link.target == Some("https://example.com") {
            saw_a1_cell_link = true
          }
        None => ()
      }
    } else if cell.reference == "B2" {
      match cell.hyperlink {
        Some(link) =>
          if link.location == Some("Links!A1") {
            saw_b2_cell_link = true
          }
        None => ()
      }
    }
  }
  assert_true(saw_a1_cell_link)
  assert_true(saw_b2_cell_link)

  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_missing_rel = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::MissingRelationshipTarget {
      saw_missing_rel = true
    }
  }
  assert_true(saw_missing_rel)
}

///|
test "xlsx semantic warning taxonomy records unsupported workbook and sheet structures" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_unsupported_relationships(),
  )
  let mut saw_workbook_external_fact = false
  let mut saw_workbook_vba_fact = false
  let mut saw_workbook_ole_fact = false
  let mut saw_workbook_protection_fact = false
  for feature in workbook.unsupported_features {
    if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::ExternalLink &&
      feature.relationship_id == Some("rIdExternal") {
      saw_workbook_external_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::VbaMacro &&
      feature.relationship_id == Some("rIdVba") {
      saw_workbook_vba_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::OleObject &&
      feature.relationship_id == Some("rIdOle") {
      saw_workbook_ole_fact = true
    } else if feature.kind ==
      @xlsx.XlsxUnsupportedFeatureKind::WorkbookProtection {
      saw_workbook_protection_fact = true
    }
  }
  assert_true(saw_workbook_external_fact)
  assert_true(saw_workbook_vba_fact)
  assert_true(saw_workbook_ole_fact)
  assert_true(saw_workbook_protection_fact)

  let sheet = workbook.sheets[0]
  let mut saw_sheet_protection_fact = false
  let mut saw_drawing_fact = false
  let mut saw_chart_fact = false
  let mut saw_image_fact = false
  let mut saw_pivot_fact = false
  let mut saw_threaded_fact = false
  for feature in sheet.unsupported_features {
    if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::SheetProtection {
      saw_sheet_protection_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::Drawing {
      saw_drawing_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::Chart {
      saw_chart_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::Image {
      saw_image_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::PivotTable {
      saw_pivot_fact = true
    } else if feature.kind == @xlsx.XlsxUnsupportedFeatureKind::ThreadedComment {
      saw_threaded_fact = true
    }
  }
  assert_true(saw_sheet_protection_fact)
  assert_true(saw_drawing_fact)
  assert_true(saw_chart_fact)
  assert_true(saw_image_fact)
  assert_true(saw_pivot_fact)
  assert_true(saw_threaded_fact)

  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_external_link = false
  let mut saw_workbook_protection = false
  let mut saw_sheet_protection = false
  let mut saw_drawing = false
  let mut saw_chart = false
  let mut saw_vba = false
  let mut saw_ole = false
  let mut saw_pivot = false
  let mut saw_threaded = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedExternalLink {
      saw_external_link = true
    } else if issue.kind ==
      @xlsx.XlsxValidationIssueKind::UnsupportedWorkbookProtection {
      saw_workbook_protection = true
    } else if issue.kind ==
      @xlsx.XlsxValidationIssueKind::UnsupportedSheetProtection {
      saw_sheet_protection = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedDrawing {
      saw_drawing = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedChart {
      saw_chart = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedVbaMacro {
      saw_vba = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedOleObject {
      saw_ole = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedPivotTable {
      saw_pivot = true
    } else if issue.kind ==
      @xlsx.XlsxValidationIssueKind::UnsupportedThreadedComment {
      saw_threaded = true
    }
  }
  assert_true(saw_external_link)
  assert_true(saw_workbook_protection)
  assert_true(saw_sheet_protection)
  assert_true(saw_drawing)
  assert_true(saw_chart)
  assert_true(saw_vba)
  assert_true(saw_ole)
  assert_true(saw_pivot)
  assert_true(saw_threaded)
}

///|
test "xlsx semantic workbook preserves structured table facts" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_tables_and_defined_names(),
  )
  assert_eq(workbook.sheets.length(), 1)
  let sheet = workbook.sheets[0]
  assert_eq(sheet.tables.length(), 1)
  let table = sheet.tables[0]
  if table.table_id != Some("1") {
    fail("table should preserve id")
  }
  if table.name != Some("SalesTable") {
    fail("table should preserve name")
  }
  if table.display_name != Some("SalesTable") {
    fail("table should preserve displayName")
  }
  assert_eq(table.range_ref, "A1:B3")
  assert_eq(table.start_row, 1)
  assert_eq(table.start_col, 1)
  assert_eq(table.end_row, 3)
  assert_eq(table.end_col, 2)
  assert_eq(table.header_row_count, 1)
  assert_eq(table.totals_row_count, 1)
  assert_true(table.header_row_visible)
  assert_true(table.totals_row_visible)
  if table.style_name != Some("TableStyleMedium2") {
    fail("table should preserve style name")
  }
  if table.auto_filter_ref != Some("A1:B3") {
    fail("table should preserve auto filter ref")
  }
  assert_true(table.column_names == ["Name", "Amount"])
  assert_eq(table.columns.length(), 2)
  if table.columns[0].column_id != Some("1") ||
    table.columns[0].name != Some("Name") ||
    table.columns[0].totals_row_label != Some("Total") {
    fail("first table column should preserve id/name/totals label")
  }
  if table.columns[1].column_id != Some("2") ||
    table.columns[1].name != Some("Amount") ||
    table.columns[1].totals_row_function != Some("sum") {
    fail("second table column should preserve id/name/totals function")
  }
  if table.source_part != Some("xl/tables/table1.xml") {
    fail("table should preserve source part")
  }
  if table.relationship_id != Some("rIdTable1") {
    fail("table should preserve relationship id")
  }
}

///|
test "xlsx semantic workbook preserves defined names and named ranges" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_tables_and_defined_names(),
  )
  assert_eq(workbook.defined_names.length(), 4)

  let named = workbook.defined_names[0]
  assert_eq(named.name, "SalesRange")
  if named.kind != @xlsx.XlsxDefinedNameKind::NamedRange {
    fail("SalesRange should classify as named range")
  }
  if named.target_sheet != Some("Data Sheet") {
    fail("SalesRange should preserve target sheet")
  }
  if named.target_range != Some("A1:B3") {
    fail("SalesRange should preserve target range")
  }

  let local_name = workbook.defined_names[1]
  if local_name.sheet_scope != Some("Data Sheet") {
    fail("LocalRange should preserve sheet scope")
  }
  if local_name.sheet_scope_index != Some(0) {
    fail("LocalRange should preserve sheet scope index")
  }

  let print_area = workbook.defined_names[2]
  if print_area.kind != @xlsx.XlsxDefinedNameKind::PrintArea {
    fail("reserved print area should classify as PrintArea")
  }

  let formula_like = workbook.defined_names[3]
  if formula_like.kind != @xlsx.XlsxDefinedNameKind::FormulaLike {
    fail("complex formula should classify as FormulaLike")
  }
  assert_true(formula_like.hidden)
  assert_eq(formula_like.text, "SUM('Data Sheet'!$B$2:$B$3)")
}

///|
test "xlsx semantic tables report broken relationship warnings" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_broken_table_relationship(),
  )
  assert_eq(workbook.sheets[0].tables.length(), 0)
  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_missing_table = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::MissingRelationshipTarget &&
      issue.part_target == Some("xl/tables/missing.xml") {
      saw_missing_table = true
    }
  }
  assert_true(saw_missing_table)
}

///|
test "xlsx semantic guard warnings stay bounded and explicit" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_with_guard_edges(),
  )
  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_shared_strings = false
  let mut saw_defined_names = false
  let mut saw_hyperlinks = false
  let mut saw_tables = false
  let mut saw_cells = false
  let mut saw_non_empty_cells = false
  let mut saw_shared_string_bytes = false
  let mut saw_long_shared_string = false
  let mut saw_dimension = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSharedStrings {
      saw_shared_strings = true
      if issue.message.contains("text bytes") {
        saw_shared_string_bytes = true
      } else if issue.message.contains("long shared string") {
        saw_long_shared_string = true
      }
    } else if issue.message.contains("defined name count") {
      saw_defined_names = true
    } else if issue.message.contains("many hyperlinks") {
      saw_hyperlinks = true
    } else if issue.message.contains("structured tables") {
      saw_tables = true
    } else if issue.message.contains("many parsed cells") {
      saw_cells = true
    } else if issue.message.contains("many non-empty cells") {
      saw_non_empty_cells = true
    } else if issue.message.contains("large sheet dimension area") {
      saw_dimension = true
    }
  }
  assert_true(saw_shared_strings)
  assert_true(saw_shared_string_bytes)
  assert_true(saw_long_shared_string)
  assert_true(saw_defined_names)
  assert_true(saw_hyperlinks)
  assert_true(saw_tables)
  assert_true(saw_cells)
  assert_true(saw_non_empty_cells)
  assert_true(saw_dimension)

  let quiet_workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_workbook_date1904_pkg(),
  )
  for issue in @xlsx.collect_xlsx_validation_issues(quiet_workbook) {
    if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSharedStrings ||
      issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated {
      fail("ordinary generated workbook should not emit guard warnings")
    }
  }
}

///|
test "xlsx semantic parser hard budgets truncate facts with typed warnings" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_over_hard_budgets(),
  )
  assert_true(workbook.shared_strings.length() <= 2000)
  assert_true(workbook.defined_names.length() <= 512)
  assert_eq(workbook.sheets.length(), 1)
  assert_true(workbook.sheets[0].cells.length() <= 2000)
  assert_true(workbook.sheets[0].hyperlinks.length() <= 2000)

  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_shared_count_cap = false
  let mut saw_defined_name_cap = false
  let mut saw_cell_cap = false
  let mut saw_hyperlink_cap = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSharedStrings &&
      issue.message.contains("sharedStrings count truncated") {
      saw_shared_count_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("defined names truncated") {
      saw_defined_name_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("cells truncated") {
      saw_cell_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("hyperlinks truncated") {
      saw_hyperlink_cap = true
    }
  }
  assert_true(saw_shared_count_cap)
  assert_true(saw_defined_name_cap)
  assert_true(saw_cell_cap)
  assert_true(saw_hyperlink_cap)
}

///|
test "xlsx semantic parser sheet hard budgets cover sheets rels comments tables and ranges" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_over_sheet_hard_budgets(),
  )
  assert_true(workbook.sheets.length() <= 256)
  assert_true(workbook.sheets[0].merged_ranges.length() <= 2000)
  assert_true(workbook.sheets[0].comments.length() <= 2000)
  assert_true(workbook.sheets[0].tables.length() <= 512)
  assert_eq(workbook.sheets[0].hyperlinks.length(), 1)

  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_sheet_cap = false
  let mut saw_relationship_cap = false
  let mut saw_merged_cap = false
  let mut saw_comment_cap = false
  let mut saw_table_cap = false
  let mut saw_hyperlink_range_cap = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("sheets truncated") {
      saw_sheet_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("relationships truncated") {
      saw_relationship_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("merged ranges truncated") {
      saw_merged_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("comments truncated") {
      saw_comment_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("tables truncated") {
      saw_table_cap = true
    } else if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("hyperlink range expansion skipped") {
      saw_hyperlink_range_cap = true
    }
  }
  assert_true(saw_sheet_cap)
  assert_true(saw_relationship_cap)
  assert_true(saw_merged_cap)
  assert_true(saw_comment_cap)
  assert_true(saw_table_cap)
  assert_true(saw_hyperlink_range_cap)
}

///|
test "xlsx semantic parser workbook total cell cap is bounded across sheets" {
  let workbook = @xlsx.parse_xlsx_workbook_from_package(
    generated_xlsx_pkg_over_total_cell_budget(),
  )
  assert_eq(workbook.sheets.length(), 11)
  let mut total_cells = 0
  for sheet in workbook.sheets {
    total_cells += sheet.cells.length()
  }
  assert_true(total_cells <= 20000)

  let issues = @xlsx.collect_xlsx_validation_issues(workbook)
  let mut saw_total_cell_cap = false
  for issue in issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::LargeSheetTruncated &&
      issue.message.contains("workbook hard cap") {
      saw_total_cell_cap = true
    }
  }
  assert_true(saw_total_cell_cap)
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
