///|
fn empty_docx_relationship_context() -> DocxRelationshipContext {
  {
    document_relationships: [],
    targets_by_rid: Map::new(),
    hyperlink_targets_by_rid: Map::new(),
  }
}

///|
fn build_docx_relationship_context(
  rels : Array[@ox.OoxmlRelationship],
) -> DocxRelationshipContext {
  let targets_by_rid : Map[String, String] = Map::new()
  let hyperlink_targets_by_rid : Map[String, String] = Map::new()

  for rel in rels {
    targets_by_rid.set(rel.id, rel.resolved_target)

    if rel.rel_type.has_suffix("/hyperlink") &&
      rel.target_mode == @ox.External &&
      rel.resolved_target.trim() != "" {
      hyperlink_targets_by_rid.set(rel.id, rel.resolved_target)
    }
  }

  { document_relationships: rels, targets_by_rid, hyperlink_targets_by_rid }
}

///|
fn lookup_doc_relationship_target(
  ctx : DocxRelationshipContext,
  rid : String,
) -> String {
  ctx.targets_by_rid.get(rid).unwrap_or("")
}

///|
fn lookup_doc_hyperlink_target(
  ctx : DocxRelationshipContext,
  rid : String,
) -> String {
  profile_hyperlink_target_lookup_call()
  ctx.hyperlink_targets_by_rid.get(rid).unwrap_or("")
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
  ctx : DocxRelationshipContext,
  out_root : String,
) -> Map[String, String] {
  let media_targets : Array[String] = []
  for rel in ctx.document_relationships {
    let normalized = normalize_doc_part_target(rel.resolved_target)
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
