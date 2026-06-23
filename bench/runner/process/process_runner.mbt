///|
pub async fn run_tool(
  request : @command.RunRequest,
  tool : @tools.BenchTool,
) -> String {
  ensure_bench_dirs()
  let select_request = @manifest.make_select_request(
    request.tier,
    request.format_filter,
    request.limit,
    @manifest.SelectOutput::Jsonl,
    false,
  )
  let rows = @manifest.select_rows(select_request)
  let result_path = @command.result_jsonl_path(
    request.run_id,
    tool.name,
    request.tier,
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
  for row in rows {
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
      append_result_rows(result_path, [result])
    }
  }
  result_path
}

///|
pub async fn run_compare(request : @command.CompareRequest) -> Json {
  ensure_bench_dirs()
  let select_request = @manifest.make_select_request(
    request.tier,
    request.format_filter,
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
  let moonbit_result = run_tool(
    @command.make_run_request(
      "moonbit-cli",
      request.tier,
      request.format_filter,
      request.limit,
      request.repeat_count,
      request.timeout_ms,
      None,
      request.cli_output_mode,
      request.engine_output_mode,
      request.run_id,
      request.git_commit,
      request.runner,
    ),
    moonbit_tool,
  )
  let result_paths : Array[String] = [moonbit_result]
  result_paths.push(
    run_tool(
      @command.make_run_request(
        "moonbit-engine",
        request.tier,
        request.format_filter,
        request.limit,
        request.repeat_count,
        request.timeout_ms,
        None,
        request.cli_output_mode,
        request.engine_output_mode,
        request.run_id,
        request.git_commit,
        request.runner,
      ),
      engine_tool,
    ),
  )
  result_paths.push(
    run_tool(
      @command.make_run_request(
        "markitdown",
        request.tier,
        request.format_filter,
        request.limit,
        request.repeat_count,
        request.timeout_ms,
        request.markitdown_path,
        request.cli_output_mode,
        request.engine_output_mode,
        request.run_id,
        request.git_commit,
        request.runner,
      ),
      markitdown_tool,
    ),
  )
  let report_request = @result.make_report_request(
    result_paths,
    Some(selector_stats_path),
  )
  @result.generate_report_from_request(report_request)
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
  ensure_dir("bench/runner/results")
  ensure_dir("bench/runner/reports")
  ensure_dir(".tmp/markitdown-bench-output")
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
  let existing = @syncfs.read_file_to_string(path, encoding="utf8") catch {
    _ => ""
  }
  let out = Ref(existing)
  for row in rows {
    out.val += row.to_json().stringify() + "\n"
  }
  @syncfs.write_string_to_file(path, out.val, encoding="utf8") catch {
    err => abort("failed to append result rows: " + err.to_string())
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
