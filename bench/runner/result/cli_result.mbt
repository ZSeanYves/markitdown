///|
pub struct CliResult {
  schema_version : Int
  run_id : String
  repo_commit : String
  runner_mode : String?
  canonical_performance : Bool?
  runner_path : String?
  measurement_policy : String?
  tool : String
  tool_version : String?
  measurement_mode : String?
  output_write_mode : String?
  bench_id : String
  format : String
  size_class : String
  enabled_tier : String
  bench_layers : String
  tags : String
  rel_path : String
  input_bytes : Int
  input_sha256 : String
  command_kind : String
  command_display : String
  repeat_index : Int
  repeat_count : Int
  warmup_count : Int
  exit_code : Int
  status : String
  timed_out : Bool
  wall_ms : Int64
  wall_us : Int64?
  user_time_us : Int64?
  sys_time_us : Int64?
  peak_rss_kb : Int64?
  stdout_bytes : Int64
  stderr_bytes : Int64
  output_bytes : Int64
  stdout_excerpt : String
  stderr_excerpt : String
  error : String?
} derive(ToJson, FromJson, Eq)

///|
pub fn make_cli_result(
  run_id : String,
  git_commit : String,
  runner : @command.RunnerContext,
  warmup_count : Int,
  process_order : String,
  tier : String,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  command : @tools.ToolCommand,
  measured : @measure.NativeMeasureResult,
  repeat_index : Int,
  repeat_count : Int,
  output_path : String,
  output_bytes : Int64,
  stdout_excerpt : String,
  stderr_excerpt : String,
  stdout_bytes : Int64,
  stderr_bytes : Int64,
  output_write_mode? : String? = Some("file"),
) -> CliResult {
  ignore(tier)
  let data = measured.data
  let status = native_measure_status(data)
  let error = native_measure_error(data, command.timeout_ms, stderr_excerpt~)
  ignore(output_path)
  {
    schema_version: 1,
    run_id,
    repo_commit: git_commit,
    runner_mode: Some(runner.runner_mode),
    canonical_performance: Some(runner.canonical_performance),
    runner_path: runner.runner_path,
    measurement_policy: Some(
      "warmup=" +
      warmup_count.to_string() +
      ";samples=" +
      repeat_count.to_string() +
      ";process_order=" +
      process_order,
    ),
    tool: tool.name,
    tool_version: tool.tool_version,
    measurement_mode: Some("process-cli"),
    output_write_mode,
    bench_id: row.bench_id,
    format: row.format,
    size_class: row.size_class,
    enabled_tier: row.enabled_tier,
    bench_layers: row.bench_layers.join(","),
    tags: row.tags.join(","),
    rel_path: row.rel_path,
    input_bytes: row.input_bytes,
    input_sha256: row.sha256,
    command_kind: command.command_kind,
    command_display: command.command_display,
    repeat_index,
    repeat_count,
    warmup_count,
    exit_code: data.exit_code,
    status,
    timed_out: data.timed_out,
    wall_ms: rounded_wall_us_to_ms(data.wall_us),
    wall_us: Some(data.wall_us),
    user_time_us: Some(data.user_time_us),
    sys_time_us: Some(data.sys_time_us),
    peak_rss_kb: Some(data.peak_rss_kb),
    stdout_bytes,
    stderr_bytes,
    output_bytes,
    stdout_excerpt,
    stderr_excerpt,
    error,
  }
}

///|
pub fn make_unavailable_result(
  run_id : String,
  git_commit : String,
  runner : @command.RunnerContext,
  warmup_count : Int,
  process_order : String,
  tier : String,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  repeat_index : Int,
  repeat_count : Int,
) -> CliResult {
  ignore(tier)
  {
    schema_version: 1,
    run_id,
    repo_commit: git_commit,
    runner_mode: Some(runner.runner_mode),
    canonical_performance: Some(runner.canonical_performance),
    runner_path: runner.runner_path,
    measurement_policy: Some(
      "warmup=" +
      warmup_count.to_string() +
      ";samples=" +
      repeat_count.to_string() +
      ";process_order=" +
      process_order,
    ),
    tool: tool.name,
    tool_version: tool.tool_version,
    measurement_mode: if tool.name == "moonbit-engine" {
      Some("inprocess-engine")
    } else {
      Some("process-cli")
    },
    output_write_mode: Some("none"),
    bench_id: row.bench_id,
    format: row.format,
    size_class: row.size_class,
    enabled_tier: row.enabled_tier,
    bench_layers: row.bench_layers.join(","),
    tags: row.tags.join(","),
    rel_path: row.rel_path,
    input_bytes: row.input_bytes,
    input_sha256: row.sha256,
    command_kind: "cli-baseline",
    command_display: tool.name + " unavailable",
    repeat_index,
    repeat_count,
    warmup_count,
    exit_code: 0,
    status: "unavailable",
    timed_out: false,
    wall_ms: 0L,
    wall_us: Some(0L),
    user_time_us: None,
    sys_time_us: None,
    peak_rss_kb: None,
    stdout_bytes: 0L,
    stderr_bytes: 0L,
    output_bytes: 0L,
    stdout_excerpt: "",
    stderr_excerpt: "",
    error: tool.availability_note,
  }
}

///|
pub fn make_inprocess_result(
  run_id : String,
  git_commit : String,
  runner : @command.RunnerContext,
  warmup_count : Int,
  process_order : String,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  command_display : String,
  repeat_index : Int,
  repeat_count : Int,
  wall_us : Int64,
  output_bytes : Int64,
  status? : String = "ok",
  error? : String? = None,
  output_write_mode? : String? = Some("file"),
) -> CliResult {
  let exit_code = if status == "ok" { 0 } else { 1 }
  {
    schema_version: 1,
    run_id,
    repo_commit: git_commit,
    runner_mode: Some(runner.runner_mode),
    canonical_performance: Some(runner.canonical_performance),
    runner_path: runner.runner_path,
    measurement_policy: Some(
      "warmup=" +
      warmup_count.to_string() +
      ";samples=" +
      repeat_count.to_string() +
      ";process_order=" +
      process_order,
    ),
    tool: tool.name,
    tool_version: tool.tool_version,
    measurement_mode: Some("inprocess-engine"),
    output_write_mode,
    bench_id: row.bench_id,
    format: row.format,
    size_class: row.size_class,
    enabled_tier: row.enabled_tier,
    bench_layers: row.bench_layers.join(","),
    tags: row.tags.join(","),
    rel_path: row.rel_path,
    input_bytes: row.input_bytes,
    input_sha256: row.sha256,
    command_kind: "engine-baseline",
    command_display,
    repeat_index,
    repeat_count,
    warmup_count,
    exit_code,
    status,
    timed_out: status == "timeout",
    wall_ms: rounded_wall_us_to_ms(wall_us),
    wall_us: Some(wall_us),
    user_time_us: None,
    sys_time_us: None,
    peak_rss_kb: None,
    stdout_bytes: 0L,
    stderr_bytes: 0L,
    output_bytes,
    stdout_excerpt: "",
    stderr_excerpt: "",
    error,
  }
}
