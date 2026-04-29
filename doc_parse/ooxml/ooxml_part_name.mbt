///|
/// Normalize a package part name to the internal no-leading-slash form.
fn normalize_part_name(part_name : String) -> String raise OoxmlError {
  let t0 = part_name.trim().to_owned()
  if t0 == "" {
    raise InvalidPartPath(part_name)
  }

  let t = if t0.has_prefix("/") { t0[1:] } else { t0 }
  if t == "" {
    raise InvalidPartPath(part_name)
  }

  normalize_relative_path(t.to_owned())
}

///|
/// Normalize a source part, allowing empty string and `/` for package root.
fn normalize_source_part_for_resolve(
  source_part : String,
) -> String raise OoxmlError {
  let t = source_part.trim().to_owned()
  if t == "" || t == "/" {
    ""
  } else {
    normalize_part_name(t)
  }
}

///|
fn rels_part_name_for_source(source_part : String) -> String {
  let (dir, file) = split_dir_file(source_part)
  if dir == "" {
    "_rels/" + file + ".rels"
  } else {
    dir + "/_rels/" + file + ".rels"
  }
}

///|
fn resolve_target(
  source_part : String,
  target : String,
  target_mode : OoxmlTargetMode,
) -> String raise OoxmlError {
  if target_mode == External {
    return target
  }

  let target0 = target.trim().to_owned()
  if target0 == "" {
    raise InvalidPartPath(target)
  }

  if target0.has_prefix("/") {
    return normalize_part_name(target0)
  }

  if source_part == "" {
    return normalize_relative_path(target0)
  }

  let (source_dir, _) = split_dir_file(source_part)
  if source_dir == "" {
    normalize_relative_path(target0)
  } else {
    normalize_relative_path(source_dir + "/" + target0)
  }
}

///|
fn split_dir_file(path : String) -> (String, String) {
  let chars = path.to_array()
  let mut slash = -1

  for i in 0..<chars.length() {
    if chars[i] == '/' {
      slash = i
    }
  }

  if slash < 0 {
    ("", path)
  } else {
    (path[:slash].to_owned(), path[slash + 1:].to_owned())
  }
}

///|
fn normalize_relative_path(path : String) -> String raise OoxmlError {
  let raw = path.trim().to_owned()
  if raw == "" {
    raise InvalidPartPath(path)
  }

  let parts = raw.split("/")
  let stack : Array[String] = []

  for segv in parts {
    let seg = segv.to_owned()
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if stack.is_empty() {
        raise InvalidPartPath(path)
      }
      ignore(stack.pop())
      continue
    }
    stack.push(seg)
  }

  if stack.is_empty() {
    raise InvalidPartPath(path)
  }

  stack.join("/")
}

///|
fn extension_of_part(path : String) -> String {
  let chars = path.to_array()
  let mut dot = -1

  for i in 0..<chars.length() {
    if chars[i] == '.' {
      dot = i
    }
  }

  if dot < 0 || dot + 1 >= chars.length() {
    ""
  } else {
    path[dot + 1:].to_owned()
  }
}
