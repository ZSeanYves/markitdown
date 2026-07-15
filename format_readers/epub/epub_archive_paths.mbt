///|
fn read_required_xml_part(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> String raise EpubError {
  read_required_xml_part_payload(archive, entry_index, path).text
}

///|
fn read_required_xml_part_payload(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> EpubXmlPartPayload raise EpubError {
  let data = read_required_part_bytes(archive, entry_index, path)
  {
    path,
    text: bytes_to_xml_text(data, path),
    structure_scan: @xml.scan_xml_structure_bytes(data),
    bytes: data,
  }
}

///|
fn read_required_part_bytes(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> Bytes raise EpubError {
  let raw_path = match entry_index.get(path) {
    Some(v) => v
    None => raise MissingPart(path)
  }
  read_archive_entry_bytes(archive, raw_path, path)
}

///|
fn read_optional_text_part(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> String? {
  let raw_path = match entry_index.get(path) {
    Some(v) => v
    None => return None
  }

  let data = match read_archive_entry_bytes_optional(archive, raw_path) {
    Some(bytes) => bytes
    None => return None
  }
  let text = @utf8.decode(data, ignore_bom=false) catch { _ => return None }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn read_archive_entry_bytes(
  archive : @zip.ZipArchive,
  raw_path : String,
  logical_path : String,
) -> Bytes raise EpubError {
  @zip.read_entry(archive, raw_path) catch {
    EntryNotFound(_) => raise MissingPart(logical_path)
    e => raise ZipError(e.to_string())
  }
}

///|
fn read_archive_entry_bytes_optional(
  archive : @zip.ZipArchive,
  raw_path : String,
) -> Bytes? {
  let data = @zip.read_entry(archive, raw_path) catch { _ => return None }
  Some(data)
}

///|
fn resolve_opf_href(opf_dir : String, href : String) -> String raise EpubError {
  let href0 = strip_fragment_and_query(href.trim().to_owned())
  if href0 == "" {
    raise InvalidPath(href)
  }
  if href0.contains("\\") || href0.has_prefix("/") {
    raise InvalidPath(href)
  }
  if href0.length() >= 2 && href0[1] == ':' {
    raise InvalidPath(href)
  }
  if has_scheme_like_prefix(href0.to_lower()) {
    raise InvalidPath(href)
  }
  ensure_no_dot_segments(href0, href)

  if opf_dir == "" {
    normalize_relative_path(href0)
  } else {
    normalize_relative_path(opf_dir + "/" + href0)
  }
}

///|
fn resolve_manifest_href(
  opf_dir : String,
  href : String,
) -> String raise EpubError {
  let href0 = strip_fragment_and_query(href.trim().to_owned())
  if href0 == "" {
    raise InvalidPath(href)
  }
  if manifest_href_is_non_local(href0) {
    return href0
  }
  resolve_opf_href(opf_dir, href)
}

///|
fn ensure_no_dot_segments(
  path : String,
  original : String,
) -> Unit raise EpubError {
  for segv in path.split("/") {
    let seg = segv.trim().to_owned()
    if seg == "" || seg == "." || seg == ".." {
      raise InvalidPath(original)
    }
  }
}

///|
fn strip_fragment_and_query(value : String) -> String {
  let mut end = value.length()
  for i in 0..<value.length() {
    if value[i] == '#' || value[i] == '?' {
      end = i
      break
    }
  }
  value[:end].trim().to_owned()
}

///|
fn has_scheme_like_prefix(src : String) -> Bool {
  for i in 0..<src.length() {
    match src[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}

///|
fn manifest_href_is_non_local(href : String) -> Bool {
  let normalized = strip_fragment_and_query(href.trim().to_owned())
  normalized.has_prefix("//") || has_scheme_like_prefix(normalized.to_lower())
}

///|
fn plan_archive_entries(
  archive : @zip.ZipArchive,
) -> (Array[EpubArchiveEntry], Map[String, String]) raise EpubError {
  let out : Array[EpubArchiveEntry] = []
  let entry_index : Map[String, String] = Map([])

  for meta in @zip.list_entries(archive) {
    append_archive_entry_plan(
      out,
      entry_index,
      meta.name,
      meta.is_directory,
      meta.uncompressed_size,
    )
  }

  out.sort_by(fn(a, b) { a.path[:].lexical_compare(b.path[:]) })
  (out, entry_index)
}

///|
fn append_archive_entry_plan(
  out : Array[EpubArchiveEntry],
  entry_index : Map[String, String],
  raw_name : String,
  is_directory : Bool,
  uncompressed_size : Int,
) -> Unit raise EpubError {
  if raw_name.has_suffix("/") || raw_name.has_suffix("\\") {
    return
  }
  if is_directory {
    return
  }

  let normalized = match normalize_archive_entry_path(raw_name) {
    Some(path) => path
    None => return
  }

  if is_hidden_or_macos_metadata(normalized) {
    return
  }

  match entry_index.get(normalized) {
    Some(first_raw) =>
      raise InvalidPackage(
        "normalized path collision: " +
        normalized +
        " (" +
        display_path(first_raw) +
        " vs " +
        display_path(raw_name) +
        ")",
      )
    None => ()
  }

  entry_index.set(normalized, raw_name)
  out.push({ raw_path: raw_name, path: normalized, uncompressed_size })
}

///|
fn normalize_archive_entry_path(raw_path : String) -> String? {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" || p.has_prefix("/") {
    return None
  }
  if p.length() >= 2 && p[1] == ':' {
    return None
  }

  let parts = p.split("/")
  let clean : Array[String] = []
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" || segment == "." || segment == ".." {
      return None
    }
    clean.push(segment)
  }

  if clean.length() == 0 {
    None
  } else {
    Some(clean.join("/"))
  }
}

///|
fn normalize_package_full_path(path : String) -> String raise EpubError {
  let raw = strip_fragment_and_query(path.trim().to_owned())
  if raw == "" || raw.contains("\\") || raw.has_prefix("/") {
    raise InvalidPath(path)
  }
  if raw.length() >= 2 && raw[1] == ':' {
    raise InvalidPath(path)
  }
  if has_scheme_like_prefix(raw.to_lower()) {
    raise InvalidPath(path)
  }
  ensure_no_dot_segments(raw, path)
  normalize_relative_path(raw)
}

///|
fn normalize_relative_path(path : String) -> String raise EpubError {
  let raw = path.trim().to_owned()
  if raw == "" {
    raise InvalidPath(path)
  }

  let parts = raw.split("/")
  let stack : Array[String] = []
  for segv in parts {
    let seg = segv.trim().to_owned()
    if seg == "" {
      raise InvalidPath(path)
    }
    if seg == "." {
      raise InvalidPath(path)
    }
    if seg == ".." {
      raise InvalidPath(path)
    }
    stack.push(seg)
  }

  if stack.is_empty() {
    raise InvalidPath(path)
  }
  stack.join("/")
}

///|
fn dirname_of_part(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last < 0 {
    ""
  } else {
    path[:last].to_owned()
  }
}

///|
fn display_path(raw_path : String) -> String {
  let p = raw_path.replace(old="\\", new="/")
  if p.trim() == "" {
    "(empty path)"
  } else {
    p
  }
}

///|
fn is_hidden_or_macos_metadata(path : String) -> Bool {
  if path == "__MACOSX" || path.has_prefix("__MACOSX/") {
    return true
  }
  let base = epub_basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}

///|
fn epub_basename(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let parts = normalized.split("/").to_array()
  parts.last().unwrap_or(normalized).to_owned()
}
