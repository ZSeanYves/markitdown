///|
/// Human-readable OOXML package inspection helpers.
///
/// These helpers are intentionally read-only and lossy: they are for debugging
/// package structure, not for feeding conversion logic.
pub fn inspect_ooxml_inventory(pkg : OoxmlPackage) -> OoxmlPackageInventory {
  match pkg.inventory_cache.val {
    Some(inventory) => inventory
    None => {
      let inventory = build_package_inventory(pkg)
      pkg.inventory_cache.val = Some(inventory)
      inventory
    }
  }
}

///|
pub fn list_part_infos(pkg : OoxmlPackage) -> Array[OoxmlPartInfo] {
  inspect_ooxml_inventory(pkg).parts
}

///|
fn build_package_inventory(pkg : OoxmlPackage) -> OoxmlPackageInventory {
  let parts : Array[OoxmlPartInfo] = []
  let content_types : Array[OoxmlContentTypeInfo] = []
  let relationship_source_parts : Array[String] = []
  let relationship_parts : Array[String] = []
  for entry in pkg.content_types_default {
    let (extension, content_type) = entry
    content_types.push({
      kind: OoxmlContentTypeInfoKind::DefaultExtension,
      extension: Some(extension),
      part_name: None,
      content_type,
    })
  }
  content_types.sort_by(fn(a, b) { compare_content_type_infos(a, b) })
  for part in list_parts(pkg) {
    if part == "[Content_Types].xml" {
      continue
    }
    if is_relationships_part_name(part) {
      relationship_parts.push(part)
    }
    parts.push({
      part_name: part,
      content_type: lookup_content_type(pkg, part) catch {
        _ => None
      },
      size: part_size(pkg, part),
      is_relationships_part: is_relationships_part_name(part),
      has_relationships: has_relationships_part(pkg, part),
    })
    if has_relationships_part(pkg, part) {
      relationship_source_parts.push(part)
    }
  }
  for entry in pkg.content_types_override {
    let (part_name, content_type) = entry
    content_types.push({
      kind: OoxmlContentTypeInfoKind::OverridePart,
      extension: None,
      part_name: Some(part_name),
      content_type,
    })
  }
  parts.sort_by(fn(a, b) { a.part_name[:].lexical_compare(b.part_name[:]) })
  relationship_source_parts.sort()
  relationship_parts.sort()
  let media_asset_count = (list_media_assets(pkg) catch { _ => [] }).length()
  {
    parts,
    content_types,
    relationship_source_parts,
    relationship_parts,
    part_count: parts.length(),
    relationship_part_count: relationship_parts.length(),
    content_type_entry_count: content_types.length(),
    media_asset_count,
    has_core_properties: has_part(pkg, "docProps/core.xml"),
    has_app_properties: has_part(pkg, "docProps/app.xml"),
  }
}

///|
fn compare_content_type_infos(
  a : OoxmlContentTypeInfo,
  b : OoxmlContentTypeInfo,
) -> Int {
  let a_key = content_type_sort_key(a)
  let b_key = content_type_sort_key(b)
  a_key[:].lexical_compare(b_key[:])
}

///|
fn content_type_sort_key(info : OoxmlContentTypeInfo) -> String {
  match info.kind {
    OoxmlContentTypeInfoKind::DefaultExtension =>
      "0:" + string_opt_or_empty(info.extension)
    OoxmlContentTypeInfoKind::OverridePart =>
      "1:" + string_opt_or_empty(info.part_name)
  }
}

///|
fn string_opt_or_empty(value : String?) -> String {
  match value {
    Some(v) => v
    None => ""
  }
}

///|
fn is_relationships_part_name(part_name : String) -> Bool {
  (part_name.has_suffix(".rels") && part_name.contains("/_rels/")) ||
  part_name == "_rels/.rels"
}

///|
fn part_size(pkg : OoxmlPackage, part_name : String) -> Int {
  pkg.part_size_index.get(part_name).unwrap_or(0)
}
