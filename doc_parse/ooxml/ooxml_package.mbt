///|
/// OOXML package infrastructure built on top of zip reader.
///
/// Responsibility:
/// - normalize/read package parts and relationships
/// - expose content-type and rel resolution helpers
///
/// Non-goal:
/// - no DOCX/PPTX/XLSX final block recovery in this layer
pub fn open_ooxml_package(bytes : Bytes) -> OoxmlPackage raise OoxmlError {
  let archive = @zip.open_zip(bytes) catch {
    e => raise ZipError(e.to_string())
  }

  let part_index : Map[String, Int] = Map::new()
  let entries = @zip.list_entries(archive)
  let mut i = 0
  while i < entries.length() {
    part_index.set(entries[i].name, i)
    i = i + 1
  }

  let content_types_bytes = @zip.read_entry(archive, "[Content_Types].xml") catch {
    @zip.EntryNotFound(path) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
  let content_types_xml = bytes_to_xml_text(content_types_bytes)

  let (defaults, overrides) = parse_content_types(content_types_xml)
  {
    archive,
    part_index,
    content_types_default: defaults,
    content_types_override: overrides,
  }
}

///|
pub fn has_part(pkg : OoxmlPackage, part_name : String) -> Bool {
  let normalized = normalize_part_name(part_name) catch { _ => return false }
  pkg.part_index.contains(normalized)
}

///|
pub fn read_part_bytes(
  pkg : OoxmlPackage,
  part_name : String,
) -> Bytes raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  @zip.read_entry(pkg.archive, normalized) catch {
    @zip.EntryNotFound(path) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
}

///|
pub fn lookup_content_type(
  pkg : OoxmlPackage,
  part_name : String,
) -> String? raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  let override_key = "/" + normalized

  match pkg.content_types_override.get(override_key) {
    Some(value) => Some(value)
    None => {
      let ext = extension_of_part(normalized)
      if ext == "" {
        None
      } else {
        pkg.content_types_default.get(ext)
      }
    }
  }
}

///|
pub fn list_parts(pkg : OoxmlPackage) -> Array[String] {
  let out : Array[String] = []
  for entry in pkg.part_index {
    let (name, _) = entry
    out.push(name)
  }
  out.sort()
  out
}

///|
pub fn list_parts_by_prefix(
  pkg : OoxmlPackage,
  prefix : String,
) -> Array[String] {
  let out : Array[String] = []
  for name in list_parts(pkg) {
    if name.has_prefix(prefix) {
      out.push(name)
    }
  }
  out
}

///|
pub fn list_parts_by_content_type(
  pkg : OoxmlPackage,
  content_type : String,
) -> Array[String] raise OoxmlError {
  let out : Array[String] = []
  for name in list_parts(pkg) {
    match lookup_content_type(pkg, name) {
      Some(ct) =>
        if ct == content_type {
          out.push(name)
        }
      None => ()
    }
  }
  out
}

///|
pub fn has_relationships_part(
  pkg : OoxmlPackage,
  source_part : String,
) -> Bool {
  let source = normalize_source_part_for_resolve(source_part) catch {
    _ => return false
  }
  let rels_part = if source == "" {
    "_rels/.rels"
  } else {
    rels_part_name_for_source(source)
  }
  pkg.part_index.contains(rels_part)
}

///|
pub fn find_relationship_by_id(
  pkg : OoxmlPackage,
  source_part : String,
  rel_id : String,
) -> OoxmlRelationship? raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  let rels = if source == "" {
    read_package_relationships(pkg)
  } else {
    read_part_relationships(pkg, source)
  }

  for rel in rels {
    if rel.id == rel_id {
      return Some(rel)
    }
  }
  None
}

///|
pub fn find_relationships_by_type(
  pkg : OoxmlPackage,
  source_part : String,
  rel_type_suffix : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  let rels = if source == "" {
    read_package_relationships(pkg)
  } else {
    read_part_relationships(pkg, source)
  }

  let out : Array[OoxmlRelationship] = []
  for rel in rels {
    if rel.rel_type.has_suffix(rel_type_suffix) || rel.rel_type == rel_type_suffix {
      out.push(rel)
    }
  }
  out
}

///|
pub fn read_package_relationships(
  pkg : OoxmlPackage,
) -> Array[OoxmlRelationship] raise OoxmlError {
  read_relationships_from_rels_part(pkg, "", "_rels/.rels")
}

///|
pub fn read_part_relationships(
  pkg : OoxmlPackage,
  source_part : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let normalized = normalize_part_name(source_part)
  let rels_part = rels_part_name_for_source(normalized)

  if !pkg.part_index.contains(rels_part) {
    return []
  }

  read_relationships_from_rels_part(pkg, normalized, rels_part)
}

///|
pub fn resolve_relationship(
  pkg : OoxmlPackage,
  source_part : String,
  rel_id : String,
) -> String raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  let rels = if source == "" {
    read_package_relationships(pkg)
  } else {
    read_part_relationships(pkg, source)
  }

  for rel in rels {
    if rel.id == rel_id {
      return rel.resolved_target
    }
  }

  let source_display = if source == "" { "(package)" } else { source }
  raise RelationshipNotFound(source_display, rel_id)
}

///|
fn read_relationships_from_rels_part(
  pkg : OoxmlPackage,
  source_part : String,
  rels_part : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let rels_bytes = read_part_bytes(pkg, rels_part)
  let rels_xml = bytes_to_xml_text(rels_bytes)
  parse_relationships_xml(rels_xml, source_part)
}

///|
fn parse_content_types(
  xml : String,
) -> (Map[String, String], Map[String, String]) raise OoxmlError {
  let defaults : Map[String, String] = Map::new()
  let overrides : Map[String, String] = Map::new()

  for tag in collect_start_tags(xml, "Default") {
    let attrs = parse_tag_attributes(tag)
    let ext = get_required_attr(attrs, "Extension")
    let content_type = get_required_attr(attrs, "ContentType")
    defaults.set(ext, content_type)
  }

  for tag in collect_start_tags(xml, "Override") {
    let attrs = parse_tag_attributes(tag)
    let part_name = get_required_attr(attrs, "PartName")
    let content_type = get_required_attr(attrs, "ContentType")
    overrides.set(part_name, content_type)
  }

  (defaults, overrides)
}

///|
fn parse_relationships_xml(
  xml : String,
  source_part : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let rels : Array[OoxmlRelationship] = []

  for tag in collect_start_tags(xml, "Relationship") {
    let attrs = parse_tag_attributes(tag)
    let id = get_required_attr(attrs, "Id")
    let rel_type = get_required_attr(attrs, "Type")
    let target = get_required_attr(attrs, "Target")
let target_mode_raw = get_optional_attr(attrs, "TargetMode")
let target_mode = parse_target_mode(target_mode_raw)
let resolved_target = resolve_target(source_part, target, target_mode)

rels.push({ id, rel_type, target, target_mode, resolved_target })
  }

  rels
}

///|
fn bytes_to_xml_text(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for b in bytes {
    chars.push(Int::unsafe_to_char(byte_to_int(b)))
  }
  String::from_array(chars)
}

///|
fn collect_start_tags(xml : String, local_name : String) -> Array[String] {
  let tags : Array[String] = []
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i = i + 1
      continue
    }

    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i = i + 1
      continue
    }

    let mut j = i + 1
    while j < n && chars[j] != '>' {
      j = j + 1
    }
    if j >= n {
      break
    }

    let tag = xml[i:j + 1].to_string()
    let tag_name = start_tag_local_name(tag)
    if tag_name == local_name {
      tags.push(tag)
    }

    i = j + 1
  }

  tags
}

///|
fn start_tag_local_name(tag : String) -> String {
  let chars = tag.to_array()
  if chars.length() < 3 {
    return ""
  }

  let mut i = 1
  while i < chars.length() && is_space(chars[i]) {
    i = i + 1
  }

  let mut j = i
  while j < chars.length() &&
        !is_space(chars[j]) &&
        chars[j] != '/' &&
        chars[j] != '>' {
    j = j + 1
  }

  if j <= i {
    return ""
  }

  let raw_name = tag[i:j].to_string()
  let raw_chars = raw_name.to_array()
  let mut colon = -1
  for k in 0..<raw_chars.length() {
    if raw_chars[k] == ':' {
      colon = k
    }
  }

  if colon < 0 {
    raw_name
  } else {
    raw_name[colon + 1:].to_string()
  }
}

///|
fn parse_tag_attributes(tag : String) -> Map[String, String] {
  let attrs : Map[String, String] = Map::new()
  let chars = tag.to_array()
  let n = chars.length()

  let mut i = 1
  while i < n && chars[i] != '>' && !is_space(chars[i]) {
    i = i + 1
  }

  while i < n {
    while i < n && is_space(chars[i]) {
      i = i + 1
    }

    if i >= n || chars[i] == '>' || chars[i] == '/' {
      break
    }

    let key_start = i
    while i < n && chars[i] != '=' && !is_space(chars[i]) && chars[i] != '>' {
      i = i + 1
    }
    if i >= n || chars[i] == '>' {
      break
    }

    let key_end = i
    while i < n && is_space(chars[i]) {
      i = i + 1
    }
    if i >= n || chars[i] != '=' {
      break
    }
    i = i + 1

    while i < n && is_space(chars[i]) {
      i = i + 1
    }
    if i >= n {
      break
    }

    let quote = chars[i]
    if quote != '"' && quote != '\'' {
      break
    }
    i = i + 1

    let value_start = i
    while i < n && chars[i] != quote {
      i = i + 1
    }
    if i >= n {
      break
    }
    let value_end = i
    i = i + 1

    let key = tag[key_start:key_end].to_string()
    let value = tag[value_start:value_end].to_string()
    attrs.set(key, value)
  }

  attrs
}

///|
fn get_required_attr(
  attrs : Map[String, String],
  key : String,
) -> String raise OoxmlError {
  match attrs.get(key) {
    Some(value) => value
    None => raise InvalidXml("missing attribute: " + key)
  }
}

///|
fn get_optional_attr(attrs : Map[String, String], key : String) -> String {
  match attrs.get(key) {
    Some(value) => value
    None => ""
  }
}

///|
fn normalize_part_name(part_name : String) -> String raise OoxmlError {
  let t0 = part_name.trim().to_string()
  if t0 == "" {
    raise InvalidPartPath(part_name)
  }

  let t = if t0.has_prefix("/") { t0[1:] } else { t0 }
  if t == "" {
    raise InvalidPartPath(part_name)
  }

  normalize_relative_path(t.to_string())
}

///|
fn normalize_source_part_for_resolve(
  source_part : String,
) -> String raise OoxmlError {
  let t = source_part.trim().to_string()
  if t == "" || t == "/" {
    ""
  } else {
    normalize_part_name(t)
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

fn resolve_target(
  source_part : String,
  target : String,
  target_mode : OoxmlTargetMode,
) -> String raise OoxmlError {
  if target_mode == External {
    return target
  }

  let target0 = target.trim().to_string()
  if target0 == "" {
    raise InvalidPartPath(target)
  }

  if target0.has_prefix("/") {
    return normalize_part_name(target0)
  }

  if source_part == "" {
    return normalize_relative_path(target0)
  }

  let (source_dir, _) = split_dir_file(source_part)
  if source_dir == "" {
    normalize_relative_path(target0)
  } else {
    normalize_relative_path(source_dir + "/" + target0)
  }
}
///|
fn parse_target_mode(value : String) -> OoxmlTargetMode {
  if value == "External" {
    External
  } else {
    Internal
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
    (path[:slash].to_string(), path[slash + 1:].to_string())
  }
}

///|
fn normalize_relative_path(path : String) -> String raise OoxmlError {
  let raw = path.trim().to_string()
  if raw == "" {
    raise InvalidPartPath(path)
  }

  let parts = raw.split("/")
  let stack : Array[String] = []

  for segv in parts {
    let seg = segv.to_string()
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if stack.is_empty() {
        raise InvalidPartPath(path)
      }
      ignore(stack.pop())
      continue
    }
    stack.push(seg)
  }

  if stack.is_empty() {
    raise InvalidPartPath(path)
  }

  stack.join("/")
}

///|
fn extension_of_part(path : String) -> String {
  let chars = path.to_array()
  let mut dot = -1

  for i in 0..<chars.length() {
    if chars[i] == '.' {
      dot = i
    }
  }

  if dot < 0 || dot + 1 >= chars.length() {
    ""
  } else {
    path[dot + 1:].to_string()
  }
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}


///|
pub fn list_media_assets(pkg : OoxmlPackage) -> Array[OoxmlAsset] raise OoxmlError {
  let out : Array[OoxmlAsset] = []

  for part in list_parts(pkg) {
    if !is_media_part(part) {
      continue
    }

    let content_type = lookup_content_type(pkg, part)
    let bytes = read_part_bytes(pkg, part)
    let refs = collect_asset_refs(pkg, part)
    out.push({
      part_name: part,
      content_type,
      ext: extension_of_part(part),
      size: bytes.length(),
      referenced_by: refs,
    })
  }

  out
}

///|
fn is_media_part(part : String) -> Bool {
  is_media_part_under(part, "word/media/") ||
  is_media_part_under(part, "ppt/media/") ||
  is_media_part_under(part, "xl/media/")
}

///|
fn is_media_part_under(part : String, prefix : String) -> Bool {
  if !part.has_prefix(prefix) {
    return false
  }

  if part.length() <= prefix.length() {
    return false
  }

  if part.has_suffix("/") {
    return false
  }

  true
}

///|
fn collect_asset_refs(
  pkg : OoxmlPackage,
  media_part : String,
) -> Array[OoxmlAssetRef] {
  let out : Array[OoxmlAssetRef] = []

  for source in list_parts(pkg) {
    if !has_relationships_part(pkg, source) {
      continue
    }

    let rels = read_part_relationships(pkg, source) catch { _ => continue }
    for rel in rels {
      if rel.target_mode == Internal && rel.resolved_target == media_part {
        out.push({
          source_part: source,
          rel_id: rel.id,
          rel_type: rel.rel_type,
        })
      }
    }
  }

  out
}

///|
pub fn read_core_properties(pkg : OoxmlPackage) -> OoxmlCoreProperties {
  let xml = read_optional_xml_text(pkg, "docProps/core.xml")
  {
    title: tag_text(xml, "title"),
    subject: tag_text(xml, "subject"),
    creator: tag_text(xml, "creator"),
    description: tag_text(xml, "description"),
    keywords: tag_text(xml, "keywords"),
    created: tag_text(xml, "created"),
    modified: tag_text(xml, "modified"),
  }
}

///|
pub fn read_app_properties(pkg : OoxmlPackage) -> OoxmlAppProperties {
  let xml = read_optional_xml_text(pkg, "docProps/app.xml")
  {
    application: tag_text(xml, "Application"),
    pages: tag_text(xml, "Pages"),
    words: tag_text(xml, "Words"),
    slides: tag_text(xml, "Slides"),
    sheets: tag_text(xml, "Worksheets"),
  }
}

///|
fn read_optional_xml_text(pkg : OoxmlPackage, part_name : String) -> String {
  let bytes = read_part_bytes(pkg, part_name) catch { _ => return "" }
  bytes_to_xml_text(bytes)
}

///|
fn tag_text(xml : String, local_name : String) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i = i + 1
      continue
    }

    if i + 1 < n && (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i = i + 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end = tag_end + 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = xml[i:tag_end + 1].to_string()
    let name = start_tag_local_name(start_tag)

    if name == local_name {
      let close = "</" + local_name + ">"
      let close_prefixed = "</"
      let content_start = tag_end + 1

      let end1 = find_sub(xml, close, content_start)
      match end1 {
        Some(pos) => return Some(xml_entity_decode(xml[content_start:pos].to_string().trim().to_string()))
        None => {
          // fallback: find next closing tag and trust local-name match loosely
          let end2 = find_sub(xml, close_prefixed, content_start)
          match end2 {
            Some(pos2) => return Some(xml_entity_decode(xml[content_start:pos2].to_string().trim().to_string()))
            None => ()
          }
        }
      }
    }

    i = tag_end + 1
  }

  None
}

///|
fn find_sub(s : String, needle : String, start : Int) -> Int? {
  let n = s.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n {
    return None
  }

  let mut i = start
  while i + m <= n {
    if s[i:i + m].to_string() == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn xml_entity_decode(s : String) -> String {
  s
    .replace(old = "&amp;", new = "&")
    .replace(old = "&lt;", new = "<")
    .replace(old = "&gt;", new = ">")
    .replace(old = "&quot;", new = "\"")
    .replace(old = "&apos;", new = "'")
}