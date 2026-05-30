///|
fn zip_entry_requires_output_dir(ext : String) -> Bool {
  match ext {
    "docx" | "pdf" | "pptx" | "html" | "htm" => true
    _ => false
  }
}

///|
fn zip_entry_uses_flat_staging(ext : String) -> Bool {
  match ext {
    "csv"
    | "tsv"
    | "txt"
    | "xml"
    | "json"
    | "yaml"
    | "yml"
    | "md"
    | "markdown" => true
    _ => false
  }
}

///|
fn materialize_safe_archive_tree(
  archive : @zipraw.ZipArchive,
  plans : Array[PlannedEntry],
  extracted_root : String,
) -> Unit raise {
  recreate_clean_dir(extracted_root) catch {
    e =>
      raise @cor.AppError(
        "zip extracted tree failed: reset temp dir failed: " + e.to_string(),
      )
  }

  let mut total_materialized = 0
  for i in 0..<plans.length() {
    let plan = plans[i]
    if i >= MAX_ZIP_ENTRIES {
      continue
    }
    if plan.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      continue
    }
    if total_materialized + plan.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      continue
    }

    let dst = extracted_entry_path(extracted_root, plan.path)
    ensure_parent_dir(dst) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: create parent dir failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }

    let entry_bytes = @zipraw.read_entry(
      archive,
      plan.raw_path,
      max_output_size=MAX_SINGLE_ENTRY_BYTES,
    ) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: read entry failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }
    total_materialized += entry_bytes.length()
    @fs.write_bytes_to_file(dst, entry_bytes) catch {
      e =>
        raise @cor.AppError(
          "zip extracted tree failed: write entry failed for " +
          plan.path +
          ": " +
          e.to_string(),
        )
    }
  }
}

///|
pub fn remove_dir_recursive(path : String) -> Unit raise {
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
pub fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  ensure_dir_tree(path)
}

///|
fn zip_tmp_dir(input_path : String) -> String {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  root + "/zip/" + safe_entry_id(@cor.basename(input_path))
}

///|
let zip_archive_run_serial : Ref[Int] = { val: 0 }

///|
fn allocate_archive_run_dir(base_root : String, prefix : String) -> String {
  zip_archive_run_serial.val += 1
  let serial = zip_archive_run_serial.val
  let stamp = @env.now().to_string()
  let trimmed_base = trim_trailing_slashes(base_root)
  let mut suffix = stamp + "-" + serial.to_string()
  let mut candidate = trimmed_base + "/" + prefix + "-" + suffix
  while true {
    if !@fs.path_exists(candidate) {
      return candidate
    }
    zip_archive_run_serial.val += 1
    suffix = stamp + "-" + zip_archive_run_serial.val.to_string()
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
pub fn ensure_dir_tree(path : String) -> Unit raise {
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
pub fn extracted_entry_path(
  extracted_root : String,
  entry_path : String,
) -> String raise {
  let normalized = match normalize_zip_entry_path(entry_path) {
    Some(path) => path
    None =>
      raise @cor.AppError(
        "zip extracted tree failed: unsafe materialized path: " +
        display_path(entry_path),
      )
  }
  let root = trim_trailing_slashes(extracted_root)
  let out = root + "/" + normalized
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  if !out.has_prefix(prefix) {
    raise @cor.AppError(
      "zip extracted tree failed: materialized path escaped root: " +
      display_path(entry_path),
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
