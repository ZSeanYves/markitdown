///|
pub(all) suberror ZipError {
  UnexpectedEOF(String)
  InvalidSignature(String, Int32, Int32)
  InvalidStructure(String)
  UnsupportedCompressionMethod(Int32)
  EntryNotFound(String)
  DecodeFailed(String)
  ChecksumMismatch(String, Int32, Int32)
  BudgetExceeded(@budget.BudgetError)
}

///|
pub impl Show for ZipError with fn to_string(self : ZipError) -> String {
  match self {
    UnexpectedEOF(context) => "unexpected EOF: " + context
    InvalidSignature(context, expected, actual) =>
      "invalid signature at " +
      context +
      ": expected=" +
      expected.to_string() +
      ", actual=" +
      actual.to_string()
    InvalidStructure(msg) => "invalid zip structure: " + msg
    UnsupportedCompressionMethod(code) =>
      "unsupported compression method: " + code.to_string()
    EntryNotFound(path) => "entry not found: " + path
    DecodeFailed(msg) => "decode failed: " + msg
    ChecksumMismatch(path, expected, actual) =>
      "crc32 mismatch for entry: " +
      path +
      " expected=" +
      expected.to_string() +
      " actual=" +
      actual.to_string()
    BudgetExceeded(error) => @budget.budget_error_message(error)
  }
}

///|
pub impl Show for ZipError with fn output(self : ZipError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct ZipEntryMeta {
  name : String
  compression_method : CompressionMethod
  compressed_size : Int32
  uncompressed_size : Int32
  local_header_offset : Int32
  crc32 : Int32
  flags : Int32
  is_directory : Bool
  is_encrypted : Bool
  has_data_descriptor : Bool
  uses_zip64 : Bool
}

///|
pub struct ZipEntryDataSlice {
  entry : ZipEntryMeta
  data_start : Int32
  data_end : Int32
}

///|
pub struct ZipArchive {
  bytes : Bytes
  entries : Array[ZipEntryMeta]
  entry_index : Map[String, Int32]
  priv source_size : Int32
  priv source_read_at : async (Int32, Int32) -> Result[Bytes, String]
  priv inspect_cache : Ref[ZipArchiveInspectReport?]
  priv read_entry_cache : Map[String, Bytes]
  priv inspect_hit_count : Ref[Int32]
  priv inspect_miss_count : Ref[Int32]
  priv read_hit_count : Ref[Int32]
  priv read_miss_count : Ref[Int32]
  priv hard_failure : Ref[String?]
  priv hard_failure_reporter : Ref[(String) -> Unit]
  priv budget_context : @budget.BudgetContext?
}

///|
pub(all) enum ZipErrorMappingKind {
  DirectVariant
  BestEffortMessage
} derive(Eq)

///|
pub(all) enum ZipErrorKind {
  MissingEntry
  UnsupportedCompressionMethod
  EncryptedEntry
  DuplicateEntryName
  UnsupportedFeature
  MalformedArchive
  ReadEntryFailed
  Unknown
} derive(Eq)

///|
pub struct ZipErrorInfo {
  kind : ZipErrorKind
  mapping : ZipErrorMappingKind
  entry_name : String?
  detail : String
}

///|
pub(all) enum ZipValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum ZipValidationIssueKind {
  UnsafeEntryPath
  DuplicateNormalizedEntry
  DirectoryEntry
  EmptyEntry
  UnsupportedCompressionMethod
  NestedArchiveCandidate
  FilenameTooLong
  DirectoryDepthExceeded
} derive(Eq)

///|
pub struct ZipValidationIssue {
  kind : ZipValidationIssueKind
  severity : ZipValidationSeverity
  raw_name : String
  normalized_path : String?
  compression_method : CompressionMethod?
  message : String
}

///|
pub struct ZipValidationReport {
  entry_count : Int32
  file_entry_count : Int32
  directory_entry_count : Int32
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  issues : Array[ZipValidationIssue]
}

///|
pub struct ZipEntryInfo {
  raw_name : String
  normalized_path : String?
  is_directory : Bool
  is_file : Bool
  extension : String?
  compression_method : CompressionMethod
  compressed_size : Int32
  uncompressed_size : Int32
  local_header_offset : Int32
  crc32 : Int32
  flags : Int32
  is_encrypted : Bool
  has_data_descriptor : Bool
  uses_zip64 : Bool
  is_unsafe_path : Bool
  is_hidden_metadata : Bool
  is_nested_archive_candidate : Bool
  issue_count : Int32
}

///|
pub struct ZipArchiveInventory {
  entries : Array[ZipEntryInfo]
  entry_count : Int32
  file_entry_count : Int32
  directory_entry_count : Int32
  unsafe_entry_count : Int32
  duplicate_normalized_entry_count : Int32
  encrypted_entry_count : Int32
  unsupported_compression_entry_count : Int32
  total_uncompressed_size : Int32
  total_compressed_size : Int32
  has_unsafe_paths : Bool
  has_duplicate_normalized_paths : Bool
}

///|
pub struct ZipArchiveInspectReport {
  entry_count : Int32
  file_entry_count : Int32
  directory_entry_count : Int32
  unsafe_entry_count : Int32
  duplicate_normalized_entry_count : Int32
  encrypted_entry_count : Int32
  unsupported_compression_entry_count : Int32
  total_uncompressed_size : Int32
  total_compressed_size : Int32
  issue_count : Int32
  warning_count : Int32
  error_count : Int32
  inventory : ZipArchiveInventory
  issues : Array[ZipValidationIssue]
}
