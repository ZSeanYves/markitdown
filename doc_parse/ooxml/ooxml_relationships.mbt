///|
/// Return whether a source part has a corresponding `.rels` part.
///
/// Use an empty source part for package-root relationships.
pub fn has_relationships_part(pkg : OoxmlPackage, source_part : String) -> Bool {
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
/// Find a relationship by id for the package root or a source part.
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
/// Find relationships whose type equals or ends with `rel_type_suffix`.
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
    if rel.rel_type.has_suffix(rel_type_suffix) ||
      rel.rel_type == rel_type_suffix {
      out.push(rel)
    }
  }
  out
}

///|
/// Read package-root relationships from `_rels/.rels`.
pub fn read_package_relationships(
  pkg : OoxmlPackage,
) -> Array[OoxmlRelationship] raise OoxmlError {
  read_relationships_from_rels_part(pkg, "", "_rels/.rels")
}

///|
/// Read relationships for a source part.
///
/// Missing `.rels` parts are treated as an empty relationship list.
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
/// Resolve a relationship target by id for the package root or a source part.
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
fn parse_target_mode(value : String) -> OoxmlTargetMode {
  if value == "External" {
    External
  } else {
    Internal
  }
}
