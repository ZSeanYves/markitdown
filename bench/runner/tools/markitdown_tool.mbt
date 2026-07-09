///|
pub fn markitdown_tool(explicit_path? : String? = None) -> BenchTool {
  let resolution = resolve_markitdown(explicit_path)
  match resolution {
    Ok(resolved) => {
      let program = resolved.program
      let version = "path=" +
        program +
        ";source=" +
        @rtcmd.resolved_command_source_label(resolved.source)
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
) -> Result[@rtcmd.ResolvedCommand, String] {
  match explicit_path {
    Some(path) =>
      return resolve_strong_path(
        path,
        "--markitdown-path",
        @rtcmd.ResolvedCommandSource::ExplicitArg,
      )
    None => ()
  }
  let repo_local = repo_local_markitdown_baseline_path()
  if @rtcmd.is_executable_file(repo_local) {
    return Ok(
      @rtcmd.make_resolved_command(
        repo_local,
        repo_local,
        @rtcmd.ResolvedCommandSource::RepoManaged,
      ),
    )
  }
  match @rtcmd.normalized_env_var("MARKITDOWN_BIN") {
    Some(path) =>
      return resolve_strong_path(
        path,
        "MARKITDOWN_BIN",
        @rtcmd.ResolvedCommandSource::EnvVar,
      )
    None => ()
  }
  match @rtcmd.resolve_path_command("markitdown") {
    Some(path) => return Ok(path)
    None => ()
  }
  for path in fallback_candidates() {
    if @rtcmd.is_executable_file(path) {
      return Ok(
        @rtcmd.make_resolved_command(
          path,
          path,
          @rtcmd.ResolvedCommandSource::Fallback,
        ),
      )
    }
  }
  Err(
    "markitdown CLI not found via repo-managed baseline, MARKITDOWN_BIN, PATH, or fallback paths: " +
    fallback_candidates().join(", "),
  )
}

///|
fn resolve_strong_path(
  raw_path : String,
  label : String,
  source : @rtcmd.ResolvedCommandSource,
) -> Result[@rtcmd.ResolvedCommand, String] {
  @rtcmd.resolve_executable_path(raw_path, label, source)
}

///|
fn repo_local_markitdown_baseline_path() -> String {
  "env/.venv-markitdown-baseline/bin/markitdown"
}

///|
fn fallback_candidates() -> Array[String] {
  ["/usr/local/bin/markitdown", "/opt/homebrew/bin/markitdown"]
}
