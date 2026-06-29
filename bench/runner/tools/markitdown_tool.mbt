///|
pub(all) enum MarkItDownSource {
  ExplicitArg
  EnvVar
  PathLookup
  Fallback
} derive(Eq)

///|
pub struct MarkItDownResolution {
  path : String
  source : MarkItDownSource
} derive(Eq)

///|
pub fn markitdown_tool(explicit_path? : String? = None) -> BenchTool {
  let resolution = resolve_markitdown(explicit_path)
  match resolution {
    Ok(resolved) => {
      let program = resolved.path
      let version = "path=" +
        program +
        ";source=" +
        source_label(resolved.source)
      {
        name: "markitdown",
        tool_version: Some(version),
        availability_note: None,
        command_builder: fn(row, output_path, timeout_ms) {
          {
            program,
            args: [row.input_path, "-o", output_path],
            cwd: None,
            env: [],
            timeout_ms,
            command_kind: "cli-baseline",
            command_display: program + " <input> -o <output>",
          }
        },
      }
    }
    Err(note) => {
      let program = explicit_path.unwrap_or("markitdown")
      {
        name: "markitdown",
        tool_version: None,
        availability_note: Some(note),
        command_builder: fn(_row, output_path, timeout_ms) {
          {
            program,
            args: ["<input>", "-o", output_path],
            cwd: None,
            env: [],
            timeout_ms,
            command_kind: "cli-baseline",
            command_display: program + " <input> -o <output>",
          }
        },
      }
    }
  }
}

///|
fn resolve_markitdown(
  explicit_path : String?,
) -> Result[MarkItDownResolution, String] {
  match explicit_path {
    Some(path) =>
      return resolve_strong_path(
        path,
        "--markitdown-path",
        MarkItDownSource::ExplicitArg,
      )
    None => ()
  }
  match normalized_env_var("MARKITDOWN_BIN") {
    Some(path) =>
      return resolve_strong_path(
        path,
        "MARKITDOWN_BIN",
        MarkItDownSource::EnvVar,
      )
    None => ()
  }
  match find_in_path("markitdown", @env.get_env_var("PATH")) {
    Some(path) => return Ok({ path, source: MarkItDownSource::PathLookup })
    None => ()
  }
  for path in fallback_candidates() {
    if is_executable_file(path) {
      return Ok({ path, source: MarkItDownSource::Fallback })
    }
  }
  Err(
    "markitdown CLI not found via PATH or fallback paths: " +
    fallback_candidates().join(", "),
  )
}

///|
fn resolve_strong_path(
  raw_path : String,
  label : String,
  source : MarkItDownSource,
) -> Result[MarkItDownResolution, String] {
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
  Ok({ path, source })
}

///|
fn normalized_env_var(name : String) -> String? {
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
fn fallback_candidates() -> Array[String] {
  [
    "/usr/local/bin/markitdown", "/opt/homebrew/bin/markitdown", "/Users/winter/miniconda3/bin/markitdown",
  ]
}

///|
fn source_label(source : MarkItDownSource) -> String {
  match source {
    MarkItDownSource::ExplicitArg => "explicit_arg"
    MarkItDownSource::EnvVar => "env_var"
    MarkItDownSource::PathLookup => "path"
    MarkItDownSource::Fallback => "fallback"
  }
}
