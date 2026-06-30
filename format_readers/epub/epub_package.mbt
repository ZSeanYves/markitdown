///|
pub fn open_epub_package(
  bytes : Bytes,
  source_name : String,
) -> EpubPackage raise EpubError {
  let archive = open_epub_archive(bytes)
  let (entries, entry_index) = plan_archive_entries(archive)

  if entry_index.contains("META-INF/encryption.xml") {
    raise UnsupportedFeature("DRM/encryption is not supported")
  }

  let mimetype = read_optional_text_part(archive, entry_index, "mimetype")
  let container_payload = read_required_xml_part_payload(
    archive, entry_index, "META-INF/container.xml",
  )
  let rootfiles = parse_container_rootfiles(container_payload.text, entry_index)
  let rootfile_path = select_primary_rootfile(rootfiles)
  let opf_payload = read_required_xml_part_payload(
    archive, entry_index, rootfile_path,
  )
  let opf_dir = dirname_of_part(rootfile_path)
  let metadata = parse_opf_metadata(opf_payload.text)
  let manifest = parse_opf_manifest(opf_payload.text, opf_dir)
  let manifest_by_id : Map[String, EpubManifestItem] = Map([])
  for item in manifest {
    if manifest_by_id.contains(item.id) {
      raise InvalidXml("duplicate manifest id: " + item.id)
    }
    manifest_by_id.set(item.id, item)
  }
  let spine = parse_opf_spine(opf_payload.text, manifest_by_id)
  if spine.length() == 0 {
    raise InvalidXml("missing spine itemref")
  }
  let nav_document_item = find_nav_item(manifest)
  let ncx_item = find_ncx_nav_item(opf_payload.text, manifest_by_id)
  let nav_item = match nav_document_item {
    Some(item) => Some(item)
    None => ncx_item
  }
  let guide_cover_path = find_guide_cover_path(opf_payload.text, opf_dir)
  let cover_item = find_cover_item(
    opf_payload.text,
    manifest_by_id,
    manifest,
    guide_cover_path,
  )
  let cover_candidates = collect_cover_candidates(
    opf_payload.text,
    manifest_by_id,
    manifest,
    guide_cover_path,
    cover_item,
  )
  let nav_points = match nav_item {
    Some(item) =>
      try {
        if manifest_item_is_ncx(item) {
          parse_ncx_nav_points(
            read_required_xml_part_payload(
              archive,
              entry_index,
              item.resolved_path,
            ).text,
            item.resolved_path,
          )
        } else {
          parse_nav_points(
            read_required_xml_part_payload(
              archive,
              entry_index,
              item.resolved_path,
            ).text,
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
fn open_epub_archive(bytes : Bytes) -> @zip.ZipArchive raise EpubError {
  @zip.open_zip(bytes) catch {
    e => raise ZipError(e.to_string())
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
  let seen_idrefs : Map[String, Int] = Map([])
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
        match item.manifest_item {
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
  let normalized = try normalize_package_full_path(part_name) |> Ok catch {
    e => Err(e)
  }
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
    let normalized = try normalize_package_full_path(full_path) |> Ok catch {
      e => Err(e)
    }
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
      resolved_path: resolve_manifest_href(opf_dir, href),
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
fn manifest_item_is_ncx(item : EpubManifestItem) -> Bool {
  match item.media_type {
    Some(v) => v.trim().to_owned().to_lower() == "application/x-dtbncx+xml"
    None => false
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
          resolved_path: if manifest_href_is_non_local(item.href) {
            None
          } else {
            Some(item.resolved_path)
          },
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
