///|
pub(all) suberror ZipError {
  UnexpectedEOF(String)
  InvalidSignature(String, Int, Int)
  InvalidStructure(String)
  UnsupportedCompressionMethod(Int)
  EntryNotFound(String)
  DecodeFailed(String)
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
  compressed_size : Int
  uncompressed_size : Int
  local_header_offset : Int
  crc32 : Int
  flags : Int
  is_directory : Bool
  is_encrypted : Bool
  has_data_descriptor : Bool
  uses_zip64 : Bool
}

///|
pub struct ZipEntryDataSlice {
  entry : ZipEntryMeta
  data_start : Int
  data_end : Int
}

///|
pub struct ZipArchive {
  bytes : Bytes
  entries : Array[ZipEntryMeta]
  entry_index : Map[String, Int]
  priv inspect_cache : Ref[ZipArchiveInspectReport?]
  priv read_entry_cache : Map[String, Bytes]
  priv inspect_hit_count : Ref[Int]
  priv inspect_miss_count : Ref[Int]
  priv read_hit_count : Ref[Int]
  priv read_miss_count : Ref[Int]
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
  entry_count : Int
  file_entry_count : Int
  directory_entry_count : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
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
  compressed_size : Int
  uncompressed_size : Int
  local_header_offset : Int
  crc32 : Int
  flags : Int
  is_encrypted : Bool
  has_data_descriptor : Bool
  uses_zip64 : Bool
  is_unsafe_path : Bool
  is_hidden_metadata : Bool
  is_nested_archive_candidate : Bool
  issue_count : Int
}

///|
pub struct ZipArchiveInventory {
  entries : Array[ZipEntryInfo]
  entry_count : Int
  file_entry_count : Int
  directory_entry_count : Int
  unsafe_entry_count : Int
  duplicate_normalized_entry_count : Int
  encrypted_entry_count : Int
  unsupported_compression_entry_count : Int
  total_uncompressed_size : Int
  total_compressed_size : Int
  has_unsafe_paths : Bool
  has_duplicate_normalized_paths : Bool
}

///|
pub struct ZipArchiveInspectReport {
  entry_count : Int
  file_entry_count : Int
  directory_entry_count : Int
  unsafe_entry_count : Int
  duplicate_normalized_entry_count : Int
  encrypted_entry_count : Int
  unsupported_compression_entry_count : Int
  total_uncompressed_size : Int
  total_compressed_size : Int
  issue_count : Int
  warning_count : Int
  error_count : Int
  inventory : ZipArchiveInventory
  issues : Array[ZipValidationIssue]
}
