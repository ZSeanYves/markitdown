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
    pkg,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  ) catch {
    e => fail("list_parts_by_content_type failed: " + e.to_string())
  }

  if docs.length() == 0 {
    fail("main document content type should be discoverable")
  }
}

///|
test "ooxml package phase-2 can find relationships by id and type" {
  let pkg = open_sample_package("samples/assets/pptx/pptx_image_single.pptx")

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
    Some(rel) =>
      if rel.id != rel0.id {
        fail("relationship id mismatch")
      }
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