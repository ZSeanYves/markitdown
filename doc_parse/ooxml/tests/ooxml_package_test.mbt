///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn open_sample_package(path : String) -> @ox.OoxmlPackage raise {
  let resolved = resolve_sample_path(path)
  let bytes = @fs.read_file_to_bytes(resolved) catch {
    e => fail("read sample failed: " + resolved + " : " + e.to_string())
  }

  @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
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
fn add_raw_bytes(out : Array[Byte], bytes : Array[Int]) -> Unit {
  for value in bytes {
    out.push(value.to_byte())
  }
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
fn build_store_zip_bytes(entries : Array[(String, Bytes)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data_bytes_raw) = entry
    let local_offset = out.length()
    let name_bytes = bytes_of_string(name)
    let data_bytes = data_bytes_raw.to_array()
    let crc32 = crc32_of_bytes(data_bytes_raw)

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
fn crc32_of_bytes(bytes : Bytes) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for b in bytes {
    crc = crc32_update_uint(crc, byte_to_int(b).reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}

///|
fn build_data_descriptor_ooxml_zip() -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int, Int)] = []
  let entries : Array[(String, Array[Int], Int, Int)] = [
    (
      "[Content_Types].xml",
      [
        125, 80, 205, 78, 195, 48, 12, 126, 149, 40, 87, 212, 186, 227, 128, 16,
        106, 187, 3, 131, 35, 112, 24, 15, 96, 37, 110, 23, 209, 216, 81, 146, 141,
        241, 246, 184, 12, 237, 192, 129, 163, 253, 253, 218, 253, 246, 28, 23, 115,
        162, 92, 130, 240, 96, 55, 109, 103, 13, 177, 19, 31, 120, 30, 236, 251,
        254, 185, 185, 183, 219, 177, 223, 127, 37, 42, 70, 169, 92, 6, 123, 168,
        53, 61, 0, 20, 119, 160, 136, 165, 149, 68, 172, 200, 36, 57, 98, 213, 49,
        207, 144, 208, 125, 224, 76, 112, 219, 117, 119, 224, 132, 43, 113, 109,
        234, 234, 97, 199, 126, 71, 19, 30, 151, 106, 158, 206, 186, 190, 196, 170,
        220, 154, 199, 11, 111, 141, 26, 44, 166, 180, 4, 135, 85, 97, 88, 81, 24,
        251, 87, 109, 153, 131, 39, 243, 134, 185, 190, 96, 84, 22, 124, 74, 246,
        224, 197, 29, 163, 42, 219, 255, 109, 78, 236, 255, 116, 109, 100, 154, 130,
        163, 171, 126, 117, 75, 89, 28, 149, 162, 231, 199, 165, 189, 34, 17, 3,
        223, 252, 246, 128, 159, 103, 140, 223,
      ],
      314,
      0x7198c69a,
    ),
    (
      "_rels/.rels",
      [
        85, 78, 187, 14, 194, 32, 20, 253, 21, 114, 119, 123, 91, 7, 99, 12, 180,
        139, 49, 233, 106, 234, 7, 16, 184, 165, 196, 242, 8, 224, 235, 239, 101,
        112, 176, 227, 121, 31, 62, 188, 221, 202, 158, 148, 178, 13, 94, 64, 215,
        180, 192, 200, 171, 160, 173, 55, 2, 110, 211, 101, 119, 132, 161, 231, 87,
        90, 101, 169, 142, 188, 216, 152, 89, 141, 248, 44, 96, 41, 37, 158, 16,
        179, 90, 200, 201, 220, 132, 72, 190, 42, 115, 72, 78, 150, 10, 147, 193,
        40, 213, 93, 26, 194, 125, 219, 30, 48, 253, 119, 192, 182, 147, 141, 90,
        64, 26, 117, 7, 108, 250, 68, 18, 16, 230, 217, 42, 58, 7, 245, 112, 228,
        75, 101, 101, 50, 84, 4, 188, 66, 210, 168, 127, 116, 83, 231, 0, 123, 142,
        155, 123, 253, 23,
      ],
      212,
      0x7cb357a5,
    ),
    (
      "word/document.xml",
      [
        69, 142, 205, 14, 194, 32, 16, 132, 95, 133, 112, 183, 91, 61, 24, 211, 244,
        231, 210, 24, 31, 64, 31, 160, 2, 182, 77, 96, 151, 44, 40, 250, 246, 66,
        61, 120, 249, 38, 147, 153, 157, 108, 59, 188, 157, 21, 47, 195, 97, 37,
        236, 228, 190, 170, 165, 48, 168, 72, 175, 56, 119, 242, 118, 61, 239, 78,
        114, 232, 219, 212, 104, 82, 79, 103, 48, 138, 220, 199, 208, 164, 78, 46,
        49, 250, 6, 32, 168, 197, 184, 41, 84, 228, 13, 230, 236, 65, 236, 166, 152,
        45, 207, 144, 136, 181, 103, 82, 38, 132, 60, 231, 44, 28, 234, 250, 8, 110,
        90, 81, 150, 201, 59, 233, 79, 81, 95, 192, 5, 177, 191, 24, 107, 73, 140,
        99, 11, 197, 21, 242, 70, 191, 241, 119, 1, 255, 111, 250, 47,
      ],
      192,
      0x6a1ed62e,
    ),
  ]

  for entry in entries {
    let (name, compressed_data, uncompressed_size, crc32) = entry
    let local_offset = out.length()
    let name_bytes = bytes_of_string(name)
    let compressed_size = compressed_data.length()
    let flags = 0x0008
    let method_code = 8

    append_u32_le(out, 0x04034b50)
    append_u16_le(out, 20)
    append_u16_le(out, flags)
    append_u16_le(out, method_code)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, 0)
    append_u16_le(out, name_bytes.length())
    append_u16_le(out, 0)
    for b in name_bytes {
      out.push(b)
    }
    add_raw_bytes(out, compressed_data)
    append_u32_le(out, 0x08074b50)
    append_u32_le(out, crc32)
    append_u32_le(out, compressed_size)
    append_u32_le(out, uncompressed_size)

    central.push(
      (name, compressed_size, uncompressed_size, crc32, local_offset),
    )
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, compressed_size, uncompressed_size, crc32, local_offset) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0x0008)
    append_u16_le(out, 8)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, crc32)
    append_u32_le(out, compressed_size)
    append_u32_le(out, uncompressed_size)
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
fn assert_core_readable(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> Unit raise {
  if !@ox.has_part(pkg, part_name) {
    fail("part should exist: " + part_name)
  }

  let bytes = @ox.read_part_bytes(pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
  if bytes.length() == 0 {
    fail("part bytes should not be empty: " + part_name)
  }

  let content_type = @ox.lookup_content_type(pkg, part_name) catch {
    e =>
      fail("lookup_content_type failed: " + part_name + " : " + e.to_string())
  }
  match content_type {
    Some(_) => ()
    None => fail("content type should exist for: " + part_name)
  }
}

///|
test "ooxml package phase-1 works on docx sample" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")

  assert_core_readable(pkg, "word/document.xml")

  let root_rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let rels = @ox.read_part_relationships(pkg, "word/document.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  ignore(rels)
}

///|
test "ooxml package phase-1 works on xlsx sample" {
  let pkg = open_sample_package("samples/main_process/xlsx/sheet_simple.xlsx")

  assert_core_readable(pkg, "xl/workbook.xml")

  let root_rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let office_rel_id = root_rels[0].id
  let resolved = @ox.resolve_relationship(pkg, "", office_rel_id) catch {
    e => fail("resolve_relationship failed: " + e.to_string())
  }
  if resolved == "" {
    fail("resolved relationship should not be empty")
  }
}

///|
test "ooxml package phase-1 works on pptx sample" {
  let pkg = open_sample_package("samples/main_process/pptx/pptx_simple.pptx")

  assert_core_readable(pkg, "ppt/presentation.xml")

  let root_rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let rels = @ox.read_part_relationships(pkg, "ppt/presentation.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  ignore(rels)
}

///|
test "ooxml package phase-2 can list and query parts" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")

  let parts = @ox.list_parts(pkg)
  if parts.length() == 0 {
    fail("list_parts should not be empty")
  }

  let word_parts = @ox.list_parts_by_prefix(pkg, "word/")
  if word_parts.length() == 0 {
    fail("word parts should not be empty")
  }

  let docs = @ox.list_parts_by_content_type(
    pkg, "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  ) catch {
    e => fail("list_parts_by_content_type failed: " + e.to_string())
  }

  if docs.length() == 0 {
    fail("main document content type should be discoverable")
  }

  let doc_override = @ox.lookup_content_type_override(pkg, "word/document.xml") catch {
    e => fail("lookup_content_type_override failed: " + e.to_string())
  }
  match doc_override {
    Some(v) =>
      if !v.has_suffix("document.main+xml") {
        fail("expected override content type for main document")
      }
    None => fail("expected override content type")
  }

  match @ox.lookup_content_type_default(pkg, "xml") {
    Some(v) =>
      if v == "" {
        fail("default xml content type should not be empty")
      }
    None => fail("expected xml default content type")
  }
}

///|
test "ooxml package phase-2 can find relationships by id and type" {
  let pkg = open_sample_package(
    "samples/main_process/pptx/assets/pptx_image_single.pptx",
  )

  let root_rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("root rels should not be empty")
  }

  let rel0 = root_rels[0]
  let found = @ox.find_relationship_by_id(pkg, "", rel0.id) catch {
    e => fail("find_relationship_by_id failed: " + e.to_string())
  }

  match found {
    Some(rel) => if rel.id != rel0.id { fail("relationship id mismatch") }
    None => fail("relationship should be found by id")
  }

  let pres_rels = @ox.find_relationships_by_type(pkg, "", "/officeDocument") catch {
    e => fail("find_relationships_by_type failed: " + e.to_string())
  }
  if pres_rels.length() == 0 {
    fail("officeDocument relationship should be found")
  }
}

///|
test "ooxml package phase-2 can list media assets" {
  let pkg = open_sample_package("samples/main_process/pptx/pptx_simple.pptx")

  let assets = @ox.list_media_assets(pkg) catch {
    e => fail("list_media_assets failed: " + e.to_string())
  }

  // 样例不一定有图片，所以这里只要求稳定不报错。
  for asset in assets {
    if asset.part_name == "" {
      fail("asset part name should not be empty")
    }
    if asset.size <= 0 {
      fail("asset size should be positive")
    }
  }
}

///|
test "ooxml package phase-2 can read document properties safely" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")

  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)

  ignore(core)
  ignore(app)
}

///|
test "ooxml package phase-2 can read part text" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")
  let text = @ox.read_part_text(pkg, "word/document.xml") catch {
    e => fail("read_part_text failed: " + e.to_string())
  }
  if text.trim() == "" {
    fail("expected non-empty part text")
  }
  if !text.contains("document") && !text.contains("w:document") {
    fail("expected xml-ish text content from part text reader")
  }
}

///|
test "ooxml read_part_text preserves utf8 non-ascii xml payload" {
  let workbook_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets>" +
    "</workbook>"
  let workbook_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/>",
  )
  let sheet_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
    "<sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c></row></sheetData>" +
    "</worksheet>"
  let shared_strings_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"1\" uniqueCount=\"1\">" +
    "<si><t>Cäsar</t></si>" +
    "</sst>"

  let bytes = build_store_zip_bytes([
    (
      "[Content_Types].xml",
      @utf8.encode(
        minimal_content_types_xml(
          "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" +
          "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" +
          "<Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/>",
        ),
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        minimal_rels_xml(
          "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"xl/workbook.xml\"/>",
        ),
      ),
    ),
    ("xl/workbook.xml", @utf8.encode(workbook_xml)),
    ("xl/_rels/workbook.xml.rels", @utf8.encode(workbook_rels_xml)),
    ("xl/worksheets/sheet1.xml", @utf8.encode(sheet_xml)),
    ("xl/sharedStrings.xml", @utf8.encode(shared_strings_xml)),
  ])

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let text = @ox.read_part_text(pkg, "xl/sharedStrings.xml") catch {
    e => fail("read_part_text failed: " + e.to_string())
  }
  if !text.contains("Cäsar") {
    fail("expected utf8 shared string text to stay readable")
  }
}

///|
fn assert_dump_has_debug_sections(dump : String) -> Unit raise {
  if dump == "" {
    fail("dump should not be empty")
  }
  if !dump.contains("[Content_Types]") {
    fail("dump should contain [Content_Types]")
  }
  if !dump.contains("relationships") {
    fail("dump should contain relationships")
  }
  if !dump.contains("media") {
    fail("dump should contain media")
  }
  if !dump.contains("properties") {
    fail("dump should contain properties")
  }
}

///|
fn expect_error_info(
  result : Result[Unit, @ox.OoxmlError],
  kind : @ox.OoxmlErrorKind,
) -> @ox.OoxmlErrorInfo raise {
  match result {
    Ok(_) => fail("expected OOXML error")
    Err(err) => {
      let info = @ox.classify_ooxml_error(err)
      if info.kind != kind {
        fail("unexpected OOXML error kind: err=" + err.to_string())
      }
      info
    }
  }
}

///|
fn[T] ok_or_err_unit(
  result : Result[T, @ox.OoxmlError],
) -> Result[Unit, @ox.OoxmlError] {
  match result {
    Ok(_) => Ok(())
    Err(e) => Err(e)
  }
}

///|
test "ooxml package phase-2.2 can dump docx sample" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")
  let dump = @ox.dump_ooxml_package(pkg)

  assert_dump_has_debug_sections(dump)
  if !dump.contains("part count") {
    fail("dump should contain part count")
  }
}

///|
test "ooxml package phase-2.2 can dump pptx sample" {
  let pkg = open_sample_package("samples/main_process/pptx/pptx_simple.pptx")
  let dump = @ox.dump_ooxml_package(pkg)

  assert_dump_has_debug_sections(dump)
  if !dump.contains("root relationships") {
    fail("dump should contain root relationships")
  }
}

///|
test "ooxml package phase-2.2 can dump xlsx sample" {
  let pkg = open_sample_package("samples/main_process/xlsx/sheet_simple.xlsx")
  let dump = @ox.dump_ooxml_package(pkg)

  assert_dump_has_debug_sections(dump)
  if !dump.contains("content type defaults") {
    fail("dump should contain content type defaults")
  }
}

///|
test "ooxml package phase-2.2 dump handles missing media and docProps" {
  let pkg = open_sample_package(
    "samples/main_process/docx/docx_blockquote_basic.docx",
  )
  let dump = @ox.dump_ooxml_package(pkg)

  assert_dump_has_debug_sections(dump)
  if !dump.contains("media asset count: 0") {
    fail("dump should report empty media assets")
  }
  if !dump.contains("title=(none)") {
    fail("dump should report missing core properties")
  }
}

///|
test "ooxml package currently preserves duplicate relationship ids for compatibility" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>" +
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let rels = @ox.read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  assert_eq(rels.length(), 2)
  if rels[0].id != "rId1" || rels[1].id != "rId1" {
    fail("expected duplicate relationship ids to remain visible to callers")
  }
}

///|
test "ooxml strict validation reports duplicate relationship ids" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>" +
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(pkg)
  if report.mode != @ox.OoxmlValidationMode::Strict {
    fail("strict validation should default to Strict mode")
  }
  if report.error_count <= 0 {
    fail("strict validation should report duplicate relationship id")
  }
  if report.issues[0].kind !=
    @ox.OoxmlValidationIssueKind::DuplicateRelationshipId {
    fail("expected duplicate relationship id issue")
  }
}

///|
test "ooxml compatible validation stays empty for duplicate relationship ids" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>" +
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(
    pkg,
    mode=@ox.OoxmlValidationMode::Compatible,
  )
  assert_eq(report.issue_count, 0)
  assert_eq(report.error_count, 0)
  assert_eq(report.warning_count, 0)
}

///|
test "ooxml package supports central-directory data descriptor entries" {
  let pkg = @ox.open_ooxml_package(build_data_descriptor_ooxml_zip()) catch {
    e =>
      fail(
        "open_ooxml_package failed for data-descriptor ooxml zip: " +
        e.to_string(),
      )
  }

  assert_core_readable(pkg, "word/document.xml")

  let text = @ox.read_part_text(pkg, "word/document.xml") catch {
    e =>
      fail(
        "read_part_text failed for data-descriptor ooxml zip: " + e.to_string(),
      )
  }
  if !text.contains("Hello DD") {
    fail("expected data-descriptor OOXML text payload to round-trip")
  }
}

///|
test "ooxml package rejects unsafe relationship target path" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"image\" Target=\"../media/../../evil.bin\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let result = ok_or_err_unit(
    try? @ox.read_part_relationships(pkg, "word/document.xml"),
  )
  let info = expect_error_info(
    result,
    @ox.OoxmlErrorKind::UnsafeRelationshipTarget,
  )
  if !info.detail.contains("rels_part=\"word/_rels/document.xml.rels\"") {
    fail("unsafe relationship target should preserve rels part context")
  }
  if !info.detail.contains("../media/../../evil.bin") {
    fail("unsafe relationship target should preserve raw target detail")
  }
  match info.target {
    Some(target) =>
      if !target.contains("../media/../../evil.bin") {
        fail("unsafe relationship target should retain traversal target detail")
      }
    None => fail("unsafe relationship target should classify target")
  }
}

///|
test "ooxml package inspect inventory is deterministic and structured" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
        "<Override PartName=\"/word/theme/theme1.xml\" ContentType=\"application/theme+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId7\" Type=\"theme\" Target=\"theme/theme1.xml\"/>",
      ),
    ),
    ("word/theme/theme1.xml", "<theme/>"),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  assert_eq(inventory.parts.length(), 4)
  assert_eq(inventory.part_count, 4)
  assert_eq(inventory.relationship_part_count, 2)
  assert_eq(inventory.content_type_entry_count, 3)
  assert_eq(inventory.media_asset_count, 0)
  if inventory.has_core_properties || inventory.has_app_properties {
    fail("docProps should be absent in this inline package")
  }
  assert_eq(inventory.parts[0].part_name, "_rels/.rels")
  assert_eq(inventory.parts[1].part_name, "word/_rels/document.xml.rels")
  assert_eq(inventory.parts[2].part_name, "word/document.xml")
  assert_eq(inventory.parts[3].part_name, "word/theme/theme1.xml")
  assert_eq(inventory.relationship_parts.length(), 2)
  assert_eq(inventory.relationship_parts[0], "_rels/.rels")
  assert_eq(inventory.relationship_parts[1], "word/_rels/document.xml.rels")
  assert_eq(inventory.relationship_source_parts.length(), 1)
  assert_eq(inventory.relationship_source_parts[0], "word/document.xml")
  let report = @ox.inspect_ooxml_package(pkg)
  assert_eq(report.package_relationship_count, 1)
  assert_eq(report.part_relationship_count, 1)
  assert_eq(report.inventory.content_types.length(), 3)
  assert_eq(report.package_relationships[0].rels_part_name, "_rels/.rels")
  assert_eq(
    report.part_relationships[0].rels_part_name,
    "word/_rels/document.xml.rels",
  )
  match report.part_relationships[0].source_part {
    Some(v) => assert_eq(v, "word/document.xml")
    None => fail("expected source part in part relationship info")
  }
}

///|
test "ooxml package can find part info and missing part info" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")
  let info = @ox.find_part_info(pkg, "word/document.xml") catch {
    e => fail("find_part_info failed: " + e.to_string())
  }
  match info {
    Some(v) => {
      assert_eq(v.part_name, "word/document.xml")
      if v.size <= 0 {
        fail("expected positive part size")
      }
    }
    None => fail("expected part info for word/document.xml")
  }

  let missing = @ox.find_part_info(pkg, "word/missing.xml") catch {
    e =>
      fail(
        "find_part_info on missing part failed unexpectedly: " + e.to_string(),
      )
  }
  match missing {
    Some(_) => fail("missing part should not produce part info")
    None => ()
  }
}

///|
test "ooxml package missing part read is classified" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")
  let result = ok_or_err_unit(try? @ox.read_part_bytes(pkg, "word/missing.xml"))
  let info = expect_error_info(result, @ox.OoxmlErrorKind::MissingPart)
  match info.part_name {
    Some(path) => assert_eq(path, "word/missing.xml")
    None => fail("expected missing part path")
  }
}

///|
test "ooxml package malformed content types is classified" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
      "<Default ContentType=\"application/xml\"/>" +
      "</Types>",
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let result = ok_or_err_unit(try? @ox.open_ooxml_package(bytes))
  let info = expect_error_info(
    result,
    @ox.OoxmlErrorKind::MalformedContentTypes,
  )
  match info.part_name {
    Some(path) => assert_eq(path, "[Content_Types].xml")
    None => fail("expected content types part name")
  }
  if !info.detail.contains("missing attribute: Extension") {
    fail("expected malformed content types detail")
  }
}

///|
test "ooxml package malformed relationships is classified" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml("<Relationship Id=\"rId1\" Type=\"image\"/>"),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let result = ok_or_err_unit(
    try? @ox.read_part_relationships(pkg, "word/document.xml"),
  )
  let info = expect_error_info(
    result,
    @ox.OoxmlErrorKind::MalformedRelationships,
  )
  match info.rels_part_name {
    Some(path) => assert_eq(path, "word/_rels/document.xml.rels")
    None => fail("expected relationships part name")
  }
  if !info.detail.contains("missing attribute: Target") {
    fail("expected malformed relationships detail")
  }
}

///|
test "ooxml strict validation reports missing relationship target" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml("<Relationship Id=\"rId1\" Type=\"image\"/>"),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(pkg)
  let issues = report.issues.filter(fn(issue) {
    issue.kind == @ox.OoxmlValidationIssueKind::MissingRelationshipTarget
  })
  assert_eq(issues.length(), 1)
}

///|
test "ooxml strict validation reports missing relationship id" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Type=\"image\" Target=\"media/image1.png\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(pkg)
  let issues = report.issues.filter(fn(issue) {
    issue.kind == @ox.OoxmlValidationIssueKind::MissingRelationshipId
  })
  assert_eq(issues.length(), 1)
}

///|
test "ooxml strict validation reports unsafe relationship target" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"image\" Target=\"../media/../../evil.bin\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(pkg)
  let issues = report.issues.filter(fn(issue) {
    issue.kind == @ox.OoxmlValidationIssueKind::UnsafeRelationshipTarget
  })
  assert_eq(issues.length(), 1)
  match issues[0].target {
    Some(v) =>
      if !v.contains("../media/../../evil.bin") {
        fail("strict validation should retain unsafe target detail")
      }
    None => fail("strict validation should keep target")
  }
}

///|
test "ooxml package classifies rooted and parent traversal part paths" {
  let pkg = open_sample_package("samples/main_process/docx/golden.docx")
  let rooted = ok_or_err_unit(try? @ox.read_part_bytes(pkg, "/../evil.xml"))
  let rooted_info = expect_error_info(
    rooted,
    @ox.OoxmlErrorKind::UnsafePartName,
  )
  match rooted_info.part_name {
    Some(path) =>
      if path.trim() == "" {
        fail("expected unsafe part path detail")
      }
    None => fail("expected unsafe part path payload")
  }
}

///|
test "ooxml package preserves external relationship classification" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"hyperlink\" Target=\"https://example.com/spec\" TargetMode=\"External\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let rels = @ox.read_part_relationships(pkg, "word/document.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  assert_eq(rels.length(), 1)
  if rels[0].target_mode != @ox.OoxmlTargetMode::External {
    fail("expected external relationship target mode")
  }
  assert_eq(rels[0].resolved_target, "https://example.com/spec")

  let infos = @ox.list_relationship_infos(pkg, "word/document.xml") catch {
    e => fail("list_relationship_infos failed: " + e.to_string())
  }
  assert_eq(infos.length(), 1)
  if infos[0].target_mode != @ox.OoxmlTargetMode::External {
    fail("expected external target mode in relationship info")
  }

  let report = @ox.validate_ooxml_package(pkg)
  assert_eq(report.warning_count, 1)
  assert_eq(report.error_count, 0)
  if report.issues[0].kind != @ox.OoxmlValidationIssueKind::ExternalRelationship {
    fail("expected external relationship validation issue")
  }
}

///|
test "ooxml package rejects duplicate normalized part names" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
    ("word/./document.xml", "<doc/>"),
  ])

  let result = try? @ox.open_ooxml_package(bytes)
  match result {
    Ok(_) => fail("expected normalized part collision to fail closed")
    Err(e) =>
      if !e.to_string().contains("normalized part collision: word/document.xml") {
        fail("unexpected normalized collision error: " + e.to_string())
      }
  }
}

///|
test "ooxml package inventory skips directory entries" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    ("word/", ""),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  assert_eq(inventory.part_count, 1)
  assert_eq(inventory.parts[0].part_name, "word/document.xml")
}

///|
test "ooxml package rejects duplicate content type override after normalization" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/xml\"/>" +
        "<Override PartName=\"/word/./document.xml\" ContentType=\"application/xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])

  let result = try? @ox.open_ooxml_package(bytes)
  match result {
    Ok(_) => fail("expected duplicate normalized content type override to fail")
    Err(e) => {
      let info = @ox.classify_ooxml_error(e)
      if info.kind != @ox.OoxmlErrorKind::DuplicateContentTypeOverride {
        fail("unexpected duplicate override error kind: " + e.to_string())
      }
      if !e
        .to_string()
        .contains("duplicate content type override: /word/document.xml") {
        fail("unexpected duplicate override error: " + e.to_string())
      }
    }
  }
}

///|
test "ooxml package content type default and override behavior is explicit" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
      "<Default Extension=\"xml\" ContentType=\"application/xml-default\"/>" +
      "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
      "<Override PartName=\"/word/document.xml\" ContentType=\"application/document-override\"/>" +
      "</Types>",
    ),
    ("word/document.xml", "<doc/>"),
    ("word/other.xml", "<other/>"),
    ("word/media/image1.png", "PNGDATA"),
    ("word/noext", "raw"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let doc_ct = @ox.lookup_content_type(pkg, "word/document.xml") catch {
    e => fail("lookup_content_type failed: " + e.to_string())
  }
  match doc_ct {
    Some(v) => assert_eq(v, "application/document-override")
    None => fail("expected override content type")
  }
  let other_ct = @ox.lookup_content_type(pkg, "word/other.xml") catch {
    e => fail("lookup_content_type failed: " + e.to_string())
  }
  match other_ct {
    Some(v) => assert_eq(v, "application/xml-default")
    None => fail("expected xml default content type")
  }
  let png_ct = @ox.lookup_content_type(pkg, "word/media/image1.png") catch {
    e => fail("lookup_content_type failed: " + e.to_string())
  }
  match png_ct {
    Some(v) => assert_eq(v, "image/png")
    None => fail("expected png default content type")
  }
  let noext_ct = @ox.lookup_content_type(pkg, "word/noext") catch {
    e => fail("lookup_content_type failed: " + e.to_string())
  }
  match noext_ct {
    Some(_) => fail("part without extension should not infer a content type")
    None => ()
  }
}

///|
test "ooxml strict validation issue ordering is deterministic" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Type=\"officeDocument\" Target=\"word/document.xml\"/>" +
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>" +
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    (
      "word/_rels/document.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId2\" Type=\"hyperlink\" Target=\"https://example.com/spec\" TargetMode=\"External\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let report = @ox.validate_ooxml_package(pkg)
  if report.issues.length() < 3 {
    fail("expected multiple strict validation issues")
  }
  if report.issues[0].kind !=
    @ox.OoxmlValidationIssueKind::DuplicateRelationshipId {
    fail("expected duplicate relationship id issue first")
  }
  if report.issues[1].kind !=
    @ox.OoxmlValidationIssueKind::MissingRelationshipId {
    fail("expected missing relationship id issue second")
  }
}

///|
test "ooxml package can parse lightweight core and app properties" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
      "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
      "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>" +
      "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>" +
      "</Types>",
    ),
    (
      "docProps/core.xml", "<cp:coreProperties><dc:title>Spec</dc:title><dc:creator>MoonBit</dc:creator></cp:coreProperties>",
    ),
    (
      "docProps/app.xml", "<Properties><Application>MarkItDown</Application><Pages>7</Pages><Worksheets>3</Worksheets></Properties>",
    ),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let core = @ox.read_core_properties(pkg)
  let app = @ox.read_app_properties(pkg)
  match core.title {
    Some(v) => assert_eq(v, "Spec")
    None => fail("expected core title")
  }
  match core.creator {
    Some(v) => assert_eq(v, "MoonBit")
    None => fail("expected core creator")
  }
  match app.application {
    Some(v) => assert_eq(v, "MarkItDown")
    None => fail("expected app application")
  }
  match app.pages {
    Some(v) => assert_eq(v, "7")
    None => fail("expected app pages")
  }
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  if !inventory.has_core_properties || !inventory.has_app_properties {
    fail("expected docProps availability in inventory")
  }
}

///|
test "ooxml package missing relationship target stays not found" {
  let bytes = build_store_zip([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", "<doc/>"),
  ])
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
  let result = ok_or_err_unit(try? @ox.resolve_relationship(pkg, "", "rId404"))
  let info = expect_error_info(result, @ox.OoxmlErrorKind::RelationshipNotFound)
  match info.rel_id {
    Some(v) => assert_eq(v, "rId404")
    None => fail("expected missing relationship id")
  }
}
