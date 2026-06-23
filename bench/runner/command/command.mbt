///|
pub struct RunRequest {
  tool_name : String
  tier : String
  format_filter : String?
  limit : Int?
  repeat_count : Int
  timeout_ms : Int
  markitdown_path : String?
  cli_output_mode : CliOutputMode
  engine_output_mode : EngineOutputMode
  run_id : String
  git_commit : String
  runner : RunnerContext
} derive(Eq)

///|
pub struct CompareRequest {
  tier : String
  format_filter : String?
  limit : Int?
  repeat_count : Int
  timeout_ms : Int
  markitdown_path : String?
  cli_output_mode : CliOutputMode
  engine_output_mode : EngineOutputMode
  run_id : String
  git_commit : String
  runner : RunnerContext
} derive(Eq)

///|
pub struct DiagnoseRequest {
  repeat_count : Int
  timeout_ms : Int
  cli_output_mode : CliOutputMode
  engine_output_mode : EngineOutputMode
  run_id : String
  git_commit : String
  runner : RunnerContext
} derive(Eq)

///|
pub enum CliOutputMode {
  File
  StdoutCapture
} derive(Eq)

///|
pub enum EngineOutputMode {
  File
  Memory
  None
} derive(Eq)

///|
pub fn default_cli_output_mode() -> CliOutputMode {
  CliOutputMode::File
}

///|
pub fn default_engine_output_mode() -> EngineOutputMode {
  EngineOutputMode::File
}

///|
pub fn cli_output_mode_name(mode : CliOutputMode) -> String {
  match mode {
    CliOutputMode::File => "file"
    CliOutputMode::StdoutCapture => "stdout_capture"
  }
}

///|
pub fn engine_output_mode_name(mode : EngineOutputMode) -> String {
  match mode {
    EngineOutputMode::File => "file"
    EngineOutputMode::Memory => "memory"
    EngineOutputMode::None => "none"
  }
}

///|
pub fn parse_cli_output_mode(text : String) -> CliOutputMode raise {
  match text.trim().to_lower() {
    "file" => CliOutputMode::File
    "stdout_capture" => CliOutputMode::StdoutCapture
    value =>
      raise @manifest.InvalidArgument(
        "unsupported --cli-output-mode value: " +
        value.to_owned() +
        " (expected file|stdout_capture)",
      )
  }
}

///|
pub fn parse_engine_output_mode(text : String) -> EngineOutputMode raise {
  match text.trim().to_lower() {
    "file" => EngineOutputMode::File
    "memory" => EngineOutputMode::Memory
    "none" => EngineOutputMode::None
    value =>
      raise @manifest.InvalidArgument(
        "unsupported --engine-output-mode value: " +
        value.to_owned() +
        " (expected file|memory|none)",
      )
  }
}

///|
pub fn make_run_request(
  tool_name : String,
  tier : String,
  format_filter : String?,
  limit : Int?,
  repeat_count : Int,
  timeout_ms : Int,
  markitdown_path : String?,
  cli_output_mode : CliOutputMode,
  engine_output_mode : EngineOutputMode,
  run_id : String,
  git_commit : String,
  runner : RunnerContext,
) -> RunRequest {
  {
    tool_name,
    tier,
    format_filter,
    limit,
    repeat_count,
    timeout_ms,
    markitdown_path,
    cli_output_mode,
    engine_output_mode,
    run_id,
    git_commit,
    runner,
  }
}

///|
pub fn make_diagnose_request(
  repeat_count : Int,
  timeout_ms : Int,
  cli_output_mode : CliOutputMode,
  engine_output_mode : EngineOutputMode,
  run_id : String,
  git_commit : String,
  runner : RunnerContext,
) -> DiagnoseRequest {
  {
    repeat_count,
    timeout_ms,
    cli_output_mode,
    engine_output_mode,
    run_id,
    git_commit,
    runner,
  }
}

///|
pub fn make_compare_request(
  tier : String,
  format_filter : String?,
  limit : Int?,
  repeat_count : Int,
  timeout_ms : Int,
  markitdown_path : String?,
  cli_output_mode : CliOutputMode,
  engine_output_mode : EngineOutputMode,
  run_id : String,
  git_commit : String,
  runner : RunnerContext,
) -> CompareRequest {
  {
    tier,
    format_filter,
    limit,
    repeat_count,
    timeout_ms,
    markitdown_path,
    cli_output_mode,
    engine_output_mode,
    run_id,
    git_commit,
    runner,
  }
}
