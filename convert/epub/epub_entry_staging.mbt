///|
fn materialize_safe_archive_tree(
  pkg : @epubpkg.EpubPackage,
  extracted_root : String,
) -> Map[String, String] raise {
  recreate_clean_dir(extracted_root) catch {
    e =>
      raise @cor.AppError(
        "epub extracted tree failed: reset temp dir failed: " + e.to_string(),
      )
  }

  let skipped : Map[String, String] = Map([])
  let mut total_materialized = 0
  for i in 0..<pkg.entries.length() {
    let entry = pkg.entries[i]
    if i >= MAX_EPUB_ENTRIES {
      skipped.set(entry.path, "Skipped: entry count limit exceeded")
      continue
    }
    if entry.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      skipped.set(
        entry.path,
        "Skipped: entry too large: " +
        entry.uncompressed_size.to_string() +
        " bytes",
      )
      continue
    }
    if total_materialized + entry.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      skipped.set(entry.path, "Skipped: total decoded size limit exceeded")
      continue
    }

    let dst = extracted_entry_path(extracted_root, entry.path)
    ensure_parent_dir(dst) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: create parent dir failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }

    let entry_bytes = @epubpkg.read_part_bytes(pkg, entry.path) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: read entry failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }
    total_materialized += entry_bytes.length()
    @fs.write_bytes_to_file(dst, entry_bytes) catch {
      e =>
        raise @cor.AppError(
          "epub extracted tree failed: write entry failed for " +
          entry.path +
          ": " +
          e.to_string(),
        )
    }
  }

  skipped
}

///|
fn unique_entry_id(path : String, used : Map[String, Int]) -> String {
  let base = safe_entry_id(path)
  let count = used.get(base).unwrap_or(0) + 1
  used.set(base, count)
  if count == 1 {
    base
  } else {
    base + "_" + count.to_string()
  }
}

///|
fn safe_entry_id(path : String) -> String {
  let out : Array[Char] = []
  for ch in path.to_array() {
    if is_safe_id_char(ch) {
      out.push(ch)
    } else {
      out.push('_')
    }
  }
  let value = String::from_array(out).trim().to_owned()
  if value == "" {
    "entry"
  } else {
    value
  }
}

///|
fn is_safe_id_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '.' ||
  ch == '_' ||
  ch == '-'
}

///|
fn epub_tmp_dir(input_path : String) -> String {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  root + "/epub/" + safe_entry_id(@cor.basename(input_path))
}

///|
let epub_archive_run_serial : Ref[Int] = { val: 0 }

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn allocate_archive_run_dir(base_root : String, prefix : String) -> String {
  epub_archive_run_serial.val += 1
  let serial = epub_archive_run_serial.val
  let stamp = @env.now().to_string()
  let trimmed_base = trim_trailing_slashes(base_root)
  let mut suffix = stamp + "-" + serial.to_string()
  let mut candidate = trimmed_base + "/" + prefix + "-" + suffix
  while true {
    if !@fs.path_exists(candidate) {
      return candidate
    }
    epub_archive_run_serial.val += 1
    suffix = stamp + "-" + epub_archive_run_serial.val.to_string()
    candidate = trimmed_base + "/" + prefix + "-" + suffix
  }
  candidate
}

///|
fn cleanup_archive_run_dir(path : String) -> Unit raise {
  let trimmed = trim_trailing_slashes(path)
  if trimmed == "" || trimmed == "." || trimmed == "/" {
    return
  }
  remove_dir_recursive(trimmed)
}

///|
fn ensure_parent_dir(path : String) -> Unit raise {
  let dir = dirname_of_path(path)
  if dir != "" && dir != "." {
    ensure_dir_tree(dir)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }
  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }
    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    if !@fs.path_exists(next) {
      @fs.create_dir(next)
    }
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }
  ignore(flush(part, current))
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn normalize_entry_path(entry_path : String) -> String? {
  if entry_path.trim() == "" || entry_path.has_prefix("/") {
    return None
  }
  if entry_path.length() >= 2 && entry_path[1] == ':' {
    return None
  }

  let parts = entry_path.split("/")
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
fn extracted_entry_path(
  extracted_root : String,
  entry_path : String,
) -> String raise {
  let normalized = match normalize_entry_path(entry_path) {
    Some(path) => path
    None =>
      raise @cor.AppError(
        "epub extracted tree failed: unsafe materialized path: " + entry_path,
      )
  }
  let root = trim_trailing_slashes(extracted_root)
  let out = root + "/" + normalized
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  if !out.has_prefix(prefix) {
    raise @cor.AppError(
      "epub extracted tree failed: materialized path escaped root: " +
      entry_path,
    )
  }
  out
}

///|
fn trim_trailing_slashes(path : String) -> String {
  let mut end = path.length()
  while end > 1 && path[end - 1] == '/' {
    end -= 1
  }
  path[:end].to_owned()
}
