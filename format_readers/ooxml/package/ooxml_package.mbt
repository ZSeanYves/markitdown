///|
/// OOXML package infrastructure built on top of zip reader.
///
/// Responsibility:
/// - open OOXML ZIP packages
/// - normalize/read package parts
/// - expose deterministic package part listing helpers
///
/// Non-goal:
/// - no DOCX/PPTX/XLSX final block recovery in this layer
pub fn open_ooxml_package(bytes : Bytes) -> OoxmlPackage raise OoxmlError {
  let archive = @zip.open_zip(bytes) catch {
    e => raise ZipError(e.to_string())
  }
  let part_cache = new_ooxml_part_cache()
  let relationship_cache = new_ooxml_relationship_cache()

  let part_index : Map[String, Int] = Map([])
  let entries = @zip.list_entries(archive)
  let mut i = 0
  while i < entries.length() {
    let raw_name = entries[i].name
    if raw_name == "" || raw_name == "[Content_Types].xml" {
      part_index.set(raw_name, i)
      i = i + 1
      continue
    }
    if entries[i].is_directory || raw_name.has_suffix("/") {
      i = i + 1
      continue
    }
    let normalized = normalize_part_name(raw_name)
    if part_index.contains(normalized) {
      raise InvalidPartPath("normalized part collision: " + normalized)
    }
    part_index.set(normalized, i)
    i = i + 1
  }

  let content_types_bytes = @zip.read_entry(archive, "[Content_Types].xml") catch {
    @zip.EntryNotFound(path) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
  let content_types_xml = bytes_to_xml_text(content_types_bytes)

  let (defaults, overrides) = parse_content_types(content_types_xml)
  {
    archive,
    part_index,
    content_types_default: defaults,
    content_types_override: overrides,
    part_cache,
    relationship_cache,
    sorted_parts_cache: Ref(None),
    inventory_cache: Ref(None),
  }
}

///|
fn new_ooxml_part_cache() -> OoxmlPartCache {
  {
    bytes_by_part: Map([]),
    text_by_part: Map([]),
    bytes_hit_count: { val: 0 },
    bytes_miss_count: { val: 0 },
    text_hit_count: { val: 0 },
    text_decode_count: { val: 0 },
  }
}

///|
fn new_ooxml_relationship_cache() -> OoxmlRelationshipCache {
  {
    index_by_rels_part: Map([]),
    relationships_hit_count: { val: 0 },
    relationships_miss_count: { val: 0 },
    by_id_hit_count: { val: 0 },
    by_id_miss_count: { val: 0 },
    by_type_query_count: { val: 0 },
  }
}

///|
/// Inspect package-local OOXML part cache reuse.
pub fn inspect_ooxml_part_cache_stats(
  pkg : OoxmlPackage,
) -> OoxmlPartCacheStats {
  {
    bytes_hit_count: pkg.part_cache.bytes_hit_count.val,
    bytes_miss_count: pkg.part_cache.bytes_miss_count.val,
    text_hit_count: pkg.part_cache.text_hit_count.val,
    text_decode_count: pkg.part_cache.text_decode_count.val,
    bytes_entry_count: pkg.part_cache.bytes_by_part.length(),
    text_entry_count: pkg.part_cache.text_by_part.length(),
  }
}

///|
/// Inspect package-local OOXML relationship index reuse.
pub fn inspect_ooxml_relationship_cache_stats(
  pkg : OoxmlPackage,
) -> OoxmlRelationshipCacheStats {
  {
    relationships_hit_count: pkg.relationship_cache.relationships_hit_count.val,
    relationships_miss_count: pkg.relationship_cache.relationships_miss_count.val,
    by_id_hit_count: pkg.relationship_cache.by_id_hit_count.val,
    by_id_miss_count: pkg.relationship_cache.by_id_miss_count.val,
    by_type_query_count: pkg.relationship_cache.by_type_query_count.val,
    entry_count: pkg.relationship_cache.index_by_rels_part.length(),
  }
}

///|
/// Return whether a normalized package part exists.
pub fn has_part(pkg : OoxmlPackage, part_name : String) -> Bool {
  let normalized = normalize_part_name(part_name) catch { _ => return false }
  pkg.part_index.contains(normalized)
}

///|
/// Read raw bytes for a package part.
pub fn read_part_bytes(
  pkg : OoxmlPackage,
  part_name : String,
) -> Bytes raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  read_part_bytes_normalized(pkg, normalized)
}

///|
fn read_part_bytes_normalized(
  pkg : OoxmlPackage,
  normalized : String,
) -> Bytes raise OoxmlError {
  match pkg.part_cache.bytes_by_part.get(normalized) {
    Some(bytes) => {
      pkg.part_cache.bytes_hit_count.val += 1
      return bytes
    }
    None => ()
  }

  let bytes = @zip.read_entry(pkg.archive, normalized) catch {
    @zip.EntryNotFound(path) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
  pkg.part_cache.bytes_miss_count.val += 1
  pkg.part_cache.bytes_by_part.set(normalized, bytes)
  bytes
}

///|
/// Read a package part as lightweight XML/text content.
///
/// This helper uses the package-local XML text decoding path. It is intended
/// for OOXML package parts such as `.xml`, `.rels`, and small metadata parts,
/// not as a general semantic text-decoding policy for converters.
pub fn read_part_text(
  pkg : OoxmlPackage,
  part_name : String,
) -> String raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  match pkg.part_cache.text_by_part.get(normalized) {
    Some(text) => {
      pkg.part_cache.text_hit_count.val += 1
      return text
    }
    None => ()
  }

  let bytes = read_part_bytes_normalized(pkg, normalized)
  let text = bytes_to_xml_text(bytes)
  pkg.part_cache.text_decode_count.val += 1
  pkg.part_cache.text_by_part.set(normalized, text)
  text
}

///|
/// List all package parts in deterministic sorted order.
pub fn list_parts(pkg : OoxmlPackage) -> Array[String] {
  match pkg.sorted_parts_cache.val {
    Some(parts) => return parts
    None => ()
  }
  let out : Array[String] = []
  for entry in pkg.part_index {
    let (name, _) = entry
    out.push(name)
  }
  out.sort()
  pkg.sorted_parts_cache.val = Some(out)
  out
}

///|
/// List package parts whose names start with `prefix`.
pub fn list_parts_by_prefix(
  pkg : OoxmlPackage,
  prefix : String,
) -> Array[String] {
  let out : Array[String] = []
  for name in list_parts(pkg) {
    if name.has_prefix(prefix) {
      out.push(name)
    }
  }
  out
}
