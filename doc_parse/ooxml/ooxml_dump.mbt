///|
/// Human-readable OOXML package inspection helpers.
///
/// These helpers are intentionally read-only and lossy: they are for debugging
/// package structure, not for feeding conversion logic.
pub fn inspect_ooxml_inventory(pkg : OoxmlPackage) -> OoxmlPackageInventory {
  build_package_inventory(pkg)
}

///|
pub fn inspect_ooxml_package(pkg : OoxmlPackage) -> OoxmlPackageInspectReport {
  let inventory = inspect_ooxml_inventory(pkg)
  let package_relationships = read_relationship_infos(pkg, "", "_rels/.rels") catch {
    _ => []
  }
  let part_relationships : Array[OoxmlRelationshipInfo] = []
  for source in inventory.relationship_source_parts {
    let rels_part_name = rels_part_name_for_source(source)
    let infos = read_relationship_infos(pkg, source, rels_part_name) catch {
      _ => []
    }
    for info in infos {
      part_relationships.push(info)
    }
  }
  let media_assets = list_media_assets(pkg) catch { _ => [] }
  {
    part_count: inventory.parts.length(),
    content_type_default_count: count_string_map(pkg.content_types_default),
    content_type_override_count: count_string_map(pkg.content_types_override),
    relationship_source_count: inventory.relationship_source_parts.length(),
    package_relationship_count: package_relationships.length(),
    part_relationship_count: part_relationships.length(),
    media_asset_count: media_assets.length(),
    inventory,
    package_relationships,
    part_relationships,
    media_assets,
    core_properties: read_core_properties(pkg),
    app_properties: read_app_properties(pkg),
  }
}

///|
pub fn list_part_infos(pkg : OoxmlPackage) -> Array[OoxmlPartInfo] {
  inspect_ooxml_package(pkg).inventory.parts
}

///|
pub fn list_content_type_infos(
  pkg : OoxmlPackage,
) -> Array[OoxmlContentTypeInfo] {
  inspect_ooxml_package(pkg).inventory.content_types
}

///|
pub fn list_relationship_infos(
  pkg : OoxmlPackage,
  source_part : String,
) -> Array[OoxmlRelationshipInfo] raise OoxmlError {
  let source = normalize_source_part_for_resolve(source_part)
  let rels_part_name = if source == "" {
    "_rels/.rels"
  } else {
    rels_part_name_for_source(source)
  }
  read_relationship_infos(pkg, source, rels_part_name)
}

///|
pub fn dump_ooxml_package(pkg : OoxmlPackage) -> String {
  let out = StringBuilder::new()
  out.write_string(dump_package_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_relationships_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_media_assets_summary(pkg))
  out.write_string("\n")
  out.write_string(dump_properties_summary(pkg))
  out.to_string()
}

///|
/// Dump part and content-type counts from the package container.
pub fn dump_package_summary(pkg : OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[Content_Types]\n")
  out.write_string("part count: ")
  out.write_string(report.part_count.to_string())
  out.write_string("\n")
  out.write_string("content type defaults: ")
  out.write_string(report.content_type_default_count.to_string())
  out.write_string("\n")
  out.write_string("content type overrides: ")
  out.write_string(report.content_type_override_count.to_string())
  out.write_string("\n")
  out.to_string()
}

///|
/// Dump package-root relationships and all source-part relationships.
pub fn dump_relationships_summary(pkg : OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[relationships]\n")
  out.write_string("root relationships:\n")
  write_relationship_infos(out, report.package_relationships)

  for source in report.inventory.relationship_source_parts {
    out.write_string("source part: ")
    out.write_string(source)
    out.write_string("\n")
    let rels : Array[OoxmlRelationshipInfo] = []
    for rel in report.part_relationships {
      match rel.source_part {
        Some(value) => if value == source { rels.push(rel) }
        None => ()
      }
    }
    write_relationship_infos(out, rels)
  }
  out.to_string()
}

///|
/// Dump indexed media assets and the source relationships that reference them.
pub fn dump_media_assets_summary(pkg : OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  out.write_string("[media]\n")
  out.write_string("media asset count: ")
  out.write_string(report.media_asset_count.to_string())
  out.write_string("\n")

  for asset in report.media_assets {
    out.write_string("- part_name=")
    out.write_string(asset.part_name)
    out.write_string(" content_type=")
    out.write_string(string_opt(asset.content_type))
    out.write_string(" size=")
    out.write_string(asset.size.to_string())
    out.write_string(" referenced_by=")
    write_asset_refs_inline(out, asset.referenced_by)
    out.write_string("\n")
  }

  out.to_string()
}

///|
/// Dump lightweight core/app document properties.
pub fn dump_properties_summary(pkg : OoxmlPackage) -> String {
  let report = inspect_ooxml_package(pkg)
  let out = StringBuilder::new()
  let core = report.core_properties
  let app = report.app_properties

  out.write_string("[properties]\n")
  out.write_string("core: title=")
  out.write_string(string_opt(core.title))
  out.write_string(" subject=")
  out.write_string(string_opt(core.subject))
  out.write_string(" creator=")
  out.write_string(string_opt(core.creator))
  out.write_string(" description=")
  out.write_string(string_opt(core.description))
  out.write_string(" keywords=")
  out.write_string(string_opt(core.keywords))
  out.write_string(" created=")
  out.write_string(string_opt(core.created))
  out.write_string(" modified=")
  out.write_string(string_opt(core.modified))
  out.write_string("\n")

  out.write_string("app: application=")
  out.write_string(string_opt(app.application))
  out.write_string(" pages=")
  out.write_string(string_opt(app.pages))
  out.write_string(" words=")
  out.write_string(string_opt(app.words))
  out.write_string(" slides=")
  out.write_string(string_opt(app.slides))
  out.write_string(" sheets=")
  out.write_string(string_opt(app.sheets))
  out.write_string("\n")
  out.to_string()
}

///|
fn build_package_inventory(pkg : OoxmlPackage) -> OoxmlPackageInventory {
  let entries = @zip.list_entries(pkg.archive)
  let parts : Array[OoxmlPartInfo] = []
  let content_types : Array[OoxmlContentTypeInfo] = []
  let relationship_source_parts : Array[String] = []
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
    parts.push({
      part_name: part,
      content_type: lookup_content_type(pkg, part) catch {
        _ => None
      },
      size: part_size(entries, pkg, part),
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
  { parts, content_types, relationship_source_parts }
}

///|
fn read_relationship_infos(
  pkg : OoxmlPackage,
  source_part : String,
  rels_part_name : String,
) -> Array[OoxmlRelationshipInfo] raise OoxmlError {
  if !pkg.part_index.contains(rels_part_name) {
    return []
  }
  let source_part_opt = if source_part == "" { None } else { Some(source_part) }
  let rels = if source_part == "" {
    read_package_relationships(pkg)
  } else {
    read_part_relationships(pkg, source_part)
  }
  let out : Array[OoxmlRelationshipInfo] = []
  for rel in rels {
    out.push({
      source_part: source_part_opt,
      rels_part_name,
      id: rel.id,
      rel_type: rel.rel_type,
      target: rel.target,
      target_mode: rel.target_mode,
      resolved_target: rel.resolved_target,
    })
  }
  out
}

///|
fn write_relationship_infos(
  out : StringBuilder,
  rels : Array[OoxmlRelationshipInfo],
) -> Unit {
  if rels.length() == 0 {
    out.write_string("  (none)\n")
    return
  }

  for rel in rels {
    out.write_string("  - id=")
    out.write_string(rel.id)
    out.write_string(" type=")
    out.write_string(rel.rel_type)
    out.write_string(" target=")
    out.write_string(rel.target)
    out.write_string(" target_mode=")
    out.write_string(target_mode_text(rel.target_mode))
    out.write_string(" resolved_target=")
    out.write_string(rel.resolved_target)
    out.write_string("\n")
  }
}

///|
fn write_asset_refs_inline(
  out : StringBuilder,
  refs : Array[OoxmlAssetRef],
) -> Unit {
  if refs.length() == 0 {
    out.write_string("[]")
    return
  }

  out.write_string("[")
  for i in 0..<refs.length() {
    let asset_ref = refs[i]
    out.write_string(asset_ref.source_part)
    out.write_string("#")
    out.write_string(asset_ref.rel_id)
    if i + 1 < refs.length() {
      out.write_string(", ")
    }
  }
  out.write_string("]")
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
fn part_size(
  entries : Array[@zip.ZipEntryMeta],
  pkg : OoxmlPackage,
  part_name : String,
) -> Int {
  match pkg.part_index.get(part_name) {
    Some(index) =>
      if index >= 0 && index < entries.length() {
        entries[index].uncompressed_size
      } else {
        0
      }
    None => 0
  }
}

///|
fn target_mode_text(mode : OoxmlTargetMode) -> String {
  match mode {
    Internal => "Internal"
    External => "External"
  }
}

///|
fn string_opt(value : String?) -> String {
  match value {
    Some(v) => if v == "" { "(empty)" } else { v }
    None => "(none)"
  }
}

///|
fn count_string_map(m : Map[String, String]) -> Int {
  let mut n = 0
  for _ in m {
    n = n + 1
  }
  n
}
