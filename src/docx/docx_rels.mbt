///|
fn rels_to_target_map(rels : Array[@ox.OoxmlRelationship]) -> Map[String, String] {
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
    return target[1:].to_string()
  }

  if target.has_prefix("word/") {
    target
  } else {
    "word/" + target
  }
}

///|
fn rid_to_asset_path(target : String) -> String {
  "assets/" + @cor.basename(target)
}
