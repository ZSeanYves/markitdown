///|
/// Human-readable OOXML package inspection helpers.
///
/// These helpers are intentionally read-only and lossy: they are for debugging
/// package structure, not for feeding conversion logic.
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
pub fn dump_package_summary(pkg : OoxmlPackage) -> String {
  let out = StringBuilder::new()
  out.write_string("[Content_Types]\n")
  out.write_string("part count: ")
  out.write_string(list_parts(pkg).length().to_string())
  out.write_string("\n")
  out.write_string("content type defaults: ")
  out.write_string(count_string_map(pkg.content_types_default).to_string())
  out.write_string("\n")
  out.write_string("content type overrides: ")
  out.write_string(count_string_map(pkg.content_types_override).to_string())
  out.write_string("\n")
  out.to_string()
}

///|
pub fn dump_relationships_summary(pkg : OoxmlPackage) -> String {
  let out = StringBuilder::new()
  out.write_string("[relationships]\n")
  out.write_string("root relationships:\n")
  write_relationships(out, read_package_relationships(pkg) catch { _ => [] })

  let sources = relationship_source_parts(pkg)
  for source in sources {
    out.write_string("source part: ")
    out.write_string(source)
    out.write_string("\n")
    write_relationships(
      out,
      read_part_relationships(pkg, source) catch {
        _ => []
      },
    )
  }
  out.to_string()
}

///|
pub fn dump_media_assets_summary(pkg : OoxmlPackage) -> String {
  let out = StringBuilder::new()
  out.write_string("[media]\n")
  let assets = list_media_assets(pkg) catch { _ => [] }
  out.write_string("media asset count: ")
  out.write_string(assets.length().to_string())
  out.write_string("\n")

  for asset in assets {
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
pub fn dump_properties_summary(pkg : OoxmlPackage) -> String {
  let out = StringBuilder::new()
  let core = read_core_properties(pkg)
  let app = read_app_properties(pkg)

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
fn relationship_source_parts(pkg : OoxmlPackage) -> Array[String] {
  let out : Array[String] = []
  for part in list_parts(pkg) {
    if has_relationships_part(pkg, part) {
      out.push(part)
    }
  }
  out.sort()
  out
}

///|
fn write_relationships(
  out : StringBuilder,
  rels : Array[OoxmlRelationship],
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
