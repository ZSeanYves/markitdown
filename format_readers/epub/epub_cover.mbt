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
        source: ManifestProperty,
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
            source: MetadataCover,
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
        source: GuideReference,
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
    ManifestProperty => "0"
    MetadataCover => "1"
    GuideReference => "2"
  }
}

///|
fn dedupe_cover_candidates(
  candidates : Array[EpubCoverCandidate],
) -> Array[EpubCoverCandidate] {
  let out : Array[EpubCoverCandidate] = []
  let seen : Map[String, Int] = Map([])
  for candidate in candidates {
    let key = cover_candidate_sort_key(candidate)
    if !seen.contains(key) {
      seen.set(key, 1)
      out.push(candidate)
    }
  }
  out
}
