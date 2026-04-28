///|
pub(all) suberror OoxmlError {
  ZipError(String)
  MissingPart(String)
  InvalidXml(String)
  InvalidPartPath(String)
  RelationshipNotFound(String, String)
}

///|
pub impl Show for OoxmlError with to_string(self : OoxmlError) -> String {
  match self {
    ZipError(msg) => "zip error: " + msg
    MissingPart(path) => "missing OOXML part: " + path
    InvalidXml(msg) => "invalid OOXML xml: " + msg
    InvalidPartPath(path) => "invalid OOXML part path: " + path
    RelationshipNotFound(source_part, rel_id) =>
      "relationship not found: source=" + source_part + ", rel_id=" + rel_id
  }
}

///|
pub impl Show for OoxmlError with output(self : OoxmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// Relationship target mode in OOXML `.rels` parts.
pub(all) enum OoxmlTargetMode {
  Internal
  External
} derive(Eq)

///|
/// A relationship entry parsed from an OOXML `.rels` part.
///
/// `target` is the raw relationship target. `resolved_target` is normalized for
/// internal targets and left as-is for external targets.
pub struct OoxmlRelationship {
  id : String
  rel_type : String
  target : String
  target_mode : OoxmlTargetMode
  resolved_target : String
}

///|
/// A source relationship that points to an OOXML media asset.
pub struct OoxmlAssetRef {
  source_part : String
  rel_id : String
  rel_type : String
}

///|
/// Media asset discovered in an OOXML package.
///
/// The index is package-level and intentionally format-neutral across DOCX,
/// PPTX, and XLSX.
pub struct OoxmlAsset {
  part_name : String
  content_type : String?
  ext : String
  size : Int
  referenced_by : Array[OoxmlAssetRef]
}

///|
/// Lightweight fields from `docProps/core.xml`.
pub struct OoxmlCoreProperties {
  title : String?
  subject : String?
  creator : String?
  description : String?
  keywords : String?
  created : String?
  modified : String?
}

///|
/// Lightweight fields from `docProps/app.xml`.
pub struct OoxmlAppProperties {
  application : String?
  pages : String?
  words : String?
  slides : String?
  sheets : String?
}

///|
/// Opened OOXML package with a ZIP archive and cached content-type maps.
pub struct OoxmlPackage {
  archive : @zip.ZipArchive
  part_index : Map[String, Int]
  content_types_default : Map[String, String]
  content_types_override : Map[String, String]
}
