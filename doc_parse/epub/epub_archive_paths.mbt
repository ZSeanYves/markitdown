///|
fn read_required_xml_part(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  path : String,
) -> String raise EpubError {
  let data = read_required_part_bytes(archive, entry_index, path)
  bytes_to_xml_text(data, path)
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
  @zip.read_entry(archive, raw_path) catch {
    @zip.EntryNotFound(_) => raise MissingPart(path)
    e => raise ZipError(e.to_string())
  }
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

  let data = @zip.read_entry(archive, raw_path) catch { _ => return None }
  let text = @utf8.decode(data, ignore_bom=false) catch { _ => return None }
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
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
    if meta.name.has_suffix("/") || meta.name.has_suffix("\\") {
      continue
    }

    let normalized = match normalize_archive_entry_path(meta.name) {
      Some(path) => path
      None => continue
    }

    if is_hidden_or_macos_metadata(normalized) {
      continue
    }

    match entry_index.get(normalized) {
      Some(first_raw) =>
        raise InvalidPackage(
          "normalized path collision: " +
          normalized +
          " (" +
          display_path(first_raw) +
          " vs " +
          display_path(meta.name) +
          ")",
        )
      None => ()
    }

    entry_index.set(normalized, meta.name)
    out.push({
      raw_path: meta.name,
      path: normalized,
      uncompressed_size: meta.uncompressed_size,
    })
  }

  out.sort_by(fn(a, b) { a.path[:].lexical_compare(b.path[:]) })
  (out, entry_index)
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
  let base = @cor.basename(path)
  base == ".DS_Store" || base.has_prefix("._")
}
