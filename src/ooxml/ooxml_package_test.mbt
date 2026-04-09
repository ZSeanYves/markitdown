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
fn open_sample_package(path : String) -> OoxmlPackage raise {
  let resolved = resolve_sample_path(path)
  let bytes = @fs.read_file_to_bytes(resolved) catch {
    e => fail("read sample failed: " + resolved + " : " + e.to_string())
  }

  open_ooxml_package(bytes) catch {
    e => fail("open_ooxml_package failed: " + e.to_string())
  }
}

///|
fn assert_core_readable(pkg : OoxmlPackage, part_name : String) -> Unit raise {
  if !has_part(pkg, part_name) {
    fail("part should exist: " + part_name)
  }

  let bytes = read_part_bytes(pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
  if bytes.length() == 0 {
    fail("part bytes should not be empty: " + part_name)
  }

  let content_type = lookup_content_type(pkg, part_name) catch {
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
  let pkg = open_sample_package("samples/docx/golden.docx")

  assert_core_readable(pkg, "word/document.xml")

  let root_rels = read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let rels = read_part_relationships(pkg, "word/document.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  ignore(rels)
}

///|
test "ooxml package phase-1 works on xlsx sample" {
  let pkg = open_sample_package("samples/xlsx/sheet_simple.xlsx")

  assert_core_readable(pkg, "xl/workbook.xml")

  let root_rels = read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let office_rel_id = root_rels[0].id
  let resolved = resolve_relationship(pkg, "", office_rel_id) catch {
    e => fail("resolve_relationship failed: " + e.to_string())
  }
  if resolved == "" {
    fail("resolved relationship should not be empty")
  }
}

///|
test "ooxml package phase-1 works on pptx sample" {
  let pkg = open_sample_package("samples/pptx/pptx_simple.pptx")

  assert_core_readable(pkg, "ppt/presentation.xml")

  let root_rels = read_package_relationships(pkg) catch {
    e => fail("read_package_relationships failed: " + e.to_string())
  }
  if root_rels.length() == 0 {
    fail("package relationships should not be empty")
  }

  let rels = read_part_relationships(pkg, "ppt/presentation.xml") catch {
    e => fail("read_part_relationships failed: " + e.to_string())
  }
  ignore(rels)
}
