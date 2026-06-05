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
  find_relationship_by_id_from_normalized_source(pkg, source, rel_id)
}

///|
/// Find relationships whose type equals or ends with `rel_type_suffix`.
pub fn find_relationships_by_type(
  pkg : OoxmlPackage,
  source_part : String,
  rel_type_suffix : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  find_relationships_by_type_from_normalized_source(
    pkg, source, rel_type_suffix,
  )
}

///|
/// Read package-root relationships from `_rels/.rels`.
pub fn read_package_relationships(
  pkg : OoxmlPackage,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let index = read_relationship_index_from_rels_part(pkg, "", "_rels/.rels")
  clone_ooxml_relationships(index.relationships)
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

  let index = read_relationship_index_from_rels_part(pkg, normalized, rels_part)
  clone_ooxml_relationships(index.relationships)
}

///|
/// Resolve a relationship target by id for the package root or a source part.
pub fn resolve_relationship(
  pkg : OoxmlPackage,
  source_part : String,
  rel_id : String,
) -> String raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  match find_relationship_by_id_from_normalized_source(pkg, source, rel_id) {
    Some(rel) => return rel.resolved_target
    None => ()
  }

  let source_display = if source == "" { "(package)" } else { source }
  raise RelationshipNotFound(source_display, rel_id)
}

///|
fn find_relationship_by_id_from_normalized_source(
  pkg : OoxmlPackage,
  source : String,
  rel_id : String,
) -> OoxmlRelationship? raise OoxmlError {
  match read_relationship_index_from_normalized_source(pkg, source) {
    Some(index) =>
      match index.by_id.get(rel_id) {
        Some(rel) => {
          pkg.relationship_cache.by_id_hit_count.val += 1
          Some(rel)
        }
        None => {
          pkg.relationship_cache.by_id_miss_count.val += 1
          None
        }
      }
    None => {
      pkg.relationship_cache.by_id_miss_count.val += 1
      None
    }
  }
}

///|
fn find_relationships_by_type_from_normalized_source(
  pkg : OoxmlPackage,
  source : String,
  rel_type_suffix : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  pkg.relationship_cache.by_type_query_count.val += 1
  let out : Array[OoxmlRelationship] = []
  match read_relationship_index_from_normalized_source(pkg, source) {
    Some(index) =>
      for entry in index.by_type {
        let (rel_type, rels) = entry
        if rel_type.has_suffix(rel_type_suffix) ||
          rel_type == rel_type_suffix {
          out.append(clone_ooxml_relationships(rels))
        }
      }
    None => ()
  }
  out
}

///|
fn read_relationship_index_from_normalized_source(
  pkg : OoxmlPackage,
  source : String,
) -> OoxmlRelationshipIndex? raise OoxmlError {
  let rels_part = if source == "" {
    "_rels/.rels"
  } else {
    rels_part_name_for_source(source)
  }
  if source != "" && !pkg.part_index.contains(rels_part) {
    return None
  }
  Some(read_relationship_index_from_rels_part(pkg, source, rels_part))
}

///|
fn read_relationship_index_from_rels_part(
  pkg : OoxmlPackage,
  source_part : String,
  rels_part : String,
) -> OoxmlRelationshipIndex raise OoxmlError {
  let key = normalize_part_name(rels_part)
  match pkg.relationship_cache.index_by_rels_part.get(key) {
    Some(index) => {
      pkg.relationship_cache.relationships_hit_count.val += 1
      return index
    }
    None => ()
  }

  let rels_xml = read_part_text(pkg, key)
  let rels = parse_relationships_xml(rels_xml, source_part, key)
  let index = build_ooxml_relationship_index(rels)
  pkg.relationship_cache.relationships_miss_count.val += 1
  pkg.relationship_cache.index_by_rels_part.set(key, index)
  index
}

///|
fn build_ooxml_relationship_index(
  rels : Array[OoxmlRelationship],
) -> OoxmlRelationshipIndex {
  let relationships = clone_ooxml_relationships(rels)
  let by_id : Map[String, OoxmlRelationship] = Map([])
  let by_type : Map[String, Array[OoxmlRelationship]] = Map([])
  for rel in relationships {
    if !by_id.contains(rel.id) {
      by_id.set(rel.id, rel)
    }
    match by_type.get(rel.rel_type) {
      Some(items) => items.push(rel)
      None => by_type.set(rel.rel_type, [rel])
    }
  }
  { relationships, by_id, by_type }
}

///|
fn clone_ooxml_relationships(
  rels : Array[OoxmlRelationship],
) -> Array[OoxmlRelationship] {
  let out : Array[OoxmlRelationship] = []
  for rel in rels {
    out.push(rel)
  }
  out
}

///|
fn parse_relationships_xml(
  xml : String,
  source_part : String,
  rels_part_name : String,
) -> Array[OoxmlRelationship] raise OoxmlError {
  let rels : Array[OoxmlRelationship] = []

  for tag in collect_start_tags(xml, "Relationship") {
    let attrs = parse_tag_attributes(tag)
    let id = get_required_attr(attrs, "Id") catch {
      _ =>
        raise InvalidXml(
          malformed_relationships_detail(
            rels_part_name, source_part, "missing attribute: Id",
          ),
        )
    }
    let rel_type = get_required_attr(attrs, "Type") catch {
      _ =>
        raise InvalidXml(
          malformed_relationships_detail(
            rels_part_name, source_part, "missing attribute: Type",
          ),
        )
    }
    let target = get_required_attr(attrs, "Target") catch {
      _ =>
        raise InvalidXml(
          malformed_relationships_detail(
            rels_part_name, source_part, "missing attribute: Target",
          ),
        )
    }
    let target_mode_raw = get_optional_attr(attrs, "TargetMode")
    let target_mode = parse_target_mode(target_mode_raw)
    let resolved_target = resolve_target(source_part, target, target_mode) catch {
      InvalidPartPath(path) =>
        raise InvalidPartPath(
          "unsafe relationship target: " +
          malformed_relationships_detail(rels_part_name, source_part, path),
        )
      e => raise e
    }

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

///|
fn malformed_relationships_detail(
  rels_part_name : String,
  source_part : String,
  detail : String,
) -> String {
  let source = if source_part == "" { "(package)" } else { source_part }
  "relationships rels_part=\"" +
  rels_part_name +
  "\" source=\"" +
  source +
  "\": " +
  detail
}
