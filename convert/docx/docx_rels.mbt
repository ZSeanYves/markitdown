///|
fn rels_to_target_map(
  rels : Array[@ox.OoxmlRelationship],
) -> Map[String, String] {
  let m : Map[String, String] = Map::new()
  for rel in rels {
    m.set(rel.id, rel.target)
  }
  m
}

///|
fn normalize_doc_part_target(target : String) -> String {
  if target == "" {
    return ""
  }

  if target.has_prefix("/") {
    return target[1:].to_owned()
  }

  if target.has_prefix("word/") {
    target
  } else {
    "word/" + target
  }
}

///|
fn build_docx_asset_path_map(
  rels : Map[String, String],
  out_root : String,
) -> Map[String, String] {
  let media_targets : Array[String] = []
  for entry in rels {
    let (_, target) = entry
    let normalized = normalize_doc_part_target(target)
    if normalized.has_prefix("word/media/") {
      media_targets.push(normalized)
    }
  }
  media_targets.sort()

  let out : Map[String, String] = Map::new()
  let next_idx : Ref[Int] = { val: 0 }
  for target in media_targets {
    if out.contains(target) {
      continue
    }
    let ext = image_ext_from_target(target)
    let rel_out = @cor.next_image_asset_rel_path_unique(next_idx, ext, out_root)
    out.set(target, rel_out)
  }
  out
}

///|
fn rid_to_asset_path(
  target : String,
  asset_by_target : Map[String, String],
) -> String {
  let normalized = normalize_doc_part_target(target)
  asset_by_target.get(normalized).unwrap_or("")
}

///|
fn image_ext_from_target(target : String) -> String {
  let b = @cor.basename(target).to_lower()
  if b.has_suffix(".png") {
    return "png"
  }
  if b.has_suffix(".jpg") {
    return "jpg"
  }
  if b.has_suffix(".jpeg") {
    return "jpeg"
  }
  if b.has_suffix(".gif") {
    return "gif"
  }
  if b.has_suffix(".bmp") {
    return "bmp"
  }
  if b.has_suffix(".tif") || b.has_suffix(".tiff") {
    return "tiff"
  }
  if b.has_suffix(".webp") {
    return "webp"
  }
  "img"
}
