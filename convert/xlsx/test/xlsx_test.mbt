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
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => fail("utf8 decode failed")
  }
}

///|
fn restore_env_var(name : String, previous : String?) -> Unit {
  match previous {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn test_tmp_root() -> String {
  ".tmp/convert-xlsx-test"
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, bytes) catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
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
fn find_substring(haystack : String, needle : String, start : Int) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    if haystack[i:i + m] == needle {
      return Some(i)
    }
    i += 1
  }
  None
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
fn write_utf8_shared_string_xlsx(path : String) -> Unit raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"UTF8\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row>" +
    "<row r=\"2\"><c r=\"A2\" t=\"s\"><v>1</v></c></row>" +
    "</sheetData>" +
    "</worksheet>"
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"2\" uniqueCount=\"2\">" +
    "<si><t>Name</t></si>" +
    "<si><t>Cäsar</t></si>" +
    "</sst>"

  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
        "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/sharedStrings.xml", shared_strings_xml),
  ])
  write_bytes(path, bytes)
}

///|
fn write_hidden_row_xlsx(path : String) -> Unit raise {
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

  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
        "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/sharedStrings.xml", shared_strings_xml),
  ])
  write_bytes(path, bytes)
}

///|
fn write_xlsx_with_comments(path : String) -> Unit raise {
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
    "<row r=\"2\"><c r=\"A2\" t=\"s\"><v>2</v></c><c r=\"B2\"><v>42</v></c></row>" +
    "</sheetData>" +
    "</worksheet>"
  let sheet_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments1.xml\"/>",
  )
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"3\" uniqueCount=\"3\">" +
    "<si><t>Name</t></si>" +
    "<si><t>Value</t></si>" +
    "<si><t>alpha</t></si>" +
    "</sst>"
  let comments_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<comments xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<authors><author>Analyst</author></authors>" +
    "<commentList>" +
    "<comment ref=\"B1\" authorId=\"0\"><text><r><t>Analyst:</t></r><r><t xml:space=\"preserve\"> First insight</t></r></text></comment>" +
    "<comment ref=\"A2\" authorId=\"0\"><text><r><t>Second insight</t></r></text></comment>" +
    "</commentList>" +
    "</comments>"

  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
        "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>" +
        "<Override PartName=\"/xl/comments1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.comments+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/worksheets/_rels/sheet1.xml.rels", sheet_rels_xml),
    ("xl/sharedStrings.xml", shared_strings_xml),
    ("xl/comments1.xml", comments_xml),
  ])
  write_bytes(path, bytes)
}

///|
fn write_huge_sparse_xlsx(path : String) -> Unit raise {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"HugeSparse\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<dimension ref=\"A1:ALL2000\"/>" +
    "<sheetData>" +
    "<row r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>Header</t></is></c></row>" +
    "<row r=\"2000\"><c r=\"ALL2000\" t=\"inlineStr\"><is><t>Far Edge</t></is></c></row>" +
    "</sheetData>" +
    "</worksheet>"

  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
    ("xl/worksheets/sheet1.xml", sheet_xml),
  ])
  write_bytes(path, bytes)
}

///|
fn write_self_closing_blank_cells_xlsx(path : String) -> Unit raise {
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

  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
        "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
        "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>" +
        "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdWorkbook\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>",
      ),
    ),
    ("xl/workbook.xml", workbook_xml),
    ("xl/_rels/workbook.xml.rels", workbook_rels_xml),
    ("xl/worksheets/sheet1.xml", sheet_xml),
    ("xl/sharedStrings.xml", shared_strings_xml),
    ("xl/styles.xml", styles_xml),
  ])
  write_bytes(path, bytes)
}

///|
test "xlsx main process samples stay stable" {
  let simple_doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    "",
    6,
  )
  let simple_markdown = @cor.emit_markdown(simple_doc)
  assert_true(simple_markdown.contains("## Sheet1"))
  assert_true(simple_markdown.contains("| Bob | 2.5 | emoji🙂 |"))
  assert_true(simple_markdown.contains("## Data"))

  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_value_current_policy.xlsx",
    ),
    "",
    6,
  )
  let formula_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_cached_value_current_policy.md",
    ),
  )
  assert_eq(@cor.emit_markdown(formula_doc), formula_expected)

  let hidden_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheet_current_behavior.xlsx",
    ),
    "",
    6,
  )
  let hidden_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_hidden_sheet_current_behavior.md",
    ),
  )
  assert_eq(@cor.emit_markdown(hidden_doc), hidden_expected)
  assert_true(!@cor.emit_markdown(hidden_doc).contains("## HiddenData"))
}

///|
test "xlsx converter preserves utf8 shared strings from OOXML parts" {
  let root = test_tmp_root()
  let case_dir = root + "/xlsx-utf8-shared-strings"
  recreate_clean_dir(case_dir) catch {
    e => fail("recreate_clean_dir failed: " + e.to_string())
  }
  let path = case_dir + "/utf8_shared_strings.xlsx"
  write_utf8_shared_string_xlsx(path) catch {
    e => fail("write_utf8_shared_string_xlsx failed: " + e.to_string())
  }

  let doc = @xlsx.parse_xlsx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Cäsar"))
  assert_true(!markdown.contains("CÃ¤sar"))

  cleanup_temp_dir(case_dir)
}

///|
test "xlsx converter skips hidden rows in normal markdown while inspect keeps them" {
  let root = test_tmp_root()
  let case_dir = root + "/xlsx-hidden-rows"
  recreate_clean_dir(case_dir) catch {
    e => fail("recreate_clean_dir failed: " + e.to_string())
  }
  let path = case_dir + "/hidden_rows.xlsx"
  write_hidden_row_xlsx(path) catch {
    e => fail("write_hidden_row_xlsx failed: " + e.to_string())
  }

  let doc = @xlsx.parse_xlsx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Visible Header"))
  assert_true(markdown.contains("Visible Public"))
  assert_true(!markdown.contains("Hidden Secret"))

  let inspected = @xlsx.inspect_xlsx(path)
  assert_true(inspected.sheets[0].hidden_rows == [2])
  let mut saw_hidden_cell = false
  for cell in inspected.sheets[0].cells {
    if cell.reference == "A2" && cell.display_text == "Hidden Secret" {
      saw_hidden_cell = true
    }
  }
  assert_true(saw_hidden_cell)

  cleanup_temp_dir(case_dir)
}

///|
test "xlsx comment parts emit conservative appendix blocks after table content" {
  let case_dir = test_tmp_root() + "/comments"
  recreate_clean_dir(case_dir) catch {
    e => fail("recreate comments case dir failed: " + e.to_string())
  }
  let path = case_dir + "/comments.xlsx"
  write_xlsx_with_comments(path) catch {
    e => fail("write_xlsx_with_comments failed: " + e.to_string())
  }

  let doc = @xlsx.parse_xlsx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Comments"))
  assert_true(markdown.contains("- B1 (Analyst): First insight"))
  assert_true(markdown.contains("- A2 (Analyst): Second insight"))
  let table_pos = find_substring(markdown, "| Name | Value |", 0).unwrap_or_else(() => {
      fail("expected worksheet table in markdown")
    },
  )
  let comments_pos = find_substring(markdown, "### Comments", 0).unwrap_or_else(() => {
      fail("expected comments appendix heading in markdown")
    },
  )
  assert_true(comments_pos > table_pos)

  cleanup_temp_dir(case_dir)
}

///|
test "xlsx profile disabled returns no report for normal parse" {
  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_XLSX")
  defer restore_env_var("MARKITDOWN_PROFILE_XLSX", prev_enabled)
  @sys.unset_env_var("MARKITDOWN_PROFILE_XLSX")

  let (doc, profile) = @xlsx.parse_xlsx_with_profile(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    "",
    6,
  )
  assert_true(@cor.emit_markdown(doc).contains("| Bob | 2.5 | emoji🙂 |"))
  match profile {
    None => ()
    Some(_) => fail("disabled xlsx profile should not create a report")
  }
}

///|
test "xlsx huge sparse sheet uses bounded fallback instead of dense RichTable" {
  let case_dir = test_tmp_root() + "/huge-sparse"
  recreate_clean_dir(case_dir) catch {
    e => fail("recreate huge sparse case dir failed: " + e.to_string())
  }
  let path = case_dir + "/huge_sparse.xlsx"
  write_huge_sparse_xlsx(path) catch {
    e => fail("write_huge_sparse_xlsx failed: " + e.to_string())
  }

  let inspected = @xlsx.inspect_xlsx(path)
  assert_eq(inspected.sheets[0].table_rows.length(), 0)
  assert_eq(inspected.sheets[0].used_min_row, 1)
  assert_eq(inspected.sheets[0].used_min_col, 1)
  assert_eq(inspected.sheets[0].used_max_row, 2000)
  assert_eq(inspected.sheets[0].used_max_col, 1000)

  let doc = @xlsx.parse_xlsx(path, "", 6)
  match doc.blocks.val[1] {
    @cor.Block::Paragraph(text) => {
      assert_true(text.contains("large sparse sheet"))
      assert_true(text.contains("2000000 cells exceeds cap 1000000"))
      assert_true(text.contains("showing 2 of 2 visible non-empty cells"))
    }
    _ => fail("huge sparse sheet should emit bounded paragraph fallback")
  }
  let mut rich_table_count = 0
  for block in doc.blocks.val {
    match block {
      @cor.Block::RichTable(_) => rich_table_count = rich_table_count + 1
      _ => ()
    }
  }
  assert_eq(rich_table_count, 0)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("- A1 (row=1 col=1): Header"))
  assert_true(markdown.contains("- ALL2000 (row=2000 col=1000): Far Edge"))

  cleanup_temp_dir(case_dir)
}

///|
test "xlsx sheets now emit RichTable with explicit header semantics" {
  let doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    "",
    6,
  )

  match doc.blocks.val[1] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Name", "Value", "备注"])
    }
    _ => fail("sheet_simple should emit RichTable")
  }
}

///|
test "xlsx inspect surface keeps hidden sheets, merged ranges, and formula text" {
  let hidden_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheet_current_behavior.xlsx",
    ),
  )
  assert_eq(hidden_book.sheets.length(), 2)
  match hidden_book.sheets[0].state {
    @xlsx.XlsxSheetState::Visible => ()
    _ => fail("first sheet should be visible")
  }
  match hidden_book.sheets[1].state {
    @xlsx.XlsxSheetState::Hidden => ()
    _ => fail("second sheet should be hidden")
  }

  let merged_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_current_policy.xlsx",
    ),
  )
  if merged_book.sheets[0].merged_ranges.length() == 0 {
    fail("merged sheet should expose merged_ranges")
  }

  let formula_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_value_current_policy.xlsx",
    ),
  )
  let mut saw_formula = false
  for cell in formula_book.sheets[0].cells {
    match cell.formula_text {
      Some(text) => if text.trim() != "" { saw_formula = true }
      None => ()
    }
  }
  assert_true(saw_formula)
}

///|
test "xlsx inspect surface keeps sparse used range and cell kinds" {
  let sparse_book = @xlsx.inspect_xlsx(
    resolve_sample_path("samples/main_process/xlsx/xlsx_sparse_edges.xlsx"),
  )
  let sparse_sheet = sparse_book.sheets[0]
  assert_true(sparse_sheet.used_min_row > 0)
  assert_true(sparse_sheet.used_min_col > 0)
  assert_true(sparse_sheet.used_max_row >= sparse_sheet.used_min_row)
  assert_true(sparse_sheet.used_max_col >= sparse_sheet.used_min_col)

  let cell_types = @xlsx.inspect_xlsx(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let mut saw_shared = false
  let mut saw_error = false
  let mut saw_bool = false
  let mut saw_number = false
  for cell in cell_types.sheets[0].cells {
    match cell.kind {
      @xlsx.XlsxCellKind::SharedString =>
        if cell.display_text == "inline ok" {
          saw_shared = true
        }
      @xlsx.XlsxCellKind::Error => saw_error = true
      @xlsx.XlsxCellKind::Boolean => saw_bool = true
      @xlsx.XlsxCellKind::Number =>
        if cell.display_text == "42" {
          saw_number = true
        }
      _ => ()
    }
  }
  assert_true(saw_shared)
  assert_true(saw_error)
  assert_true(saw_bool)
  assert_true(saw_number)
}

///|
test "xlsx conversion keeps self-closing blank styled cells empty" {
  let case_dir = test_tmp_root() + "/self-closing-blank-cells"
  recreate_clean_dir(case_dir) catch {
    e => fail("recreate self-closing case dir failed: " + e.to_string())
  }
  let path = case_dir + "/self_closing_blank_cells.xlsx"
  write_self_closing_blank_cells_xlsx(path) catch {
    e => fail("write_self_closing_blank_cells_xlsx failed: " + e.to_string())
  }

  let doc = @xlsx.parse_xlsx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## SharedLinks"))
  assert_true(markdown.contains("http://www.apache.org"))
  assert_true(!markdown.contains("| http://www.apache.org | 0 |"))
  assert_true(!markdown.contains("|  | 0 |"))

  let inspected = @xlsx.inspect_xlsx(path)
  assert_eq(inspected.sheets.length(), 1)
  let mut saw_blank_b1 = false
  let mut saw_blank_b3 = false
  for cell in inspected.sheets[0].cells {
    if cell.reference == "B1" && cell.display_text == "" {
      saw_blank_b1 = true
    }
    if cell.reference == "B3" && cell.display_text == "" {
      saw_blank_b3 = true
    }
  }
  assert_true(saw_blank_b1)
  assert_true(saw_blank_b3)

  cleanup_temp_dir(case_dir)
}

///|
test "xlsx second-round policy samples stay stable" {
  let formula_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_cached_values.md",
    ),
  )
  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(formula_doc), formula_expected)

  let missing_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_missing_cache.md",
    ),
  )
  let missing_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_missing_cache.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(missing_doc), missing_expected)

  let merged_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_merged_cells_policy.md",
    ),
  )
  let merged_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(merged_doc), merged_expected)

  let hidden_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_hidden_sheets_policy.md",
    ),
  )
  let hidden_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
    "",
    6,
  )
  let hidden_markdown = @cor.emit_markdown(hidden_doc)
  assert_eq(hidden_markdown, hidden_expected)
  assert_true(!hidden_markdown.contains("## HiddenData"))
  assert_true(!hidden_markdown.contains("## VeryHiddenAudit"))

  let typed_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_typed_cells_matrix.md",
    ),
  )
  let typed_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(typed_doc), typed_expected)

  let arithmetic_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_eval_arithmetic.md",
    ),
  )
  let arithmetic_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_arithmetic.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(arithmetic_doc), arithmetic_expected)

  let ranges_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_eval_ranges.md",
    ),
  )
  let ranges_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(ranges_doc), ranges_expected)

  let if_round_text_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_eval_if_round_text.md",
    ),
  )
  let if_round_text_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(if_round_text_doc), if_round_text_expected)

  let unsupported_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_eval_unsupported.md",
    ),
  )
  let unsupported_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(unsupported_doc), unsupported_expected)

  let errors_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xlsx/expected/xlsx_formula_eval_errors.md",
    ),
  )
  let errors_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_errors.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(errors_doc), errors_expected)
}

///|
test "xlsx RichTable hints expose formula, merged, semantic-type, and sheet-state policy" {
  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
    "",
    6,
  )
  match formula_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) => {
          if hints.format != Some("xlsx") {
            fail("expected xlsx format hint on formula policy sheet")
          }
          if hints.sheet_state != Some("visible") {
            fail("expected visible sheet_state on formula policy sheet")
          }
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              assert_eq(cells[0].semantic_type, "formula_cached_value")
              if cells[0].policy != Some("cached") {
                fail("expected cached policy on cached formula cell")
              }
              assert_eq(cells[4].semantic_type, "number")
              if cells[4].policy != Some("evaluated_missing_cache") {
                fail("expected evaluated_missing_cache policy")
              }
              if cells[4].evaluated_value != Some("5") {
                fail("expected evaluated missing-cache formula value 5")
              }
            }
            None => fail("formula policy sheet should expose formula_cells")
          }
          match hints.semantic_types {
            Some(rows) => {
              assert_eq(rows[1][1], "formula_cached_value")
              assert_eq(rows[5][1], "number")
              assert_eq(rows[6][1], "string")
            }
            None => fail("formula policy sheet should expose semantic_types")
          }
        }
        None => fail("xlsx RichTable should expose hints")
      }
    _ => fail("xlsx formula policy should emit RichTable")
  }

  let merged_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
    "",
    6,
  )
  match merged_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.merged_ranges {
            Some(ranges) => assert_true(ranges == ["B2:C2", "B3:C4", "B5:C5"])
            None => fail("merged policy should expose merged_ranges")
          }
        None => fail("merged policy should expose hints")
      }
    _ => fail("merged policy should emit RichTable")
  }

  let hidden_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  assert_eq(hidden_book.sheets.length(), 3)
  match hidden_book.sheets[2].state {
    @xlsx.XlsxSheetState::VeryHidden => ()
    _ => fail("third sheet should be veryHidden")
  }

  let typed_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx",
    ),
  )
  let mut saw_string = false
  let mut saw_boolean = false
  let mut saw_error = false
  let mut saw_number = false
  for cell in typed_book.sheets[0].cells {
    match cell.semantic_type {
      @xlsx.XlsxCellSemanticType::String => saw_string = true
      @xlsx.XlsxCellSemanticType::Boolean => saw_boolean = true
      @xlsx.XlsxCellSemanticType::Error => saw_error = true
      @xlsx.XlsxCellSemanticType::Number => saw_number = true
      _ => ()
    }
  }
  assert_true(saw_string)
  assert_true(saw_boolean)
  assert_true(saw_error)
  assert_true(saw_number)
}

///|
test "xlsx metadata hints expose evaluated, unsupported, and error formula policy" {
  let eval_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
    "",
    6,
  )
  match eval_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              assert_eq(cells[0].reference, "D2")
              if cells[0].policy != Some("evaluated_missing_cache") {
                fail("expected evaluated_missing_cache policy on IF sample")
              }
              if cells[0].evaluated_value != Some("high") {
                fail("expected IF sample evaluated value high")
              }
              match cells[0].referenced_cells {
                Some(refs) => assert_true(refs == ["A2"])
                None => fail("expected IF sample referenced_cells")
              }
            }
            None => fail("expected formula hints on IF/ROUND/TEXT sample")
          }
        None => fail("expected table hints on IF/ROUND/TEXT sample")
      }
    _ => fail("expected RichTable for IF/ROUND/TEXT sample")
  }

  let unsupported_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
    "",
    6,
  )
  match unsupported_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 4)
              if cells[0].policy != Some("unsupported_formula") {
                fail("expected unsupported_formula policy for VLOOKUP")
              }
              match cells[0].unsupported_reason {
                Some(reason) =>
                  assert_true(reason.contains("unsupported function"))
                None => fail("expected unsupported reason for VLOOKUP")
              }
              if cells[1].policy != Some("unsupported_formula") {
                fail(
                  "expected unsupported_formula policy for cross-sheet formula",
                )
              }
              if cells[3].policy != Some("unsupported_formula") {
                fail(
                  "expected unsupported_formula policy for range scalar coercion",
                )
              }
              match cells[3].unsupported_reason {
                Some(reason) =>
                  assert_true(
                    reason.contains("range scalar coercion unsupported"),
                  )
                None =>
                  fail("expected unsupported reason for range scalar coercion")
              }
            }
            None => fail("expected formula hints on unsupported sample")
          }
        None => fail("expected table hints on unsupported sample")
      }
    _ => fail("expected RichTable for unsupported sample")
  }

  let error_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_errors.xlsx",
    ),
    "",
    6,
  )
  match error_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              if cells[0].policy != Some("formula_error") {
                fail("expected formula_error policy on division by zero cell")
              }
              if cells[0].error_reason != Some("division by zero") {
                fail("expected division by zero error reason")
              }
              if cells[2].policy != Some("formula_error") {
                fail("expected formula_error policy in error sample")
              }
              if cells[2].error_reason != Some("#N/A") {
                fail("expected #N/A error reason in formula error sample")
              }
            }
            None => fail("expected formula hints on error sample")
          }
        None => fail("expected table hints on error sample")
      }
    _ => fail("expected RichTable for error sample")
  }
}
