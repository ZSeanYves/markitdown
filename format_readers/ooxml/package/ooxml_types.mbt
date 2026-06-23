///|
pub(all) suberror OoxmlError {
  ZipError(String)
  MissingPart(String)
  InvalidXml(String)
  InvalidPartPath(String)
  RelationshipNotFound(String, String)
}

///|
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
pub(all) enum OoxmlValidationMode {
  Compatible
  Strict
} derive(Eq)

///|
pub(all) enum OoxmlValidationSeverity {
  Warning
  Error
} derive(Eq)

///|
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
pub struct OoxmlErrorInfo {
  kind : OoxmlErrorKind
  detail : String
  part_name : String?
  rels_part_name : String?
  source_part : String?
  rel_id : String?
  target : String?
}

///|
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
pub fn classify_ooxml_error(err : OoxmlError) -> OoxmlErrorInfo {
  match err {
    ZipError(msg) =>
      {
        kind: OoxmlErrorKind::ZipFailure,
        detail: msg,
        part_name: None,
        rels_part_name: None,
        source_part: None,
        rel_id: None,
        target: None,
      }
    MissingPart(path) =>
      {
        kind: OoxmlErrorKind::MissingPart,
        detail: path,
        part_name: Some(path),
        rels_part_name: if path.has_suffix(".rels") {
          Some(path)
        } else {
          None
        },
        source_part: None,
        rel_id: None,
        target: None,
      }
    InvalidXml(msg) => classify_invalid_xml_detail(msg)
    InvalidPartPath(path) => classify_invalid_part_path_detail(path)
    RelationshipNotFound(source_part, rel_id) =>
      {
        kind: OoxmlErrorKind::RelationshipNotFound,
        detail: "source=" + source_part + ", rel_id=" + rel_id,
        part_name: None,
        rels_part_name: None,
        source_part: Some(source_part),
        rel_id: Some(rel_id),
        target: None,
      }
  }
}

///|
/// Relationship target mode in OOXML `.rels` parts.
pub(all) enum OoxmlTargetMode {
  Internal
  External
} derive(Eq)

///|
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
pub struct OoxmlRelationshipInfo {
  source_part : String?
  rels_part_name : String
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
pub struct OoxmlPartInfo {
  part_name : String
  content_type : String?
  size : Int
  is_relationships_part : Bool
  has_relationships : Bool
}

///|
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
pub struct OoxmlPackageInspectReport {
  part_count : Int
  content_type_default_count : Int
  content_type_override_count : Int
  relationship_source_count : Int
  package_relationship_count : Int
  part_relationship_count : Int
  media_asset_count : Int
  inventory : OoxmlPackageInventory
  package_relationships : Array[OoxmlRelationshipInfo]
  part_relationships : Array[OoxmlRelationshipInfo]
  media_assets : Array[OoxmlAsset]
  core_properties : OoxmlCoreProperties
  app_properties : OoxmlAppProperties
}

///|
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
/// Read-only observability for package-local OOXML part cache reuse.
pub struct OoxmlPartCacheStats {
  bytes_hit_count : Int
  bytes_miss_count : Int
  text_hit_count : Int
  text_decode_count : Int
  bytes_entry_count : Int
  text_entry_count : Int
}

///|
/// Read-only observability for package-local OOXML relationship index reuse.
pub struct OoxmlRelationshipCacheStats {
  relationships_hit_count : Int
  relationships_miss_count : Int
  by_id_hit_count : Int
  by_id_miss_count : Int
  by_type_query_count : Int
  entry_count : Int
}

///|
/// Opened OOXML package with a ZIP archive, cached content-type maps, and a
/// per-package part / relationship cache.
pub struct OoxmlPackage {
  archive : @zip.ZipArchive
  part_index : Map[String, Int]
  content_types_default : Map[String, String]
  content_types_override : Map[String, String]
  priv part_cache : OoxmlPartCache
  priv relationship_cache : OoxmlRelationshipCache
  priv sorted_parts_cache : Ref[Array[String]?]
  priv inventory_cache : Ref[OoxmlPackageInventory?]
}

///|
fn classify_invalid_xml_detail(msg : String) -> OoxmlErrorInfo {
  if msg.has_prefix("[Content_Types].xml: ") {
    let detail = msg["[Content_Types].xml: ".length():].to_owned()
    {
      kind: classify_content_types_detail(detail),
      detail,
      part_name: Some("[Content_Types].xml"),
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target: None,
    }
  } else if msg.has_prefix("relationships ") {
    classify_relationships_detail(msg)
  } else {
    {
      kind: OoxmlErrorKind::InvalidXml,
      detail: msg,
      part_name: None,
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target: None,
    }
  }
}

///|
fn classify_content_types_detail(detail : String) -> OoxmlErrorKind {
  if detail.contains("duplicate content type override: ") {
    OoxmlErrorKind::DuplicateContentTypeOverride
  } else {
    OoxmlErrorKind::MalformedContentTypes
  }
}

///|
fn classify_relationships_detail(msg : String) -> OoxmlErrorInfo {
  let rels_part_name = parse_quoted_field(msg, "rels_part=")
  let source_part = parse_quoted_field(msg, "source=")
  let detail = parse_relationship_detail(msg)
  {
    kind: OoxmlErrorKind::MalformedRelationships,
    detail,
    part_name: rels_part_name,
    rels_part_name,
    source_part,
    rel_id: None,
    target: None,
  }
}

///|
fn classify_invalid_part_path_detail(path : String) -> OoxmlErrorInfo {
  if path.has_prefix("unsafe relationship target: ") {
    let detail = path["unsafe relationship target: ".length():].to_owned()
    let target = parse_relationship_target(detail)
    {
      kind: OoxmlErrorKind::UnsafeRelationshipTarget,
      detail,
      part_name: None,
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target,
    }
  } else if path.has_prefix("normalized part collision: ") {
    let detail = path["normalized part collision: ".length():].to_owned()
    {
      kind: OoxmlErrorKind::DuplicateNormalizedPart,
      detail,
      part_name: Some(detail),
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target: None,
    }
  } else {
    {
      kind: OoxmlErrorKind::UnsafePartName,
      detail: path,
      part_name: Some(path),
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target: None,
    }
  }
}

///|
fn parse_quoted_field(msg : String, key : String) -> String? {
  let start = find_substring(msg, key)
  if start < 0 {
    return None
  }
  let value_start = start + key.length()
  if value_start >= msg.length() || msg[value_start] != '"' {
    return None
  }
  let body_start = value_start + 1
  let end_abs = find_char_from(msg, '"', body_start)
  if end_abs < 0 {
    None
  } else {
    Some(msg[body_start:end_abs].to_owned())
  }
}

///|
fn parse_relationship_detail(msg : String) -> String {
  let idx = find_substring(msg, ": ")
  if idx < 0 {
    msg
  } else {
    msg[idx + 2:].to_owned()
  }
}

///|
fn parse_relationship_target(detail : String) -> String? {
  let idx = find_substring(detail, ": ")
  if idx < 0 || idx + 2 >= detail.length() {
    None
  } else {
    Some(detail[idx + 2:].to_owned())
  }
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

///|
fn find_char_from(text : String, needle : Char, start : Int) -> Int {
  let chars = text.to_array()
  let mut i = start
  while i < chars.length() {
    if chars[i] == needle {
      return i
    }
    i = i + 1
  }
  -1
}
