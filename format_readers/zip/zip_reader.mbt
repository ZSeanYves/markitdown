///|
/// ZIP low-level reader used as raw parsing infrastructure for OOXML families.
///
/// This layer only guarantees container integrity + entry byte access.
/// It intentionally does NOT perform document semantics recovery.
const EOCD_SIG : Int = 0x06054b50

///|
const CD_FILE_HEADER_SIG : Int = 0x02014b50

///|
const LOCAL_FILE_HEADER_SIG : Int = 0x04034b50

///|
const ZIP64_U16_SENTINEL : Int = 0xFFFF

///|
const ZIP64_U32_SENTINEL : Int = 0xFFFFFFFF

///|
const ZIP64_U32_SENTINEL_SIGNED : Int = -1

///|
const GP_FLAG_ENCRYPTED : Int = 0x0001

///|
const GP_FLAG_DATA_DESCRIPTOR : Int = 0x0008

///|
const MAX_NORMALIZED_ENTRY_PATH_LENGTH : Int = 240

///|
const MAX_NORMALIZED_DIRECTORY_DEPTH : Int = 16

///|
pub fn open_zip(bytes : Bytes) -> ZipArchive raise ZipError {
  let eocd_offset = find_eocd(bytes)
  let (cd_offset, cd_size, entry_count) = parse_eocd(bytes, eocd_offset)
  let entries = parse_cd_entries(bytes, cd_offset, cd_size, entry_count)
  let index : Map[String, Int] = Map([])

  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if index.contains(entry.name) {
      raise InvalidStructure(
        "duplicate entry name in central directory: " + entry.name,
      )
    }
    index.set(entry.name, i)
    i = i + 1
  }

  { bytes, entries, entry_index: index }
}

///|
pub fn list_entries(archive : ZipArchive) -> Array[ZipEntryMeta] {
  archive.entries
}

///|
pub fn has_entry(archive : ZipArchive, path : String) -> Bool {
  archive.entry_index.contains(path)
}

///|
pub fn normalize_entry_path(raw_path : String) -> String? {
  normalize_entry_path_impl(raw_path, false)
}

///|
pub fn list_entry_infos(archive : ZipArchive) -> Array[ZipEntryInfo] {
  inspect_zip_archive(archive).inventory.entries
}

///|
pub fn find_entry_info(archive : ZipArchive, path : String) -> ZipEntryInfo? {
  for info in list_entry_infos(archive) {
    if info.raw_name == path {
      return Some(info)
    }
  }
  None
}

///|
pub fn inspect_zip_inventory(archive : ZipArchive) -> ZipArchiveInventory {
  inspect_zip_archive(archive).inventory
}

///|
pub fn inspect_zip_archive(archive : ZipArchive) -> ZipArchiveInspectReport {
  build_zip_archive_report(archive)
}

///|
pub fn collect_zip_validation_issues(
  archive : ZipArchive,
) -> Array[ZipValidationIssue] {
  inspect_zip_archive(archive).issues
}

///|
pub fn validate_zip_archive(archive : ZipArchive) -> ZipValidationReport {
  let report = inspect_zip_archive(archive)
  {
    entry_count: report.entry_count,
    file_entry_count: report.file_entry_count,
    directory_entry_count: report.directory_entry_count,
    issue_count: report.issue_count,
    warning_count: report.warning_count,
    error_count: report.error_count,
    issues: report.issues,
  }
}

///|
pub fn inspect_zip(bytes : Bytes) -> Array[ZipEntryMeta] raise ZipError {
  open_zip(bytes).entries
}

///|
pub fn read_entry(
  archive : ZipArchive,
  path : String,
  max_output_size? : Int = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  let slice = read_entry_data_slice(archive, path)
  let entry = slice.entry
  let compressed = subview(
    archive.bytes,
    slice.data_start,
    slice.data_end,
    "entry data",
  )

  let decoded = decompress(
    entry.compression_method,
    compressed,
    max_output_size~,
  ) catch {
    UnsupportedCompressionMethod(code) =>
      raise UnsupportedCompressionMethod(code)
    DecodeFailed(msg) =>
      raise DecodeFailed("decode failed for `" + entry.name + "`: " + msg)
    OutputTooLarge(max, actual) =>
      raise InvalidStructure(
        "decoded entry exceeds max_output_size: max=" +
        max.to_string() +
        ", actual=" +
        actual.to_string(),
      )
  }

  if decoded.length() != entry.uncompressed_size {
    raise InvalidStructure(
      "decoded size mismatch for entry: " +
      entry.name +
      " expected=" +
      entry.uncompressed_size.to_string() +
      " actual=" +
      decoded.length().to_string(),
    )
  }

  validate_crc32(decoded, entry)
  decoded
}

///|
pub fn read_entry_data_slice(
  archive : ZipArchive,
  path : String,
) -> ZipEntryDataSlice raise ZipError {
  let entry = match archive.entry_index.get(path) {
    Some(idx) => archive.entries[idx]
    None => raise EntryNotFound(path)
  }
  read_entry_data_slice_from_meta(archive, entry)
}

///|
fn read_entry_data_slice_from_meta(
  archive : ZipArchive,
  entry : ZipEntryMeta,
) -> ZipEntryDataSlice raise ZipError {
  validate_entry_supported_flags(entry.flags, entry.name)

  let local_offset = entry.local_header_offset
  let sig = read_u32_le(
    archive.bytes,
    local_offset,
    "local file header signature",
  )
  if sig != LOCAL_FILE_HEADER_SIG {
    raise InvalidSignature("local file header", LOCAL_FILE_HEADER_SIG, sig)
  }

  let flags = read_u16_le(
    archive.bytes,
    local_offset + 6,
    "local file header flags",
  )
  let method_code = read_u16_le(
    archive.bytes,
    local_offset + 8,
    "local file header method",
  )
  let local_crc32 = read_u32_le(
    archive.bytes,
    local_offset + 14,
    "local file header crc32",
  )
  let local_compressed_size = read_u32_le(
    archive.bytes,
    local_offset + 18,
    "local file header compressed size",
  )
  let local_uncompressed_size = read_u32_le(
    archive.bytes,
    local_offset + 22,
    "local file header uncompressed size",
  )
  let name_len = read_u16_le(
    archive.bytes,
    local_offset + 26,
    "local file header name length",
  )
  let extra_len = read_u16_le(
    archive.bytes,
    local_offset + 28,
    "local file header extra length",
  )

  validate_entry_supported_flags(flags, entry.name)

  let local_method = compression_method_from_code(method_code)
  if local_method != entry.compression_method {
    raise InvalidStructure(
      "central/local compression method mismatch for entry: " + entry.name,
    )
  }

  if flags != entry.flags {
    raise InvalidStructure(
      "central/local flags mismatch for entry: " + entry.name,
    )
  }

  let local_name_start = local_offset + 30
  let local_name_end = local_name_start + name_len
  let local_name_bytes = subview(
    archive.bytes,
    local_name_start,
    local_name_end,
    "local file header name",
  )
  let local_name = bytes_to_string(local_name_bytes)

  if local_name != entry.name {
    raise InvalidStructure(
      "central/local filename mismatch: central=`" +
      entry.name +
      "`, local=`" +
      local_name +
      "`",
    )
  }

  if !entry.has_data_descriptor {
    if local_crc32 != entry.crc32 {
      raise InvalidStructure(
        "central/local crc32 mismatch for entry: " + entry.name,
      )
    }
    if local_compressed_size != entry.compressed_size {
      raise InvalidStructure(
        "central/local compressed size mismatch for entry: " + entry.name,
      )
    }
    if local_uncompressed_size != entry.uncompressed_size {
      raise InvalidStructure(
        "central/local uncompressed size mismatch for entry: " + entry.name,
      )
    }
  }

  let data_start = local_name_end + extra_len
  let data_end = data_start + entry.compressed_size
  if data_start < 0 ||
    data_end < data_start ||
    data_end > archive.bytes.length() {
    raise UnexpectedEOF("entry data")
  }
  { entry, data_start, data_end }
}

///|
pub fn visit_inflated_entry_chunks(
  archive : ZipArchive,
  path : String,
  chunk_size? : Int = 64 * 1024,
  on_chunk : (Bytes) -> Result[Unit, String],
) -> Result[Unit, String] {
  let slice = read_entry_data_slice(archive, path) catch {
    err => return Err(err.to_string())
  }
  visit_inflated_entry_chunks_from_slice(
    archive.bytes,
    slice,
    chunk_size~,
    on_chunk,
  )
}

///|
pub fn visit_inflated_entry_chunks_from_slice(
  archive_bytes : Bytes,
  slice : ZipEntryDataSlice,
  chunk_size? : Int = 64 * 1024,
  on_chunk : (Bytes) -> Result[Unit, String],
) -> Result[Unit, String] {
  let chunk_size = if chunk_size <= 0 { 64 * 1024 } else { chunk_size }
  let entry = slice.entry
  let mut emitted_bytes = 0
  let crc = @checksum.CRC32::new()
  match entry.compression_method {
    Store => {
      let mut pos = slice.data_start
      while pos < slice.data_end {
        let end_ = (pos + chunk_size).min(slice.data_end)
        let chunk = archive_bytes[pos:end_].to_owned()
        emitted_bytes += chunk.length()
        crc.update(chunk[:])
        match on_chunk(chunk) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
        pos = end_
      }
    }
    DeflateRaw => {
      let inflater = @flate.Inflater::new()
      let mut pos = slice.data_start
      let mut done = false
      while !done {
        let feed_end = (pos + chunk_size).min(slice.data_end)
        if pos < feed_end {
          inflater.src(archive_bytes[pos:feed_end])
          pos = feed_end
        }
        loop inflater.decode() {
          Await =>
            if pos >= slice.data_end {
              return Err(
                "zip decode failed for `" + entry.name + "`: unexpected EOF",
              )
            } else {
              break
            }
          Data(out) => {
            let chunk = out.to_owned()
            emitted_bytes += chunk.length()
            crc.update(chunk[:])
            if emitted_bytes > entry.uncompressed_size {
              return Err(
                "invalid zip structure: decoded size overflow for entry: " +
                entry.name +
                " expected=" +
                entry.uncompressed_size.to_string() +
                " actual=" +
                emitted_bytes.to_string(),
              )
            }
            match on_chunk(chunk) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
            continue inflater.decode()
          }
          End => {
            done = true
            break
          }
          Error(err) =>
            return Err(
              "decode failed for `" + entry.name + "`: " + err.to_string(),
            )
        }
      }
      let remaining = inflater.remaining()
      if remaining.length() > 0 {
        return Err(
          "invalid zip structure: decoded entry left trailing compressed bytes: " +
          entry.name,
        )
      }
    }
    Unsupported(code) =>
      return Err("unsupported compression method: " + code.to_string())
  }
  if emitted_bytes != entry.uncompressed_size {
    return Err(
      "invalid zip structure: decoded size mismatch for entry: " +
      entry.name +
      " expected=" +
      entry.uncompressed_size.to_string() +
      " actual=" +
      emitted_bytes.to_string(),
    )
  }
  let actual_crc = crc.checksum().reinterpret_as_int()
  if actual_crc != entry.crc32 {
    return Err(
      "invalid zip structure: crc32 mismatch for entry: " +
      entry.name +
      " expected=" +
      entry.crc32.to_string() +
      " actual=" +
      actual_crc.to_string(),
    )
  }
  Ok(())
}

///|
pub fn classify_zip_error(err : ZipError) -> ZipErrorInfo {
  match err {
    EntryNotFound(path) =>
      {
        kind: ZipErrorKind::MissingEntry,
        mapping: ZipErrorMappingKind::DirectVariant,
        entry_name: Some(path),
        detail: err.to_string(),
      }
    UnsupportedCompressionMethod(_) =>
      {
        kind: ZipErrorKind::UnsupportedCompressionMethod,
        mapping: ZipErrorMappingKind::DirectVariant,
        entry_name: None,
        detail: err.to_string(),
      }
    DecodeFailed(detail) =>
      {
        kind: ZipErrorKind::ReadEntryFailed,
        mapping: ZipErrorMappingKind::DirectVariant,
        entry_name: extract_backtick_wrapped_name(detail),
        detail: err.to_string(),
      }
    UnexpectedEOF(_) | InvalidSignature(_, _, _) =>
      {
        kind: ZipErrorKind::MalformedArchive,
        mapping: ZipErrorMappingKind::DirectVariant,
        entry_name: None,
        detail: err.to_string(),
      }
    InvalidStructure(detail) => classify_invalid_structure_detail(detail)
  }
}

///|
fn validate_entry_supported_flags(
  flags : Int,
  entry_name : String,
) -> Unit raise ZipError {
  if (flags & GP_FLAG_ENCRYPTED) != 0 {
    raise InvalidStructure("encrypted zip is not supported: " + entry_name)
  }
}

///|
fn validate_crc32(decoded : Bytes, entry : ZipEntryMeta) -> Unit raise ZipError {
  let actual = crc32_of_bytes(decoded)
  if actual != entry.crc32 {
    raise InvalidStructure(
      "crc32 mismatch for entry: " +
      entry.name +
      " expected=" +
      entry.crc32.to_string() +
      " actual=" +
      actual.to_string(),
    )
  }
}

///|
fn crc32_of_bytes(bytes : Bytes) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for b in bytes {
    let value = b.to_uint()
    crc = crc32_update_byte(crc, value)
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn crc32_update_byte(crc : UInt, value : UInt) -> UInt {
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
fn find_eocd(bytes : Bytes) -> Int raise ZipError {
  let len = bytes.length()
  if len < 22 {
    raise UnexpectedEOF("zip smaller than minimum EOCD size")
  }

  let max_back = 65535 + 22
  let scan_start = if len > max_back { len - max_back } else { 0 }
  let mut pos = len - 22

  while pos >= scan_start {
    let sig = read_u32_le(bytes, pos, "EOCD signature probe")
    if sig == EOCD_SIG {
      return pos
    }
    pos = pos - 1
  }

  raise InvalidStructure("EOCD not found")
}

///|
fn parse_eocd(
  bytes : Bytes,
  eocd_offset : Int,
) -> (Int, Int, Int) raise ZipError {
  let sig = read_u32_le(bytes, eocd_offset, "EOCD signature")
  if sig != EOCD_SIG {
    raise InvalidSignature("EOCD", EOCD_SIG, sig)
  }

  let disk_no = read_u16_le(bytes, eocd_offset + 4, "EOCD disk number")
  let cd_start_disk = read_u16_le(bytes, eocd_offset + 6, "EOCD cd start disk")
  let disk_entries = read_u16_le(bytes, eocd_offset + 8, "EOCD entries on disk")
  let total_entries = read_u16_le(bytes, eocd_offset + 10, "EOCD total entries")
  let cd_size = read_u32_le(bytes, eocd_offset + 12, "EOCD cd size")
  let cd_offset = read_u32_le(bytes, eocd_offset + 16, "EOCD cd offset")
  let comment_len = read_u16_le(bytes, eocd_offset + 20, "EOCD comment length")

  if disk_no != 0 || cd_start_disk != 0 {
    raise InvalidStructure("multi-disk zip is not supported")
  }
  if disk_entries != total_entries {
    raise InvalidStructure("inconsistent EOCD entry counts")
  }

  if total_entries == ZIP64_U16_SENTINEL ||
    is_zip64_u32_sentinel(cd_size) ||
    is_zip64_u32_sentinel(cd_offset) {
    raise InvalidStructure("ZIP64 is not supported in phase-1")
  }

  let eocd_end = eocd_offset + 22 + comment_len
  if eocd_end != bytes.length() {
    raise InvalidStructure("EOCD comment length mismatch")
  }

  let cd_end = cd_offset + cd_size
  if cd_offset < 0 || cd_size < 0 || cd_end > bytes.length() {
    raise InvalidStructure("central directory range out of bounds")
  }

  (cd_offset, cd_size, total_entries)
}

///|
fn parse_cd_entries(
  bytes : Bytes,
  cd_offset : Int,
  cd_size : Int,
  entry_count : Int,
) -> Array[ZipEntryMeta] raise ZipError {
  let entries : Array[ZipEntryMeta] = []
  let mut cursor = cd_offset
  let cd_end = cd_offset + cd_size
  let mut i = 0

  while i < entry_count {
    if cursor + 46 > cd_end {
      raise UnexpectedEOF("central directory entry header")
    }

    let sig = read_u32_le(bytes, cursor, "central directory signature")
    if sig != CD_FILE_HEADER_SIG {
      raise InvalidSignature("central directory entry", CD_FILE_HEADER_SIG, sig)
    }

    let flags = read_u16_le(bytes, cursor + 8, "central directory flags")
    validate_entry_supported_flags(flags, "(central directory entry)")

    let method_code = read_u16_le(
      bytes,
      cursor + 10,
      "central directory method",
    )
    let crc32 = read_u32_le(bytes, cursor + 16, "central directory crc32")
    let compressed_size = read_u32_le(
      bytes,
      cursor + 20,
      "central directory compressed size",
    )
    let uncompressed_size = read_u32_le(
      bytes,
      cursor + 24,
      "central directory uncompressed size",
    )
    let name_len = read_u16_le(
      bytes,
      cursor + 28,
      "central directory name length",
    )
    let extra_len = read_u16_le(
      bytes,
      cursor + 30,
      "central directory extra length",
    )
    let comment_len = read_u16_le(
      bytes,
      cursor + 32,
      "central directory comment length",
    )
    let local_header_offset = read_u32_le(
      bytes,
      cursor + 42,
      "central directory local header offset",
    )

    if is_zip64_u32_sentinel(compressed_size) ||
      is_zip64_u32_sentinel(uncompressed_size) ||
      is_zip64_u32_sentinel(local_header_offset) {
      raise InvalidStructure(
        "ZIP64 central directory entry is not supported in phase-1",
      )
    }

    let name_start = cursor + 46
    let name_end = name_start + name_len
    let entry_end = name_end + extra_len + comment_len
    if entry_end > cd_end {
      raise UnexpectedEOF("central directory entry payload")
    }

    let name_bytes = subview(bytes, name_start, name_end, "entry name")
    let name = bytes_to_string(name_bytes)
    if name == "" {
      raise InvalidStructure("empty entry name in central directory")
    }

    let compression_method = compression_method_from_code(method_code)

    entries.push({
      name,
      compression_method,
      compressed_size,
      uncompressed_size,
      local_header_offset,
      crc32,
      flags,
      is_directory: name.has_suffix("/") || name.has_suffix("\\"),
      is_encrypted: is_encrypted_flag(flags),
      has_data_descriptor: has_data_descriptor_flag(flags),
      uses_zip64: false,
    })

    cursor = entry_end
    i = i + 1
  }

  if cursor != cd_end {
    raise InvalidStructure("central directory trailing bytes mismatch")
  }

  entries
}

///|
fn compression_method_from_code(code : Int) -> CompressionMethod {
  if code == 0 {
    Store
  } else if code == 8 {
    DeflateRaw
  } else {
    Unsupported(code)
  }
}

///|
fn is_encrypted_flag(flags : Int) -> Bool {
  (flags & GP_FLAG_ENCRYPTED) != 0
}

///|
fn has_data_descriptor_flag(flags : Int) -> Bool {
  (flags & GP_FLAG_DATA_DESCRIPTOR) != 0
}

///|
fn is_zip64_u32_sentinel(value : Int) -> Bool {
  value == ZIP64_U32_SENTINEL || value == ZIP64_U32_SENTINEL_SIGNED
}

///|
fn build_zip_archive_report(archive : ZipArchive) -> ZipArchiveInspectReport {
  let infos0 : Array[ZipEntryInfo] = []
  let normalized_counts : Map[String, Int] = Map([])

  for meta in archive.entries {
    let info = build_zip_entry_info(meta)
    infos0.push(info)
    match info.normalized_path {
      Some(path) =>
        normalized_counts.set(
          path,
          normalized_counts.get(path).unwrap_or(0) + 1,
        )
      None => ()
    }
  }

  infos0.sort_by(compare_zip_entry_info)

  let issues = collect_zip_validation_issues_from_infos(
    infos0, normalized_counts,
  )
  let issue_counts : Map[String, Int] = Map([])
  let mut warning_count = 0
  let mut error_count = 0
  for issue in issues {
    issue_counts.set(
      issue.raw_name,
      issue_counts.get(issue.raw_name).unwrap_or(0) + 1,
    )
    match issue.severity {
      ZipValidationSeverity::Warning => warning_count += 1
      ZipValidationSeverity::Error => error_count += 1
    }
  }

  let infos : Array[ZipEntryInfo] = []
  let mut file_entry_count = 0
  let mut directory_entry_count = 0
  let mut unsafe_entry_count = 0
  let mut duplicate_normalized_entry_count = 0
  let mut encrypted_entry_count = 0
  let mut unsupported_compression_entry_count = 0
  let mut total_uncompressed_size = 0
  let mut total_compressed_size = 0

  for info in infos0 {
    let issue_count = issue_counts.get(info.raw_name).unwrap_or(0)
    let final_info = { ..info, issue_count, }
    if final_info.is_directory {
      directory_entry_count += 1
    } else {
      file_entry_count += 1
    }
    if final_info.is_unsafe_path {
      unsafe_entry_count += 1
    }
    match final_info.normalized_path {
      Some(path) =>
        if normalized_counts.get(path).unwrap_or(0) > 1 {
          duplicate_normalized_entry_count += 1
        }
      None => ()
    }
    if final_info.is_encrypted {
      encrypted_entry_count += 1
    }
    match final_info.compression_method {
      Unsupported(_) => unsupported_compression_entry_count += 1
      _ => ()
    }
    total_uncompressed_size += final_info.uncompressed_size
    total_compressed_size += final_info.compressed_size
    infos.push(final_info)
  }

  let inventory = {
    entries: infos,
    entry_count: infos.length(),
    file_entry_count,
    directory_entry_count,
    unsafe_entry_count,
    duplicate_normalized_entry_count,
    encrypted_entry_count,
    unsupported_compression_entry_count,
    total_uncompressed_size,
    total_compressed_size,
    has_unsafe_paths: unsafe_entry_count > 0,
    has_duplicate_normalized_paths: duplicate_normalized_entry_count > 0,
  }

  {
    entry_count: inventory.entry_count,
    file_entry_count: inventory.file_entry_count,
    directory_entry_count: inventory.directory_entry_count,
    unsafe_entry_count: inventory.unsafe_entry_count,
    duplicate_normalized_entry_count: inventory.duplicate_normalized_entry_count,
    encrypted_entry_count: inventory.encrypted_entry_count,
    unsupported_compression_entry_count: inventory.unsupported_compression_entry_count,
    total_uncompressed_size: inventory.total_uncompressed_size,
    total_compressed_size: inventory.total_compressed_size,
    issue_count: issues.length(),
    warning_count,
    error_count,
    inventory,
    issues,
  }
}

///|
fn build_zip_entry_info(meta : ZipEntryMeta) -> ZipEntryInfo {
  let normalized_path = if meta.is_directory {
    normalize_entry_path_impl(meta.name, true)
  } else {
    normalize_entry_path(meta.name)
  }
  let ext = if meta.is_directory {
    None
  } else {
    let candidate = match normalized_path {
      Some(path) => path
      None => display_entry_path(meta.name)
    }
    let ext0 = file_ext_lower(candidate)
    if ext0 == "" {
      None
    } else {
      Some(ext0)
    }
  }
  let is_hidden_metadata = match normalized_path {
    Some(path) => is_hidden_or_macos_metadata(path)
    None => false
  }
  let is_nested_archive_candidate = match ext {
    Some(v) => is_nested_archive_ext(v)
    None => false
  }
  let compressed_size = meta.compressed_size
  let is_encrypted = meta.is_encrypted
  let flags = if is_encrypted {
    meta.flags | GP_FLAG_ENCRYPTED
  } else {
    meta.flags
  }
  {
    raw_name: meta.name,
    normalized_path,
    is_directory: meta.is_directory,
    is_file: !meta.is_directory,
    extension: ext,
    compression_method: meta.compression_method,
    compressed_size,
    uncompressed_size: meta.uncompressed_size,
    local_header_offset: meta.local_header_offset,
    crc32: meta.crc32,
    flags,
    is_encrypted,
    has_data_descriptor: meta.has_data_descriptor,
    uses_zip64: meta.uses_zip64,
    is_unsafe_path: normalized_path == None,
    is_hidden_metadata,
    is_nested_archive_candidate,
    issue_count: 0,
  }
}

///|
fn collect_zip_validation_issues_from_infos(
  infos : Array[ZipEntryInfo],
  normalized_counts : Map[String, Int],
) -> Array[ZipValidationIssue] {
  let issues : Array[ZipValidationIssue] = []

  for info in infos {
    if info.is_unsafe_path {
      issues.push({
        kind: ZipValidationIssueKind::UnsafeEntryPath,
        severity: ZipValidationSeverity::Error,
        raw_name: info.raw_name,
        normalized_path: None,
        compression_method: None,
        message: "unsafe archive entry path: " +
        display_entry_path(info.raw_name),
      })
    }
    if info.is_directory {
      issues.push({
        kind: ZipValidationIssueKind::DirectoryEntry,
        severity: ZipValidationSeverity::Warning,
        raw_name: info.raw_name,
        normalized_path: info.normalized_path,
        compression_method: None,
        message: "directory entry",
      })
    } else if info.uncompressed_size == 0 {
      issues.push({
        kind: ZipValidationIssueKind::EmptyEntry,
        severity: ZipValidationSeverity::Warning,
        raw_name: info.raw_name,
        normalized_path: info.normalized_path,
        compression_method: None,
        message: "empty file entry",
      })
    }
    match info.compression_method {
      Unsupported(_) =>
        issues.push({
          kind: ZipValidationIssueKind::UnsupportedCompressionMethod,
          severity: ZipValidationSeverity::Error,
          raw_name: info.raw_name,
          normalized_path: info.normalized_path,
          compression_method: Some(info.compression_method),
          message: "unsupported compression method for entry: " +
          display_entry_path(info.raw_name),
        })
      _ => ()
    }
    if info.is_nested_archive_candidate {
      issues.push({
        kind: ZipValidationIssueKind::NestedArchiveCandidate,
        severity: ZipValidationSeverity::Warning,
        raw_name: info.raw_name,
        normalized_path: info.normalized_path,
        compression_method: None,
        message: "entry looks like a nested archive candidate: " +
        info.extension.unwrap_or(""),
      })
    }
    match info.normalized_path {
      Some(path) => {
        if path.length() > MAX_NORMALIZED_ENTRY_PATH_LENGTH {
          issues.push({
            kind: ZipValidationIssueKind::FilenameTooLong,
            severity: ZipValidationSeverity::Error,
            raw_name: info.raw_name,
            normalized_path: Some(path),
            compression_method: None,
            message: "normalized entry path too long: " + path,
          })
        }
        if zip_entry_directory_depth(path) > MAX_NORMALIZED_DIRECTORY_DEPTH {
          issues.push({
            kind: ZipValidationIssueKind::DirectoryDepthExceeded,
            severity: ZipValidationSeverity::Error,
            raw_name: info.raw_name,
            normalized_path: Some(path),
            compression_method: None,
            message: "normalized entry path too deep: " + path,
          })
        }
      }
      None => ()
    }
  }

  for info in infos {
    match info.normalized_path {
      Some(path) =>
        if normalized_counts.get(path).unwrap_or(0) > 1 {
          issues.push({
            kind: ZipValidationIssueKind::DuplicateNormalizedEntry,
            severity: ZipValidationSeverity::Error,
            raw_name: info.raw_name,
            normalized_path: Some(path),
            compression_method: None,
            message: "normalized entry path collision: " + path,
          })
        }
      None => ()
    }
  }

  issues
}

///|
fn classify_invalid_structure_detail(detail : String) -> ZipErrorInfo {
  if detail.contains("duplicate entry name in central directory: ") {
    let name = extract_after_prefix(
      detail, "duplicate entry name in central directory: ",
    )
    return {
      kind: ZipErrorKind::DuplicateEntryName,
      mapping: ZipErrorMappingKind::BestEffortMessage,
      entry_name: name,
      detail: "invalid zip structure: " + detail,
    }
  }

  if detail.contains("encrypted zip is not supported: ") {
    let name = extract_after_prefix(detail, "encrypted zip is not supported: ")
    return {
      kind: ZipErrorKind::EncryptedEntry,
      mapping: ZipErrorMappingKind::BestEffortMessage,
      entry_name: name,
      detail: "invalid zip structure: " + detail,
    }
  }

  if detail.contains("data descriptor is not supported in phase-1") ||
    detail.contains("multi-disk zip is not supported") ||
    detail.contains("ZIP64 is not supported in phase-1") ||
    detail.contains("ZIP64 central directory entry is not supported in phase-1") {
    return {
      kind: ZipErrorKind::UnsupportedFeature,
      mapping: ZipErrorMappingKind::BestEffortMessage,
      entry_name: extract_after_last_colon(detail),
      detail: "invalid zip structure: " + detail,
    }
  }

  {
    kind: ZipErrorKind::MalformedArchive,
    mapping: ZipErrorMappingKind::DirectVariant,
    entry_name: None,
    detail: "invalid zip structure: " + detail,
  }
}

///|
fn normalize_entry_path_impl(
  raw_path : String,
  allow_directory_tail : Bool,
) -> String? {
  if contains_nul_char(raw_path) {
    return None
  }

  let replaced0 = raw_path.replace(old="\\", new="/")
  let replaced = if allow_directory_tail {
    strip_trailing_slashes(replaced0)
  } else {
    replaced0
  }

  if replaced.trim() == "" || replaced.has_prefix("/") {
    return None
  }
  if replaced.length() >= 2 && replaced[1] == ':' {
    return None
  }

  let parts = replaced.split("/")
  let clean : Array[String] = []
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    clean.push(segment)
  }

  if clean.length() == 0 {
    None
  } else {
    Some(clean.join("/"))
  }
}

///|
fn compare_zip_entry_info(a : ZipEntryInfo, b : ZipEntryInfo) -> Int {
  let a_key = zip_entry_sort_key(a)
  let b_key = zip_entry_sort_key(b)
  let primary = a_key[:].lexical_compare(b_key[:])
  if primary != 0 {
    return primary
  }
  a.raw_name[:].lexical_compare(b.raw_name[:])
}

///|
fn zip_entry_sort_key(info : ZipEntryInfo) -> String {
  match info.normalized_path {
    Some(path) => path
    None => display_entry_path(info.raw_name)
  }
}

///|
fn strip_trailing_slashes(path : String) -> String {
  let mut end_ = path.length()
  while end_ > 0 {
    let ch = path[end_ - 1]
    if ch == '/' {
      end_ -= 1
    } else {
      break
    }
  }
  path[:end_].to_owned()
}

///|
fn contains_nul_char(path : String) -> Bool {
  for ch in path.to_array() {
    if ch.to_int() == 0 {
      return true
    }
  }
  false
}

///|
fn display_entry_path(raw_path : String) -> String {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" {
    "(empty path)"
  } else {
    p
  }
}

///|
fn is_hidden_or_macos_metadata(path : String) -> Bool {
  if path == "__MACOSX" || path.has_prefix("__MACOSX/") {
    return true
  }
  let base = basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}

///|
fn basename(path : String) -> String {
  let mut last = 0
  for i in 0..<path.length() {
    if path[i] == '/' {
      last = i + 1
    }
  }
  path[last:].to_owned()
}

///|
fn is_nested_archive_ext(ext : String) -> Bool {
  match ext {
    "zip" | "jar" | "epub" => true
    _ => false
  }
}

///|
fn file_ext_lower(path : String) -> String {
  let n = path.length()
  if n == 0 {
    return ""
  }
  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return ""
      }
      return path[i + 1:].to_owned().to_lower()
    }
    i -= 1
  }
  ""
}

///|
fn zip_entry_directory_depth(path : String) -> Int {
  let trimmed = path.trim()
  if trimmed == "" {
    return 0
  }
  trimmed.split("/").length()
}

///|
fn extract_after_prefix(src : String, prefix : String) -> String? {
  if !src.has_prefix(prefix) {
    return None
  }
  let out = src[prefix.length():].trim().to_owned()
  if out == "" {
    None
  } else {
    Some(out)
  }
}

///|
fn extract_after_last_colon(src : String) -> String? {
  let mut last = -1
  for i in 0..<src.length() {
    if src[i] == ':' {
      last = i
    }
  }
  if last < 0 || last + 1 >= src.length() {
    return None
  }
  let out = src[last + 1:].trim().to_owned()
  if out == "" {
    None
  } else {
    Some(out)
  }
}

///|
fn extract_backtick_wrapped_name(src : String) -> String? {
  let mut first = -1
  let mut second = -1
  for i in 0..<src.length() {
    if src[i] == '`' {
      if first < 0 {
        first = i
      } else {
        second = i
        break
      }
    }
  }
  if first < 0 || second <= first + 1 {
    return None
  }
  Some(src[first + 1:second].to_owned())
}

///|
fn read_u16_le(
  bytes : Bytes,
  offset : Int,
  context : String,
) -> Int raise ZipError {
  let tail = offset + 2
  if offset < 0 || tail > bytes.length() {
    raise UnexpectedEOF(context)
  }

  byte_to_int(bytes[offset]) | (byte_to_int(bytes[offset + 1]) << 8)
}

///|
fn read_u32_le(
  bytes : Bytes,
  offset : Int,
  context : String,
) -> Int raise ZipError {
  let tail = offset + 4
  if offset < 0 || tail > bytes.length() {
    raise UnexpectedEOF(context)
  }

  byte_to_int(bytes[offset]) |
  (byte_to_int(bytes[offset + 1]) << 8) |
  (byte_to_int(bytes[offset + 2]) << 16) |
  (byte_to_int(bytes[offset + 3]) << 24)
}

///|
fn subview(
  bytes : Bytes,
  start : Int,
  end_ : Int,
  context : String,
) -> Bytes raise ZipError {
  if start < 0 || end_ < start || end_ > bytes.length() {
    raise UnexpectedEOF(context)
  }
  bytes[start:end_].to_owned()
}

///|
fn bytes_to_string(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for b in bytes {
    chars.push(Int::unsafe_to_char(byte_to_int(b)))
  }
  String::from_array(chars)
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
