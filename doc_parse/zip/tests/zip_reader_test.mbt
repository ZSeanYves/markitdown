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
fn bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn bytes_to_string(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for b in bytes {
    let v = b.to_int()
    let code = if v >= 0 { v } else { v + 256 }
    chars.push(Int::unsafe_to_char(code))
  }
  String::from_array(chars)
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
fn add_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
  method_code? : Int = 0,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)

  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, method_code)
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

  central.push((name, data_bytes.length(), local_offset, method_code))
}

///|
fn build_zip(entries : Array[(String, String, Int)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data, method_code) = entry
    add_entry(out, central, name, data, method_code~)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, method_code) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, method_code)
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
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let decorated : Array[(String, String, Int)] = []
  for entry in entries {
    let (name, data) = entry
    decorated.push((name, data, 0))
  }
  build_zip(decorated)
}

///|
fn open_inline_zip(entries : Array[(String, String)]) -> @zip.ZipArchive raise {
  @zip.open_zip(build_store_zip(entries)) catch {
    e => fail("open inline zip failed: " + e.to_string())
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

///|
test "zip facade inventory reports deterministic normalized entry info" {
  let archive = open_inline_zip([
    ("docs/", ""),
    ("docs/readme.md", "# Readme"),
    ("data/person.json", "{\"name\":\"Ada\"}"),
    ("empty.txt", ""),
  ])

  if !@zip.has_entry(archive, "docs/readme.md") {
    fail("has_entry should find docs/readme.md")
  }
  if @zip.has_entry(archive, "missing.txt") {
    fail("has_entry should not find missing.txt")
  }

  let infos = @zip.list_entry_infos(archive)
  if infos.length() != 4 {
    fail("expected 4 entry infos")
  }
  if infos[0].raw_name != "data/person.json" ||
    infos[1].raw_name != "docs/" ||
    infos[2].raw_name != "docs/readme.md" ||
    infos[3].raw_name != "empty.txt" {
    fail("entry infos should be sorted deterministically")
  }

  let dir_info = match @zip.find_entry_info(archive, "docs/") {
    Some(info) => info
    None => fail("expected docs/ entry info")
  }
  if !dir_info.is_directory || dir_info.normalized_path != Some("docs") {
    fail("directory info should preserve normalized path")
  }

  let readme_info = match @zip.find_entry_info(archive, "docs/readme.md") {
    Some(info) => info
    None => fail("expected docs/readme.md entry info")
  }
  if readme_info.extension != Some("md") || !readme_info.is_file {
    fail("readme info should expose extension and file flag")
  }

  let inventory = @zip.inspect_zip_inventory(archive)
  if inventory.entry_count != 4 ||
    inventory.file_entry_count != 3 ||
    inventory.directory_entry_count != 1 {
    fail("unexpected zip inventory counts")
  }
  if inventory.total_uncompressed_size <= 0 ||
    inventory.total_compressed_size <= 0 {
    fail("inventory should expose positive size totals")
  }

  let report = @zip.inspect_zip_archive(archive)
  if report.issue_count != 2 ||
    report.warning_count != 2 ||
    report.error_count != 0 {
    fail("expected directory + empty entry warnings")
  }
}

///|
test "zip facade can read entry bytes and classify missing entry" {
  let archive = open_inline_zip([("notes/hello.txt", "hello zip")])
  let data = @zip.read_entry(archive, "notes/hello.txt") catch {
    e => fail("read_entry failed: " + e.to_string())
  }
  if bytes_to_string(data) != "hello zip" {
    fail("read_entry should return exact entry bytes")
  }

  let result = try? @zip.read_entry(archive, "notes/missing.txt")
  match result {
    Ok(_) => fail("expected missing entry read to fail")
    Err(err) => {
      let info = @zip.classify_zip_error(err)
      if info.kind != @zip.ZipErrorKind::MissingEntry ||
        info.mapping != @zip.ZipErrorMappingKind::DirectVariant ||
        info.entry_name != Some("notes/missing.txt") {
        fail("missing entry should classify as direct MissingEntry")
      }
    }
  }
}

///|
test "zip validation reports unsafe paths and normalized collisions" {
  let archive = open_inline_zip([
    ("../evil.txt", "1"),
    ("/absolute.txt", "2"),
    ("C:/temp/evil.txt", "3"),
    ("a/../../evil.txt", "4"),
    ("safe\\dir/file.txt", "x"),
    ("safe/dir/file.txt", "y"),
  ])

  let report = @zip.inspect_zip_archive(archive)
  if report.unsafe_entry_count != 4 || !report.inventory.has_unsafe_paths {
    fail("unsafe paths should be counted in inspect report")
  }
  if report.duplicate_normalized_entry_count != 2 ||
    !report.inventory.has_duplicate_normalized_paths {
    fail("normalized collisions should be counted in inspect report")
  }

  let validation = @zip.validate_zip_archive(archive)
  if validation.error_count != 6 || validation.warning_count != 0 {
    fail("expected four unsafe-path errors and two collision errors")
  }

  let mut unsafe_count = 0
  let mut duplicate_count = 0
  for issue in validation.issues {
    match issue.kind {
      @zip.ZipValidationIssueKind::UnsafeEntryPath => unsafe_count += 1
      @zip.ZipValidationIssueKind::DuplicateNormalizedEntry =>
        duplicate_count += 1
      _ => ()
    }
  }
  if unsafe_count != 4 || duplicate_count != 2 {
    fail("unexpected unsafe/collision issue counts")
  }
}

///|
test "zip validation reports unsupported compression and nested archive candidates" {
  let bytes = build_zip([
    ("nested/archive.zip", "PK", 0),
    ("unsupported.bin", "raw", 99),
  ])
  let archive = @zip.open_zip(bytes) catch {
    e =>
      fail("open_zip failed for unsupported-compression case: " + e.to_string())
  }

  let report = @zip.inspect_zip_archive(archive)
  if report.unsupported_compression_entry_count != 1 {
    fail("unsupported compression entry should be counted")
  }

  let validation = @zip.validate_zip_archive(archive)
  let mut saw_unsupported = false
  let mut saw_nested = false
  for issue in validation.issues {
    match issue.kind {
      @zip.ZipValidationIssueKind::UnsupportedCompressionMethod =>
        saw_unsupported = true
      @zip.ZipValidationIssueKind::NestedArchiveCandidate => saw_nested = true
      _ => ()
    }
  }
  if !saw_unsupported || !saw_nested {
    fail("expected unsupported-compression and nested-archive issues")
  }

  let result = try? @zip.read_entry(archive, "unsupported.bin")
  match result {
    Ok(_) => fail("unsupported compression entry should not decode")
    Err(err) => {
      let info = @zip.classify_zip_error(err)
      if info.kind != @zip.ZipErrorKind::UnsupportedCompressionMethod {
        fail("unsupported compression should classify correctly")
      }
    }
  }
}

///|
test "zip error classifier distinguishes direct and best-effort mappings" {
  let missing = @zip.classify_zip_error(@zip.EntryNotFound("missing.txt"))
  if missing.kind != @zip.ZipErrorKind::MissingEntry ||
    missing.mapping != @zip.ZipErrorMappingKind::DirectVariant {
    fail("EntryNotFound should classify via direct variant mapping")
  }

  let encrypted = @zip.classify_zip_error(
    @zip.InvalidStructure("encrypted zip is not supported: secret.txt"),
  )
  if encrypted.kind != @zip.ZipErrorKind::EncryptedEntry ||
    encrypted.mapping != @zip.ZipErrorMappingKind::BestEffortMessage ||
    encrypted.entry_name != Some("secret.txt") {
    fail(
      "encrypted invalid-structure error should classify via best-effort mapping",
    )
  }

  let duplicate = @zip.classify_zip_error(
    @zip.InvalidStructure("duplicate entry name in central directory: dup.txt"),
  )
  if duplicate.kind != @zip.ZipErrorKind::DuplicateEntryName ||
    duplicate.mapping != @zip.ZipErrorMappingKind::BestEffortMessage {
    fail("duplicate-entry invalid-structure error should classify distinctly")
  }

  let unsupported = @zip.classify_zip_error(
    @zip.InvalidStructure("ZIP64 is not supported in phase-1"),
  )
  if unsupported.kind != @zip.ZipErrorKind::UnsupportedFeature ||
    unsupported.mapping != @zip.ZipErrorMappingKind::BestEffortMessage {
    fail("ZIP64 unsupported message should classify as UnsupportedFeature")
  }

  let malformed = @zip.classify_zip_error(
    @zip.InvalidStructure("central/local filename mismatch"),
  )
  if malformed.kind != @zip.ZipErrorKind::MalformedArchive ||
    malformed.mapping != @zip.ZipErrorMappingKind::DirectVariant {
    fail("generic invalid structure should remain malformed archive")
  }

  let read_failed = @zip.classify_zip_error(
    @zip.DecodeFailed("decode failed for `bad.bin`: broken deflate stream"),
  )
  if read_failed.kind != @zip.ZipErrorKind::ReadEntryFailed ||
    read_failed.mapping != @zip.ZipErrorMappingKind::DirectVariant ||
    read_failed.entry_name != Some("bad.bin") {
    fail("decode failure should retain entry context")
  }
}
