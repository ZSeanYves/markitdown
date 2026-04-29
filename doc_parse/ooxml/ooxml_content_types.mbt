///|
/// Look up a part content type from `[Content_Types].xml`.
///
/// Overrides are checked first, then extension defaults.
pub fn lookup_content_type(
  pkg : OoxmlPackage,
  part_name : String,
) -> String? raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  let override_key = "/" + normalized

  match pkg.content_types_override.get(override_key) {
    Some(value) => Some(value)
    None => {
      let ext = extension_of_part(normalized)
      if ext == "" {
        None
      } else {
        pkg.content_types_default.get(ext)
      }
    }
  }
}

///|
/// List package parts that resolve to the given content type.
pub fn list_parts_by_content_type(
  pkg : OoxmlPackage,
  content_type : String,
) -> Array[String] raise OoxmlError {
  let out : Array[String] = []
  for name in list_parts(pkg) {
    match lookup_content_type(pkg, name) {
      Some(ct) => if ct == content_type { out.push(name) }
      None => ()
    }
  }
  out
}

///|
fn parse_content_types(
  xml : String,
) -> (Map[String, String], Map[String, String]) raise OoxmlError {
  let defaults : Map[String, String] = Map::new()
  let overrides : Map[String, String] = Map::new()

  for tag in collect_start_tags(xml, "Default") {
    let attrs = parse_tag_attributes(tag)
    let ext = get_required_attr(attrs, "Extension")
    let content_type = get_required_attr(attrs, "ContentType")
    defaults.set(ext, content_type)
  }

  for tag in collect_start_tags(xml, "Override") {
    let attrs = parse_tag_attributes(tag)
    let part_name = get_required_attr(attrs, "PartName")
    let content_type = get_required_attr(attrs, "ContentType")
    overrides.set(part_name, content_type)
  }

  (defaults, overrides)
}
