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
fn add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)

  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u32_le(out, 0)
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

  central.push((name, data_bytes.length(), local_offset))
}

///|
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
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
  assert_eq(inventory.parts[0].part_name, "_rels/.rels")
  assert_eq(inventory.parts[1].part_name, "word/_rels/document.xml.rels")
  assert_eq(inventory.parts[2].part_name, "word/document.xml")
  assert_eq(inventory.parts[3].part_name, "word/theme/theme1.xml")
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
