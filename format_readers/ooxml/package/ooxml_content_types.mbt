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
pub fn lookup_content_type_default(
  pkg : OoxmlPackage,
  extension : String,
) -> String? {
  let ext = extension.trim().to_owned()
  if ext == "" {
    None
  } else {
    pkg.content_types_default.get(ext)
  }
}

///|
pub fn lookup_content_type_override(
  pkg : OoxmlPackage,
  part_name : String,
) -> String? raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  pkg.content_types_override.get("/" + normalized)
}

///|
fn parse_content_types(
  xml : String,
) -> (Map[String, String], Map[String, String]) raise OoxmlError {
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])

  for tag in collect_start_tags(xml, "Default") {
    let attrs = parse_tag_attributes(tag)
    let ext = get_required_attr(attrs, "Extension") catch {
      _ => raise InvalidXml("[Content_Types].xml: missing attribute: Extension")
    }
    let content_type = get_required_attr(attrs, "ContentType") catch {
      _ =>
        raise InvalidXml("[Content_Types].xml: missing attribute: ContentType")
    }
    if ext.trim() == "" {
      raise InvalidXml(
        "[Content_Types].xml: empty content type default extension",
      )
    }
    if defaults.contains(ext) {
      raise InvalidXml(
        "[Content_Types].xml: duplicate content type default extension: " + ext,
      )
    }
    defaults.set(ext, content_type)
  }

  for tag in collect_start_tags(xml, "Override") {
    let attrs = parse_tag_attributes(tag)
    let part_name = get_required_attr(attrs, "PartName") catch {
      _ => raise InvalidXml("[Content_Types].xml: missing attribute: PartName")
    }
    let content_type = get_required_attr(attrs, "ContentType") catch {
      _ =>
        raise InvalidXml("[Content_Types].xml: missing attribute: ContentType")
    }
    let normalized_part_name = normalize_part_name(part_name)
    let override_key = "/" + normalized_part_name
    if overrides.contains(override_key) {
      raise InvalidXml(
        "[Content_Types].xml: duplicate content type override: " + override_key,
      )
    }
    overrides.set(override_key, content_type)
  }

  (defaults, overrides)
}
