///|
pub fn open_epub_package(
  bytes : Bytes,
  source_name : String,
) -> EpubPackage raise EpubError {
  let archive = @zip.open_zip(bytes) catch {
    e => raise ZipError(e.to_string())
  }

  let (entries, entry_index) = plan_archive_entries(archive)

  if entry_index.contains("META-INF/encryption.xml") {
    raise UnsupportedFeature("DRM/encryption is not supported")
  }

  let mimetype = read_optional_text_part(archive, entry_index, "mimetype")
  let container_xml = read_required_xml_part(
    archive, entry_index, "META-INF/container.xml",
  )
  let rootfile_path = parse_container_rootfile_path(container_xml, entry_index)
  let opf_xml = read_required_xml_part(archive, entry_index, rootfile_path)
  let opf_dir = dirname_of_part(rootfile_path)
  let metadata = parse_opf_metadata(opf_xml)
  let manifest = parse_opf_manifest(opf_xml, opf_dir)
  let manifest_by_id : Map[String, EpubManifestItem] = Map::new()
  for item in manifest {
    if manifest_by_id.contains(item.id) {
      raise InvalidXml("duplicate manifest id: " + item.id)
    }
    manifest_by_id.set(item.id, item)
  }
  let spine = parse_opf_spine(opf_xml, manifest_by_id)
  if spine.length() == 0 {
    raise InvalidXml("missing spine itemref")
  }
  let nav_item = find_nav_item(manifest)
  let cover_item = find_cover_item(opf_xml, manifest_by_id, manifest)
  let nav_points = match nav_item {
    Some(item) =>
      parse_nav_points(
        read_required_xml_part(archive, entry_index, item.resolved_path),
      ) catch {
        _ => []
      }
    None => []
  }

  {
    archive,
    entries,
    entry_index,
    source_name,
    mimetype,
    rootfile_path,
    opf_dir,
    metadata,
    manifest,
    spine,
    nav_item,
    cover_item,
    nav_points,
  }
}

///|
pub fn inspect_epub_package(pkg : EpubPackage) -> EpubInspectReport {
  let spine_items : Array[EpubInspectSpineItem] = []
  for item in pkg.spine {
    let media_type = item.manifest_item.media_type
    let action = if !item.linear {
      "skip"
    } else if spine_item_supported(item) {
      "convert"
    } else {
      "warn"
    }
    spine_items.push({
      idref: item.idref,
      href: item.manifest_item.href,
      media_type,
      linear: item.linear,
      action,
    })
  }
  {
    source_name: pkg.source_name,
    mimetype: pkg.mimetype,
    rootfile_path: pkg.rootfile_path,
    manifest_count: pkg.manifest.length(),
    spine_count: pkg.spine.length(),
    nav_path: match pkg.nav_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    cover_path: match pkg.cover_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    has_encryption: pkg.entry_index.contains("META-INF/encryption.xml"),
    metadata: pkg.metadata,
    spine_items,
  }
}

///|
pub fn has_part(pkg : EpubPackage, part_name : String) -> Bool {
  let normalized = try? normalize_package_full_path(part_name)
  match normalized {
    Ok(path) => pkg.entry_index.contains(path)
    Err(_) => false
  }
}

///|
pub fn read_part_bytes(
  pkg : EpubPackage,
  part_name : String,
) -> Bytes raise EpubError {
  let normalized = normalize_package_full_path(part_name)
  read_required_part_bytes(pkg.archive, pkg.entry_index, normalized)
}

///|
pub fn list_parts(pkg : EpubPackage) -> Array[String] {
  let out : Array[String] = []
  for entry in pkg.entries {
    out.push(entry.path)
  }
  out
}

///|
pub fn read_nav_document(pkg : EpubPackage) -> String? {
  match pkg.nav_item {
    Some(item) =>
      try
        read_required_xml_part(pkg.archive, pkg.entry_index, item.resolved_path)
      catch {
        _ => None
      } noraise {
        xml => Some(xml)
      }
    None => None
  }
}

///|
fn read_required_xml_part(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> String raise EpubError {
  let data = read_required_part_bytes(archive, entry_index, path)
  bytes_to_xml_text(data, path)
}

///|
fn read_required_part_bytes(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> Bytes raise EpubError {
  let raw_path = match entry_index.get(path) {
    Some(v) => v
    None => raise MissingPart(path)
  }
  @zip.read_entry(archive, raw_path) catch {
    @zip.EntryNotFound(_) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
}

///|
fn read_optional_text_part(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> String? {
  let raw_path = match entry_index.get(path) {
    Some(v) => v
    None => return None
  }

  let data = @zip.read_entry(archive, raw_path) catch { _ => return None }
  let text = @cor.utf8_bytes_to_string(data) catch { _ => return None }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn parse_container_rootfile_path(
  xml : String,
  entry_index : Map[String, String],
) -> String raise EpubError {
  let tags = collect_start_tags(xml, "rootfile")
  if tags.length() == 0 {
    raise InvalidXml("container.xml missing rootfile")
  }

  for tag in tags {
    let attrs = parse_tag_attributes(tag)
    let full_path = get_optional_attr(attrs, "full-path").trim().to_owned()
    if full_path == "" {
      continue
    }
    let normalized = try? normalize_package_full_path(full_path)
    match normalized {
      Ok(path) => if entry_index.contains(path) { return path }
      Err(_) => ()
    }
  }

  raise InvalidXml("container.xml has no usable rootfile")
}

///|
fn parse_opf_metadata(xml : String) -> EpubMetadata {
  {
    title: tag_text(xml, "title"),
    creator: tag_text(xml, "creator"),
    language: tag_text(xml, "language"),
    identifier: tag_text(xml, "identifier"),
    publisher: tag_text(xml, "publisher"),
    subject: tag_text(xml, "subject"),
    date: tag_text(xml, "date"),
    modified: tag_text_with_attr(xml, "meta", "property", "dcterms:modified"),
  }
}

///|
fn parse_opf_manifest(
  xml : String,
  opf_dir : String,
) -> Array[EpubManifestItem] raise EpubError {
  let out : Array[EpubManifestItem] = []
  for tag in collect_start_tags(xml, "item") {
    let attrs = parse_tag_attributes(tag)
    let id = get_required_attr(attrs, "id").trim().to_owned()
    let href = get_required_attr(attrs, "href").trim().to_owned()
    let media_type0 = get_optional_attr(attrs, "media-type").trim().to_owned()
    let media_type = if media_type0 == "" { None } else { Some(media_type0) }
    let properties = split_space_properties(
      get_optional_attr(attrs, "properties"),
    )
    out.push({
      id,
      href,
      media_type,
      properties,
      resolved_path: resolve_opf_href(opf_dir, href),
    })
  }

  if out.length() == 0 {
    raise InvalidXml("missing manifest items")
  }

  out
}

///|
fn find_nav_item(manifest : Array[EpubManifestItem]) -> EpubManifestItem? {
  for item in manifest {
    if has_manifest_property(item, "nav") {
      return Some(item)
    }
  }
  None
}

///|
fn find_cover_item(
  opf_xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
  manifest : Array[EpubManifestItem],
) -> EpubManifestItem? {
  for item in manifest {
    if has_manifest_property(item, "cover-image") {
      return Some(item)
    }
  }

  let cover_id = tag_attr_with_attr(opf_xml, "meta", "name", "cover", "content")
  match cover_id {
    Some(id) => manifest_by_id.get(id.trim().to_owned())
    None => None
  }
}

///|
fn has_manifest_property(item : EpubManifestItem, property : String) -> Bool {
  for entry in item.properties {
    if entry == property {
      return true
    }
  }
  false
}

///|
fn split_space_properties(value : String) -> Array[String] {
  let out : Array[String] = []
  for part in value.trim().split(" ") {
    let normalized = part.trim().to_owned()
    if normalized != "" {
      out.push(normalized)
    }
  }
  out
}

///|
fn parse_nav_points(xml : String) -> Array[EpubNavPoint] {
  let out : Array[EpubNavPoint] = []
  let nav_tag = first_start_tag_with_attr(xml, "nav", "epub:type", "toc")
  let nav_region = match nav_tag {
    Some(tag) =>
      match tag_content(xml, tag, "nav") {
        Some(body) => body
        None => return out
      }
    None => return out
  }

  let links = collect_start_tags(nav_region, "a")
  for tag in links {
    let attrs = parse_tag_attributes(tag)
    let href = get_optional_attr(attrs, "href").trim().to_owned()
    if href == "" {
      continue
    }
    match tag_content(nav_region, tag, "a") {
      Some(text) => {
        let label = xml_entity_decode(text.trim().to_owned())
        if label != "" {
          out.push({ label, href })
        }
      }
      None => ()
    }
  }
  out
}

///|
fn parse_opf_spine(
  xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
) -> Array[EpubSpineItem] raise EpubError {
  let out : Array[EpubSpineItem] = []
  for tag in collect_start_tags(xml, "itemref") {
    let attrs = parse_tag_attributes(tag)
    let idref = get_required_attr(attrs, "idref").trim().to_owned()
    let linear = get_optional_attr(attrs, "linear").trim().to_lower() != "no"
    let item = match manifest_by_id.get(idref) {
      Some(v) => v
      None => raise InvalidXml("spine itemref missing manifest item: " + idref)
    }
    out.push({
      idref,
      linear,
      manifest_item: item,
      resolved_path: item.resolved_path,
    })
  }
  out
}

///|
fn spine_item_supported(item : EpubSpineItem) -> Bool {
  let media_type = match item.manifest_item.media_type {
    Some(v) => v.trim().to_owned().to_lower()
    None => ""
  }
  if media_type == "application/xhtml+xml" || media_type == "text/html" {
    return true
  }

  let path = item.resolved_path
  let n = path.length()
  if n == 0 {
    return false
  }
  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return false
      }
      let ext = path[i + 1:].to_owned().to_lower()
      return ext == "xhtml" || ext == "html" || ext == "htm"
    }
    i -= 1
  }
  false
}

///|
fn resolve_opf_href(opf_dir : String, href : String) -> String raise EpubError {
  let href0 = strip_fragment_and_query(href.trim().to_owned())
  if href0 == "" {
    raise InvalidPath(href)
  }
  if href0.contains("\\") || href0.has_prefix("/") {
    raise InvalidPath(href)
  }
  if href0.length() >= 2 && href0[1] == ':' {
    raise InvalidPath(href)
  }
  if has_scheme_like_prefix(href0.to_lower()) {
    raise InvalidPath(href)
  }
  ensure_no_dot_segments(href0, href)

  if opf_dir == "" {
    normalize_relative_path(href0)
  } else {
    normalize_relative_path(opf_dir + "/" + href0)
  }
}

///|
fn ensure_no_dot_segments(
  path : String,
  original : String,
) -> Unit raise EpubError {
  for segv in path.split("/") {
    let seg = segv.trim().to_owned()
    if seg == "" || seg == "." || seg == ".." {
      raise InvalidPath(original)
    }
  }
}

///|
fn strip_fragment_and_query(value : String) -> String {
  let mut end = value.length()
  for i in 0..<value.length() {
    if value[i] == '#' || value[i] == '?' {
      end = i
      break
    }
  }
  value[:end].trim().to_owned()
}

///|
fn has_scheme_like_prefix(src : String) -> Bool {
  for i in 0..<src.length() {
    match src[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}

///|
fn plan_archive_entries(
  archive : @zip.ZipArchive,
) -> (Array[EpubArchiveEntry], Map[String, String]) raise EpubError {
  let out : Array[EpubArchiveEntry] = []
  let entry_index : Map[String, String] = Map::new()

  for meta in @zip.list_entries(archive) {
    if meta.name.has_suffix("/") || meta.name.has_suffix("\\") {
      continue
    }

    let normalized = match normalize_archive_entry_path(meta.name) {
      Some(path) => path
      None => continue
    }

    if is_hidden_or_macos_metadata(normalized) {
      continue
    }

    match entry_index.get(normalized) {
      Some(first_raw) =>
        raise InvalidPackage(
          "normalized path collision: " +
          normalized +
          " (" +
          display_path(first_raw) +
          " vs " +
          display_path(meta.name) +
          ")",
        )
      None => ()
    }

    entry_index.set(normalized, meta.name)
    out.push({
      raw_path: meta.name,
      path: normalized,
      uncompressed_size: meta.uncompressed_size,
    })
  }

  out.sort_by(fn(a, b) { a.path[:].lexical_compare(b.path[:]) })
  (out, entry_index)
}

///|
fn normalize_archive_entry_path(raw_path : String) -> String? {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" || p.has_prefix("/") {
    return None
  }
  if p.length() >= 2 && p[1] == ':' {
    return None
  }

  let parts = p.split("/")
  let clean : Array[String] = []
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    clean.push(segment)
  }

  if clean.length() == 0 {
    None
  } else {
    Some(clean.join("/"))
  }
}

///|
fn normalize_package_full_path(path : String) -> String raise EpubError {
  let raw = strip_fragment_and_query(path.trim().to_owned())
  if raw == "" || raw.contains("\\") || raw.has_prefix("/") {
    raise InvalidPath(path)
  }
  if raw.length() >= 2 && raw[1] == ':' {
    raise InvalidPath(path)
  }
  if has_scheme_like_prefix(raw.to_lower()) {
    raise InvalidPath(path)
  }
  ensure_no_dot_segments(raw, path)
  normalize_relative_path(raw)
}

///|
fn normalize_relative_path(path : String) -> String raise EpubError {
  let raw = path.trim().to_owned()
  if raw == "" {
    raise InvalidPath(path)
  }

  let parts = raw.split("/")
  let stack : Array[String] = []
  for segv in parts {
    let seg = segv.trim().to_owned()
    if seg == "" {
      raise InvalidPath(path)
    }
    if seg == "." {
      raise InvalidPath(path)
    }
    if seg == ".." {
      raise InvalidPath(path)
    }
    stack.push(seg)
  }

  if stack.is_empty() {
    raise InvalidPath(path)
  }
  stack.join("/")
}

///|
fn dirname_of_part(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last < 0 {
    ""
  } else {
    path[:last].to_owned()
  }
}

///|
fn display_path(raw_path : String) -> String {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" {
    "(empty path)"
  } else {
    p
  }
}

///|
fn is_hidden_or_macos_metadata(path : String) -> Bool {
  if path == "__MACOSX" || path.has_prefix("__MACOSX/") {
    return true
  }
  let base = @cor.basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}
