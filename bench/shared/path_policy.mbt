///|
pub(all) suberror BenchSharedError {
  Failed(String)
}

///|
pub impl Show for BenchSharedError with fn to_string(self : BenchSharedError) -> String {
  match self {
    Failed(msg) => msg
  }
}

///|
pub impl Show for BenchSharedError with fn output(
  self : BenchSharedError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn reject_forbidden_benchmark_path(
  path : String,
) -> Unit raise BenchSharedError {
  let normalized = path.replace(old="\\", new="/")
  if normalized == "samples/main_process" ||
    normalized == "samples/benchmark" ||
    normalized.has_prefix("samples/main_process/") ||
    normalized.has_prefix("samples/benchmark/") ||
    normalized.has_suffix("/samples/main_process") ||
    normalized.has_suffix("/samples/benchmark") ||
    normalized.contains("/samples/main_process/") ||
    normalized.contains("/samples/benchmark/") {
    raise Failed(
      "benchmark rows must not use repo-local samples/main_process or samples/benchmark paths: " +
      path,
    )
  }
}

///|
pub fn resolve_manifest_rel_path(
  manifest_dir : String,
  rel_path : String,
) -> String {
  if rel_path.has_prefix("/") {
    return rel_path
  }
  if manifest_dir == "" || manifest_dir == "." {
    rel_path
  } else {
    manifest_dir + "/" + rel_path
  }
}

///|
pub fn parent_dir(path : String) -> String {
  let chars = path.to_array()
  let mut last_sep = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last_sep = i
    }
  }
  if last_sep <= 0 {
    "."
  } else {
    path[:last_sep].to_owned()
  }
}

///|
pub fn raw_output_path(summary_path : String) -> String {
  if summary_path.has_suffix(".tsv") {
    summary_path[:summary_path.length() - 4].to_owned() + ".runs.tsv"
  } else {
    summary_path + ".runs.tsv"
  }
}

///|
pub fn ensure_dir_tree(path : String) -> Unit raise BenchSharedError {
  if path == "" || path == "." {
    return
  }
  let parts = path.split("/").to_array()
  let mut current = if path.has_prefix("/") { "/" } else { "" }
  for part in parts {
    let segment = part.trim().to_owned()
    if segment == "" {
      continue
    }
    current = if current == "" || current == "." {
      segment
    } else if current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current) catch {
        e => raise Failed("mkdir failed: " + current + " : " + e.to_string())
      }
    }
  }
}
