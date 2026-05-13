///|
fn docx_target_mode_from_ooxml(mode : @ox.OoxmlTargetMode) -> DocxTargetMode {
  match mode {
    @ox.Internal => DocxTargetMode::Internal
    @ox.External => DocxTargetMode::External
  }
}

///|
fn docx_relationship_from_ooxml(
  rel : @ox.OoxmlRelationship,
) -> DocxRelationship {
  {
    id: rel.id,
    rel_type: rel.rel_type,
    target: rel.target,
    target_mode: docx_target_mode_from_ooxml(rel.target_mode),
    resolved_target: rel.resolved_target,
  }
}

///|
fn build_docx_relationship_index(
  rels : Array[@ox.OoxmlRelationship],
) -> DocxRelationshipIndex {
  let relationships : Array[DocxRelationship] = []
  let targets_by_rid : Map[String, String] = Map([])
  let hyperlink_targets_by_rid : Map[String, String] = Map([])

  for rel in rels {
    let docx_rel = docx_relationship_from_ooxml(rel)
    relationships.push(docx_rel)
    targets_by_rid.set(rel.id, rel.resolved_target)
    if rel.rel_type.has_suffix("/hyperlink") &&
      rel.target_mode == @ox.External &&
      rel.resolved_target.trim() != "" {
      hyperlink_targets_by_rid.set(rel.id, rel.resolved_target)
    }
  }

  { relationships, targets_by_rid, hyperlink_targets_by_rid }
}

///|
fn read_docx_relationship_index(
  pkg : @ox.OoxmlPackage,
  source_part : String,
) -> DocxRelationshipIndex {
  let rels = @ox.read_part_relationships(pkg, source_part) catch {
    _ => return empty_docx_relationship_index()
  }
  build_docx_relationship_index(rels)
}

///|
fn lookup_docx_relationship_target(
  rels : DocxRelationshipIndex,
  rid : String,
) -> String {
  rels.targets_by_rid.get(rid).unwrap_or("")
}

///|
fn lookup_docx_hyperlink_target(
  rels : DocxRelationshipIndex,
  rid : String,
) -> String {
  rels.hyperlink_targets_by_rid.get(rid).unwrap_or("")
}

///|
fn normalize_docx_part_target(target : String) -> String {
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
fn lookup_docx_part_target_opt(
  rels : DocxRelationshipIndex,
  rid : String,
) -> String? {
  let target = lookup_docx_relationship_target(rels, rid)
  let normalized = normalize_docx_part_target(target)
  if normalized == "" {
    None
  } else {
    Some(normalized)
  }
}
