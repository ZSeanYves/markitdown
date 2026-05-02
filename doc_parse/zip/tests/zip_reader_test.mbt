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
fn open_sample_zip(path : String) -> @zip.ZipArchive raise {
  let bytes = read_sample_bytes(path)
  @zip.open_zip(bytes) catch {
    e => fail("open_zip failed for sample: " + path + " : " + e.to_string())
  }
}

///|
fn assert_entry_readable(
  archive : @zip.ZipArchive,
  entry_path : String,
) -> Unit raise {
  let data = @zip.read_entry(archive, entry_path) catch {
    e => fail("read_entry failed: " + entry_path + " : " + e.to_string())
  }
  if data.length() == 0 {
    fail("entry data is empty: " + entry_path)
  }
}

///|
test "zip reader can list and read docx core entry" {
  let z = open_sample_zip("samples/main_process/docx/golden.docx")
  let entries = @zip.list_entries(z)
  if entries.length() == 0 {
    fail("docx entries should not be empty")
  }
  assert_entry_readable(z, "word/document.xml")
}

///|
test "zip reader can list and read xlsx core entry" {
  let z = open_sample_zip("samples/main_process/xlsx/sheet_simple.xlsx")
  let entries = @zip.list_entries(z)
  if entries.length() == 0 {
    fail("xlsx entries should not be empty")
  }
  assert_entry_readable(z, "xl/workbook.xml")
}

///|
test "zip reader can list and read pptx core entry" {
  let z = open_sample_zip("samples/main_process/pptx/pptx_simple.pptx")
  let entries = @zip.list_entries(z)
  if entries.length() == 0 {
    fail("pptx entries should not be empty")
  }
  assert_entry_readable(z, "ppt/presentation.xml")
}

///|
test "zip inspect exposes entry structural facts" {
  let bytes = read_sample_bytes(
    "samples/main_process/zip/zip_basic_structured.zip",
  )
  let entries = @zip.inspect_zip(bytes) catch {
    e => fail("inspect_zip failed: " + e.to_string())
  }

  if entries.length() == 0 {
    fail("expected zip inspect entries to be non-empty")
  }

  let mut found_json = false
  let mut found_txt = false
  for entry in entries {
    if entry.name == "data/person.json" {
      found_json = true
      if entry.is_directory {
        fail("json entry should not be marked as directory")
      }
      if entry.is_encrypted {
        fail("json entry should not be marked encrypted")
      }
      if entry.has_data_descriptor {
        fail("json entry should not be marked with data descriptor")
      }
      if entry.uses_zip64 {
        fail("json entry should not be marked as zip64")
      }
      if entry.compressed_size <= 0 || entry.uncompressed_size <= 0 {
        fail("json entry should expose positive sizes")
      }
    }
    if entry.name == "docs/readme.md" {
      found_txt = true
    }
  }

  if !found_json {
    fail("expected data/person.json in inspect output")
  }
  if !found_txt {
    fail("expected docs/readme.md in inspect output")
  }
}
