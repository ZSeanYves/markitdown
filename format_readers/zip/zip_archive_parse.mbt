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
  parse_eocd_window(bytes, eocd_offset, bytes.length(), 0)
}

///|
fn parse_eocd_window(
  bytes : Bytes,
  eocd_offset : Int,
  archive_size : Int,
  window_start : Int,
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

  let eocd_end = window_start + eocd_offset + 22 + comment_len
  if eocd_end != archive_size {
    raise InvalidStructure("EOCD comment length mismatch")
  }

  let cd_end = cd_offset + cd_size
  if cd_offset < 0 || cd_size < 0 || cd_end > archive_size {
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
      Warning => warning_count += 1
      Error => error_count += 1
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
        kind: UnsafeEntryPath,
        severity: Error,
        raw_name: info.raw_name,
        normalized_path: None,
        compression_method: None,
        message: "unsafe archive entry path: " +
        display_entry_path(info.raw_name),
      })
    }
    if info.is_directory {
      issues.push({
        kind: DirectoryEntry,
        severity: Warning,
        raw_name: info.raw_name,
        normalized_path: info.normalized_path,
        compression_method: None,
        message: "directory entry",
      })
    } else if info.uncompressed_size == 0 {
      issues.push({
        kind: EmptyEntry,
        severity: Warning,
        raw_name: info.raw_name,
        normalized_path: info.normalized_path,
        compression_method: None,
        message: "empty file entry",
      })
    }
    match info.compression_method {
      Unsupported(_) =>
        issues.push({
          kind: UnsupportedCompressionMethod,
          severity: Error,
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
        kind: NestedArchiveCandidate,
        severity: Warning,
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
            kind: FilenameTooLong,
            severity: Error,
            raw_name: info.raw_name,
            normalized_path: Some(path),
            compression_method: None,
            message: "normalized entry path too long: " + path,
          })
        }
        if zip_entry_directory_depth(path) > MAX_NORMALIZED_DIRECTORY_DEPTH {
          issues.push({
            kind: DirectoryDepthExceeded,
            severity: Error,
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
            kind: DuplicateNormalizedEntry,
            severity: Error,
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
      kind: DuplicateEntryName,
      mapping: BestEffortMessage,
      entry_name: name,
      detail: "invalid zip structure: " + detail,
    }
  }

  if detail.contains("encrypted zip is not supported: ") {
    let name = extract_after_prefix(detail, "encrypted zip is not supported: ")
    return {
      kind: EncryptedEntry,
      mapping: BestEffortMessage,
      entry_name: name,
      detail: "invalid zip structure: " + detail,
    }
  }

  if detail.contains("data descriptor is not supported in phase-1") ||
    detail.contains("multi-disk zip is not supported") ||
    detail.contains("ZIP64 is not supported in phase-1") ||
    detail.contains("ZIP64 central directory entry is not supported in phase-1") {
    return {
      kind: UnsupportedFeature,
      mapping: BestEffortMessage,
      entry_name: extract_after_last_colon(detail),
      detail: "invalid zip structure: " + detail,
    }
  }

  {
    kind: MalformedArchive,
    mapping: DirectVariant,
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
fn read_zip_source_exact(
  read_at : (Int, Int) -> Result[Bytes, String],
  offset : Int,
  length : Int,
  context : String,
) -> Bytes raise ZipError {
  if offset < 0 || length < 0 {
    raise UnexpectedEOF(context)
  }
  let bytes = match read_zip_source_fully(read_at, offset, length) {
    Ok(value) => value
    Err(message) => raise DecodeFailed(context + " read failed: " + message)
  }
  bytes
}

///|
fn read_zip_source_fully(
  read_at : (Int, Int) -> Result[Bytes, String],
  offset : Int,
  length : Int,
) -> Result[Bytes, String] {
  if offset < 0 || length < 0 {
    return Err("zip source range must be non-negative")
  }
  if length == 0 {
    return Ok(b"")
  }
  let output = Buffer()
  let mut consumed = 0
  while consumed < length {
    let remaining = length - consumed
    let chunk = match read_at(offset + consumed, remaining) {
      Ok(value) => value
      Err(message) => return Err("zip source read failed: " + message)
    }
    if chunk.length() == 0 {
      return Err("unexpected EOF while reading zip source")
    }
    if chunk.length() > remaining {
      return Err("zip source reader returned more bytes than requested")
    }
    output.write_bytes(chunk)
    consumed += chunk.length()
  }
  Ok(output.to_bytes())
}

///|
fn read_zip_archive_range(
  archive : ZipArchive,
  start : Int,
  end_ : Int,
  context : String,
) -> Bytes raise ZipError {
  if start < 0 || end_ < start || end_ > archive.source_size {
    raise UnexpectedEOF(context)
  }
  read_zip_source_exact(archive.source_read_at, start, end_ - start, context)
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
