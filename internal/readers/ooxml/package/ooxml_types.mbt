///|
/// Public OOXML package errors surfaced by the reader layer.
pub(all) suberror OoxmlError {
  ZipError(String)
  MissingPart(String)
  InvalidXml(String)
  InvalidPartPath(String)
  RelationshipNotFound(String, String)
}

///|
/// Coarse error kinds used for diagnostics and validation summaries.
pub(all) enum OoxmlErrorKind {
  ZipFailure
  MissingPart
  MalformedContentTypes
  MalformedRelationships
  InvalidXml
  UnsafePartName
  UnsafeRelationshipTarget
  DuplicateNormalizedPart
  DuplicateContentTypeOverride
  RelationshipNotFound
} derive(Eq)

///|
/// Validation strictness applied when checking OOXML package structure.
pub(all) enum OoxmlValidationMode {
  Compatible
  Strict
} derive(Eq)

///|
/// Severity levels attached to OOXML validation issues.
pub(all) enum OoxmlValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
/// Fine-grained validation issue kinds for `.rels` and external references.
pub(all) enum OoxmlValidationIssueKind {
  ExternalRelationship
  DuplicateRelationshipId
  MissingRelationshipId
  MissingRelationshipType
  MissingRelationshipTarget
  UnsafeRelationshipTarget
} derive(Eq)

///|
pub impl Show for OoxmlError with fn to_string(self : OoxmlError) -> String {
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
pub impl Show for OoxmlError with fn output(self : OoxmlError, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
/// One validation issue discovered while scanning an OOXML package.
///
/// The optional location fields let callers point back to either the source
/// part or the relationships part that triggered the issue.
pub struct OoxmlValidationIssue {
  kind : OoxmlValidationIssueKind
  severity : OoxmlValidationSeverity
  part_name : String?
  rels_part_name : String?
  source_part : String?
  relationship_id : String?
  target : String?
  message : String
}

///|
/// Summary of OOXML package validation results.
pub struct OoxmlValidationReport {
  mode : OoxmlValidationMode
  part_count : Int
  relationship_part_count : Int
  issue_count : Int
  error_count : Int
  warning_count : Int
  issues : Array[OoxmlValidationIssue]
}

///|
/// Relationship target mode in OOXML `.rels` parts.
pub(all) enum OoxmlTargetMode {
  Internal
  External
} derive(Eq)

///|
/// Whether a content-type entry came from a default extension mapping or a
/// part-specific override.
pub(all) enum OoxmlContentTypeInfoKind {
  DefaultExtension
  OverridePart
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
/// Lightweight inventory row for one OOXML part.
pub struct OoxmlPartInfo {
  part_name : String
  content_type : String?
  size : Int
  is_relationships_part : Bool
  has_relationships : Bool
}

///|
/// Decoded XML part payload cached together with a structure scan.
pub struct OoxmlXmlPartPayload {
  part_name : String
  bytes : Bytes
  text : String
  structure_scan : @xml.XmlStructureScan
}

///|
/// Content-type mapping entry extracted from `[Content_Types].xml`.
pub struct OoxmlContentTypeInfo {
  kind : OoxmlContentTypeInfoKind
  extension : String?
  part_name : String?
  content_type : String
}

///|
/// Lightweight fields from `docProps/core.xml`.
pub struct OoxmlCoreProperties {
  title : String?
  subject : String?
  creator : String?
  last_modified_by : String?
  description : String?
  keywords : String?
  category : String?
  created : String?
  modified : String?
}

///|
/// Lightweight fields from `docProps/app.xml`.
pub struct OoxmlAppProperties {
  application : String?
  company : String?
  manager : String?
  pages : String?
  words : String?
  slides : String?
  sheets : String?
}

///|
/// Lightweight fields from `docProps/custom.xml`.
pub struct OoxmlCustomProperty {
  name : String
  value : String
  value_type : String?
}

///|
/// Read-only summary of an OOXML package inventory used by tests and debug
/// inspection.
pub struct OoxmlPackageInventory {
  parts : Array[OoxmlPartInfo]
  content_types : Array[OoxmlContentTypeInfo]
  relationship_source_parts : Array[String]
  relationship_parts : Array[String]
  part_count : Int
  relationship_part_count : Int
  content_type_entry_count : Int
  media_asset_count : Int
  has_core_properties : Bool
  has_app_properties : Bool
}

///|
/// Internal decoded-part cache used to avoid repeatedly re-reading or
/// re-decoding OOXML parts.
priv struct OoxmlPartCache {
  bytes_by_part : Map[String, Bytes]
  text_by_part : Map[String, String]
  bytes_hit_count : Ref[Int]
  bytes_miss_count : Ref[Int]
  text_hit_count : Ref[Int]
  text_decode_count : Ref[Int]
}

///|
priv struct OoxmlRelationshipIndex {
  relationships : Array[OoxmlRelationship]
  by_id : Map[String, OoxmlRelationship]
  by_type : Map[String, Array[OoxmlRelationship]]
}

///|
priv struct OoxmlRelationshipCache {
  index_by_rels_part : Map[String, OoxmlRelationshipIndex]
  relationships_hit_count : Ref[Int]
  relationships_miss_count : Ref[Int]
  by_id_hit_count : Ref[Int]
  by_id_miss_count : Ref[Int]
  by_type_query_count : Ref[Int]
}

///|
/// Opened OOXML package with a ZIP archive, cached content-type maps, and a
/// per-package part / relationship cache.
pub struct OoxmlPackage {
  archive : @zip.ZipArchive
  part_index : Map[String, String]
  part_size_index : Map[String, Int]
  content_types_default : Map[String, String]
  content_types_override : Map[String, String]
  priv part_cache : OoxmlPartCache
  priv relationship_cache : OoxmlRelationshipCache
  priv sorted_parts_cache : Ref[Array[String]?]
  priv inventory_cache : Ref[OoxmlPackageInventory?]
}

///|
fn find_substring(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let text_chars = text.to_array()
  let needle_chars = needle.to_array()
  if needle_chars.length() > text_chars.length() {
    return -1
  }

  let limit = text_chars.length() - needle_chars.length()
  for start in 0..<=limit {
    let mut ok = true
    for offset in 0..<needle_chars.length() {
      if text_chars[start + offset] != needle_chars[offset] {
        ok = false
        break
      }
    }
    if ok {
      return start
    }
  }
  -1
}
