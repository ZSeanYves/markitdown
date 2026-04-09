///|
pub(all) suberror ZipError {
  UnexpectedEOF(context : String)
  InvalidSignature(context : String, expected : Int, actual : Int)
  InvalidStructure(String)
  UnsupportedCompressionMethod(Int)
  EntryNotFound(String)
  DecodeFailed(String)
}

///|
pub struct ZipEntryMeta {
  name : String
  compression_method : @common.CompressionMethod
  compressed_size : Int
  uncompressed_size : Int
  local_header_offset : Int
  crc32 : Int
  flags : Int
}

///|
pub struct ZipArchive {
  bytes : Bytes
  entries : Array[ZipEntryMeta]
  entry_index : Map[String, Int]
}
