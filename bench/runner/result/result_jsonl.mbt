///|
pub struct ReportRequest {
  input_paths : Array[String]
  selector_stats_path : String?
} derive(Eq)

///|
struct LegacyCliResult {
  schema_version : Int
  run_id : String
  repo_commit : String
  runner_mode : String?
  canonical_performance : Bool?
  runner_path : String?
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
  exit_code : Int
  status : String
  timed_out : Bool
  wall_ms : Int
  user_time_us : Int?
  sys_time_us : Int?
  peak_rss_kb : Int?
  stdout_bytes : Int
  stderr_bytes : Int
  output_bytes : Int
  stdout_excerpt : String
  stderr_excerpt : String
  error : String?
} derive(FromJson)

///|
pub fn parse_report_request(args : Array[String]) -> ReportRequest raise {
  let input_paths : Ref[Array[String]] = Ref([])
  let selector_stats_path : Ref[String?] = Ref(None)
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--input" => {
        if i.val + 1 >= args.length() {
          raise @manifest.InvalidArgument("missing value for --input")
        }
        input_paths.val = args[i.val + 1]
          .split(",")
          .to_array()
          .map(item => item.trim().to_owned())
          .filter(item => item != "")
        i.val += 2
      }
      "--selector-stats" => {
        if i.val + 1 >= args.length() {
          raise @manifest.InvalidArgument("missing value for --selector-stats")
        }
        selector_stats_path.val = Some(args[i.val + 1])
        i.val += 2
      }
      _ =>
        raise @manifest.InvalidArgument("unsupported report argument: " + arg)
    }
  }
  if input_paths.val.length() == 0 {
    raise @manifest.InvalidArgument("missing --input")
  }
  make_report_request(input_paths.val, selector_stats_path.val)
}

///|
pub fn make_report_request(
  input_paths : Array[String],
  selector_stats_path : String?,
) -> ReportRequest {
  { input_paths, selector_stats_path }
}

///|
pub fn load_jsonl_results(path : String) -> Array[CliResult] {
  let content = @fs.read_file_to_string(path, encoding="utf8") catch {
    err =>
      abort("failed to read jsonl results: " + path + " :: " + err.to_string())
  }
  let rows : Array[CliResult] = []
  for line in content.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let json = @json.parse(trimmed) catch {
      err =>
        abort("failed to parse jsonl row: " + path + " :: " + err.to_string())
    }
    let row : CliResult = decode_cli_result_row(json, path)
    rows.push(row)
  }
  rows
}

///|
fn decode_cli_result_row(json : Json, path : String) -> CliResult {
  (@json.from_json(json) : CliResult) catch {
    _ =>
      legacy_cli_result_to_current(
        (@json.from_json(json) : LegacyCliResult) catch {
          err =>
            abort(
              "failed to decode jsonl row: " + path + " :: " + err.to_string(),
            )
        },
      )
  }
}

///|
fn legacy_cli_result_to_current(row : LegacyCliResult) -> CliResult {
  {
    schema_version: row.schema_version,
    run_id: row.run_id,
    repo_commit: row.repo_commit,
    runner_mode: row.runner_mode,
    canonical_performance: row.canonical_performance,
    runner_path: row.runner_path,
    tool: row.tool,
    tool_version: row.tool_version,
    measurement_mode: row.measurement_mode,
    output_write_mode: row.output_write_mode,
    bench_id: row.bench_id,
    format: row.format,
    size_class: row.size_class,
    enabled_tier: row.enabled_tier,
    bench_layers: row.bench_layers,
    tags: row.tags,
    rel_path: row.rel_path,
    input_bytes: row.input_bytes,
    input_sha256: row.input_sha256,
    command_kind: row.command_kind,
    command_display: row.command_display,
    repeat_index: row.repeat_index,
    repeat_count: row.repeat_count,
    exit_code: row.exit_code,
    status: row.status,
    timed_out: row.timed_out,
    wall_ms: row.wall_ms.to_int64(),
    wall_us: None,
    user_time_us: row.user_time_us.map(value => value.to_int64()),
    sys_time_us: row.sys_time_us.map(value => value.to_int64()),
    peak_rss_kb: row.peak_rss_kb.map(value => value.to_int64()),
    stdout_bytes: row.stdout_bytes.to_int64(),
    stderr_bytes: row.stderr_bytes.to_int64(),
    output_bytes: row.output_bytes.to_int64(),
    stdout_excerpt: row.stdout_excerpt,
    stderr_excerpt: row.stderr_excerpt,
    error: row.error,
  }
}
