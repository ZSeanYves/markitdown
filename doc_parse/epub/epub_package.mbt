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
  let rootfiles = parse_container_rootfiles(container_xml, entry_index)
  let rootfile_path = select_primary_rootfile(rootfiles)
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
  let nav_document_item = find_nav_item(manifest)
  let ncx_item = find_ncx_nav_item(opf_xml, manifest_by_id)
  let nav_item = match nav_document_item {
    Some(item) => Some(item)
    None => ncx_item
  }
  let guide_cover_path = find_guide_cover_path(opf_xml, opf_dir)
  let cover_item = find_cover_item(
    opf_xml, manifest_by_id, manifest, guide_cover_path,
  )
  let cover_candidates = collect_cover_candidates(
    opf_xml, manifest_by_id, manifest, guide_cover_path, cover_item,
  )
  let nav_points = match nav_item {
    Some(item) =>
      try {
        if manifest_item_is_ncx(item) {
          parse_ncx_nav_points(
            read_required_xml_part(archive, entry_index, item.resolved_path),
            item.resolved_path,
          )
        } else {
          parse_nav_points(
            read_required_xml_part(archive, entry_index, item.resolved_path),
          )
        }
      } catch {
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
    rootfiles,
    opf_dir,
    metadata,
    manifest,
    spine,
    nav_item,
    nav_document_item,
    ncx_item,
    cover_item,
    guide_cover_path,
    cover_candidates,
    nav_points,
  }
}

///|
pub fn list_epub_rootfiles(pkg : EpubPackage) -> Array[EpubRootfileInfo] {
  pkg.rootfiles
}

///|
pub fn get_epub_primary_rootfile(pkg : EpubPackage) -> EpubRootfileInfo {
  for item in pkg.rootfiles {
    if item.is_primary {
      return item
    }
  }
  {
    full_path: pkg.rootfile_path,
    media_type: None,
    normalized_path: Some(pkg.rootfile_path),
    exists: true,
    usable: true,
    is_primary: true,
  }
}

///|
pub fn list_epub_manifest_items(pkg : EpubPackage) -> Array[EpubManifestItem] {
  pkg.manifest
}

///|
pub fn find_epub_manifest_item(
  pkg : EpubPackage,
  id : String,
) -> EpubManifestItem? {
  for item in pkg.manifest {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
pub fn list_epub_spine_items(pkg : EpubPackage) -> Array[EpubSpineItem] {
  pkg.spine
}

///|
pub fn list_epub_spine_reading_order(pkg : EpubPackage) -> Array[String] {
  let out : Array[String] = []
  for item in pkg.spine {
    match item.resolved_path {
      Some(path) => out.push(path)
      None => ()
    }
  }
  out
}

///|
pub fn find_epub_nav_item(pkg : EpubPackage) -> EpubManifestItem? {
  pkg.nav_document_item
}

///|
pub fn find_epub_ncx_item(pkg : EpubPackage) -> EpubManifestItem? {
  pkg.ncx_item
}

///|
pub fn list_epub_metadata(pkg : EpubPackage) -> Array[EpubMetadataEntry] {
  metadata_entries_of(pkg.metadata)
}

///|
pub fn find_epub_cover_candidates(
  pkg : EpubPackage,
) -> Array[EpubCoverCandidate] {
  pkg.cover_candidates
}

///|
pub fn inspect_epub_inventory(pkg : EpubPackage) -> EpubPackageInventory {
  let primary_rootfile = get_epub_primary_rootfile(pkg)
  let metadata_entries = list_epub_metadata(pkg)
  let mut spine_linear_count = 0
  for item in pkg.spine {
    if item.linear {
      spine_linear_count += 1
    }
  }
  {
    source_name: pkg.source_name,
    mimetype: pkg.mimetype,
    primary_rootfile_path: primary_rootfile.full_path,
    part_count: pkg.entries.length(),
    rootfile_count: pkg.rootfiles.length(),
    manifest_count: pkg.manifest.length(),
    spine_count: pkg.spine.length(),
    spine_linear_count,
    nav_point_count: pkg.nav_points.length(),
    metadata_count: metadata_entries.length(),
    cover_candidate_count: pkg.cover_candidates.length(),
    has_encryption: pkg.entry_index.contains("META-INF/encryption.xml"),
    nav_path: match pkg.nav_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    nav_document_path: match pkg.nav_document_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    ncx_path: match pkg.ncx_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    cover_path: match pkg.cover_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    guide_cover_path: pkg.guide_cover_path,
    parts: pkg.entries,
    rootfiles: pkg.rootfiles,
    metadata_entries,
    cover_candidates: pkg.cover_candidates,
  }
}

///|
pub fn inspect_epub_package(pkg : EpubPackage) -> EpubInspectReport {
  let inventory = inspect_epub_inventory(pkg)
  let primary_rootfile = get_epub_primary_rootfile(pkg)
  let spine_items : Array[EpubInspectSpineItem] = []
  for item in pkg.spine {
    let media_type = match item.manifest_item {
      Some(v) => v.media_type
      None => None
    }
    let action = if !item.linear {
      "skip"
    } else if spine_item_supported(item) {
      "convert"
    } else {
      "warn"
    }
    spine_items.push({
      idref: item.idref,
      href: match item.manifest_item {
        Some(v) => v.href
        None => ""
      },
      media_type,
      linear: item.linear,
      spine_index: item.spine_index,
      action,
    })
  }
  {
    source_name: pkg.source_name,
    mimetype: pkg.mimetype,
    rootfile_path: pkg.rootfile_path,
    primary_rootfile,
    rootfiles: pkg.rootfiles,
    manifest_count: pkg.manifest.length(),
    spine_count: pkg.spine.length(),
    nav_path: match pkg.nav_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    nav_document_path: match pkg.nav_document_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    ncx_path: match pkg.ncx_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    cover_path: match pkg.cover_item {
      Some(v) => Some(v.resolved_path)
      None => None
    },
    guide_cover_path: pkg.guide_cover_path,
    has_encryption: pkg.entry_index.contains("META-INF/encryption.xml"),
    metadata: pkg.metadata,
    cover_candidates: pkg.cover_candidates,
    inventory,
    spine_items,
  }
}

///|
pub fn classify_epub_error(err : EpubError) -> EpubErrorInfo {
  match err {
    ZipError(msg) =>
      {
        kind: EpubErrorKind::ZipFailure,
        detail: msg,
        part_name: None,
        rootfile_path: None,
        manifest_id: None,
        source_part: None,
        path: None,
        href: None,
      }
    MissingPart(path) =>
      if path == "META-INF/container.xml" {
        {
          kind: EpubErrorKind::MissingContainer,
          detail: path,
          part_name: Some(path),
          rootfile_path: None,
          manifest_id: None,
          source_part: None,
          path: Some(path),
          href: None,
        }
      } else {
        {
          kind: EpubErrorKind::MissingPart,
          detail: path,
          part_name: Some(path),
          rootfile_path: None,
          manifest_id: None,
          source_part: None,
          path: Some(path),
          href: None,
        }
      }
    InvalidXml(msg) => classify_invalid_xml_detail(msg)
    InvalidPath(path) => classify_invalid_path_detail(path)
    InvalidPackage(msg) =>
      {
        kind: EpubErrorKind::InvalidPackage,
        detail: msg,
        part_name: None,
        rootfile_path: None,
        manifest_id: None,
        source_part: None,
        path: None,
        href: None,
      }
    UnsupportedFeature(msg) =>
      {
        kind: EpubErrorKind::UnsupportedFeature,
        detail: msg,
        part_name: None,
        rootfile_path: None,
        manifest_id: None,
        source_part: None,
        path: None,
        href: None,
      }
  }
}

///|
pub fn collect_epub_validation_issues(
  pkg : EpubPackage,
) -> Array[EpubValidationIssue] {
  let out : Array[EpubValidationIssue] = []
  if pkg.rootfiles.length() > 1 {
    out.push({
      kind: EpubValidationIssueKind::MultipleRootfiles,
      severity: EpubValidationSeverity::Warning,
      rootfile_path: pkg.rootfile_path,
      manifest_id: None,
      spine_idref: None,
      part_name: None,
      href: None,
      media_type: None,
      spine_index: None,
      message: "multiple container rootfiles present; first usable rootfile is selected deterministically",
    })
  }
  if (match pkg.nav_item {
      None => true
      Some(_) => false
    }) {
    out.push({
      kind: EpubValidationIssueKind::MissingNavigationDocument,
      severity: EpubValidationSeverity::Warning,
      rootfile_path: pkg.rootfile_path,
      manifest_id: None,
      spine_idref: None,
      part_name: None,
      href: None,
      media_type: None,
      spine_index: None,
      message: "no EPUB3 nav document or NCX navigation document was discovered",
    })
  }
  let seen_idrefs : Map[String, Int] = Map::new()
  for item in pkg.spine {
    if seen_idrefs.contains(item.idref) {
      out.push({
        kind: EpubValidationIssueKind::DuplicateSpineIdref,
        severity: EpubValidationSeverity::Warning,
        rootfile_path: pkg.rootfile_path,
        manifest_id: item.manifest_item.map(fn(entry) { entry.id }),
        spine_idref: Some(item.idref),
        part_name: item.resolved_path,
        href: item.manifest_item.map(fn(entry) { entry.href }),
        media_type: item.manifest_item.bind(fn(entry) { entry.media_type }),
        spine_index: Some(item.spine_index),
        message: "duplicate spine idref: " + item.idref,
      })
    } else {
      seen_idrefs.set(item.idref, 1)
    }

    match item.manifest_item {
      Some(manifest_item) =>
        if !spine_item_supported(item) {
          out.push({
            kind: EpubValidationIssueKind::UnsupportedSpineItem,
            severity: EpubValidationSeverity::Warning,
            rootfile_path: pkg.rootfile_path,
            manifest_id: Some(manifest_item.id),
            spine_idref: Some(item.idref),
            part_name: Some(manifest_item.resolved_path),
            href: Some(manifest_item.href),
            media_type: manifest_item.media_type,
            spine_index: Some(item.spine_index),
            message: "spine item media type is not supported for lower-layer reading order consumers",
          })
        }
      None =>
        out.push({
          kind: EpubValidationIssueKind::MissingManifestItem,
          severity: EpubValidationSeverity::Error,
          rootfile_path: pkg.rootfile_path,
          manifest_id: Some(item.idref),
          spine_idref: Some(item.idref),
          part_name: None,
          href: None,
          media_type: None,
          spine_index: Some(item.spine_index),
          message: "spine item references missing manifest id: " + item.idref,
        })
    }

    match item.resolved_path {
      Some(_) => ()
      None =>
        out.push({
          kind: EpubValidationIssueKind::MissingSpineTarget,
          severity: EpubValidationSeverity::Error,
          rootfile_path: pkg.rootfile_path,
          manifest_id: Some(item.idref),
          spine_idref: Some(item.idref),
          part_name: None,
          href: item.manifest_item.map(fn(entry) { entry.href }),
          media_type: item.manifest_item.bind(fn(entry) { entry.media_type }),
          spine_index: Some(item.spine_index),
          message: "spine item has no resolved target path: " + item.idref,
        })
    }
  }
  out.sort_by(fn(a, b) { compare_validation_issue(a, b) })
  out
}

///|
pub fn validate_epub_package(pkg : EpubPackage) -> EpubValidationReport {
  let inventory = inspect_epub_inventory(pkg)
  let issues = collect_epub_validation_issues(pkg)
  let mut error_count = 0
  let mut warning_count = 0
  for issue in issues {
    match issue.severity {
      EpubValidationSeverity::Error => error_count += 1
      EpubValidationSeverity::Warning => warning_count += 1
    }
  }
  {
    source_name: pkg.source_name,
    part_count: inventory.part_count,
    rootfile_count: inventory.rootfile_count,
    manifest_count: inventory.manifest_count,
    spine_count: inventory.spine_count,
    issue_count: issues.length(),
    error_count,
    warning_count,
    issues,
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
pub fn read_part_text(
  pkg : EpubPackage,
  part_name : String,
) -> String raise EpubError {
  let normalized = normalize_package_full_path(part_name)
  read_required_xml_part(pkg.archive, pkg.entry_index, normalized)
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
  let text = @utf8.decode(data, ignore_bom=false) catch { _ => return None }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn parse_container_rootfiles(
  xml : String,
  entry_index : Map[String, String],
) -> Array[EpubRootfileInfo] raise EpubError {
  let tags = collect_start_tags(xml, "rootfile")
  if tags.length() == 0 {
    raise InvalidXml("container.xml missing rootfile")
  }

  let out : Array[EpubRootfileInfo] = []
  for tag in tags {
    let attrs = parse_tag_attributes(tag)
    let full_path = get_optional_attr(attrs, "full-path").trim().to_owned()
    if full_path == "" {
      continue
    }
    let media_type0 = get_optional_attr(attrs, "media-type").trim().to_owned()
    let media_type = if media_type0 == "" { None } else { Some(media_type0) }
    let normalized = try? normalize_package_full_path(full_path)
    let normalized_path = match normalized {
      Ok(path) => Some(path)
      Err(_) => None
    }
    let exists = match normalized_path {
      Some(path) => entry_index.contains(path)
      None => false
    }
    let usable = match normalized_path {
      Some(path) => entry_index.contains(path)
      None => false
    }
    out.push({
      full_path,
      media_type,
      normalized_path,
      exists,
      usable,
      is_primary: false,
    })
  }

  if out.length() == 0 {
    raise InvalidXml("container.xml missing rootfile")
  }

  let primary_index = first_usable_rootfile_index(out)
  if primary_index < 0 {
    raise InvalidXml("container.xml has no usable rootfile")
  }
  let primary_path = out[primary_index].normalized_path.unwrap_or("")
  let finalized : Array[EpubRootfileInfo] = []
  for i in 0..<out.length() {
    let item = out[i]
    finalized.push({
      full_path: item.full_path,
      media_type: item.media_type,
      normalized_path: item.normalized_path,
      exists: item.exists,
      usable: item.usable,
      is_primary: item.normalized_path == Some(primary_path) &&
      i == primary_index,
    })
  }
  finalized
}

///|
fn select_primary_rootfile(
  rootfiles : Array[EpubRootfileInfo],
) -> String raise EpubError {
  for item in rootfiles {
    if item.is_primary {
      match item.normalized_path {
        Some(path) => return path
        None => ()
      }
    }
  }
  raise InvalidXml("container.xml has no usable rootfile")
}

///|
fn first_usable_rootfile_index(rootfiles : Array[EpubRootfileInfo]) -> Int {
  for i in 0..<rootfiles.length() {
    if rootfiles[i].usable {
      return i
    }
  }
  -1
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
fn find_ncx_nav_item(
  opf_xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
) -> EpubManifestItem? {
  let spine_tags = collect_start_tags(opf_xml, "spine")
  if spine_tags.length() == 0 {
    return None
  }
  let attrs = parse_tag_attributes(spine_tags[0])
  let toc_id = get_optional_attr(attrs, "toc").trim().to_owned()
  if toc_id == "" {
    return None
  }
  match manifest_by_id.get(toc_id) {
    Some(item) => if manifest_item_is_ncx(item) { Some(item) } else { None }
    None => None
  }
}

///|
fn find_cover_item(
  opf_xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
  manifest : Array[EpubManifestItem],
  guide_cover_path : String?,
) -> EpubManifestItem? {
  for item in manifest {
    if has_manifest_property(item, "cover-image") {
      return Some(item)
    }
  }

  let cover_id = tag_attr_with_attr(opf_xml, "meta", "name", "cover", "content")
  match cover_id {
    Some(id) =>
      match manifest_by_id.get(id.trim().to_owned()) {
        Some(item) => Some(item)
        None => find_cover_manifest_by_path(manifest, guide_cover_path)
      }
    None => find_cover_manifest_by_path(manifest, guide_cover_path)
  }
}

///|
fn find_cover_manifest_by_path(
  manifest : Array[EpubManifestItem],
  guide_cover_path : String?,
) -> EpubManifestItem? {
  let path = match guide_cover_path {
    Some(v) => v
    None => return None
  }
  for item in manifest {
    if item.resolved_path == path && manifest_item_is_image(item) {
      return Some(item)
    }
  }
  None
}

///|
fn manifest_item_is_image(item : EpubManifestItem) -> Bool {
  let media_type = match item.media_type {
    Some(v) => v.trim().to_owned().to_lower()
    None => ""
  }
  media_type.has_prefix("image/")
}

///|
fn manifest_item_is_ncx(item : EpubManifestItem) -> Bool {
  match item.media_type {
    Some(v) => v.trim().to_owned().to_lower() == "application/x-dtbncx+xml"
    None => false
  }
}

///|
fn find_guide_cover_path(
  opf_xml : String,
  opf_dir : String,
) -> String? raise EpubError {
  let guide_tags = collect_start_tags(opf_xml, "guide")
  if guide_tags.length() == 0 {
    return None
  }
  let guide_region = match tag_content(opf_xml, guide_tags[0], "guide") {
    Some(body) => body
    None => return None
  }

  for tag in collect_start_tags(guide_region, "reference") {
    let attrs = parse_tag_attributes(tag)
    let ref_type = get_optional_attr(attrs, "type").trim().to_owned().to_lower()
    if ref_type != "cover" {
      continue
    }
    let href = get_optional_attr(attrs, "href").trim().to_owned()
    if href == "" {
      continue
    }
    return Some(resolve_opf_href(opf_dir, href))
  }
  None
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
fn collect_cover_candidates(
  opf_xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
  manifest : Array[EpubManifestItem],
  guide_cover_path : String?,
  selected_cover_item : EpubManifestItem?,
) -> Array[EpubCoverCandidate] {
  let out : Array[EpubCoverCandidate] = []
  let selected_path = match selected_cover_item {
    Some(item) => Some(item.resolved_path)
    None => None
  }

  for item in manifest {
    if has_manifest_property(item, "cover-image") {
      out.push({
        source: EpubCoverCandidateSource::ManifestProperty,
        path: item.resolved_path,
        manifest_id: Some(item.id),
        media_type: item.media_type,
        is_image: manifest_item_is_image(item),
        selected: selected_path == Some(item.resolved_path),
      })
    }
  }

  let cover_id = tag_attr_with_attr(opf_xml, "meta", "name", "cover", "content")
  match cover_id {
    Some(id) =>
      match manifest_by_id.get(id.trim().to_owned()) {
        Some(item) =>
          out.push({
            source: EpubCoverCandidateSource::MetadataCover,
            path: item.resolved_path,
            manifest_id: Some(item.id),
            media_type: item.media_type,
            is_image: manifest_item_is_image(item),
            selected: selected_path == Some(item.resolved_path),
          })
        None => ()
      }
    None => ()
  }

  match guide_cover_path {
    Some(path) =>
      out.push({
        source: EpubCoverCandidateSource::GuideReference,
        path,
        manifest_id: find_manifest_id_by_path(manifest, path),
        media_type: find_manifest_media_type_by_path(manifest, path),
        is_image: guide_cover_path_is_image(manifest, path),
        selected: selected_path == Some(path),
      })
    None => ()
  }

  out.sort_by(fn(a, b) {
    cover_candidate_sort_key(a)[:].lexical_compare(
      cover_candidate_sort_key(b)[:],
    )
  })
  dedupe_cover_candidates(out)
}

///|
fn find_manifest_id_by_path(
  manifest : Array[EpubManifestItem],
  path : String,
) -> String? {
  for item in manifest {
    if item.resolved_path == path {
      return Some(item.id)
    }
  }
  None
}

///|
fn find_manifest_media_type_by_path(
  manifest : Array[EpubManifestItem],
  path : String,
) -> String? {
  for item in manifest {
    if item.resolved_path == path {
      return item.media_type
    }
  }
  None
}

///|
fn guide_cover_path_is_image(
  manifest : Array[EpubManifestItem],
  path : String,
) -> Bool {
  for item in manifest {
    if item.resolved_path == path {
      return manifest_item_is_image(item)
    }
  }
  false
}

///|
fn cover_candidate_sort_key(candidate : EpubCoverCandidate) -> String {
  cover_candidate_source_text(candidate.source) +
  ":" +
  candidate.path +
  ":" +
  candidate.manifest_id.unwrap_or("")
}

///|
fn cover_candidate_source_text(source : EpubCoverCandidateSource) -> String {
  match source {
    EpubCoverCandidateSource::ManifestProperty => "0"
    EpubCoverCandidateSource::MetadataCover => "1"
    EpubCoverCandidateSource::GuideReference => "2"
  }
}

///|
fn dedupe_cover_candidates(
  candidates : Array[EpubCoverCandidate],
) -> Array[EpubCoverCandidate] {
  let out : Array[EpubCoverCandidate] = []
  let seen : Map[String, Int] = Map::new()
  for candidate in candidates {
    let key = cover_candidate_sort_key(candidate)
    if !seen.contains(key) {
      seen.set(key, 1)
      out.push(candidate)
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
          out.push({ label, href, depth: 0, source_path: None })
        }
      }
      None => ()
    }
  }
  out
}

///|
fn parse_ncx_nav_points(
  xml : String,
  source_path : String,
) -> Array[EpubNavPoint] {
  let nav_map_tags = collect_start_tags(xml, "navMap")
  if nav_map_tags.length() == 0 {
    return []
  }
  let nav_map_region = match tag_content(xml, nav_map_tags[0], "navMap") {
    Some(body) => body
    None => return []
  }
  parse_ncx_nav_points_from_elements(
    collect_direct_child_elements(nav_map_region, "navPoint"),
    source_path,
    0,
  )
}

///|
fn parse_ncx_nav_points_from_elements(
  elements : Array[String],
  source_path : String,
  depth : Int,
) -> Array[EpubNavPoint] {
  let out : Array[EpubNavPoint] = []
  for nav_point_xml in elements {
    let label = match tag_text(nav_point_xml, "text") {
      Some(v) => v.trim().to_owned()
      None => ""
    }
    let href = match extract_safe_ncx_href(nav_point_xml, source_path) {
      Some(v) => v
      None => ""
    }
    if label != "" && href != "" {
      out.push({ label, href, depth, source_path: Some(source_path) })
    }

    let child_nav_points = collect_direct_child_elements(
      inner_element_content(nav_point_xml, "navPoint"),
      "navPoint",
    )
    if child_nav_points.length() > 0 {
      out.append(
        parse_ncx_nav_points_from_elements(
          child_nav_points,
          source_path,
          depth + 1,
        ),
      )
    }
  }
  out
}

///|
fn inner_element_content(xml : String, local_name : String) -> String {
  let tags = collect_start_tags(xml, local_name)
  if tags.length() == 0 {
    return ""
  }
  match tag_content(xml, tags[0], local_name) {
    Some(body) => body
    None => ""
  }
}

///|
fn extract_safe_ncx_href(
  nav_point_xml : String,
  source_path : String,
) -> String? {
  let content_tags = collect_start_tags(nav_point_xml, "content")
  if content_tags.length() == 0 {
    return None
  }
  let attrs = parse_tag_attributes(content_tags[0])
  let raw_href = get_optional_attr(attrs, "src").trim().to_owned()
  if raw_href == "" {
    return None
  }
  if raw_href.has_prefix("#") {
    return Some(raw_href)
  }
  let ncx_dir = dirname_of_part(source_path)
  let validated = try? resolve_opf_href(ncx_dir, raw_href)
  match validated {
    Ok(_) => Some(raw_href)
    Err(_) => None
  }
}

///|
fn collect_direct_child_elements(
  xml : String,
  local_name : String,
) -> Array[String] {
  collect_direct_child_elements_in_parent(xml, local_name)
}

///|
fn collect_direct_child_elements_in_parent(
  xml : String,
  local_name : String,
) -> Array[String] {
  let out : Array[String] = []
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0
  let mut depth = 0
  let mut element_start = -1

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }
    if i + 1 < n && (chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let tag = xml[i:tag_end + 1].to_owned()
    if i + 1 < n && chars[i + 1] == '/' {
      if end_tag_local_name(tag) == local_name {
        depth -= 1
        if depth == 0 && element_start >= 0 {
          out.push(xml[element_start:tag_end + 1].to_owned())
          element_start = -1
        }
      }
      i = tag_end + 1
      continue
    }

    if start_tag_local_name(tag) == local_name {
      if depth == 0 {
        element_start = i
      }
      if start_tag_is_self_closing(tag) {
        if depth == 0 {
          out.push(xml[i:tag_end + 1].to_owned())
          element_start = -1
        }
      } else {
        depth += 1
      }
    }
    i = tag_end + 1
  }

  out
}

///|
fn parse_opf_spine(
  xml : String,
  manifest_by_id : Map[String, EpubManifestItem],
) -> Array[EpubSpineItem] raise EpubError {
  let out : Array[EpubSpineItem] = []
  let mut spine_index = 0
  for tag in collect_start_tags(xml, "itemref") {
    let attrs = parse_tag_attributes(tag)
    let idref = get_required_attr(attrs, "idref").trim().to_owned()
    let linear = get_optional_attr(attrs, "linear").trim().to_lower() != "no"
    match manifest_by_id.get(idref) {
      Some(item) =>
        out.push({
          idref,
          linear,
          spine_index,
          manifest_item: Some(item),
          resolved_path: Some(item.resolved_path),
        })
      None =>
        out.push({
          idref,
          linear,
          spine_index,
          manifest_item: None,
          resolved_path: None,
        })
    }
    spine_index += 1
  }
  out
}

///|
fn spine_item_supported(item : EpubSpineItem) -> Bool {
  let media_type = match item.manifest_item {
    Some(manifest_item) =>
      match manifest_item.media_type {
        Some(v) => v.trim().to_owned().to_lower()
        None => ""
      }
    None => return false
  }
  if media_type == "application/xhtml+xml" || media_type == "text/html" {
    return true
  }

  let path = match item.resolved_path {
    Some(v) => v
    None => return false
  }
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

///|
fn metadata_entries_of(metadata : EpubMetadata) -> Array[EpubMetadataEntry] {
  let out : Array[EpubMetadataEntry] = []
  push_metadata_entry(out, "title", metadata.title)
  push_metadata_entry(out, "creator", metadata.creator)
  push_metadata_entry(out, "language", metadata.language)
  push_metadata_entry(out, "identifier", metadata.identifier)
  push_metadata_entry(out, "publisher", metadata.publisher)
  push_metadata_entry(out, "subject", metadata.subject)
  push_metadata_entry(out, "date", metadata.date)
  push_metadata_entry(out, "modified", metadata.modified)
  out
}

///|
fn push_metadata_entry(
  out : Array[EpubMetadataEntry],
  name : String,
  value : String?,
) -> Unit {
  match value {
    Some(v) => if v.trim() != "" { out.push({ name, value: v }) }
    None => ()
  }
}

///|
fn classify_invalid_xml_detail(msg : String) -> EpubErrorInfo {
  if msg.contains("container.xml missing rootfile") ||
    msg.contains("container.xml has no usable rootfile") {
    {
      kind: EpubErrorKind::MissingRootfile,
      detail: msg,
      part_name: Some("META-INF/container.xml"),
      rootfile_path: None,
      manifest_id: None,
      source_part: Some("META-INF/container.xml"),
      path: None,
      href: None,
    }
  } else if msg.contains("duplicate manifest id: ") {
    {
      kind: EpubErrorKind::DuplicateManifestId,
      detail: msg,
      part_name: None,
      rootfile_path: None,
      manifest_id: extract_duplicate_manifest_id(msg),
      source_part: None,
      path: None,
      href: None,
    }
  } else {
    {
      kind: EpubErrorKind::InvalidXml,
      detail: msg,
      part_name: None,
      rootfile_path: None,
      manifest_id: None,
      source_part: None,
      path: None,
      href: None,
    }
  }
}

///|
fn classify_invalid_path_detail(path : String) -> EpubErrorInfo {
  let lower = path.to_lower()
  let kind = if has_scheme_like_prefix(lower) {
    EpubErrorKind::RemoteResourceBlocked
  } else {
    EpubErrorKind::UnsafeHref
  }
  {
    kind,
    detail: path,
    part_name: None,
    rootfile_path: None,
    manifest_id: None,
    source_part: None,
    path: Some(path),
    href: Some(path),
  }
}

///|
fn extract_duplicate_manifest_id(msg : String) -> String? {
  let prefix = "duplicate manifest id: "
  let idx = find_substring(msg, prefix, 0)
  match idx {
    None => None
    Some(start) => {
      let id = msg[start + prefix.length():].trim().to_owned()
      if id == "" {
        None
      } else {
        Some(id)
      }
    }
  }
}

///|
fn compare_validation_issue(
  a : EpubValidationIssue,
  b : EpubValidationIssue,
) -> Int {
  validation_issue_sort_key(a)[:].lexical_compare(
    validation_issue_sort_key(b)[:],
  )
}

///|
fn validation_issue_sort_key(issue : EpubValidationIssue) -> String {
  validation_severity_text(issue.severity) +
  ":" +
  validation_issue_kind_text(issue.kind) +
  ":" +
  issue.spine_index.map(fn(v) { v.to_string() }).unwrap_or("") +
  ":" +
  issue.spine_idref.unwrap_or("") +
  ":" +
  issue.manifest_id.unwrap_or("") +
  ":" +
  issue.part_name.unwrap_or("") +
  ":" +
  issue.href.unwrap_or("")
}

///|
fn validation_severity_text(severity : EpubValidationSeverity) -> String {
  match severity {
    EpubValidationSeverity::Error => "0"
    EpubValidationSeverity::Warning => "1"
  }
}

///|
fn validation_issue_kind_text(kind : EpubValidationIssueKind) -> String {
  match kind {
    EpubValidationIssueKind::MissingManifestItem => "MissingManifestItem"
    EpubValidationIssueKind::MissingSpineTarget => "MissingSpineTarget"
    EpubValidationIssueKind::UnsupportedSpineItem => "UnsupportedSpineItem"
    EpubValidationIssueKind::DuplicateSpineIdref => "DuplicateSpineIdref"
    EpubValidationIssueKind::MissingNavigationDocument =>
      "MissingNavigationDocument"
    EpubValidationIssueKind::MultipleRootfiles => "MultipleRootfiles"
  }
}
