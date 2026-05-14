///|
pub fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
  @sys.exit(1)
}

///|
pub async fn delegate_external_command(
  capability_name : String,
  package_name : String,
  env_name : String,
  args : Array[String],
) -> Result[Unit, String] {
  let worker_cli = match
    resolve_worker_cli_path(capability_name, package_name, env_name) {
    Ok(path) => path
    Err(msg) => return Err(msg)
  }

  let delegated = @process.collect_output(worker_cli, args) catch {
    e =>
      return Err(
        "launch " +
        package_name +
        " failed: " +
        e.to_string() +
        ". Run `moon build " +
        package_name +
        " --target native` or set " +
        env_name,
      )
  }

  match delegated {
    (0, stdout, stderr) => {
      let stdout_text = stdout.text()
      let stderr_text = stderr.text()
      if stdout_text != "" {
        @stdio.stdout.write(stdout_text)
      }
      if stderr_text != "" {
        @stdio.stderr.write(stderr_text)
      }
      Ok(())
    }
    (code, stdout, stderr) => {
      let stderr_text = stderr.text().trim().to_owned()
      let stdout_text = stdout.text().trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        package_name + " exited with code " + code.to_string()
      }
      Err(strip_error_prefix(raw_message))
    }
  }
}

///|
fn resolve_worker_cli_path(
  capability_name : String,
  package_name : String,
  env_name : String,
) -> Result[String, String] {
  match @sys.get_env_var(env_name) {
    Some(raw) => {
      let override_path = raw.trim().to_owned()
      if override_path == "" {
        Err(
          env_name +
          " is set but empty; run `moon build " +
          package_name +
          " --target native` or point " +
          env_name +
          " at an executable " +
          package_name +
          " binary",
        )
      } else if @fs.path_exists(override_path) {
        Ok(override_path)
      } else {
        Err(
          env_name +
          " points to a missing path: " +
          override_path +
          ". Run `moon build " +
          package_name +
          " --target native` or fix " +
          env_name,
        )
      }
    }
    None => {
      for candidate in worker_cli_candidates(package_name) {
        if candidate != "" && @fs.path_exists(candidate) {
          return Ok(candidate)
        }
      }
      Err(
        capability_name +
        " is provided by " +
        package_name +
        "; run `moon build " +
        package_name +
        " --target native` or set " +
        env_name,
      )
    }
  }
}

///|
fn worker_cli_candidates(package_name : String) -> Array[String] {
  let out : Array[String] = []
  add_worker_cli_candidate(out, infer_packaged_worker_path(package_name, true))
  add_worker_cli_candidate(out, infer_packaged_worker_path(package_name, false))
  add_worker_cli_candidate(
    out,
    infer_build_tree_worker_path(package_name, true),
  )
  add_worker_cli_candidate(
    out,
    infer_build_tree_worker_path(package_name, false),
  )
  add_worker_cli_candidate(
    out,
    Some(
      "_build/native/debug/build/" + package_name + "/" + package_name + ".exe",
    ),
  )
  add_worker_cli_candidate(
    out,
    Some(
      "_build/native/release/build/" +
      package_name +
      "/" +
      package_name +
      ".exe",
    ),
  )
  add_worker_cli_candidate(
    out,
    Some("target/native/debug/build/" + package_name + "/" + package_name),
  )
  add_worker_cli_candidate(
    out,
    Some("target/native/release/build/" + package_name + "/" + package_name),
  )
  add_worker_cli_candidate(
    out,
    Some(
      "target/native/debug/build/" + package_name + "/" + package_name + ".exe",
    ),
  )
  add_worker_cli_candidate(
    out,
    Some(
      "target/native/release/build/" +
      package_name +
      "/" +
      package_name +
      ".exe",
    ),
  )
  out
}

///|
fn add_worker_cli_candidate(out : Array[String], path : String?) -> Unit {
  match path {
    Some(candidate) => {
      let normalized = candidate.trim().to_owned()
      if normalized == "" {
        return
      }
      for existing in out {
        if existing == normalized {
          return
        }
      }
      out.push(normalized)
    }
    None => ()
  }
}

///|
fn infer_packaged_worker_path(
  package_name : String,
  with_exe : Bool,
) -> String? {
  match current_executable_dir() {
    Some(dir) =>
      Some(
        join_path(
          dir,
          if with_exe {
            package_name + ".exe"
          } else {
            package_name
          },
        ),
      )
    None => None
  }
}

///|
fn infer_build_tree_worker_path(
  package_name : String,
  with_exe : Bool,
) -> String? {
  match current_executable_dir() {
    Some(current_dir) => {
      let build_dir = dirname_of_path(current_dir)
      Some(
        join_path(
          join_path(build_dir, package_name),
          if with_exe {
            package_name + ".exe"
          } else {
            package_name
          },
        ),
      )
    }
    None => None
  }
}

///|
fn current_executable_dir() -> String? {
  match current_executable_path() {
    Some(path) => Some(dirname_of_path(path))
    None => None
  }
}

///|
fn current_executable_path() -> String? {
  let cli_args = @sys.get_cli_args()
  if cli_args.length() == 0 {
    return None
  }

  let argv0 = cli_args[0].trim().to_owned()
  if argv0 == "" {
    return None
  }

  if argv0.contains("/") || argv0.contains("\\") {
    return Some(argv0)
  }

  find_executable_on_path(argv0)
}

///|
fn find_executable_on_path(name : String) -> String? {
  match @sys.get_env_var("PATH") {
    Some(raw) => {
      let separator = if raw.contains(";") { ";" } else { ":" }
      for dir in raw.split(separator) {
        let trimmed = dir.trim().to_owned()
        if trimmed == "" {
          continue
        }
        let plain = join_path(trimmed, name)
        if @fs.path_exists(plain) {
          return Some(plain)
        }
        let exe = join_path(trimmed, name + ".exe")
        if @fs.path_exists(exe) {
          return Some(exe)
        }
      }
      None
    }
    None => None
  }
}

///|
fn strip_error_prefix(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix("error: ") {
    trimmed[7:].trim().to_owned()
  } else {
    trimmed
  }
}

///|
pub fn write_document_output(
  input : String,
  format : String,
  doc : @cor.Document,
  output : String?,
  with_metadata : Bool,
) -> Result[Unit, String] {
  write_document_output_with_document_properties(
    input,
    format,
    doc,
    output,
    with_metadata,
    None,
  )
}

///|
pub fn write_document_output_with_document_properties(
  input : String,
  format : String,
  doc : @cor.Document,
  output : String?,
  with_metadata : Bool,
  document : @cor.MetadataDocumentProperties?,
) -> Result[Unit, String] {
  let resolved_output = resolve_output_path(input, output)
  let md = @cor.emit_markdown(doc)

  match resolved_output {
    Some(p) => {
      let parent = dirname_of_path(p)
      ensure_dir_tree(parent) catch {
        e => return Err("create output dir failed: " + e.to_string())
      }
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => return Err("write output failed: " + e.to_string())
      }

      if with_metadata {
        let markdown_file = @cor.basename(p)
        let metadata_json = @cor.emit_metadata_json_with_document_properties(
          doc,
          @cor.basename(input),
          format,
          markdown_file,
          document,
        )
        let metadata_path = metadata_output_path(p)
        let metadata_dir = dirname_of_path(metadata_path)
        ensure_dir_tree(metadata_dir) catch {
          e => return Err("create metadata dir failed: " + e.to_string())
        }
        @fs.write_string_to_file(metadata_path, metadata_json, encoding="utf8") catch {
          e => return Err("write metadata failed: " + e.to_string())
        }
      }

      Ok(())
    }
    None => {
      println(md)
      Ok(())
    }
  }
}

///|
pub fn resolve_output_path(input : String, output : String?) -> String? {
  match output {
    None => None
    Some(raw) => {
      let out = raw.trim().to_owned()
      if out == "" {
        None
      } else if looks_like_output_dir(out) {
        Some(join_path(out, input_stem(input) + ".md"))
      } else {
        Some(out)
      }
    }
  }
}

///|
fn looks_like_output_dir(path : String) -> Bool {
  if path.has_suffix("/") || path.has_suffix("\\") {
    true
  } else {
    let base = @cor.basename(path)
    let base_lower = base.to_lower()
    if base_lower.has_suffix(".md") || base_lower.has_suffix(".markdown") {
      false
    } else if !@fs.path_exists(path) {
      true
    } else {
      true
    }
  }
}

///|
pub fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
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
pub fn join_path(dir : String, file : String) -> String {
  if dir == "" || dir == "." {
    file
  } else if dir.has_suffix("/") || dir.has_suffix("\\") {
    dir + file
  } else {
    dir + "/" + file
  }
}

///|
pub fn input_stem(path : String) -> String {
  let base = @cor.basename(path)
  let mut dot = -1
  for i in 0..<base.length() {
    if base[i] == '.' {
      dot = i
    }
  }
  if dot <= 0 {
    base
  } else {
    base[:dot].to_owned()
  }
}

///|
pub fn metadata_output_path(markdown_path : String) -> String {
  let parent = dirname_of_path(markdown_path)
  let stem = input_stem(markdown_path)
  join_path(join_path(parent, "metadata"), stem + ".metadata.json")
}

///|
pub fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }

    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
pub fn detect_input_format(path : String) -> String {
  let base = @cor.basename(path).to_lower()
  if base.has_suffix(".docx") {
    "docx"
  } else if base.has_suffix(".pdf") {
    "pdf"
  } else if base.has_suffix(".xlsx") {
    "xlsx"
  } else if base.has_suffix(".pptx") {
    "pptx"
  } else if base.has_suffix(".html") || base.has_suffix(".htm") {
    "html"
  } else if base.has_suffix(".csv") {
    "csv"
  } else if base.has_suffix(".tsv") {
    "tsv"
  } else if base.has_suffix(".txt") {
    "txt"
  } else if base.has_suffix(".xml") {
    "xml"
  } else if base.has_suffix(".json") {
    "json"
  } else if base.has_suffix(".yaml") || base.has_suffix(".yml") {
    "yaml"
  } else if base.has_suffix(".markdown") || base.has_suffix(".md") {
    "markdown"
  } else if base.has_suffix(".zip") {
    "zip"
  } else if base.has_suffix(".epub") {
    "epub"
  } else {
    "unknown"
  }
}

///|
pub fn detect_ocr_image_format(path : String) -> String? {
  let base = @cor.basename(path).to_lower()
  if base.has_suffix(".png") {
    Some("png")
  } else if base.has_suffix(".jpg") || base.has_suffix(".jpeg") {
    Some("jpg")
  } else if base.has_suffix(".bmp") {
    Some("bmp")
  } else if base.has_suffix(".webp") {
    Some("webp")
  } else if base.has_suffix(".tif") || base.has_suffix(".tiff") {
    Some("tiff")
  } else {
    None
  }
}

///|
pub fn parse_ocr_lang_arg(raw : String?) -> Array[String] {
  match raw {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        []
      } else {
        let langs : Array[String] = []
        for part in trimmed.split("+") {
          let token = part.trim().to_owned()
          if token != "" {
            langs.push(token)
          }
        }
        langs
      }
    }
    None => []
  }
}
