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
pub(all) enum EpubErrorKind {
  ZipFailure
  MissingContainer
  MissingRootfile
  MissingPart
  DuplicateManifestId
  InvalidXml
  InvalidPath
  InvalidPackage
  UnsupportedFeature
  UnsafeHref
  RemoteResourceBlocked
} derive(Eq)

///|
pub(all) enum EpubCoverCandidateSource {
  ManifestProperty
  MetadataCover
  GuideReference
} derive(Eq)

///|
pub(all) enum EpubValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
pub(all) enum EpubValidationIssueKind {
  MissingManifestItem
  MissingSpineTarget
  UnsupportedSpineItem
  DuplicateSpineIdref
  MissingNavigationDocument
  MultipleRootfiles
} derive(Eq)

///|
pub impl Show for EpubError with fn to_string(self : EpubError) -> String {
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
pub impl Show for EpubError with fn output(self : EpubError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct EpubErrorInfo {
  kind : EpubErrorKind
  detail : String
  part_name : String?
  rootfile_path : String?
  manifest_id : String?
  source_part : String?
  path : String?
  href : String?
}

///|
pub struct EpubArchiveEntry {
  raw_path : String
  path : String
  uncompressed_size : Int
}

///|
pub struct EpubRootfileInfo {
  full_path : String
  media_type : String?
  normalized_path : String?
  exists : Bool
  usable : Bool
  is_primary : Bool
}

///|
pub struct EpubMetadata {
  title : String?
  creator : String?
  language : String?
  identifier : String?
  publisher : String?
  subject : String?
  date : String?
  modified : String?
}

///|
pub struct EpubMetadataEntry {
  name : String
  value : String
}

///|
pub struct EpubManifestItem {
  id : String
  href : String
  media_type : String?
  properties : Array[String]
  resolved_path : String
}

///|
pub struct EpubSpineItem {
  idref : String
  linear : Bool
  spine_index : Int
  manifest_item : EpubManifestItem?
  resolved_path : String?
}

///|
pub struct EpubNavPoint {
  label : String
  href : String
  depth : Int
  source_path : String?
}

///|
pub struct EpubCoverCandidate {
  source : EpubCoverCandidateSource
  path : String
  manifest_id : String?
  media_type : String?
  is_image : Bool
  selected : Bool
}

///|
pub struct EpubPackageInventory {
  source_name : String
  mimetype : String?
  primary_rootfile_path : String
  part_count : Int
  rootfile_count : Int
  manifest_count : Int
  spine_count : Int
  spine_linear_count : Int
  nav_point_count : Int
  metadata_count : Int
  cover_candidate_count : Int
  has_encryption : Bool
  nav_path : String?
  nav_document_path : String?
  ncx_path : String?
  cover_path : String?
  guide_cover_path : String?
  parts : Array[EpubArchiveEntry]
  rootfiles : Array[EpubRootfileInfo]
  metadata_entries : Array[EpubMetadataEntry]
  cover_candidates : Array[EpubCoverCandidate]
}

///|
pub struct EpubInspectSpineItem {
  idref : String
  href : String
  media_type : String?
  linear : Bool
  spine_index : Int
  action : String
}

///|
pub struct EpubInspectReport {
  source_name : String
  mimetype : String?
  rootfile_path : String
  primary_rootfile : EpubRootfileInfo
  rootfiles : Array[EpubRootfileInfo]
  manifest_count : Int
  spine_count : Int
  nav_path : String?
  nav_document_path : String?
  ncx_path : String?
  cover_path : String?
  guide_cover_path : String?
  has_encryption : Bool
  metadata : EpubMetadata
  cover_candidates : Array[EpubCoverCandidate]
  inventory : EpubPackageInventory
  spine_items : Array[EpubInspectSpineItem]
}

///|
pub struct EpubValidationIssue {
  kind : EpubValidationIssueKind
  severity : EpubValidationSeverity
  rootfile_path : String
  manifest_id : String?
  spine_idref : String?
  part_name : String?
  href : String?
  media_type : String?
  spine_index : Int?
  message : String
}

///|
pub struct EpubValidationReport {
  source_name : String
  part_count : Int
  rootfile_count : Int
  manifest_count : Int
  spine_count : Int
  issue_count : Int
  error_count : Int
  warning_count : Int
  issues : Array[EpubValidationIssue]
}

///|
pub struct EpubPackage {
  archive : @zip.ZipArchive
  entries : Array[EpubArchiveEntry]
  entry_index : Map[String, String]
  source_name : String
  mimetype : String?
  rootfile_path : String
  rootfiles : Array[EpubRootfileInfo]
  opf_dir : String
  metadata : EpubMetadata
  manifest : Array[EpubManifestItem]
  spine : Array[EpubSpineItem]
  nav_item : EpubManifestItem?
  nav_document_item : EpubManifestItem?
  ncx_item : EpubManifestItem?
  cover_item : EpubManifestItem?
  guide_cover_path : String?
  cover_candidates : Array[EpubCoverCandidate]
  nav_points : Array[EpubNavPoint]
}
