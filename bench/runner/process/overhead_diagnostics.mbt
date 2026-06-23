///|
struct OverheadDiagnosticResult {
  schema_version : Int
  run_id : String
  repo_commit : String
  runner_mode : String
  canonical_performance : Bool
  runner_path : String?
  diagnostic : String
  command_kind : String
  measurement_mode : String
  output_write_mode : String?
  repeat_index : Int
  repeat_count : Int
  exit_code : Int
  status : String
  wall_us : Int64
  stdout_bytes : Int64
  stderr_bytes : Int64
  output_bytes : Int64
  error : String?
} derive(ToJson, FromJson, Eq)

///|
struct OverheadDiagnosticAggregate {
  diagnostic : String
  repeat_count : Int
  success_count : Int
  status : String
  median_wall_us : Int64?
  min_wall_us : Int64?
  max_wall_us : Int64?
  interpretation : String
} derive(ToJson, FromJson, Eq)

///|
pub async fn run_overhead_diagnostics(
  request : @command.DiagnoseRequest,
) -> Json {
  ensure_bench_dirs()
  let results = collect_overhead_diagnostics(request)
  let result_path = @command.overhead_result_jsonl_path(request.run_id)
  write_overhead_jsonl(result_path, results)
  let report_path = @command.overhead_report_markdown_path(request.run_id)
  @syncfs.write_string_to_file(
    report_path,
    render_overhead_markdown_report(request, results) + "\n",
    encoding="utf8",
  ) catch {
    err => abort("failed to write overhead markdown report: " + err.to_string())
  }
  Json::object({
    "overhead_jsonl": result_path.to_json(),
    "overhead_md": report_path.to_json(),
  })
}

///|
fn collect_overhead_diagnostics(
  request : @command.DiagnoseRequest,
) -> Array[OverheadDiagnosticResult] {
  let out : Array[OverheadDiagnosticResult] = []
  out.append(measurement_noop_results(request))
  out.append(process_true_results(request))
  out.append(process_echo_empty_results(request))
  out.append(moonbit_cli_help_results(request))
  out.append(moonbit_cli_bench_results(request, "txt_tiny_plain_v1"))
  out.append(
    moonbit_cli_bench_results(request, "html_small_synthetic_articles_v1"),
  )
  out.append(moonbit_engine_bench_results(request, "txt_tiny_plain_v1"))
  out.append(
    moonbit_engine_bench_results(request, "html_small_synthetic_articles_v1"),
  )
  out
}

///|
fn measurement_noop_results(
  request : @command.DiagnoseRequest,
) -> Array[OverheadDiagnosticResult] {
  let out : Array[OverheadDiagnosticResult] = []
  for repeat_index in 0..<request.repeat_count {
    let started = @measure.monotonic_start()
    let wall_us = monotonic_elapsed_us_int64(started)
    out.push({
      schema_version: 1,
      run_id: request.run_id,
      repo_commit: request.git_commit,
      runner_mode: request.runner.runner_mode,
      canonical_performance: request.runner.canonical_performance,
      runner_path: request.runner.runner_path,
      diagnostic: "measurement_noop",
      command_kind: "measurement-baseline",
      measurement_mode: "diagnostic",
      output_write_mode: Some("none"),
      repeat_index,
      repeat_count: request.repeat_count,
      exit_code: 0,
      status: "ok",
      wall_us,
      stdout_bytes: 0L,
      stderr_bytes: 0L,
      output_bytes: 0L,
      error: None,
    })
  }
  out
}

///|
fn process_true_results(
  request : @command.DiagnoseRequest,
) -> Array[OverheadDiagnosticResult] {
  let program = resolve_diagnostic_program("true", [
    "/usr/bin/true", "/bin/true",
  ])
  run_command_diagnostic(
    request,
    "process_true",
    "diagnostic-process",
    program,
    [],
    output_write_mode=Some("none"),
  )
}

///|
fn process_echo_empty_results(
  request : @command.DiagnoseRequest,
) -> Array[OverheadDiagnosticResult] {
  let program = resolve_diagnostic_program("echo", [
    "/bin/echo", "/usr/bin/echo",
  ])
  run_command_diagnostic(
    request,
    "process_echo_empty",
    "diagnostic-process",
    program,
    [""],
    output_write_mode=Some("stdout_capture"),
  )
}

///|
fn moonbit_cli_help_results(
  request : @command.DiagnoseRequest,
) -> Array[OverheadDiagnosticResult] {
  let tool = @tools.moonbit_cli_tool()
  if !tool.is_available() {
    return unavailable_diagnostic_results(
      request,
      "moonbit_cli_help",
      "cli-baseline",
      tool.availability_note.unwrap_or("built cli unavailable"),
    )
  }
  let command = @tools.make_tool_command(
    "_build/native/release/build/cli/cli.exe",
    ["help"],
    None,
    [],
    request.timeout_ms,
    "cli-baseline",
    "_build/native/release/build/cli/cli.exe help",
  )
  run_command_diagnostic_from_command(
    request,
    "moonbit_cli_help",
    command,
    output_write_mode=Some("stdout_capture"),
  )
}

///|
fn moonbit_cli_bench_results(
  request : @command.DiagnoseRequest,
  bench_id : String,
) -> Array[OverheadDiagnosticResult] {
  let row = find_bench_row_by_id(bench_id)
  let tool = @tools.moonbit_cli_tool()
  if !tool.is_available() {
    return unavailable_diagnostic_results(
      request,
      "moonbit_cli_" + row.format,
      "cli-baseline",
      tool.availability_note.unwrap_or("built cli unavailable"),
    )
  }
  let diagnostic = if row.format == "txt" {
    "moonbit_cli_tiny_txt"
  } else {
    "moonbit_cli_small_html"
  }
  let out : Array[OverheadDiagnosticResult] = []
  for repeat_index in 0..<request.repeat_count {
    let output_path = @command.output_markdown_path(
      request.run_id,
      "diagnostic-" + diagnostic,
      row.bench_id,
      repeat_index,
      request.repeat_count,
    )
    ensure_dir_tree_sync(dirname_of_path_sync(output_path))
    let command = tool.build_command(
      row,
      output_path,
      request.timeout_ms,
      request.cli_output_mode,
      request.engine_output_mode,
    )
    out.push(
      measure_diagnostic_command(
        request,
        diagnostic,
        repeat_index,
        command,
        output_path,
        output_write_mode=Some(
          @command.cli_output_mode_name(request.cli_output_mode),
        ),
      ),
    )
  }
  out
}

///|
fn moonbit_engine_bench_results(
  request : @command.DiagnoseRequest,
  bench_id : String,
) -> Array[OverheadDiagnosticResult] {
  let row = find_bench_row_by_id(bench_id)
  let tool = @tools.moonbit_engine_tool()
  let diagnostic = if row.format == "txt" {
    "moonbit_engine_tiny_txt"
  } else {
    "moonbit_engine_small_html"
  }
  let out : Array[OverheadDiagnosticResult] = []
  for repeat_index in 0..<request.repeat_count {
    let output_path = @command.output_markdown_path(
      request.run_id,
      "diagnostic-" + diagnostic,
      row.bench_id,
      repeat_index,
      request.repeat_count,
    )
    let command = tool.build_command(
      row,
      output_path,
      request.timeout_ms,
      request.cli_output_mode,
      request.engine_output_mode,
    )
    let started = @measure.monotonic_start()
    let converted = @convert.convert_input(
      @input.input_from_path(row.input_path),
      @convert.default_convert_options(),
    )
    match converted {
      Ok(value) => {
        let finalized = try
          finalize_engine_output(
            row.input_path,
            output_path,
            value,
            request.engine_output_mode,
          )
          |> Ok
        catch {
          err => Err(err.to_string())
        }
        let wall_us = monotonic_elapsed_us_int64(started)
        match finalized {
          Ok(output_bytes) =>
            out.push({
              schema_version: 1,
              run_id: request.run_id,
              repo_commit: request.git_commit,
              runner_mode: request.runner.runner_mode,
              canonical_performance: request.runner.canonical_performance,
              runner_path: request.runner.runner_path,
              diagnostic,
              command_kind: command.command_kind,
              measurement_mode: "inprocess-engine",
              output_write_mode: Some(
                @command.engine_output_mode_name(request.engine_output_mode),
              ),
              repeat_index,
              repeat_count: request.repeat_count,
              exit_code: 0,
              status: "ok",
              wall_us,
              stdout_bytes: 0L,
              stderr_bytes: 0L,
              output_bytes,
              error: None,
            })
          Err(message) =>
            out.push({
              schema_version: 1,
              run_id: request.run_id,
              repo_commit: request.git_commit,
              runner_mode: request.runner.runner_mode,
              canonical_performance: request.runner.canonical_performance,
              runner_path: request.runner.runner_path,
              diagnostic,
              command_kind: command.command_kind,
              measurement_mode: "inprocess-engine",
              output_write_mode: Some(
                @command.engine_output_mode_name(request.engine_output_mode),
              ),
              repeat_index,
              repeat_count: request.repeat_count,
              exit_code: 1,
              status: "failed",
              wall_us,
              stdout_bytes: 0L,
              stderr_bytes: 0L,
              output_bytes: file_size(output_path),
              error: Some("write output failed: " + message),
            })
        }
      }
      Err(err) =>
        out.push({
          schema_version: 1,
          run_id: request.run_id,
          repo_commit: request.git_commit,
          runner_mode: request.runner.runner_mode,
          canonical_performance: request.runner.canonical_performance,
          runner_path: request.runner.runner_path,
          diagnostic,
          command_kind: command.command_kind,
          measurement_mode: "inprocess-engine",
          output_write_mode: Some(
            @command.engine_output_mode_name(request.engine_output_mode),
          ),
          repeat_index,
          repeat_count: request.repeat_count,
          exit_code: 1,
          status: "failed",
          wall_us: monotonic_elapsed_us_int64(started),
          stdout_bytes: 0L,
          stderr_bytes: 0L,
          output_bytes: 0L,
          error: Some(err.to_string()),
        })
    }
  }
  out
}

///|
fn run_command_diagnostic(
  request : @command.DiagnoseRequest,
  diagnostic : String,
  command_kind : String,
  program : String?,
  args : Array[String],
  output_write_mode? : String? = Some("file"),
) -> Array[OverheadDiagnosticResult] {
  match program {
    Some(value) =>
      run_command_diagnostic_from_command(
        request,
        diagnostic,
        @tools.make_tool_command(
          value,
          args,
          None,
          [],
          request.timeout_ms,
          command_kind,
          value + " " + args.join(" "),
        ),
        output_write_mode~,
      )
    None =>
      unavailable_diagnostic_results(
        request, diagnostic, command_kind, "command unavailable",
      )
  }
}

///|
fn run_command_diagnostic_from_command(
  request : @command.DiagnoseRequest,
  diagnostic : String,
  command : @tools.ToolCommand,
  output_write_mode? : String? = Some("file"),
) -> Array[OverheadDiagnosticResult] {
  let out : Array[OverheadDiagnosticResult] = []
  for repeat_index in 0..<request.repeat_count {
    let output_path = @command.output_markdown_path(
      request.run_id,
      "diagnostic-" + diagnostic,
      diagnostic,
      repeat_index,
      request.repeat_count,
    )
    ensure_dir_tree_sync(dirname_of_path_sync(output_path))
    out.push(
      measure_diagnostic_command(
        request,
        diagnostic,
        repeat_index,
        command,
        output_path,
        output_write_mode~,
      ),
    )
  }
  out
}

///|
fn measure_diagnostic_command(
  request : @command.DiagnoseRequest,
  diagnostic : String,
  repeat_index : Int,
  command : @tools.ToolCommand,
  output_path : String,
  output_write_mode? : String? = Some("file"),
) -> OverheadDiagnosticResult {
  let stdout_path = output_path + ".stdout"
  let stderr_path = output_path + ".stderr"
  let measured = measure_command(command, stdout_path, stderr_path)
  let data = measured.data
  {
    schema_version: 1,
    run_id: request.run_id,
    repo_commit: request.git_commit,
    runner_mode: request.runner.runner_mode,
    canonical_performance: request.runner.canonical_performance,
    runner_path: request.runner.runner_path,
    diagnostic,
    command_kind: command.command_kind,
    measurement_mode: "process-cli",
    output_write_mode,
    repeat_index,
    repeat_count: request.repeat_count,
    exit_code: data.exit_code,
    status: @result.native_measure_status(data),
    wall_us: data.wall_us,
    stdout_bytes: file_size(stdout_path),
    stderr_bytes: file_size(stderr_path),
    output_bytes: file_size(output_path),
    error: @result.native_measure_error(data, command.timeout_ms),
  }
}

///|
fn unavailable_diagnostic_results(
  request : @command.DiagnoseRequest,
  diagnostic : String,
  command_kind : String,
  error : String,
) -> Array[OverheadDiagnosticResult] {
  let out : Array[OverheadDiagnosticResult] = []
  for repeat_index in 0..<request.repeat_count {
    out.push({
      schema_version: 1,
      run_id: request.run_id,
      repo_commit: request.git_commit,
      runner_mode: request.runner.runner_mode,
      canonical_performance: request.runner.canonical_performance,
      runner_path: request.runner.runner_path,
      diagnostic,
      command_kind,
      measurement_mode: "diagnostic",
      output_write_mode: Some("none"),
      repeat_index,
      repeat_count: request.repeat_count,
      exit_code: 0,
      status: "unavailable",
      wall_us: 0L,
      stdout_bytes: 0L,
      stderr_bytes: 0L,
      output_bytes: 0L,
      error: Some(error),
    })
  }
  out
}

///|
fn resolve_diagnostic_program(
  lookup_name : String,
  fallbacks : Array[String],
) -> String? {
  for path in fallbacks {
    if @tools.is_executable_file(path) {
      return Some(path)
    }
  }
  match @tools.find_in_path(lookup_name, @env.get_env_var("PATH")) {
    Some(path) => Some(path)
    None => None
  }
}

///|
fn find_bench_row_by_id(bench_id : String) -> @manifest.BenchRow {
  let rows = @manifest.select_rows(
    @manifest.make_select_request(
      "smoke",
      None,
      None,
      @manifest.SelectOutput::Jsonl,
      false,
    ),
  )
  for row in rows {
    if row.bench_id == bench_id {
      return row
    }
  }
  abort("missing bench row for diagnostic: " + bench_id)
}

///|
fn write_overhead_jsonl(
  path : String,
  rows : Array[OverheadDiagnosticResult],
) -> Unit {
  let out = Ref("")
  for row in rows {
    out.val += row.to_json().stringify() + "\n"
  }
  @syncfs.write_string_to_file(path, out.val, encoding="utf8") catch {
    err => abort("failed to write overhead jsonl: " + err.to_string())
  }
}

///|
fn render_overhead_markdown_report(
  request : @command.DiagnoseRequest,
  rows : Array[OverheadDiagnosticResult],
) -> String {
  let lines : Array[String] = ["# Runner Overhead Diagnostics", ""]
  lines.push("- run id: `" + request.run_id + "`")
  lines.push("- git commit: `" + request.git_commit + "`")
  lines.push("- runner mode: `" + request.runner.runner_mode + "`")
  lines.push(
    "- canonical performance: `" +
    request.runner.canonical_performance.to_string() +
    "`",
  )
  lines.push(
    "- runner path: `" + request.runner.runner_path.unwrap_or("unknown") + "`",
  )
  lines.push("- repeat count: `" + request.repeat_count.to_string() + "`")
  lines.push("")
  if !request.runner.canonical_performance {
    lines.push("## Warning")
    for
      warning in @result.canonical_runner_warnings(
        request.runner.runner_mode,
        request.runner.canonical_performance,
        has_inprocess_engine=true,
      ) {
      lines.push(warning)
    }
    lines.push("")
  }
  lines.push("## Diagnostic Baselines")
  lines.push(
    markdown_table_row_overhead([
      "diagnostic", "status", "ok/repeat", "median ms", "median us", "min us", "max us",
      "interpretation",
    ]),
  )
  lines.push(markdown_table_separator_overhead(8))
  for aggregate in summarize_overhead_rows(rows) {
    lines.push(
      markdown_table_row_overhead([
        aggregate.diagnostic,
        aggregate.status,
        aggregate.success_count.to_string() +
        "/" +
        aggregate.repeat_count.to_string(),
        @result.format_wall_ms_from_us(aggregate.median_wall_us),
        @result.format_optional_int64(aggregate.median_wall_us),
        @result.format_optional_int64(aggregate.min_wall_us),
        @result.format_optional_int64(aggregate.max_wall_us),
        aggregate.interpretation,
      ]),
    )
  }
  lines.join("\n")
}

///|
fn summarize_overhead_rows(
  rows : Array[OverheadDiagnosticResult],
) -> Array[OverheadDiagnosticAggregate] {
  let grouped : Map[String, Array[OverheadDiagnosticResult]] = {}
  for row in rows {
    grouped[row.diagnostic] = match grouped.get(row.diagnostic) {
      Some(existing) => {
        let next = existing.copy()
        next.push(row)
        next
      }
      None => [row]
    }
  }
  let out : Array[OverheadDiagnosticAggregate] = []
  for entry in grouped {
    out.push(summarize_overhead_row(entry.0, entry.1))
  }
  out.sort_by(fn(a, b) { a.diagnostic[:].lexical_compare(b.diagnostic[:]) })
  out
}

///|
fn summarize_overhead_row(
  diagnostic : String,
  rows : Array[OverheadDiagnosticResult],
) -> OverheadDiagnosticAggregate {
  let ok_rows = rows.filter(row => row.status == "ok")
  let wall_values = ok_rows.map(row => row.wall_us)
  wall_values.sort()
  {
    diagnostic,
    repeat_count: rows[0].repeat_count,
    success_count: ok_rows.length(),
    status: aggregate_overhead_status(rows),
    median_wall_us: median_sorted_int64_overhead(wall_values),
    min_wall_us: first_sorted_int64_overhead(wall_values),
    max_wall_us: wall_values.last(),
    interpretation: diagnostic_interpretation(diagnostic),
  }
}

///|
fn diagnostic_interpretation(diagnostic : String) -> String {
  match diagnostic {
    "measurement_noop" => "Runner monotonic clock overhead only."
    "process_true" => "Approximate fork/exec plus wait4 baseline."
    "process_echo_empty" =>
      "Process launch plus minimal stdout capture baseline."
    "moonbit_cli_help" => "Built CLI startup and argument dispatch overhead."
    "moonbit_cli_tiny_txt" =>
      "Real CLI tiny text conversion including IO and selected output mode."
    "moonbit_cli_small_html" =>
      "Real CLI small HTML conversion including IO and selected output mode."
    "moonbit_engine_tiny_txt" =>
      "In-process engine tiny text convert with selected output mode."
    "moonbit_engine_small_html" =>
      "In-process engine small HTML convert with selected output mode."
    _ => "Diagnostic baseline."
  }
}

///|
fn aggregate_overhead_status(rows : Array[OverheadDiagnosticResult]) -> String {
  let run_count = rows.length()
  let success_count = rows.filter(row => row.status == "ok").length()
  if success_count == run_count {
    return "ok"
  }
  if success_count > 0 {
    return "partial_success"
  }
  if rows.filter(row => row.status == "unavailable").length() == run_count {
    "unavailable"
  } else if rows.filter(row => row.status == "timeout").length() == run_count {
    "timeout"
  } else if rows.filter(row => row.status == "measurement_error").length() ==
    run_count {
    "measurement_error"
  } else {
    "failed"
  }
}

///|
fn markdown_table_row_overhead(cells : Array[String]) -> String {
  "| " + cells.join(" | ") + " |"
}

///|
fn markdown_table_separator_overhead(columns : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<columns {
    cells.push("---")
  }
  markdown_table_row_overhead(cells)
}

///|
fn median_sorted_int64_overhead(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    return None
  }
  let middle = values.length() / 2
  if values.length() % 2 == 1 {
    Some(values[middle])
  } else {
    Some((values[middle - 1] + values[middle]) / 2L)
  }
}

///|
fn first_sorted_int64_overhead(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn monotonic_elapsed_us_int64(started : @bench.Timestamp) -> Int64 {
  @measure.monotonic_elapsed_us(started).to_int64()
}
