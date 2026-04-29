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

  let part_index : Map[String, Int] = Map::new()
  let entries = @zip.list_entries(archive)
  let mut i = 0
  while i < entries.length() {
    part_index.set(entries[i].name, i)
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
  @zip.read_entry(pkg.archive, normalized) catch {
    @zip.EntryNotFound(path) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
}

///|
/// List all package parts in deterministic sorted order.
pub fn list_parts(pkg : OoxmlPackage) -> Array[String] {
  let out : Array[String] = []
  for entry in pkg.part_index {
    let (name, _) = entry
    out.push(name)
  }
  out.sort()
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
