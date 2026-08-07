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
  open_ooxml_archive(ensure_archive(bytes))
}

///|
/// Open OOXML semantics over an already validated ZIP archive.
pub fn open_ooxml_archive(
  archive : @zip.ZipArchive,
) -> OoxmlPackage raise OoxmlError {
  let part_cache = new_ooxml_part_cache()
  let relationship_cache = new_ooxml_relationship_cache()

  let (part_index, part_size_index) = build_ooxml_part_index(archive)

  let content_types_payload = read_archive_xml_payload_or_raise(
    archive, "[Content_Types].xml",
  )
  let (defaults, overrides) = parse_content_types(content_types_payload.text)
  {
    archive,
    part_index,
    part_size_index,
    content_types_default: defaults,
    content_types_override: overrides,
    part_cache,
    relationship_cache,
    sorted_parts_cache: Ref(None),
    inventory_cache: Ref(None),
  }
}

///|
fn build_ooxml_part_index(
  archive : @zip.ZipArchive,
) -> (Map[String, String], Map[String, Int]) raise OoxmlError {
  let part_index : Map[String, String] = Map([])
  let part_size_index : Map[String, Int] = Map([])
  for entry in @zip.list_entries(archive) {
    let raw_name = entry.name
    if raw_name == "" || raw_name == "[Content_Types].xml" {
      part_index.set(raw_name, raw_name)
      part_size_index.set(raw_name, entry.uncompressed_size)
      continue
    }
    if entry.is_directory || raw_name.has_suffix("/") {
      continue
    }
    let normalized = normalize_part_name(raw_name)
    if part_index.contains(normalized) {
      raise InvalidPartPath("normalized part collision: " + normalized)
    }
    part_index.set(normalized, raw_name)
    part_size_index.set(normalized, entry.uncompressed_size)
  }
  (part_index, part_size_index)
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
/// Return whether a normalized package part exists.
pub fn has_part(pkg : OoxmlPackage, part_name : String) -> Bool {
  let normalized = normalize_part_name(part_name) catch { _ => return false }
  pkg.part_index.contains(normalized)
}

///|
/// Return the declared uncompressed size for a normalized package part.
/// Callers can reject oversized binary parts before decompression.
pub fn part_declared_size(pkg : OoxmlPackage, part_name : String) -> Int? {
  let normalized = normalize_part_name(part_name) catch { _ => return None }
  pkg.part_size_index.get(normalized)
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
/// Read raw bytes for a package part without populating the package-local
/// part cache. This is intended for one-shot large-part scans where cache
/// reuse would only increase peak memory.
pub fn read_part_bytes_transient(
  pkg : OoxmlPackage,
  part_name : String,
) -> Bytes raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  let raw_name = resolve_part_raw_name(pkg, normalized)
  @zip.read_entry_transient(pkg.archive, raw_name) catch {
    EntryNotFound(missing) => raise MissingPart(missing)
    e => raise ZipError(e.to_string())
  }
}

///|
/// Visit a package part as validated decompressed chunks without materializing
/// the complete part. The ZIP reader still verifies decoded size and CRC after
/// the callback has consumed the stream.
pub fn visit_part_inflated_chunks(
  pkg : OoxmlPackage,
  part_name : String,
  chunk_size? : Int = 64 * 1024,
  on_chunk : (Bytes) -> Result[Unit, String],
) -> Result[Unit, String] {
  let normalized = normalize_part_name(part_name) catch {
    err => return Err(err.to_string())
  }
  let raw_name = resolve_part_raw_name(pkg, normalized) catch {
    err => return Err(err.to_string())
  }
  @zip.visit_inflated_entry_chunks(pkg.archive, raw_name, chunk_size~, on_chunk)
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

  let raw_name = resolve_part_raw_name(pkg, normalized)
  let bytes = read_archive_entry_or_raise(pkg.archive, raw_name)
  pkg.part_cache.bytes_miss_count.val += 1
  pkg.part_cache.bytes_by_part.set(normalized, bytes)
  bytes
}

///|
fn resolve_part_raw_name(
  pkg : OoxmlPackage,
  normalized : String,
) -> String raise OoxmlError {
  match pkg.part_index.get(normalized) {
    Some(raw_name) => raw_name
    None => raise MissingPart(normalized)
  }
}

///|
fn read_archive_entry_or_raise(
  archive : @zip.ZipArchive,
  path : String,
) -> Bytes raise OoxmlError {
  @zip.read_entry(archive, path) catch {
    EntryNotFound(missing) => raise MissingPart(missing)
    e => raise ZipError(e.to_string())
  }
}

///|
fn ensure_archive(archive_bytes : Bytes) -> @zip.ZipArchive raise OoxmlError {
  @zip.open_zip(archive_bytes) catch {
    e => raise ZipError(e.to_string())
  }
}

///|
fn read_archive_xml_payload_or_raise(
  archive : @zip.ZipArchive,
  path : String,
) -> OoxmlXmlPartPayload raise OoxmlError {
  let bytes = read_archive_entry_or_raise(archive, path)
  {
    part_name: path,
    bytes,
    text: bytes_to_xml_text(bytes),
    structure_scan: @xml.scan_xml_structure_bytes(bytes),
  }
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
/// Read a package part as XML/text content without populating the package-local
/// text/byte cache. This keeps large one-shot XML parts from remaining pinned
/// in memory after the caller finishes scanning them.
pub fn read_part_text_transient(
  pkg : OoxmlPackage,
  part_name : String,
) -> String raise OoxmlError {
  let bytes = read_part_bytes_transient(pkg, part_name)
  bytes_to_xml_text(bytes)
}

///|
pub fn read_xml_part_payload(
  pkg : OoxmlPackage,
  part_name : String,
) -> OoxmlXmlPartPayload raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  let bytes = read_part_bytes_normalized(pkg, normalized)
  let text = match pkg.part_cache.text_by_part.get(normalized) {
    Some(value) => {
      pkg.part_cache.text_hit_count.val += 1
      value
    }
    None => {
      let decoded = bytes_to_xml_text(bytes)
      pkg.part_cache.text_decode_count.val += 1
      pkg.part_cache.text_by_part.set(normalized, decoded)
      decoded
    }
  }
  {
    part_name: normalized,
    bytes,
    text,
    structure_scan: @xml.scan_xml_structure_bytes(bytes),
  }
}

///|
pub fn read_xml_part_payload_transient(
  pkg : OoxmlPackage,
  part_name : String,
) -> OoxmlXmlPartPayload raise OoxmlError {
  let normalized = normalize_part_name(part_name)
  let bytes = read_part_bytes_transient(pkg, normalized)
  {
    part_name: normalized,
    text: bytes_to_xml_text(bytes),
    structure_scan: @xml.scan_xml_structure_bytes(bytes),
    bytes,
  }
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
