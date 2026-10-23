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
/// Admitted per-part cursor statistics for profiling. No finite numeric
/// depth/token defaults have been selected by this consumer.
pub fn inspect_content_types_cursor(pkg : OoxmlPackage) -> @xml.XmlCursorStats {
  pkg.content_types_scan
}
