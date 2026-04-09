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
fn read_sample_bytes(path : String) -> Bytes raise {
  let resolved = resolve_sample_path(path)
  @fs.read_file_to_bytes(resolved) catch {
    e => fail("failed to read sample: " + resolved + " : " + e.to_string())
  }
}

///|
fn open_sample_zip(path : String) -> ZipArchive raise {
  let bytes = read_sample_bytes(path)
  open_zip(bytes) catch {
    e => fail("open_zip failed for sample: " + path + " : " + e.to_string())
  }
}

///|
fn assert_entry_readable(
  archive : ZipArchive,
  entry_path : String,
) -> Unit raise {
  let data = read_entry(archive, entry_path) catch {
    e => fail("read_entry failed: " + entry_path + " : " + e.to_string())
  }
  if data.length() == 0 {
    fail("entry data is empty: " + entry_path)
  }
}

///|
test "zip reader can list and read docx core entry" {
  let z = open_sample_zip("samples/docx/golden.docx")
  let entries = list_entries(z)
  if entries.length() == 0 {
    fail("docx entries should not be empty")
  }
  assert_entry_readable(z, "word/document.xml")
}

///|
test "zip reader can list and read xlsx core entry" {
  let z = open_sample_zip("samples/xlsx/sheet_simple.xlsx")
  let entries = list_entries(z)
  if entries.length() == 0 {
    fail("xlsx entries should not be empty")
  }
  assert_entry_readable(z, "xl/workbook.xml")
}

///|
test "zip reader can list and read pptx core entry" {
  let z = open_sample_zip("samples/pptx/pptx_simple.pptx")
  let entries = list_entries(z)
  if entries.length() == 0 {
    fail("pptx entries should not be empty")
  }
  assert_entry_readable(z, "ppt/presentation.xml")
}
