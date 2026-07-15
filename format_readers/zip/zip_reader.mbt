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
fn open_zip_impl(bytes : Bytes) -> ZipArchive raise ZipError {
  let eocd_offset = find_eocd(bytes)
  let (cd_offset, cd_size, entry_count) = parse_eocd(bytes, eocd_offset)
  let entries = parse_cd_entries(bytes, cd_offset, cd_size, entry_count)
  build_zip_archive(
    bytes,
    bytes.length(),
    fn(offset, length) {
      if offset < 0 || length < 0 || offset > bytes.length() {
        return Err("zip source read is outside the payload")
      }
      Ok(bytes[offset:(offset + length).min(bytes.length())].to_owned())
    },
    entries,
  )
}

///|
fn build_zip_archive(
  bytes : Bytes,
  source_size : Int,
  source_read_at : (Int, Int) -> Result[Bytes, String],
  entries : Array[ZipEntryMeta],
) -> ZipArchive raise ZipError {
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

  {
    bytes,
    entries,
    entry_index: index,
    source_size,
    source_read_at,
    inspect_cache: Ref(None),
    read_entry_cache: Map([]),
    inspect_hit_count: { val: 0 },
    inspect_miss_count: { val: 0 },
    read_hit_count: { val: 0 },
    read_miss_count: { val: 0 },
  }
}

///|
pub fn open_zip(bytes : Bytes) -> ZipArchive raise ZipError {
  open_zip_impl(bytes)
}

///|
/// Open a seekable ZIP source by reading only its EOCD tail and central
/// directory. The callback must return at most `length` bytes from `offset`.
pub fn open_zip_reader(
  size : Int,
  read_at : (Int, Int) -> Result[Bytes, String],
) -> ZipArchive raise ZipError {
  if size < 22 {
    raise UnexpectedEOF("zip smaller than minimum EOCD size")
  }
  let tail_length = size.min(65535 + 22)
  let tail_start = size - tail_length
  let tail = read_zip_source_exact(
    read_at, tail_start, tail_length, "EOCD tail",
  )
  let eocd_offset = find_eocd(tail)
  let (cd_offset, cd_size, entry_count) = parse_eocd_window(
    tail, eocd_offset, size, tail_start,
  )
  let central = read_zip_source_exact(
    read_at, cd_offset, cd_size, "central directory",
  )
  let entries = parse_cd_entries(central, 0, cd_size, entry_count)
  build_zip_archive(b"", size, read_at, entries)
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
  match archive.inspect_cache.val {
    Some(report) => {
      archive.inspect_hit_count.val += 1
      report
    }
    None => {
      let report = build_zip_archive_report(archive)
      archive.inspect_miss_count.val += 1
      archive.inspect_cache.val = Some(report)
      report
    }
  }
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
  match archive.read_entry_cache.get(path) {
    Some(cached) => {
      archive.read_hit_count.val += 1
      return cached
    }
    None => ()
  }
  let slice = read_entry_data_slice(archive, path)
  let entry = slice.entry
  let compressed = read_zip_archive_range(
    archive,
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
  archive.read_miss_count.val += 1
  archive.read_entry_cache.set(path, decoded)
  decoded
}

///|
/// Read and validate an entry without retaining the decoded payload in the
/// archive cache. Use this for one-shot large parts whose callers keep a
/// parsed representation instead.
pub fn read_entry_transient(
  archive : ZipArchive,
  path : String,
  max_output_size? : Int = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  let slice = read_entry_data_slice(archive, path)
  let entry = slice.entry
  let compressed = read_zip_archive_range(
    archive,
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
  let local_header = read_zip_archive_range(
    archive,
    local_offset,
    local_offset + 30,
    "local file header",
  )
  let sig = read_u32_le(local_header, 0, "local file header signature")
  if sig != LOCAL_FILE_HEADER_SIG {
    raise InvalidSignature("local file header", LOCAL_FILE_HEADER_SIG, sig)
  }

  let flags = read_u16_le(local_header, 6, "local file header flags")
  let method_code = read_u16_le(local_header, 8, "local file header method")
  let local_crc32 = read_u32_le(local_header, 14, "local file header crc32")
  let local_compressed_size = read_u32_le(
    local_header, 18, "local file header compressed size",
  )
  let local_uncompressed_size = read_u32_le(
    local_header, 22, "local file header uncompressed size",
  )
  let name_len = read_u16_le(local_header, 26, "local file header name length")
  let extra_len = read_u16_le(
    local_header, 28, "local file header extra length",
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
  let local_name_bytes = read_zip_archive_range(
    archive, local_name_start, local_name_end, "local file header name",
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
  if data_start < 0 || data_end < data_start || data_end > archive.source_size {
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
  visit_inflated_entry_chunks_from_reader(
    archive.source_read_at,
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
  visit_inflated_entry_chunks_from_reader(
    fn(offset, length) {
      if offset < 0 || length < 0 || offset > archive_bytes.length() {
        return Err("zip source read is outside the payload")
      }
      Ok(
        archive_bytes[offset:(offset + length).min(archive_bytes.length())].to_owned(),
      )
    },
    slice,
    chunk_size~,
    on_chunk,
  )
}

///|
fn visit_inflated_entry_chunks_from_reader(
  read_at : (Int, Int) -> Result[Bytes, String],
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
        let chunk = match read_zip_source_fully(read_at, pos, end_ - pos) {
          Ok(value) => value
          Err(err) => return Err(err)
        }
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
          let compressed = match
            read_zip_source_fully(read_at, pos, feed_end - pos) {
            Ok(value) => value
            Err(err) => return Err(err)
          }
          inflater.src(compressed[:])
          pos = feed_end
        }
        let mut needs_more_input = false
        while !done && !needs_more_input {
          match inflater.decode() {
            Await =>
              if pos >= slice.data_end {
                return Err(
                  "zip decode failed for `" + entry.name + "`: unexpected EOF",
                )
              } else {
                needs_more_input = true
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
            }
            End => done = true
            Error(err) =>
              return Err(
                "decode failed for `" + entry.name + "`: " + err.to_string(),
              )
          }
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
