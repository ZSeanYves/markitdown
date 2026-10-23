///|
/// ZIP low-level reader used as raw parsing infrastructure for OOXML families.
///
/// This layer only guarantees container integrity + entry byte access.
/// It intentionally does NOT perform document semantics recovery.
const EOCD_SIG : Int32 = 0x06054b50

///|
const CD_FILE_HEADER_SIG : Int32 = 0x02014b50

///|
const LOCAL_FILE_HEADER_SIG : Int32 = 0x04034b50

///|
const ZIP64_U16_SENTINEL : Int32 = 0xFFFF

///|
const ZIP64_U32_SENTINEL : Int32 = 0xFFFFFFFF

///|
const ZIP64_U32_SENTINEL_SIGNED : Int32 = -1

///|
const GP_FLAG_ENCRYPTED : Int32 = 0x0001

///|
const GP_FLAG_DATA_DESCRIPTOR : Int32 = 0x0008

///|
const MAX_NORMALIZED_ENTRY_PATH_LENGTH : Int32 = 240

///|
const MAX_NORMALIZED_DIRECTORY_DEPTH : Int32 = 16

///|
fn open_zip_impl(
  bytes : Bytes,
  budget_context : @budget.BudgetContext?,
) -> ZipArchive raise ZipError {
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
    budget_context,
  )
}

///|
fn build_zip_archive(
  bytes : Bytes,
  source_size : Int32,
  source_read_at : async (Int32, Int32) -> Result[Bytes, String],
  entries : Array[ZipEntryMeta],
  budget_context : @budget.BudgetContext?,
) -> ZipArchive raise ZipError {
  let index : Map[String, Int32] = Map([])

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
    inspect_hit_count: { val: 0, },
    inspect_miss_count: { val: 0, },
    read_hit_count: { val: 0, },
    read_miss_count: { val: 0, },
    hard_failure: Ref(None),
    hard_failure_reporter: Ref(fn(_) { () }),
    budget_context,
  }
}

///|
/// Attach the owning conversion's first-error recorder. Standalone archive
/// users can also inspect the sticky integrity failure without an Input
/// dependency in this low-level package.
pub fn set_hard_failure_reporter(
  archive : ZipArchive,
  report : (String) -> Unit,
) -> Unit {
  archive.hard_failure_reporter.val = report
  if archive.hard_failure.val is Some(message) {
    report(message)
  }
}

///|
pub fn record_hard_failure(archive : ZipArchive, message : String) -> Unit {
  if archive.hard_failure.val is None {
    archive.hard_failure.val = Some(message)
    (archive.hard_failure_reporter.val)(message)
  }
}

///|
pub fn archive_hard_failure(archive : ZipArchive) -> String? {
  archive.hard_failure.val
}

///|
/// Borrow the existing conversion account; consumers must not replace it or
/// create a nested account. Escaping payload leases belong to its scope owner.
pub fn archive_budget_context(archive : ZipArchive) -> @budget.BudgetContext? {
  archive.budget_context
}

///|
pub fn open_zip(
  bytes : Bytes,
  budget_context? : @budget.BudgetContext,
) -> ZipArchive raise ZipError {
  open_zip_impl(bytes, budget_context)
}

///|
/// Open a seekable ZIP source by reading only its EOCD tail and central
/// directory. The callback must return at most `length` bytes from `offset`.
pub async fn open_zip_reader(
  size : Int32,
  read_at : async (Int32, Int32) -> Result[Bytes, String],
  budget_context? : @budget.BudgetContext,
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
  build_zip_archive(b"", size, read_at, entries, budget_context)
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
pub async fn read_entry(
  archive : ZipArchive,
  path : String,
  max_output_size~ : Int32 = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  read_entry_impl(archive, path, max_output_size~) catch {
    EntryNotFound(path) => raise EntryNotFound(path)
    error => {
      record_hard_failure(archive, error.to_string())
      raise error
    }
  }
}

///|
async fn read_entry_impl(
  archive : ZipArchive,
  path : String,
  max_output_size~ : Int32 = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  zip_check_archive_ready(archive)
  match archive.read_entry_cache.get(path) {
    Some(cached) => {
      if cached.length() > max_output_size {
        raise InvalidStructure(
          "decoded entry exceeds max_output_size: max=" +
          max_output_size.to_string() +
          ", actual=" +
          cached.length().to_string(),
        )
      }
      archive.read_hit_count.val += 1
      return cached
    }
    None => ()
  }
  let slice = read_entry_data_slice(archive, path)
  let decoded = collect_zip_entry_chunks(
    archive,
    slice,
    max_output_size,
    @budget.CacheBytes,
  )
  archive.read_miss_count.val += 1
  archive.read_entry_cache.set(path, decoded)
  decoded
}

///|
/// Read and validate an entry without retaining the decoded payload in the
/// archive cache. Use this for one-shot large parts whose callers keep a
/// parsed representation instead.
pub async fn read_entry_transient(
  archive : ZipArchive,
  path : String,
  max_output_size~ : Int32 = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  read_entry_transient_impl(archive, path, max_output_size~) catch {
    EntryNotFound(path) => raise EntryNotFound(path)
    error => {
      record_hard_failure(archive, error.to_string())
      raise error
    }
  }
}

///|
async fn read_entry_transient_impl(
  archive : ZipArchive,
  path : String,
  max_output_size~ : Int32 = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  zip_check_archive_ready(archive)
  let slice = read_entry_data_slice(archive, path)
  collect_zip_entry_chunks(
    archive,
    slice,
    max_output_size,
    @budget.WorkingBytes,
  )
}

///|
pub async fn read_entry_data_slice(
  archive : ZipArchive,
  path : String,
) -> ZipEntryDataSlice raise ZipError {
  if archive.hard_failure.val is Some(message) {
    raise DecodeFailed(message)
  }
  let entry = match archive.entry_index.get(path) {
    Some(idx) => archive.entries[idx]
    None => raise EntryNotFound(path)
  }
  read_entry_data_slice_from_meta(archive, entry)
}

///|
async fn read_entry_data_slice_from_meta(
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
      let error = ChecksumMismatch(entry.name, entry.crc32, local_crc32)
      record_hard_failure(archive, error.to_string())
      raise error
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
  { entry, data_start, data_end, }
}

///|
/// An omitted output cap preserves the visitor's declared-size/CRC contract.
/// Explicit caps and the shared cumulative inflate budget remain enforced.
pub async fn visit_inflated_entry_chunks(
  archive : ZipArchive,
  path : String,
  chunk_size~ : Int32 = 64 * 1024,
  max_output_size? : Int32,
  on_chunk : async (Bytes) -> Result[Unit, String],
) -> Result[Unit, String] noraise {
  zip_check_archive_ready(archive) catch {
    error => {
      record_hard_failure(archive, error.to_string())
      return Err(error.to_string())
    }
  }
  let slice = read_entry_data_slice(archive, path) catch {
    EntryNotFound(path) => return Err(EntryNotFound(path).to_string())
    err => {
      record_hard_failure(archive, err.to_string())
      return Err(err.to_string())
    }
  }
  match
    emit_zip_entry_chunks(
      archive.source_read_at,
      slice,
      chunk_size,
      max_output_size.unwrap_or(slice.entry.uncompressed_size),
      archive.budget_context,
      true,
      on_chunk,
    ) {
    Ok(_) => Ok(())
    Err(EntryFailure(error)) => {
      record_hard_failure(archive, error.to_string())
      Err(error.to_string())
    }
    Err(ConsumerFailure(message)) => Err(message)
  }
}

///|
/// Uses the same omitted-cap semantics as the archive-backed visitor.
pub async fn visit_inflated_entry_chunks_from_slice(
  archive_bytes : Bytes,
  slice : ZipEntryDataSlice,
  chunk_size~ : Int32 = 64 * 1024,
  max_output_size? : Int32,
  budget_context? : @budget.BudgetContext,
  on_chunk : async (Bytes) -> Result[Unit, String],
) -> Result[Unit, String] noraise {
  match
    emit_zip_entry_chunks(
      fn(offset, length) {
        if offset < 0 || length < 0 || offset > archive_bytes.length() {
          return Err("zip source read is outside the payload")
        }
        Ok(
          archive_bytes[offset:(offset + length).min(archive_bytes.length())].to_owned(),
        )
      },
      slice,
      chunk_size,
      max_output_size.unwrap_or(slice.entry.uncompressed_size),
      budget_context,
      true,
      on_chunk,
    ) {
    Ok(_) => Ok(())
    Err(EntryFailure(error)) => Err(error.to_string())
    Err(ConsumerFailure(message)) => Err(message)
  }
}

///|
pub fn classify_zip_error(err : ZipError) -> ZipErrorInfo {
  match err {
    EntryNotFound(path) =>
      {
        kind: MissingEntry,
        mapping: DirectVariant,
        entry_name: Some(path),
        detail: err.to_string(),
      }
    UnsupportedCompressionMethod(_) =>
      {
        kind: UnsupportedCompressionMethod,
        mapping: DirectVariant,
        entry_name: None,
        detail: err.to_string(),
      }
    DecodeFailed(detail) =>
      {
        kind: ReadEntryFailed,
        mapping: DirectVariant,
        entry_name: extract_backtick_wrapped_name(detail),
        detail: err.to_string(),
      }
    ChecksumMismatch(path, _, _) =>
      {
        kind: ReadEntryFailed,
        mapping: DirectVariant,
        entry_name: Some(path),
        detail: err.to_string(),
      }
    BudgetExceeded(_) =>
      {
        kind: ReadEntryFailed,
        mapping: DirectVariant,
        entry_name: None,
        detail: err.to_string(),
      }
    UnexpectedEOF(_) | InvalidSignature(_, _, _) =>
      {
        kind: MalformedArchive,
        mapping: DirectVariant,
        entry_name: None,
        detail: err.to_string(),
      }
    InvalidStructure(detail) => classify_invalid_structure_detail(detail)
  }
}

///|
fn validate_entry_supported_flags(
  flags : Int32,
  entry_name : String,
) -> Unit raise ZipError {
  if (flags & GP_FLAG_ENCRYPTED) != 0 {
    raise InvalidStructure("encrypted zip is not supported: " + entry_name)
  }
}
