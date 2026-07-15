///|
pub struct OoxmlErrorInfo {
  kind : @ox.OoxmlErrorKind
  detail : String
  part_name : String?
  rels_part_name : String?
  source_part : String?
  rel_id : String?
  target : String?
}

///|
pub struct OoxmlRelationshipInfo {
  source_part : String?
  rels_part_name : String
  id : String
  rel_type : String
  target : String
  target_mode : @ox.OoxmlTargetMode
  resolved_target : String
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
  inventory : @ox.OoxmlPackageInventory
  package_relationships : Array[OoxmlRelationshipInfo]
  part_relationships : Array[OoxmlRelationshipInfo]
  media_assets : Array[@ox.OoxmlAsset]
  core_properties : @ox.OoxmlCoreProperties
  app_properties : @ox.OoxmlAppProperties
}

///|
pub fn classify_ooxml_error(err : @ox.OoxmlError) -> OoxmlErrorInfo {
  match err {
    ZipError(msg) =>
      {
        kind: ZipFailure,
        detail: msg,
        part_name: None,
        rels_part_name: None,
        source_part: None,
        rel_id: None,
        target: None,
      }
    MissingPart(path) =>
      {
        kind: MissingPart,
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
        kind: RelationshipNotFound,
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
pub fn inspect_ooxml_package(
  pkg : @ox.OoxmlPackage,
) -> OoxmlPackageInspectReport {
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let package_relationships = list_relationship_infos(pkg, "") catch { _ => [] }
  let part_relationships : Array[OoxmlRelationshipInfo] = []
  for source in inventory.relationship_source_parts {
    let infos = list_relationship_infos(pkg, source) catch { _ => [] }
    for info in infos {
      part_relationships.push(info)
    }
  }
  let media_assets = @ox.list_media_assets(pkg) catch { _ => [] }
  {
    part_count: inventory.parts.length(),
    content_type_default_count: count_default_content_types(
      inventory.content_types,
    ),
    content_type_override_count: count_override_content_types(
      inventory.content_types,
    ),
    relationship_source_count: inventory.relationship_source_parts.length(),
    package_relationship_count: package_relationships.length(),
    part_relationship_count: part_relationships.length(),
    media_asset_count: media_assets.length(),
    inventory,
    package_relationships,
    part_relationships,
    media_assets,
    core_properties: @ox.read_core_properties(pkg),
    app_properties: @ox.read_app_properties(pkg),
  }
}

///|
pub fn find_part_info(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> @ox.OoxmlPartInfo? {
  let normalized = normalize_part_name_soft(part_name)
  for info in @ox.inspect_ooxml_inventory(pkg).parts {
    if info.part_name == normalized {
      return Some(info)
    }
  }
  None
}

///|
pub fn list_content_type_infos(
  pkg : @ox.OoxmlPackage,
) -> Array[@ox.OoxmlContentTypeInfo] {
  @ox.inspect_ooxml_inventory(pkg).content_types
}

///|
pub fn list_relationship_infos(
  pkg : @ox.OoxmlPackage,
  source_part : String,
) -> Array[OoxmlRelationshipInfo] raise @ox.OoxmlError {
  let source = normalize_source_part(source_part)
  let rels = if source == "" {
    @ox.read_package_relationships(pkg)
  } else {
    @ox.read_part_relationships(pkg, source)
  }
  let rels_part_name = if source == "" {
    "_rels/.rels"
  } else {
    rels_part_name_for_source(source)
  }
  let source_part_opt = if source == "" { None } else { Some(source) }
  let out : Array[OoxmlRelationshipInfo] = []
  for rel in rels {
    out.push({
      source_part: source_part_opt,
      rels_part_name,
      id: rel.id,
      rel_type: rel.rel_type,
      target: rel.target,
      target_mode: rel.target_mode,
      resolved_target: rel.resolved_target,
    })
  }
  out
}

///|
pub fn dump_ooxml_package(pkg : @ox.OoxmlPackage) -> String {
  let out = StringBuilder::new()
  out.write_string(dump_package_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_relationships_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_media_assets_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_properties_summary(pkg))
  out.to_string()
}

///|
pub fn dump_package_summary(pkg : @ox.OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[Content_Types]\n")
  out.write_string("part count: ")
  out.write_string(report.part_count.to_string())
  out.write_string("\n")
  out.write_string("content type defaults: ")
  out.write_string(report.content_type_default_count.to_string())
  out.write_string("\n")
  out.write_string("content type overrides: ")
  out.write_string(report.content_type_override_count.to_string())
  out.write_string("\n")
  out.to_string()
}

///|
pub fn dump_relationships_summary(pkg : @ox.OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[relationships]\n")
  out.write_string("root relationships:\n")
  write_relationship_infos(out, report.package_relationships)

  for source in report.inventory.relationship_source_parts {
    out.write_string("source part: ")
    out.write_string(source)
    out.write_string("\n")
    let rels : Array[OoxmlRelationshipInfo] = []
    for rel in report.part_relationships {
      match rel.source_part {
        Some(value) => if value == source { rels.push(rel) }
        None => ()
      }
    }
    write_relationship_infos(out, rels)
  }
  out.to_string()
}

///|
pub fn dump_media_assets_summary(pkg : @ox.OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[media]\n")
  out.write_string("media asset count: ")
  out.write_string(report.media_asset_count.to_string())
  out.write_string("\n")

  for asset in report.media_assets {
    out.write_string("- part_name=")
    out.write_string(asset.part_name)
    out.write_string(" content_type=")
    out.write_string(string_opt(asset.content_type))
    out.write_string(" size=")
    out.write_string(asset.size.to_string())
    out.write_string(" referenced_by=")
    write_asset_refs_inline(out, asset.referenced_by)
    out.write_string("\n")
  }

  out.to_string()
}

///|
pub fn dump_properties_summary(pkg : @ox.OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  let core = report.core_properties
  let app = report.app_properties

  out.write_string("[properties]\n")
  out.write_string("core: title=")
  out.write_string(string_opt(core.title))
  out.write_string(" subject=")
  out.write_string(string_opt(core.subject))
  out.write_string(" creator=")
  out.write_string(string_opt(core.creator))
  out.write_string(" description=")
  out.write_string(string_opt(core.description))
  out.write_string(" keywords=")
  out.write_string(string_opt(core.keywords))
  out.write_string(" created=")
  out.write_string(string_opt(core.created))
  out.write_string(" modified=")
  out.write_string(string_opt(core.modified))
  out.write_string("\n")

  out.write_string("app: application=")
  out.write_string(string_opt(app.application))
  out.write_string(" pages=")
  out.write_string(string_opt(app.pages))
  out.write_string(" words=")
  out.write_string(string_opt(app.words))
  out.write_string(" slides=")
  out.write_string(string_opt(app.slides))
  out.write_string(" sheets=")
  out.write_string(string_opt(app.sheets))
  out.write_string("\n")
  out.to_string()
}

///|
fn count_default_content_types(infos : Array[@ox.OoxmlContentTypeInfo]) -> Int {
  let mut count = 0
  for info in infos {
    match info.kind {
      DefaultExtension => count += 1
      _ => ()
    }
  }
  count
}

///|
fn count_override_content_types(infos : Array[@ox.OoxmlContentTypeInfo]) -> Int {
  let mut count = 0
  for info in infos {
    match info.kind {
      OverridePart => count += 1
      _ => ()
    }
  }
  count
}

///|
fn normalize_part_name_soft(part_name : String) -> String {
  let t0 = part_name.trim().to_owned()
  let t = if t0.has_prefix("/") { t0[1:].to_owned() } else { t0 }
  normalize_relative_path_soft(t)
}

///|
fn normalize_source_part(source_part : String) -> String {
  let t = source_part.trim().to_owned()
  if t == "" || t == "/" {
    ""
  } else {
    normalize_part_name_soft(t)
  }
}

///|
fn rels_part_name_for_source(source_part : String) -> String {
  let (dir, file) = split_dir_file(source_part)
  if dir == "" {
    "_rels/" + file + ".rels"
  } else {
    dir + "/_rels/" + file + ".rels"
  }
}

///|
fn split_dir_file(path : String) -> (String, String) {
  let chars = path.to_array()
  let mut slash = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      slash = i
    }
  }
  if slash < 0 {
    ("", path)
  } else {
    (path[:slash].to_owned(), path[slash + 1:].to_owned())
  }
}

///|
fn normalize_relative_path_soft(path : String) -> String {
  let raw = path.trim().to_owned()
  if raw == "" {
    return path
  }
  let parts = raw.split("/")
  let stack : Array[String] = []
  for segv in parts {
    let seg = segv.to_owned()
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if stack.is_empty() {
        return path
      }
      ignore(stack.pop())
      continue
    }
    stack.push(seg)
  }
  if stack.is_empty() {
    path
  } else {
    stack.join("/")
  }
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
      kind: InvalidXml,
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
fn classify_content_types_detail(detail : String) -> @ox.OoxmlErrorKind {
  if detail.contains("duplicate content type override: ") {
    DuplicateContentTypeOverride
  } else {
    MalformedContentTypes
  }
}

///|
fn classify_relationships_detail(msg : String) -> OoxmlErrorInfo {
  let rels_part_name = parse_quoted_field(msg, "rels_part=")
  let source_part = parse_quoted_field(msg, "source=")
  let detail = parse_relationship_detail(msg)
  {
    kind: MalformedRelationships,
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
      kind: UnsafeRelationshipTarget,
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
      kind: DuplicateNormalizedPart,
      detail,
      part_name: Some(detail),
      rels_part_name: None,
      source_part: None,
      rel_id: None,
      target: None,
    }
  } else {
    {
      kind: UnsafePartName,
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

///|
fn write_relationship_infos(
  out : StringBuilder,
  rels : Array[OoxmlRelationshipInfo],
) -> Unit {
  if rels.length() == 0 {
    out.write_string("  (none)\n")
    return
  }

  for rel in rels {
    out.write_string("  - id=")
    out.write_string(rel.id)
    out.write_string(" type=")
    out.write_string(rel.rel_type)
    out.write_string(" target=")
    out.write_string(rel.target)
    out.write_string(" target_mode=")
    out.write_string(target_mode_text(rel.target_mode))
    out.write_string(" resolved_target=")
    out.write_string(rel.resolved_target)
    out.write_string("\n")
  }
}

///|
fn write_asset_refs_inline(
  out : StringBuilder,
  refs : Array[@ox.OoxmlAssetRef],
) -> Unit {
  if refs.length() == 0 {
    out.write_string("[]")
    return
  }

  out.write_string("[")
  for i in 0..<refs.length() {
    let asset_ref = refs[i]
    out.write_string(asset_ref.source_part)
    out.write_string("#")
    out.write_string(asset_ref.rel_id)
    if i + 1 < refs.length() {
      out.write_string(", ")
    }
  }
  out.write_string("]")
}

///|
fn target_mode_text(mode : @ox.OoxmlTargetMode) -> String {
  match mode {
    Internal => "Internal"
    External => "External"
  }
}

///|
fn string_opt(value : String?) -> String {
  match value {
    Some(v) => if v == "" { "(empty)" } else { v }
    None => "(none)"
  }
}
