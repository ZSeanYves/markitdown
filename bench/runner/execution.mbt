///|
let bench_console_enabled : Ref[Bool] = Ref(true)

///|
fn bench_println(message : String) -> Unit {
  if bench_console_enabled.val {
    println(message)
  }
}

///|
#cfg(not(target="native"))
fn bench_write_stderr(message : String) -> Unit {
  bench_println(message)
}

///|
#cfg(target="native")
#borrow(payload)
extern "C" fn bench_write_stderr_ffi(payload : Bytes, payload_len : Int) = "markitdown_bench_write_stderr"

///|
#cfg(target="native")
extern "C" fn bench_stderr_isatty_ffi() -> Int = "markitdown_bench_stderr_isatty"

///|
#cfg(target="native")
fn bench_write_stderr(message : String) -> Unit {
  if !bench_console_enabled.val {
    return
  }
  let payload = @utf8.encode(message)
  if payload.length() == 0 {
    return
  }
  bench_write_stderr_ffi(payload, payload.length())
}

///|
fn bench_progress_enabled() -> Bool {
  if progress_disabled_by_env("NO_PROGRESS") || progress_disabled_by_env("CI") {
    return false
  }
  bench_stderr_isatty()
}

///|
#cfg(not(target="native"))
fn bench_stderr_isatty() -> Bool {
  false
}

///|
#cfg(target="native")
fn bench_stderr_isatty() -> Bool {
  bench_stderr_isatty_ffi() != 0
}

///|
fn progress_disabled_by_env(name : String) -> Bool {
  match @env.get_env_var(name) {
    Some(value) => {
      let lowered = value.trim().to_lower()
      lowered == "1" || lowered == "true" || lowered == "yes" || lowered == "on"
    }
    None => false
  }
}

///|
fn bench_progress_state(total : Int, mode : String) -> BenchProgressState {
  {
    enabled: mode == "json" || (mode == "auto" && bench_progress_enabled()),
    mode,
    total,
    completed: 0,
  }
}

///|
fn bench_progress_total(
  scenarios : Array[ScenarioSpec],
  opts : RunOptions,
) -> Int {
  let total = Ref(0)
  for scenario in scenarios {
    let rows = select_rows(scenario, opts)
    for _row in rows {
      for tool_name in scenario.tool_names {
        if tool_name == "moonbit-engine" {
          total.val = total.val + opts.repeat_count
        } else {
          total.val = total.val + opts.warmup_count + opts.repeat_count
        }
      }
    }
  }
  total.val
}

///|
fn bench_progress_label(
  scenario : ScenarioSpec,
  tool_name : String,
  row : @manifest.BenchRow,
  phase : String,
  index : Int,
  total : Int,
) -> String {
  let repeat_label = if total <= 1 {
    phase
  } else {
    phase + " " + (index + 1).to_string() + "/" + total.to_string()
  }
  scenario.scenario_id +
  " " +
  tool_name +
  " " +
  row.bench_id +
  " " +
  repeat_label
}

///|
fn bench_progress_render_line(
  completed : Int,
  total : Int,
  status : String,
  label : String,
) -> String {
  let trimmed = label.trim().to_owned()
  if trimmed == "" {
    "progress: " +
    completed.to_string() +
    "/" +
    total.to_string() +
    " " +
    status
  } else {
    "progress: " +
    completed.to_string() +
    "/" +
    total.to_string() +
    " " +
    status +
    " " +
    bench_progress_truncate(trimmed)
  }
}

///|
fn bench_progress_truncate(value : String, max? : Int = 88) -> String {
  if value.length() <= max {
    return value
  }
  if max <= 3 {
    return String::from_array(value.to_array()[:max])
  }
  String::from_array(value.to_array()[:max - 3]) + "..."
}

///|
fn bench_progress_update(
  state : BenchProgressState,
  status : String,
  label : String,
) -> Unit {
  if !state.enabled {
    return
  }
  if state.mode == "json" {
    bench_write_stderr(
      bench_progress_json(state.completed, state.total, status, label) + "\n",
    )
  } else {
    bench_write_stderr(
      "\r" +
      bench_progress_render_line(state.completed, state.total, status, label),
    )
  }
}

///|
fn bench_progress_json(
  completed : Int,
  total : Int,
  status : String,
  label : String,
) -> String {
  Json::object({
    "event": "bench_progress".to_json(),
    "completed": completed.to_json(),
    "total": total.to_json(),
    "status": status.to_json(),
    "label": label.to_json(),
  }).stringify()
}

///|
fn bench_progress_finish(
  state : BenchProgressState,
  status? : String = "done",
  label? : String = "",
) -> Unit {
  if !state.enabled {
    return
  }
  if state.mode == "json" {
    bench_write_stderr(
      bench_progress_json(state.completed, state.total, status, label) + "\n",
    )
  } else {
    bench_write_stderr(
      "\r" +
      bench_progress_render_line(state.completed, state.total, status, label) +
      "\n",
    )
  }
}

///|
fn bench_progress_advance(
  state : BenchProgressState,
  label : String,
  status? : String = "done",
) -> BenchProgressState {
  let next = { ..state, completed: state.completed + 1 }
  if next.enabled {
    if next.mode == "json" {
      bench_write_stderr(
        bench_progress_json(next.completed, next.total, status, label) + "\n",
      )
    } else {
      bench_write_stderr(
        "\r" +
        bench_progress_render_line(next.completed, next.total, status, label),
      )
    }
  }
  next
}

///|
fn release_binary_contract(
  runner : @command.RunnerContext,
) -> Result[BinaryContract, BenchError] {
  let runner_path = match runner.runner_path {
    Some(path) => path
    None => return Err(TrustFailure("runner path unavailable"))
  }
  let cli_path = "_build/native/release/build/cli/cli.exe"
  let runner_release_ok = runner.runner_mode == "release" &&
    runner_path.contains("_build/native/release/build/bench/runner/")
  let cli_release_ok = @fs.path_exists(cli_path)
  let used_moon_delegate = runner_path == "moon" ||
    runner_path.contains("/moon")
  if !runner_release_ok {
    return Err(
      TrustFailure("formal benchmark runner must be the release runner.exe"),
    )
  }
  if !cli_release_ok {
    return Err(
      TrustFailure(
        "formal moonbit-cli baseline requires _build/native/release/build/cli/cli.exe",
      ),
    )
  }
  if used_moon_delegate {
    return Err(
      TrustFailure("formal benchmark contract forbids moon delegation"),
    )
  }
  Ok({
    runner_path,
    cli_path,
    runner_release_ok,
    cli_release_ok,
    used_moon_delegate,
  })
}

///|
fn execute_run(
  run_id : String,
  scenarios : Array[ScenarioSpec],
  opts : RunOptions,
  contract : BinaryContract,
  policy : BenchPolicy,
) -> Result[Json, BenchError] {
  ensure_bench_dirs(run_id) catch {
    err =>
      return Err(RuntimeFailure("init run dirs failed: " + err.to_string()))
  }
  if scenarios.length() == 1 && scenarios[0].scenario_kind == "doctor" {
    let summary = summarize_doctor_run(run_id, scenarios[0], opts, contract)
    write_summary_and_report(run_id, summary) catch {
      err =>
        return Err(
          RuntimeFailure("write doctor summary failed: " + err.to_string()),
        )
    }
    return Ok(
      Json::object({
        "run_id": run_id.to_json(),
        "summary_json": summary_json_path(run_id).to_json(),
        "report_md": report_markdown_path(run_id).to_json(),
        "trust_status": summary.trust_status.to_json(),
      }),
    )
  }
  let samples = match opts.resume_run_id {
    Some(_) =>
      match load_sample_rows(samples_jsonl_path(run_id), "sample") {
        Ok(value) => value
        Err(_) => []
      }
    None => []
  }
  let resumed_sample_count = samples.length()
  let progress_total = bench_progress_total(scenarios, opts)
  let initial_progress = bench_progress_state(
    progress_total,
    opts.progress_mode,
  )
  let progress = Ref({
    ..initial_progress,
    completed: if samples.length() < progress_total {
      samples.length()
    } else {
      progress_total
    },
  })
  for scenario in scenarios {
    let rows = select_rows(scenario, opts)
    let scenario_samples = match
      run_samples(run_id, scenario, rows, opts, contract, progress, samples) {
      Ok(value) => value
      Err(err) => {
        bench_progress_finish(progress.val, status="failed")
        return Err(err)
      }
    }
    ignore(scenario_samples)
  }
  bench_progress_finish(progress.val)
  write_jsonl(samples_jsonl_path(run_id), samples.map(item => item.to_json())) catch {
    err =>
      return Err(RuntimeFailure("write samples failed: " + err.to_string()))
  }
  let cases = aggregate_cases(run_id, samples, scenarios, policy)
  write_jsonl(cases_jsonl_path(run_id), cases.map(item => item.to_json())) catch {
    err => return Err(RuntimeFailure("write cases failed: " + err.to_string()))
  }
  let summary = summarize_run(
    run_id,
    scenarios,
    samples,
    cases,
    contract,
    opts.preset,
    opts.baseline_run_id,
    policy,
    resource_summary=Some(benchmark_resource_summary(run_id, samples, opts)),
    resume_summary=Some(
      Json::object({
        "requested": (opts.resume_run_id is Some(_)).to_json(),
        "reused_samples": resumed_sample_count.to_json(),
        "completed_samples": samples.length().to_json(),
      }),
    ),
  )
  write_summary_and_report(run_id, summary) catch {
    err =>
      return Err(RuntimeFailure("write summary failed: " + err.to_string()))
  }
  Ok(
    Json::object({
      "run_id": run_id.to_json(),
      "samples_jsonl": samples_jsonl_path(run_id).to_json(),
      "cases_jsonl": cases_jsonl_path(run_id).to_json(),
      "summary_json": summary_json_path(run_id).to_json(),
      "report_md": report_markdown_path(run_id).to_json(),
      "trust_status": summary.trust_status.to_json(),
    }),
  )
}

///|
fn benchmark_resource_summary(
  run_id : String,
  samples : Array[SampleRow],
  opts : RunOptions,
) -> Json {
  let mut peak_rss_kb = 0L
  let mut timed_out_samples = 0
  for sample in samples {
    match sample.peak_rss_kb {
      Some(value) if value > peak_rss_kb => peak_rss_kb = value
      _ => ()
    }
    if sample.timed_out {
      timed_out_samples += 1
    }
  }
  let retained_disk_bytes = directory_size_bytes(run_root(run_id)) catch {
    _ => 0L
  }
  Json::object({
    "peak_rss_kb": peak_rss_kb.to_json(),
    "timed_out_samples": timed_out_samples.to_json(),
    "retained_disk_bytes": retained_disk_bytes.to_json(),
    "max_disk_mb": opts.max_disk_mb.to_json(),
    "keep_outputs": opts.keep_outputs.to_json(),
  })
}

///|
fn select_rows(
  scenario : ScenarioSpec,
  opts : RunOptions,
) -> Array[@manifest.BenchRow] {
  let exact_tiers = if opts.exact_tiers.length() > 0 {
    opts.exact_tiers
  } else {
    scenario.exact_tiers
  }
  let format_filters = if opts.format_filters.length() > 0 {
    opts.format_filters
  } else {
    scenario.format_filters
  }
  let request = @manifest.make_select_request(
    "smoke",
    exact_tiers,
    opts.bench_ids,
    format_filters,
    opts.limit,
    Jsonl,
    false,
    comparison_classes=scenario.comparison_classes,
  )
  @manifest.select_rows(request)
}

///|
fn run_samples(
  run_id : String,
  scenario : ScenarioSpec,
  rows : Array[@manifest.BenchRow],
  opts : RunOptions,
  contract : BinaryContract,
  progress : Ref[BenchProgressState],
  all_samples : Array[SampleRow],
) -> Result[Array[SampleRow], BenchError] {
  let config = @tools.make_tool_registry_config(opts.markitdown_path)
  let out : Array[SampleRow] = []
  for row in rows {
    for tool_name in scenario.tool_names {
      let tool = @tools.find_tool(tool_name, config~).unwrap_or_else(fn() {
        abort("missing tool registration: " + tool_name)
      })
      if scenario.official_membership == "official-external-compare" &&
        tool_name == "markitdown" &&
        !tool.is_available() {
        return Err(
          TrustFailure(
            "official-external-compare requires markitdown baseline availability",
          ),
        )
      }
      if tool_name == "moonbit-engine" {
        out.append(
          run_engine_samples(
            run_id, scenario, row, opts, contract, progress, all_samples,
          ),
        )
      } else {
        out.append(
          run_process_samples(
            run_id, scenario, row, tool, opts, contract, progress, all_samples,
          ),
        )
      }
      all_samples.append(out[:])
      out.clear()
      write_jsonl(
        samples_jsonl_path(run_id),
        all_samples.map(item => item.to_json()),
      ) catch {
        err =>
          return Err(
            RuntimeFailure("checkpoint samples failed: " + err.to_string()),
          )
      }
      let disk_bytes = directory_size_bytes(run_root(run_id)) catch {
        err =>
          return Err(
            RuntimeFailure(
              "measure benchmark disk usage failed: " + err.to_string(),
            ),
          )
      }
      let disk_limit = opts.max_disk_mb.to_int64() * 1024L * 1024L
      if disk_bytes > disk_limit {
        return Err(
          RuntimeFailure(
            "benchmark disk budget exceeded: " +
            disk_bytes.to_string() +
            " > " +
            disk_limit.to_string() +
            " bytes",
          ),
        )
      }
    }
  }
  Ok(out)
}

///|
fn sample_completed(
  samples : Array[SampleRow],
  scenario_id : String,
  tool : String,
  bench_id : String,
  repeat_index : Int,
  input_sha256 : String,
  expected_measurement_policy : String,
  runner_artifact_identity : String,
) -> Bool {
  samples.any(fn(sample) {
    sample.scenario_id == scenario_id &&
    sample.tool == tool &&
    sample.bench_id == bench_id &&
    sample.repeat_index == repeat_index &&
    sample.input_sha256 == input_sha256 &&
    sample.measurement_policy == expected_measurement_policy &&
    sample.runner_artifact_identity == runner_artifact_identity
  })
}

///|
fn cleanup_bench_output(
  path : String,
  status : String,
  policy : String,
) -> Unit {
  let keep = policy == "all" || (policy == "failures" && status != "ok")
  if !keep {
    if @fs.path_exists(path) {
      @fs.remove_file(path) catch {
        _ => ()
      }
    }
    let assets_path = dirname(path) + "/assets"
    remove_bench_output_tree(assets_path) catch {
      _ => ()
    }
  }
}

///|
fn remove_bench_output_tree(path : String) -> Unit raise @fs.IOError {
  if !@fs.path_exists(path) {
    return
  }
  if @fs.is_dir(path) {
    for name in @fs.read_dir(path) {
      remove_bench_output_tree(path + "/" + name)
    }
    @fs.remove_dir(path)
  } else {
    @fs.remove_file(path)
  }
}

///|
fn run_process_samples(
  run_id : String,
  scenario : ScenarioSpec,
  row : @manifest.BenchRow,
  tool : @tools.BenchTool,
  opts : RunOptions,
  contract : BinaryContract,
  progress : Ref[BenchProgressState],
  completed_samples : Array[SampleRow],
) -> Array[SampleRow] {
  let out : Array[SampleRow] = []
  let provenance_path = provenance_output_path(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  let stdout_path = stdout_output_path(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  let stderr_path = stderr_output_path(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  ensure_parent_dir(provenance_path) catch {
    _ => ()
  }
  ensure_parent_dir(stdout_path) catch {
    _ => ()
  }
  ensure_parent_dir(stderr_path) catch {
    _ => ()
  }
  for warmup_index in 0..<opts.warmup_count {
    if tool.is_available() {
      let label = bench_progress_label(
        scenario,
        tool.name,
        row,
        "warmup",
        warmup_index,
        opts.warmup_count,
      )
      bench_progress_update(progress.val, "running", label)
      let warmup_path = output_path(
        run_id,
        scenario.scenario_id,
        tool.name,
        row.bench_id,
        0,
        1,
      )
      ensure_parent_dir(warmup_path) catch {
        _ => ()
      }
      let warmup = tool.build_command(row, warmup_path, opts.timeout_ms)
      let command = cli_command_with_provenance(
        warmup,
        tool.name,
        provenance_path,
      )
      ignore(native_measure_command(command, stdout_path, stderr_path))
      cleanup_bench_output(warmup_path, "ok", "none")
      progress.val = bench_progress_advance(progress.val, label)
    }
  }
  for repeat_index in 0..<opts.repeat_count {
    if sample_completed(
        completed_samples,
        scenario.scenario_id,
        tool.name,
        row.bench_id,
        repeat_index,
        row.sha256,
        measurement_policy(opts),
        contract.runner_path,
      ) {
      continue
    }
    let label = bench_progress_label(
      scenario,
      tool.name,
      row,
      "sample",
      repeat_index,
      opts.repeat_count,
    )
    bench_progress_update(progress.val, "running", label)
    let output_path = output_path(
      run_id,
      scenario.scenario_id,
      tool.name,
      row.bench_id,
      repeat_index,
      opts.repeat_count,
    )
    ensure_parent_dir(output_path) catch {
      _ => ()
    }
    let base = tool.build_command(row, output_path, opts.timeout_ms)
    let command = cli_command_with_provenance(base, tool.name, provenance_path)
    let measured = if tool.is_available() {
      Some(native_measure_command(command, stdout_path, stderr_path))
    } else {
      None
    }
    let status = if !tool.is_available() {
      "unavailable"
    } else if measured is Some(result) && result.data.timed_out {
      "timeout"
    } else if measured is Some(result) && result.data.exit_code == 0 {
      "ok"
    } else {
      "failed"
    }
    progress.val = bench_progress_advance(progress.val, label, status~)
    let sample = {
      schema_version: 2,
      run_id,
      scenario_id: scenario.scenario_id,
      scenario_kind: scenario.scenario_kind,
      official_membership: scenario.official_membership,
      tool: tool.name,
      measurement_mode: "process-cli",
      measurement_policy: measurement_policy(opts),
      repeat_index,
      repeat_count: opts.repeat_count,
      warmup_count: opts.warmup_count,
      bench_id: row.bench_id,
      format: row.format,
      size_class: row.size_class,
      enabled_tier: row.enabled_tier,
      rel_path: row.rel_path,
      input_bytes: row.input_bytes,
      input_sha256: row.sha256,
      status,
      exit_code: measured.map(fn(m) { m.data.exit_code }).unwrap_or(0),
      timed_out: measured.map(fn(m) { m.data.timed_out }).unwrap_or(false),
      wall_us: measured.map(fn(m) { m.data.wall_us }),
      peak_rss_kb: measured.map(fn(m) { m.data.peak_rss_kb }),
      output_bytes: file_size_or_zero(output_path),
      output_sha256: if status == "ok" {
        file_sha256_or_none(output_path)
      } else {
        None
      },
      error: tool.availability_note,
      route_provenance: if tool.name == "moonbit-cli" {
        read_json_or_default(
          provenance_path,
          Json::object({ "missing": true.to_json() }),
        )
      } else {
        Json::object({ "status": "not_applicable".to_json() })
      },
      runner_artifact_identity: contract.runner_path,
      cli_artifact_path: if tool.name == "moonbit-cli" {
        Some(contract.cli_path)
      } else {
        None
      },
    }
    out.push(sample)
    cleanup_bench_output(output_path, sample.status, opts.keep_outputs)
    cleanup_bench_output(stdout_path, sample.status, opts.keep_outputs)
    cleanup_bench_output(stderr_path, sample.status, opts.keep_outputs)
  }
  out
}

///|
fn run_engine_samples(
  run_id : String,
  scenario : ScenarioSpec,
  row : @manifest.BenchRow,
  opts : RunOptions,
  contract : BinaryContract,
  progress : Ref[BenchProgressState],
  completed_samples : Array[SampleRow],
) -> Array[SampleRow] {
  let out : Array[SampleRow] = []
  let source = @input.input_from_path(row.input_path)
  let options = bench_convert_options_for_row(row)
  let stdout_path = stdout_output_path(
    run_id,
    scenario.scenario_id,
    "moonbit-engine-rss",
    row.bench_id,
  )
  let stderr_path = stderr_output_path(
    run_id,
    scenario.scenario_id,
    "moonbit-engine-rss",
    row.bench_id,
  )
  for _ in 0..<opts.warmup_count {
    ignore(@convert.convert_input_with_provenance(source, options))
  }
  for repeat_index in 0..<opts.repeat_count {
    if sample_completed(
        completed_samples,
        scenario.scenario_id,
        "moonbit-engine",
        row.bench_id,
        repeat_index,
        row.sha256,
        measurement_policy(opts),
        contract.runner_path,
      ) {
      continue
    }
    let label = bench_progress_label(
      scenario,
      "moonbit-engine",
      row,
      "sample",
      repeat_index,
      opts.repeat_count,
    )
    bench_progress_update(progress.val, "running", label)
    let started = @measure.monotonic_start()
    let execution = @convert.convert_input_with_provenance(source, options)
    let wall_us = @measure.monotonic_elapsed_us(started).to_int64()
    let worker_output = output_path(
      run_id,
      scenario.scenario_id,
      "moonbit-engine-rss",
      row.bench_id,
      repeat_index,
      opts.repeat_count,
    )
    let worker_measurement = measure_engine_worker_rss(
      contract,
      row,
      worker_output,
      stdout_path,
      stderr_path,
      opts.timeout_ms,
    )
    let worker_peak_rss = match worker_measurement {
      Some(measured) if !measured.data.timed_out && measured.data.exit_code == 0 =>
        Some(measured.data.peak_rss_kb)
      _ => None
    }
    cleanup_bench_output(worker_output, "ok", "none")
    cleanup_bench_output(stdout_path, "ok", "none")
    cleanup_bench_output(stderr_path, "ok", "none")
    match execution {
      Ok(value) => {
        progress.val = bench_progress_advance(progress.val, label, status="ok")
        out.push({
          schema_version: 2,
          run_id,
          scenario_id: scenario.scenario_id,
          scenario_kind: scenario.scenario_kind,
          official_membership: scenario.official_membership,
          tool: "moonbit-engine",
          measurement_mode: "inprocess-engine+process-rss",
          measurement_policy: measurement_policy(opts),
          repeat_index,
          repeat_count: opts.repeat_count,
          warmup_count: opts.warmup_count,
          bench_id: row.bench_id,
          format: row.format,
          size_class: row.size_class,
          enabled_tier: row.enabled_tier,
          rel_path: row.rel_path,
          input_bytes: row.input_bytes,
          input_sha256: row.sha256,
          status: "ok",
          exit_code: 0,
          timed_out: false,
          wall_us: Some(wall_us),
          peak_rss_kb: worker_peak_rss,
          output_bytes: @utf8.encode(value.result.content).length().to_int64(),
          output_sha256: Some(
            @crypto.bytes_to_hex_string(
              @crypto.sha256(@utf8.encode(value.result.content)),
            ),
          ),
          error: None,
          route_provenance: bench_provenance_with_stage_timings(value),
          runner_artifact_identity: contract.runner_path,
          cli_artifact_path: None,
        })
      }
      Err(err) => {
        progress.val = bench_progress_advance(
          progress.val,
          label,
          status="failed",
        )
        out.push({
          schema_version: 2,
          run_id,
          scenario_id: scenario.scenario_id,
          scenario_kind: scenario.scenario_kind,
          official_membership: scenario.official_membership,
          tool: "moonbit-engine",
          measurement_mode: "inprocess-engine+process-rss",
          measurement_policy: measurement_policy(opts),
          repeat_index,
          repeat_count: opts.repeat_count,
          warmup_count: opts.warmup_count,
          bench_id: row.bench_id,
          format: row.format,
          size_class: row.size_class,
          enabled_tier: row.enabled_tier,
          rel_path: row.rel_path,
          input_bytes: row.input_bytes,
          input_sha256: row.sha256,
          status: "failed",
          exit_code: 1,
          timed_out: false,
          wall_us: Some(wall_us),
          peak_rss_kb: worker_peak_rss,
          output_bytes: 0L,
          output_sha256: None,
          error: Some(err.to_string()),
          route_provenance: Json::object({ "missing": true.to_json() }),
          runner_artifact_identity: contract.runner_path,
          cli_artifact_path: None,
        })
      }
    }
  }
  out
}

///|
fn measure_engine_worker_rss(
  contract : BinaryContract,
  row : @manifest.BenchRow,
  output_path : String,
  stdout_path : String,
  stderr_path : String,
  timeout_ms : Int,
) -> @measure.NativeMeasureResult? {
  if !contract.runner_release_ok || !@fs.path_exists(contract.runner_path) {
    return None
  }
  ensure_parent_dir(output_path) catch {
    _ => return None
  }
  ensure_parent_dir(stdout_path) catch {
    _ => return None
  }
  ensure_parent_dir(stderr_path) catch {
    _ => return None
  }
  let command = @tools.make_tool_command(
    contract.runner_path,
    ["engine-worker", row.format, row.input_path, output_path],
    None,
    [],
    timeout_ms,
    "engine-rss-worker",
    contract.runner_path + " engine-worker <format> <input> <output>",
  )
  Some(native_measure_command(command, stdout_path, stderr_path))
}

///|
fn file_sha256_or_none(path : String) -> String? {
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return None }
  Some(@crypto.bytes_to_hex_string(@crypto.sha256(bytes)))
}

///|
fn bench_provenance_with_stage_timings(
  execution : @convert.ConvertExecution,
) -> Json {
  let provenance = @convert.convert_provenance_to_json(execution.provenance)
  match provenance {
    Object(fields) => {
      let timings : Map[String, Json] = Map([])
      for
        entry in [
          ("detect_probe", "timing_detect_probe_ms"),
          ("parse_lower", "timing_parse_lower_ms"),
          ("pipeline", "timing_pipeline_ms"),
          ("render", "timing_render_ms"),
          ("total", "timing_total_ms"),
        ] {
        match execution.result.diagnostics.metrics.get(entry.1) {
          Some(value) => timings.set(entry.0, value.to_json())
          None => ()
        }
      }
      fields.set("stage_timings_ms", Json::object(timings))
      provenance
    }
    _ => provenance
  }
}

///|
fn bench_convert_options_for_row(
  row : @manifest.BenchRow,
) -> @convert.ConvertOptions {
  let source = @input.input_from_path(row.input_path)
  let declared_format = @input.parse_detected_format(row.format)
  let detected_format = if declared_format != Unknown {
    declared_format
  } else {
    (@input.default_format_detector().detect)(source).format
  }
  bench_convert_options(detected_format)
}

///|
fn bench_convert_options(
  detected_format : @input.DetectedFormat,
) -> @convert.ConvertOptions {
  let ocr_options = if @input.detected_format_is_image_candidate(
      detected_format,
    ) {
    @parser.explicit_ocr_options()
  } else {
    @parser.default_ocr_options()
  }
  @convert.make_convert_options(
    Balanced,
    Markdown,
    Some(detected_format),
    ocr_options,
    @convert.default_resource_limits(),
  )
}

///|
fn cli_command_with_provenance(
  command : @tools.ToolCommand,
  tool_name : String,
  provenance_path : String,
) -> @tools.ToolCommand {
  if tool_name != "moonbit-cli" {
    return command
  }
  let args : Array[String] = []
  if command.args.length() >= 1 {
    args.push(command.args[0])
    args.push("--provenance-out")
    args.push(provenance_path)
    for i in 1..<command.args.length() {
      args.push(command.args[i])
    }
  } else {
    args.append(command.args)
  }
  @tools.make_tool_command(
    command.program,
    args,
    command.cwd,
    command.env,
    command.timeout_ms,
    command.command_kind,
    command.command_display,
  )
}

///|
fn native_measure_command(
  command : @tools.ToolCommand,
  stdout_path : String,
  stderr_path : String,
) -> @measure.NativeMeasureResult {
  let argv : Array[String] = [command.program]
  argv.append(command.args)
  let argv_blob = @measure.encode_c_string_blob(argv)
  let env_blob = @measure.encode_c_string_blob([])
  let spec = @measure.make_native_measure_spec(
    argv_blob,
    argv_blob.length(),
    argv.length(),
    env_blob,
    env_blob.length(),
    0,
    stdout_path,
    stderr_path,
    command.cwd,
    command.timeout_ms.to_int64(),
  )
  @measure.native_measure_command(spec)
}
