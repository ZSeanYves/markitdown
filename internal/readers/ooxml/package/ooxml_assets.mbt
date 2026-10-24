///|
/// List media assets under `word/media`, `ppt/media`, and `xl/media`.
///
/// Each result includes the asset part name, resolved content type, declared
/// uncompressed byte size, and internal relationships that reference it.
/// Inventory never decodes media; read_part_bytes still validates the actual
/// decoded size and CRC when an asset is materialized.
pub async fn list_media_assets(
  pkg : OoxmlPackage,
) -> Array[OoxmlAsset] raise OoxmlError {
  let out : Array[OoxmlAsset] = []

  for part in list_parts(pkg) {
    if !is_media_part(part) {
      continue
    }

    let content_type = lookup_content_type(pkg, part)
    let size = match part_declared_size(pkg, part) {
      Some(value) if value >= 0 => value
      _ => raise MissingPart(part)
    }
    let refs = collect_asset_refs(pkg, part)
    out.push({
      part_name: part,
      content_type,
      ext: extension_of_part(part),
      size,
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
async fn collect_asset_refs(
  pkg : OoxmlPackage,
  media_part : String,
) -> Array[OoxmlAssetRef] noraise {
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
