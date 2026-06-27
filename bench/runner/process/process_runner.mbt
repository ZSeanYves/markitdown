///|
pub async fn run_tool(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
) -> String {
  ensure_bench_dirs()
  ensure_bench_run_dirs(request.run_id)
  let select_request = @manifest.make_select_request(
    request.tier,
    request.exact_tiers,
    request.bench_ids,
    request.format_filters,
    request.limit,
    @manifest.SelectOutput::Jsonl,
    false,
  )
  let result_tier = @command.result_tier_label(
    request.tier,
    request.exact_tiers,
  )
  let rows = @manifest.select_rows(select_request)
  let result_path = @command.result_jsonl_path(
    request.run_id,
    tool.name,
    result_tier,
  )
  @syncfs.write_string_to_file(result_path, "", encoding="utf8") catch {
    err => abort("failed to initialize result jsonl: " + err.to_string())
  }
  if tool.name == "moonbit-engine" {
    return run_inprocess_engine_tool(request, tool, rows, result_path)
  }
  if !tool.is_available() {
    let unavailable_rows : Array[@result.CliResult] = []
    for row in rows {
      for repeat_index in 0..<request.repeat_count {
        unavailable_rows.push(
          @result.make_unavailable_result(
            request.run_id,
            request.git_commit,
            request.runner,
            request.warmup_count,
            "tool_major",
            request.tier,
            tool,
            row,
            repeat_index,
            request.repeat_count,
          ),
        )
      }
    }
    append_result_rows(result_path, unavailable_rows)
    return result_path
  }
  let measured_rows : Array[@result.CliResult] = []
  for row in rows {
    run_tool_warmups(request, tool, row)
    for repeat_index in 0..<request.repeat_count {
      let output_path = @command.output_markdown_path(
        request.run_id,
        tool.name,
        row.bench_id,
        repeat_index,
        request.repeat_count,
      )
      ensure_parent_dir(output_path)
      let stdout_path = output_path + ".stdout"
      let stderr_path = output_path + ".stderr"
      let command = tool.build_command(
        row,
        output_path,
        request.timeout_ms,
        request.cli_output_mode,
        request.engine_output_mode,
      )
      let measured = measure_command(command, stdout_path, stderr_path)
      let stdout_text = read_excerpt(stdout_path)
      let stderr_text = read_excerpt(stderr_path)
      let output_bytes = file_size(output_path)
      let stdout_bytes = file_size(stdout_path)
      let stderr_bytes = file_size(stderr_path)
      let output_write_mode = process_cli_output_mode_name(
        tool.name,
        request.cli_output_mode,
      )
      let result = @result.make_cli_result(
        request.run_id,
        request.git_commit,
        request.runner,
        request.warmup_count,
        "tool_major",
        request.tier,
        tool,
        row,
        command,
        measured,
        repeat_index,
        request.repeat_count,
        output_path,
        output_bytes,
        stdout_text,
        stderr_text,
        stdout_bytes,
        stderr_bytes,
        output_write_mode=Some(output_write_mode),
      )
      measured_rows.push(result)
    }
  }
  append_result_rows(result_path, measured_rows)
  result_path
}

///|
pub async fn run_compare(request : @command.CompareRequest) -> Json {
  ensure_bench_dirs()
  ensure_bench_run_dirs(request.run_id)
  let select_request = @manifest.make_select_request(
    request.tier,
    request.exact_tiers,
    request.bench_ids,
    request.format_filters,
    request.limit,
    @manifest.SelectOutput::Jsonl,
    true,
  )
  let stats_json = @manifest.selector_stats_json(select_request)
  let selector_stats_path = @command.selector_stats_path(request.run_id)
  @syncfs.write_string_to_file(
    selector_stats_path,
    stats_json.stringify() + "\n",
    encoding="utf8",
  ) catch {
    err => abort("failed to write selector stats: " + err.to_string())
  }
  let moonbit_tool = @tools.find_tool("moonbit-cli").unwrap()
  let engine_tool = @tools.find_tool("moonbit-engine").unwrap()
  let markitdown_tool = @tools.find_tool(
    "markitdown",
    config=@tools.make_tool_registry_config(request.markitdown_path),
  ).unwrap()
  let result_paths = run_compare_interleaved(
    request,
    @manifest.select_rows(select_request),
    moonbit_tool,
    engine_tool,
    markitdown_tool,
  )
  let report_request = @result.make_report_request(
    result_paths,
    Some(selector_stats_path),
  )
  @result.generate_report_from_request(report_request)
}

///|
pub async fn run_profile(request : @command.ProfileRequest) -> Json {
  ensure_bench_dirs()
  ensure_profile_dirs(request.run_id)
  let effective_formats = profile_effective_formats(request)
  let stage_cases = profile_stage_cases(effective_formats)
  let entries : Array[ProfileRunEntry] = []
  for case in stage_cases {
    let stdout_path = @command.profile_bench_stdout_path(
      request.run_id,
      case.key,
    )
    let stderr_path = @command.profile_bench_stderr_path(
      request.run_id,
      case.key,
    )
    ensure_parent_dir(stdout_path)
    ensure_parent_dir(stderr_path)
    let stdout = @aprocess.redirect_to_file(
      stdout_path,
      create=0o644,
      truncate=true,
    )
    let stderr = @aprocess.redirect_to_file(
      stderr_path,
      create=0o644,
      truncate=true,
    )
    let exit_code = @aprocess.run(
      "moon",
      case.argv,
      extra_env=profile_env(request, case.formats),
      stdout~,
      stderr~,
      cwd=".",
    )
    let entry : ProfileRunEntry = {
      profile_key: case.key,
      formats: case.formats,
      argv: case.argv,
      stdout_path,
      stderr_path,
      exit_code,
    }
    entries.push(entry)
  }
  let payload : ProfileRunSummary = {
    schema_version: 1,
    run_id: request.run_id,
    profile_kind: request.profile_kind,
    requested_tiers: request.exact_tiers,
    requested_bench_ids: request.bench_ids,
    requested_formats: effective_formats,
    entry_count: entries.length(),
    entries,
  }
  @syncfs.write_string_to_file(
    @command.profile_index_path(request.run_id),
    payload.to_json().stringify() + "\n",
    encoding="utf8",
  ) catch {
    err => abort("failed to write profile index: " + err.to_string())
  }
  payload.to_json()
}

///|
pub fn measure_command(
  command : @tools.ToolCommand,
  stdout_path : String,
  stderr_path : String,
) -> @measure.NativeMeasureResult {
  let argv_values : Array[String] = [command.program]
  argv_values.append(command.args)
  let env_values = command.env.map(pair => pair.0 + "=" + pair.1)
  let argv_blob = @measure.encode_c_string_blob(argv_values)
  let env_blob = @measure.encode_c_string_blob(env_values)
  let spec = @measure.make_native_measure_spec(
    argv_blob,
    argv_blob.length(),
    argv_values.length(),
    env_blob,
    env_blob.length(),
    env_values.length(),
    stdout_path,
    stderr_path,
    command.cwd,
    command.timeout_ms.to_int64(),
  )
  @measure.native_measure_command(spec)
}

///|
async fn ensure_bench_dirs() -> Unit {
  ensure_dir(".tmp/bench")
  ensure_dir(".tmp/bench/runs")
}

///|
async fn ensure_bench_run_dirs(run_id : String) -> Unit {
  ensure_dir(@command.run_root(run_id))
  ensure_dir(@command.results_root(run_id))
  ensure_dir(@command.reports_root(run_id))
  ensure_dir(@command.outputs_root(run_id))
}

///|
async fn ensure_profile_dirs(run_id : String) -> Unit {
  ensure_dir(".tmp/bench")
  ensure_dir(@command.profiles_root())
  ensure_dir(@command.profile_run_root(run_id))
  ensure_dir(@command.profile_results_root(run_id))
  ensure_dir(@command.profile_reports_root(run_id))
}

///|
async fn ensure_dir(path : String) -> Unit {
  @asyncfs.mkdir(path, permission=0o755, recursive=true) catch {
    @os_error.OSError(_) as err if err.is_EEXIST() => ()
    err => raise err
  }
}

///|
async fn ensure_parent_dir(path : String) -> Unit {
  match path.rev_find("/") {
    Some(index) => ensure_dir(path[:index].to_owned())
    None => ()
  }
}

///|
fn append_result_rows(path : String, rows : Array[@result.CliResult]) -> Unit {
  let out = Ref("")
  for row in rows {
    out.val += row.to_json().stringify() + "\n"
  }
  let existing = @syncfs.read_file_to_string(path, encoding="utf8") catch {
    _ => ""
  }
  @syncfs.write_string_to_file(path, existing + out.val, encoding="utf8") catch {
    err => abort("failed to append result rows: " + err.to_string())
  }
}

///|
fn run_tool_warmups(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
) -> Unit {
  if request.warmup_count <= 0 || tool.name == "moonbit-engine" {
    return
  }
  for warmup_index in 0..<request.warmup_count {
    let output_path = @command.output_markdown_path(
      request.run_id,
      tool.name,
      row.bench_id + "-warmup",
      warmup_index,
      request.warmup_count,
    )
    ensure_dir_tree_sync(dirname_of_path_sync(output_path))
    let stdout_path = output_path + ".stdout"
    let stderr_path = output_path + ".stderr"
    let command = tool.build_command(
      row,
      output_path,
      request.timeout_ms,
      request.cli_output_mode,
      request.engine_output_mode,
    )
    ignore(measure_command(command, stdout_path, stderr_path))
  }
}

///|
fn run_compare_interleaved(
  request : @command.CompareRequest,
  rows : Array[@manifest.BenchRow],
  moonbit_tool : @tools.BenchTool,
  engine_tool : @tools.BenchTool,
  markitdown_tool : @tools.BenchTool,
) -> Array[String] {
  let tier_label = @command.result_tier_label(request.tier, request.exact_tiers)
  let moonbit_result_path = @command.result_jsonl_path(
    request.run_id,
    moonbit_tool.name,
    tier_label,
  )
  let engine_result_path = @command.result_jsonl_path(
    request.run_id,
    engine_tool.name,
    tier_label,
  )
  let markitdown_result_path = @command.result_jsonl_path(
    request.run_id,
    markitdown_tool.name,
    tier_label,
  )
  @syncfs.write_string_to_file(moonbit_result_path, "", encoding="utf8") catch {
    err => abort("failed to initialize result jsonl: " + err.to_string())
  }
  @syncfs.write_string_to_file(engine_result_path, "", encoding="utf8") catch {
    err => abort("failed to initialize result jsonl: " + err.to_string())
  }
  @syncfs.write_string_to_file(markitdown_result_path, "", encoding="utf8") catch {
    err => abort("failed to initialize result jsonl: " + err.to_string())
  }
  let moonbit_rows : Array[@result.CliResult] = []
  let engine_rows : Array[@result.CliResult] = []
  let markitdown_rows : Array[@result.CliResult] = []
  let moonbit_run = compare_run_request(request, "moonbit-cli", None)
  let engine_run = compare_run_request(request, "moonbit-engine", None)
  let markitdown_run = compare_run_request(
    request,
    "markitdown",
    request.markitdown_path,
  )

  let moonbit_available = moonbit_tool.is_available()
  let engine_available = engine_tool.is_available()
  let markitdown_available = markitdown_tool.is_available()

  for row in rows {
    run_compare_tool_warmups(moonbit_run, moonbit_tool, row, moonbit_available)
    run_compare_tool_warmups(engine_run, engine_tool, row, engine_available)
    run_compare_tool_warmups(
      markitdown_run, markitdown_tool, row, markitdown_available,
    )
    for repeat_index in 0..<request.repeat_count {
      moonbit_rows.push(
        run_compare_tool_once(
          moonbit_run, moonbit_tool, row, repeat_index, moonbit_result_path, moonbit_available,
        ),
      )
      engine_rows.push(
        run_compare_engine_once(
          engine_run, engine_tool, row, repeat_index, engine_available,
        ),
      )
      markitdown_rows.push(
        run_compare_tool_once(
          markitdown_run, markitdown_tool, row, repeat_index, markitdown_result_path,
          markitdown_available,
        ),
      )
    }
  }
  append_result_rows(moonbit_result_path, moonbit_rows)
  append_result_rows(engine_result_path, engine_rows)
  append_result_rows(markitdown_result_path, markitdown_rows)
  [moonbit_result_path, engine_result_path, markitdown_result_path]
}

///|
fn compare_run_request(
  request : @command.CompareRequest,
  tool_name : String,
  markitdown_path : String?,
) -> @command.RunRequest {
  @command.make_run_request(
    tool_name,
    request.tier,
    request.exact_tiers,
    request.bench_ids,
    request.format_filters,
    request.limit,
    request.repeat_count,
    request.warmup_count,
    request.timeout_ms,
    markitdown_path,
    request.cli_output_mode,
    request.engine_output_mode,
    request.run_id,
    request.git_commit,
    request.runner,
  )
}

///|
fn run_compare_tool_warmups(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  available : Bool,
) -> Unit {
  if request.warmup_count <= 0 || !available {
    return
  }
  if tool.name == "moonbit-engine" {
    for _ in 0..<request.warmup_count {
      ignore(
        @convert.convert_input(
          @input.input_from_path(row.input_path),
          @convert.default_convert_options(),
        ),
      )
    }
    return
  }
  for warmup_index in 0..<request.warmup_count {
    let output_path = @command.output_markdown_path(
      request.run_id,
      tool.name,
      row.bench_id + "-warmup",
      warmup_index,
      request.warmup_count,
    )
    ensure_dir_tree_sync(dirname_of_path_sync(output_path))
    let stdout_path = output_path + ".stdout"
    let stderr_path = output_path + ".stderr"
    let command = tool.build_command(
      row,
      output_path,
      request.timeout_ms,
      request.cli_output_mode,
      request.engine_output_mode,
    )
    ignore(measure_command(command, stdout_path, stderr_path))
  }
}

///|
fn run_compare_tool_once(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  repeat_index : Int,
  _result_path : String,
  available : Bool,
) -> @result.CliResult {
  if !available {
    return @result.make_unavailable_result(
      request.run_id,
      request.git_commit,
      request.runner,
      request.warmup_count,
      "row_major",
      request.tier,
      tool,
      row,
      repeat_index,
      request.repeat_count,
    )
  }
  let output_path = @command.output_markdown_path(
    request.run_id,
    tool.name,
    row.bench_id,
    repeat_index,
    request.repeat_count,
  )
  ensure_dir_tree_sync(dirname_of_path_sync(output_path))
  let stdout_path = output_path + ".stdout"
  let stderr_path = output_path + ".stderr"
  let command = tool.build_command(
    row,
    output_path,
    request.timeout_ms,
    request.cli_output_mode,
    request.engine_output_mode,
  )
  let measured = measure_command(command, stdout_path, stderr_path)
  let stdout_text = read_excerpt(stdout_path)
  let stderr_text = read_excerpt(stderr_path)
  let output_bytes = file_size(output_path)
  let stdout_bytes = file_size(stdout_path)
  let stderr_bytes = file_size(stderr_path)
  let output_write_mode = process_cli_output_mode_name(
    tool.name,
    request.cli_output_mode,
  )
  @result.make_cli_result(
    request.run_id,
    request.git_commit,
    request.runner,
    request.warmup_count,
    "row_major",
    request.tier,
    tool,
    row,
    command,
    measured,
    repeat_index,
    request.repeat_count,
    output_path,
    output_bytes,
    stdout_text,
    stderr_text,
    stdout_bytes,
    stderr_bytes,
    output_write_mode=Some(output_write_mode),
  )
}

///|
fn run_compare_engine_once(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
  row : @manifest.BenchRow,
  repeat_index : Int,
  available : Bool,
) -> @result.CliResult {
  if !available {
    return @result.make_unavailable_result(
      request.run_id,
      request.git_commit,
      request.runner,
      request.warmup_count,
      "row_major",
      request.tier,
      tool,
      row,
      repeat_index,
      request.repeat_count,
    )
  }
  let output_path = @command.output_markdown_path(
    request.run_id,
    tool.name,
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
  let rendered = match converted {
    Ok(value) => value
    Err(err) =>
      return @result.make_inprocess_result(
        request.run_id,
        request.git_commit,
        request.runner,
        request.warmup_count,
        "row_major",
        tool,
        row,
        command.command_display,
        repeat_index,
        request.repeat_count,
        monotonic_elapsed_us_int64(started),
        0L,
        status="failed",
        error=Some(err.to_string()),
        output_write_mode=Some(
          @command.engine_output_mode_name(request.engine_output_mode),
        ),
      )
  }
  let finalized = try
    finalize_engine_output(
      row.input_path,
      output_path,
      rendered,
      request.engine_output_mode,
    )
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  let wall_us = monotonic_elapsed_us_int64(started)
  match finalized {
    Ok(output_bytes) =>
      @result.make_inprocess_result(
        request.run_id,
        request.git_commit,
        request.runner,
        request.warmup_count,
        "row_major",
        tool,
        row,
        command.command_display,
        repeat_index,
        request.repeat_count,
        wall_us,
        output_bytes,
        output_write_mode=Some(
          @command.engine_output_mode_name(request.engine_output_mode),
        ),
      )
    Err(message) =>
      @result.make_inprocess_result(
        request.run_id,
        request.git_commit,
        request.runner,
        request.warmup_count,
        "row_major",
        tool,
        row,
        command.command_display,
        repeat_index,
        request.repeat_count,
        wall_us,
        file_size(output_path),
        status="failed",
        error=Some("write output failed: " + message),
        output_write_mode=Some(
          @command.engine_output_mode_name(request.engine_output_mode),
        ),
      )
  }
}

///|
fn read_excerpt(path : String) -> String {
  let text = @syncfs.read_file_to_string(path, encoding="utf8") catch {
    _ => ""
  }
  if text.length() <= 500 {
    text
  } else {
    text[:500].to_owned()
  }
}

///|
fn file_size(path : String) -> Int64 {
  if !@syncfs.path_exists(path) {
    return 0L
  }
  @syncfs.read_file_to_bytes(path).length().to_int64() catch {
    _ => 0L
  }
}

///|
fn process_cli_output_mode_name(
  tool_name : String,
  cli_output_mode : @command.CliOutputMode,
) -> String {
  if tool_name == "moonbit-cli" {
    @command.cli_output_mode_name(cli_output_mode)
  } else {
    "file"
  }
}

///|
priv struct ProfileStageCase {
  key : String
  formats : Array[String]
  argv : Array[String]
}

///|
priv struct ProfileRunEntry {
  profile_key : String
  formats : Array[String]
  argv : Array[String]
  stdout_path : String
  stderr_path : String
  exit_code : Int
} derive(ToJson)

///|
priv struct ProfileRunSummary {
  schema_version : Int
  run_id : String
  profile_kind : String
  requested_tiers : Array[String]
  requested_bench_ids : Array[String]
  requested_formats : Array[String]
  entry_count : Int
  entries : Array[ProfileRunEntry]
} derive(ToJson)

///|
fn profile_effective_formats(
  request : @command.ProfileRequest,
) -> Array[String] {
  if request.formats.length() > 0 {
    let formats = request.formats.map(format => {
      format.trim().to_lower().to_owned()
    })
    formats.dedup()
    return formats
  }
  @shared.official_gate_main_formats()
}

///|
fn profile_stage_cases(formats : Array[String]) -> Array[ProfileStageCase] {
  let rows : Array[ProfileStageCase] = []
  let normalized = formats
    .map(format => format.trim().to_lower().to_owned())
    .filter(format => format != "")
  normalized.dedup()
  if normalized.length() > 0 {
    rows.push(
      profile_stage_case("official-gate-convert-total", normalized, [
        "bench", "--target", "native", "--release", "--package", "ZSeanYves/markitdown/bench/pipeline",
        "--file", "convert_pipeline_bench_test.mbt", "--no-parallelize",
      ]),
    )
  }
  for format in normalized {
    match pipeline_profile_file_for_format(format) {
      Some(file_name) =>
        rows.push(
          profile_stage_case(format, [format], [
            "bench", "--target", "native", "--release", "--package", "ZSeanYves/markitdown/bench/pipeline",
            "--file", file_name, "--no-parallelize",
          ]),
        )
      None => ()
    }
  }
  rows
}

///|
fn profile_stage_case(
  key : String,
  formats : Array[String],
  argv : Array[String],
) -> ProfileStageCase {
  { key, formats, argv }
}

///|
fn pipeline_profile_file_for_format(format : String) -> String? {
  match format {
    "txt" | "csv" | "tsv" => Some("convert_pipeline_bench_test.mbt")
    "json" => Some("json_stage_bench_test.mbt")
    "yaml" => Some("yaml_stage_bench_test.mbt")
    "xml" => Some("xml_stage_bench_test.mbt")
    "markdown" => Some("markdown_stage_bench_test.mbt")
    "html" => Some("html_stage_bench_test.mbt")
    "zip" => Some("zip_stage_bench_test.mbt")
    "epub" => Some("epub_stage_bench_test.mbt")
    "pdf" => Some("pdf_stage_bench_test.mbt")
    "docx" => Some("docx_stage_bench_test.mbt")
    "pptx" => Some("pptx_stage_bench_test.mbt")
    "xlsx" => Some("xlsx_stage_bench_test.mbt")
    _ => None
  }
}

///|
fn profile_env(
  request : @command.ProfileRequest,
  formats : Array[String],
) -> Map[String, String] {
  {
    "MARKITDOWN_BENCH_PROFILE_BENCH_IDS": request.bench_ids.join(","),
    "MARKITDOWN_BENCH_PROFILE_FORMATS": formats.join(","),
  }
}
