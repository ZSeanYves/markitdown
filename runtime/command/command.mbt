///|
pub(all) enum ResolvedCommandSource {
  ExplicitArg
  RepoManaged
  EnvVar
  Path
  Fallback
} derive(Eq)

///|
pub(all) enum ShellCommandSplitError {
  TrailingEscape
  UnterminatedQuotes
} derive(Eq)

///|
pub struct ResolvedCommand {
  program : String
  display_command : String
  source : ResolvedCommandSource
} derive(Eq)

///|
pub fn make_resolved_command(
  program : String,
  display_command : String,
  source : ResolvedCommandSource,
) -> ResolvedCommand {
  { program, display_command, source }
}

///|
#borrow(path_blob)
extern "C" fn native_is_executable_file(path_blob : Bytes) -> Int = "markitdown_runtime_is_executable_file"

///|
#borrow(name_blob, path_blob)
extern "C" fn native_find_in_path(
  name_blob : Bytes,
  path_blob : Bytes,
) -> Bytes = "markitdown_runtime_find_in_path"

///|
pub fn resolved_command_source_label(source : ResolvedCommandSource) -> String {
  match source {
    ExplicitArg => "explicit_arg"
    RepoManaged => "repo_managed"
    EnvVar => "env_var"
    Path => "path"
    Fallback => "fallback"
  }
}

///|
pub fn resolved_command_context(resolved : ResolvedCommand) -> String {
  "source=" +
  resolved_command_source_label(resolved.source) +
  ";path=" +
  resolved.display_command
}

///|
pub fn normalized_env_var(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
pub fn markitdown_module_root_env_var() -> String {
  "MARKITDOWN_MODULE_ROOT"
}

///|
fn trim_trailing_slashes(path : String) -> String {
  let chars = path.to_array()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end = end - 1
  }
  if end == chars.length() {
    path
  } else {
    String::from_array(chars[:end])
  }
}

///|
pub fn resolve_repo_relative_path(path : String) -> String {
  let trimmed = path.trim().to_owned()
  if trimmed == "" || trimmed.has_prefix("/") {
    return trimmed
  }
  match normalized_env_var(markitdown_module_root_env_var()) {
    Some(root) => {
      let normalized_root = trim_trailing_slashes(root.trim().to_owned())
      if normalized_root == "" || normalized_root == "." {
        trimmed
      } else if normalized_root == "/" {
        "/" + trimmed
      } else {
        normalized_root + "/" + trimmed
      }
    }
    None => trimmed
  }
}

///|
pub fn is_executable_file(path : String) -> Bool {
  if path.trim() == "" {
    return false
  }
  native_is_executable_file(encode_c_path(path)) != 0
}

///|
pub fn find_in_path(name : String, path_env : String?) -> String? {
  if name.trim() == "" {
    return None
  }
  let path_blob = match path_env {
    Some(value) => encode_c_path(value)
    None => b""
  }
  let result = native_find_in_path(
    encode_c_path(name.trim().to_owned()),
    path_blob,
  )
  let text = (@utf8.decode(result, ignore_bom=false) catch { _ => "" })
    .trim()
    .to_owned()
  if text == "" {
    None
  } else {
    Some(text)
  }
}

///|
pub fn resolve_executable_path(
  raw_path : String,
  label : String,
  source : ResolvedCommandSource,
) -> Result[ResolvedCommand, String] {
  let path = raw_path.trim().to_owned()
  if path == "" {
    return Err(label + " must not be empty")
  }
  if !@fs.path_exists(path) {
    return Err(label + " path does not exist: " + path)
  }
  if !is_executable_file(path) {
    return Err(label + " path is not executable: " + path)
  }
  Ok(make_resolved_command(path, path, source))
}

///|
pub fn resolve_path_command(name : String) -> ResolvedCommand? {
  match find_in_path(name, @env.get_env_var("PATH")) {
    Some(path) => Some(make_resolved_command(path, path, Path))
    None => None
  }
}

///|
pub fn fallback_command(name : String) -> ResolvedCommand {
  make_resolved_command(name, name, Fallback)
}

///|
pub fn repo_managed_command_record_path(name : String) -> String {
  resolve_repo_relative_path("env/managed-paths/" + name.trim().to_owned())
}

///|
pub fn resolve_repo_managed_command(name : String) -> ResolvedCommand? {
  let record_path = repo_managed_command_record_path(name)
  let recorded = @fs.read_file_to_string(record_path, encoding="utf8") catch {
    _ => return None
  }
  let trimmed = recorded.trim().to_owned()
  if trimmed == "" ||
    trimmed.contains("\n") ||
    trimmed.contains("\r") ||
    !trimmed.has_prefix("/") {
    return None
  }
  match resolve_executable_path(trimmed, record_path, RepoManaged) {
    Ok(resolved) => Some(resolved)
    Err(_) => None
  }
}

///|
pub fn shell_quote_command_part(part : String) -> String {
  let mut needs_quote = false
  for ch in part.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '"' || ch == '\\' {
      needs_quote = true
    }
  }
  if !needs_quote {
    return part
  }
  let out : Array[Char] = ['"']
  for ch in part.to_array() {
    if ch == '"' || ch == '\\' {
      out.push('\\')
    }
    out.push(ch)
  }
  out.push('"')
  String::from_array(out)
}

///|
pub fn join_shell_command(parts : Array[String]) -> String {
  let quoted : Array[String] = []
  for part in parts {
    quoted.push(shell_quote_command_part(part))
  }
  quoted.join(" ")
}

///|
pub fn resolved_command_from_parts(
  parts : Array[String],
  source : ResolvedCommandSource,
) -> ResolvedCommand? {
  if parts.length() == 0 {
    None
  } else {
    Some(make_resolved_command(parts[0], join_shell_command(parts), source))
  }
}

///|
pub fn split_shell_command(
  command : String,
) -> Result[Array[String], ShellCommandSplitError] {
  if @fs.path_exists(command) {
    return Ok([command])
  }
  let parts : Array[String] = []
  let current : Array[Char] = []
  let chars = command.to_array()
  let mut in_single_quote = false
  let mut in_double_quote = false
  let mut escape_next = false

  fn flush_current(parts : Array[String], current : Array[Char]) -> Unit {
    if current.length() == 0 {
      return
    }
    parts.push(String::from_array(current))
    current.clear()
  }

  for ch in chars {
    if escape_next {
      current.push(ch)
      escape_next = false
      continue
    }
    if ch == '\\' && !in_single_quote {
      escape_next = true
      continue
    }
    if ch == '\'' && !in_double_quote {
      in_single_quote = !in_single_quote
      continue
    }
    if ch == '"' && !in_single_quote {
      in_double_quote = !in_double_quote
      continue
    }
    if (ch == ' ' || ch == '\t' || ch == '\n') &&
      !in_single_quote &&
      !in_double_quote {
      flush_current(parts, current)
      continue
    }
    current.push(ch)
  }

  if escape_next {
    return Err(TrailingEscape)
  }
  if in_single_quote || in_double_quote {
    return Err(UnterminatedQuotes)
  }
  flush_current(parts, current)
  Ok(parts)
}

///|
fn encode_c_path(value : String) -> Bytes {
  let bytes : Array[Byte] = []
  let encoded = @utf8.encode(value)
  for item in encoded {
    bytes.push(item)
  }
  bytes.push(b'\x00')
  Bytes::from_array(bytes)
}
