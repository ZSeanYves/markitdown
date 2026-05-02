///|
pub(all) suberror EpubError {
  ZipError(String)
  MissingPart(String)
  InvalidXml(String)
  InvalidPath(String)
  InvalidPackage(String)
  UnsupportedFeature(String)
}

///|
pub impl Show for EpubError with to_string(self : EpubError) -> String {
  match self {
    ZipError(msg) => "zip error: " + msg
    MissingPart(path) => "missing EPUB part: " + path
    InvalidXml(msg) => "invalid EPUB xml: " + msg
    InvalidPath(path) => "invalid EPUB path: " + path
    InvalidPackage(msg) => "invalid EPUB package: " + msg
    UnsupportedFeature(msg) => "unsupported EPUB feature: " + msg
  }
}

///|
pub impl Show for EpubError with output(self : EpubError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct EpubArchiveEntry {
  raw_path : String
  path : String
  uncompressed_size : Int
}

///|
pub struct EpubMetadata {
  title : String?
  creator : String?
  date : String?
  modified : String?
}

///|
pub struct EpubManifestItem {
  id : String
  href : String
  media_type : String?
  resolved_path : String
}

///|
pub struct EpubSpineItem {
  idref : String
  linear : Bool
  manifest_item : EpubManifestItem
  resolved_path : String
}

///|
pub struct EpubPackage {
  archive : @zip.ZipArchive
  entries : Array[EpubArchiveEntry]
  entry_index : Map[String, String]
  source_name : String
  mimetype : String?
  rootfile_path : String
  opf_dir : String
  metadata : EpubMetadata
  manifest : Array[EpubManifestItem]
  spine : Array[EpubSpineItem]
}
