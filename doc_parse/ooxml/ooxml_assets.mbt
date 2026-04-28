///|
/// List media assets under `word/media`, `ppt/media`, and `xl/media`.
///
/// Each result includes the asset part name, resolved content type, byte size,
/// and internal relationships that reference the asset.
pub fn list_media_assets(
  pkg : OoxmlPackage,
) -> Array[OoxmlAsset] raise OoxmlError {
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
        out.push({ source_part: source, rel_id: rel.id, rel_type: rel.rel_type })
      }
    }
  }

  out
}
