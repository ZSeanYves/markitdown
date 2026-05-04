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
pub impl Show for ZipError with to_string(self : ZipError) -> String {
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
pub impl Show for ZipError with output(self : ZipError, logger : &Logger) -> Unit {
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
pub struct ZipArchive {
  bytes : Bytes
  entries : Array[ZipEntryMeta]
  entry_index : Map[String, Int]
}
