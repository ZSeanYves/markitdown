///|
pub(all) suberror BenchV2Error {
  InvalidArgument(String)
  TrustFailure(String)
  RuntimeFailure(String)
}

///|
pub impl Show for BenchV2Error with fn to_string(self : BenchV2Error) -> String {
  match self {
    InvalidArgument(msg) => msg
    TrustFailure(msg) => msg
    RuntimeFailure(msg) => msg
  }
}

///|
pub struct BinaryContract {
  runner_path : String
  cli_path : String
  runner_release_ok : Bool
  cli_release_ok : Bool
  used_moon_delegate : Bool
} derive(Eq)

///|
pub struct ScenarioSpecV2 {
  scenario_id : String
  scenario_kind : String
  tool_names : Array[String]
  exact_tiers : Array[String]
  format_filters : Array[String]
  official_membership : String
  route_expectation : String
} derive(Eq)

///|
pub struct ScenarioSummaryV2 {
  scenario_id : String
  scenario_kind : String
  official_membership : String
  selected_rows : Int
  comparable_rows : Int
  trust_status : String
  gate_status : String
} derive(ToJson, FromJson, Eq)

///|
pub struct RunOptionsV2 {
  preset : String?
  scenario_id : String?
  exact_tiers : Array[String]
  bench_ids : Array[String]
  format_filters : Array[String]
  limit : Int?
  repeat_count : Int
  warmup_count : Int
  timeout_ms : Int
  markitdown_path : String?
  baseline_run_id : String?
} derive(Eq)

///|
pub struct SampleRowV2 {
  schema_version : Int
  run_id : String
  scenario_id : String
  scenario_kind : String
  official_membership : String
  tool : String
  measurement_mode : String
  measurement_policy : String
  repeat_index : Int
  repeat_count : Int
  warmup_count : Int
  bench_id : String
  format : String
  size_class : String
  enabled_tier : String
  rel_path : String
  input_bytes : Int
  input_sha256 : String
  status : String
  exit_code : Int
  timed_out : Bool
  wall_us : Int64?
  peak_rss_kb : Int64?
  output_bytes : Int64
  error : String?
  route_provenance : Json
  runner_artifact_identity : String
  cli_artifact_path : String?
} derive(ToJson, FromJson, Eq)

///|
pub struct CaseAggregateV2 {
  schema_version : Int
  run_id : String
  scenario_id : String
  tool : String
  bench_id : String
  format : String
  size_class : String
  input_bytes : Int
  sample_count : Int
  success_count : Int
  median_wall_us : Int64?
  min_wall_us : Int64?
  max_wall_us : Int64?
  median_output_bytes : Int64?
  output_density : Double?
  comparable_status : String
  route_coverage_status : String
  semantic_coverage : String
  render_path : String
  trust_status : String
  trust_failure_reason : String
  expected_route : String?
  actual_route : String?
  route_fidelity_status : String?
  provenance_complete : Bool
  route_provenance : Json
} derive(ToJson, FromJson, Eq)

///|
pub struct ToolSummaryV2 {
  tool : String
  rows : Int
  success_rows : Int
  median_wall_us : Int64?
} derive(ToJson, FromJson, Eq)

///|
pub struct FormatSummaryV2 {
  format : String
  rows : Int
  comparable_rows : Int
  cli_geomean_speedup : Double?
  engine_geomean_speedup : Double?
  status : String
} derive(ToJson, FromJson, Eq)

///|
pub struct RunSummaryV2 {
  schema_version : Int
  run_id : String
  preset : String?
  scenario_ids : Array[String]
  binary_only_contract : Json
  trust_status : String
  gate_summary : Json
  route_coverage_summary : Json
  truth_summary : Json
  diff_summary : Json?
  scenarios : Array[ScenarioSummaryV2]
  tools : Array[ToolSummaryV2]
  by_format : Array[FormatSummaryV2]
} derive(ToJson, FromJson, Eq)

///|
priv struct PolicyDefaultsV2 {
  repeat_count : Int
  warmup_count : Int
  timeout_ms : Int
  tiers : Array[String]
}

///|
priv struct ScenarioPolicyV2 {
  scenario_id : String
  scenario_kind : String
  tool_set : String
  exact_tiers : Array[String]
  format_filters : Array[String]
  official_membership : String
  route_expectation : String
}

///|
priv struct PresetPolicyV2 {
  scenario_ids : Array[String]
  tiers : Array[String]
  repeat_count : Int
  warmup_count : Int
  timeout_ms : Int
}

///|
priv struct BenchPolicyV2 {
  defaults : PolicyDefaultsV2
  tool_matrix : Map[String, Array[String]]
  presets : Map[String, PresetPolicyV2]
  scenarios : Array[ScenarioPolicyV2]
  row_expected_routes : Map[String, String]
}

///|
pub fn run_bench_v2_cli(
  raw_args : Array[String],
  runner : @command.RunnerContext,
) -> Int {
  let args = normalize_v2_args(raw_args)
  if args.length() == 0 ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    print_help_v2()
    return 0
  }
  match args[0] {
    "catalog" => run_catalog_v2(args[1:].to_owned())
    "run" => run_command_v2(args[1:].to_owned(), runner)
    "report" => report_command_v2(args[1:].to_owned())
    "doctor" => doctor_command_v2(runner)
    _ => {
      println("unknown bench v2 command: " + args[0])
      print_help_v2()
      2
    }
  }
}

///|
fn normalize_v2_args(raw_args : Array[String]) -> Array[String] {
  let args = if raw_args.length() > 0 &&
    (
      raw_args[0].contains("/") ||
      raw_args[0] == "runner" ||
      raw_args[0] == "runner.exe"
    ) {
    raw_args[1:].to_owned()
  } else {
    raw_args.copy()
  }
  if args.length() >= 1 &&
    (args[0] == "tools/bench" || args[0] == "bench/runner") {
    return args[1:].to_owned()
  }
  args
}

///|
fn print_help_v2() -> Unit {
  println("Bench v2 binary-only runner for mb-markitdown.")
  println("Usage:")
  println(
    "  _build/native/release/build/bench/runner/runner.exe catalog rows [--tiers regular,release,stress] [--bench-id <id[,more]>] [--format <fmt[,more]>] [--limit N]",
  )
  println(
    "  _build/native/release/build/bench/runner/runner.exe catalog scenarios",
  )
  println(
    "  _build/native/release/build/bench/runner/runner.exe run --preset official-internal [--limit N]",
  )
  println(
    "  _build/native/release/build/bench/runner/runner.exe run --preset official-compare [--limit N] [--markitdown-path <path>]",
  )
  println(
    "  _build/native/release/build/bench/runner/runner.exe run --scenario <scenario_id> [--bench-id <id>] [--limit N]",
  )
  println(
    "  _build/native/release/build/bench/runner/runner.exe report --run <run_id> [--baseline <run_id>]",
  )
  println("  _build/native/release/build/bench/runner/runner.exe doctor")
}

///|
fn run_catalog_v2(args : Array[String]) -> Int {
  let policy = unwrap_or_report(
    load_policy_v2(),
    "catalog failed to load policy",
  )
  if policy is None {
    return 1
  }
  if args.length() == 0 {
    println("catalog requires rows|scenarios")
    return 2
  }
  match args[0] {
    "rows" => {
      let opts = parse_run_options_v2(args[1:].to_owned()) catch {
        err => {
          println("catalog rows argument error: " + err.to_string())
          return 2
        }
      }
      let request = @manifest.make_select_request(
        "smoke",
        opts.exact_tiers,
        opts.bench_ids,
        opts.format_filters,
        opts.limit,
        @manifest.SelectOutput::Jsonl,
        false,
      )
      for row in @manifest.select_rows(request) {
        println(row.to_json().stringify())
      }
      0
    }
    "scenarios" => {
      for scenario in policy_scenarios_v2(policy.unwrap()) {
        println(
          Json::object({
            "scenario_id": scenario.scenario_id.to_json(),
            "scenario_kind": scenario.scenario_kind.to_json(),
            "tool_names": scenario.tool_names.to_json(),
            "official_membership": scenario.official_membership.to_json(),
            "route_expectation": scenario.route_expectation.to_json(),
          }).stringify(),
        )
      }
      0
    }
    _ => {
      println("unsupported catalog target: " + args[0])
      2
    }
  }
}

///|
fn run_command_v2(args : Array[String], runner : @command.RunnerContext) -> Int {
  let opts = parse_run_options_v2(args) catch {
    err => {
      println("run argument error: " + err.to_string())
      return 2
    }
  }
  let policy = unwrap_or_report(load_policy_v2(), "load bench policy failed")
  if policy is None {
    return 1
  }
  let contract = unwrap_or_report(
    release_binary_contract(runner),
    "binary-only contract failed",
  )
  if contract is None {
    return 1
  }
  let effective_opts = apply_policy_defaults_v2(opts, policy.unwrap())
  let scenarios = resolve_scenarios_v2(effective_opts, policy.unwrap())
  let run_id = make_run_id_v2(args)
  let payload = unwrap_or_report(
    execute_run_v2(
      run_id,
      scenarios,
      effective_opts,
      contract.unwrap(),
      policy.unwrap(),
    ),
    "run failed",
  )
  if payload is None {
    return 1
  }
  println(payload.unwrap().stringify())
  0
}

///|
fn report_command_v2(args : Array[String]) -> Int {
  let run_id = parse_report_run_id_v2(args) catch {
    err => {
      println("report argument error: " + err.to_string())
      return 2
    }
  }
  let baseline = parse_report_baseline_v2(args)
  let summary = unwrap_or_report(
    regenerate_report_v2(run_id, baseline),
    "report failed",
  )
  if summary is None {
    return 1
  }
  println(summary.unwrap().to_json().stringify())
  0
}

///|
fn doctor_command_v2(runner : @command.RunnerContext) -> Int {
  let contract = unwrap_or_report(
    release_binary_contract(runner),
    "doctor failed",
  )
  if contract is None {
    return 1
  }
  let value = contract.unwrap()
  println(
    Json::object({
      "runner_path": value.runner_path.to_json(),
      "cli_path": value.cli_path.to_json(),
      "runner_release_ok": value.runner_release_ok.to_json(),
      "cli_release_ok": value.cli_release_ok.to_json(),
      "used_moon_delegate": value.used_moon_delegate.to_json(),
    }).stringify(),
  )
  0
}

///|
fn[T] unwrap_or_report(result : Result[T, BenchV2Error], label : String) -> T? {
  match result {
    Ok(value) => Some(value)
    Err(err) => {
      println(label + ": " + err.to_string())
      None
    }
  }
}

///|
fn parse_run_options_v2(args : Array[String]) -> RunOptionsV2 raise {
  let preset : Ref[String?] = Ref(None)
  let scenario_id : Ref[String?] = Ref(None)
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let formats : Ref[Array[String]] = Ref([])
  let limit : Ref[Int?] = Ref(None)
  let repeat_count = Ref(3)
  let warmup_count = Ref(1)
  let timeout_ms = Ref(60000)
  let markitdown_path : Ref[String?] = Ref(None)
  let baseline_run_id : Ref[String?] = Ref(None)
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--preset" => {
        ensure_next_arg_v2(args, i.val, "--preset")
        preset.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--scenario" => {
        ensure_next_arg_v2(args, i.val, "--scenario")
        scenario_id.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--tiers" => {
        ensure_next_arg_v2(args, i.val, "--tiers")
        exact_tiers.val = @manifest.parse_tier_list(args[i.val + 1], "--tiers")
        i.val += 2
      }
      "--bench-id" => {
        ensure_next_arg_v2(args, i.val, "--bench-id")
        bench_ids.val = parse_csv_v2(args[i.val + 1], "--bench-id")
        i.val += 2
      }
      "--format" => {
        ensure_next_arg_v2(args, i.val, "--format")
        formats.val = parse_csv_v2(args[i.val + 1], "--format")
        i.val += 2
      }
      "--limit" => {
        ensure_next_arg_v2(args, i.val, "--limit")
        limit.val = Some(parse_non_negative_int_v2(args[i.val + 1], "--limit"))
        i.val += 2
      }
      "--repeat" => {
        ensure_next_arg_v2(args, i.val, "--repeat")
        repeat_count.val = parse_non_negative_int_v2(
          args[i.val + 1],
          "--repeat",
        )
        i.val += 2
      }
      "--warmup" => {
        ensure_next_arg_v2(args, i.val, "--warmup")
        warmup_count.val = parse_non_negative_int_v2(
          args[i.val + 1],
          "--warmup",
        )
        i.val += 2
      }
      "--timeout-ms" => {
        ensure_next_arg_v2(args, i.val, "--timeout-ms")
        timeout_ms.val = parse_non_negative_int_v2(
          args[i.val + 1],
          "--timeout-ms",
        )
        i.val += 2
      }
      "--markitdown-path" => {
        ensure_next_arg_v2(args, i.val, "--markitdown-path")
        markitdown_path.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--baseline" => {
        ensure_next_arg_v2(args, i.val, "--baseline")
        baseline_run_id.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      _ => raise InvalidArgument("unsupported argument: " + arg)
    }
  }
  {
    preset: preset.val,
    scenario_id: scenario_id.val,
    exact_tiers: exact_tiers.val,
    bench_ids: bench_ids.val,
    format_filters: formats.val,
    limit: limit.val,
    repeat_count: repeat_count.val,
    warmup_count: warmup_count.val,
    timeout_ms: timeout_ms.val,
    markitdown_path: markitdown_path.val,
    baseline_run_id: baseline_run_id.val,
  }
}

///|
fn ensure_next_arg_v2(
  args : Array[String],
  index : Int,
  flag : String,
) -> Unit raise {
  if index + 1 >= args.length() {
    raise InvalidArgument("missing value for " + flag)
  }
}

///|
fn parse_csv_v2(text : String, flag : String) -> Array[String] raise {
  let items = text
    .split(",")
    .to_array()
    .map(item => item.trim().to_owned())
    .filter(item => item != "")
  if items.length() == 0 {
    raise InvalidArgument("empty value is not allowed for " + flag)
  }
  items
}

///|
fn parse_non_negative_int_v2(text : String, flag : String) -> Int raise {
  let value = @string.parse_int(text.trim()) catch {
    _ => raise InvalidArgument("invalid integer for " + flag + ": " + text)
  }
  if value < 0 {
    raise InvalidArgument("negative integer is not allowed for " + flag)
  }
  value
}

///|
fn resolve_scenarios_v2(
  opts : RunOptionsV2,
  policy : BenchPolicyV2,
) -> Array[ScenarioSpecV2] {
  let scenarios = policy_scenarios_v2(policy)
  match opts.scenario_id {
    Some(wanted) => [find_scenario_or_abort(scenarios, wanted)]
    None =>
      match opts.preset {
        Some(name) => resolve_preset_scenarios_v2(name, scenarios, policy)
        None => abort("run requires --preset or --scenario")
      }
  }
}

///|
fn find_scenario_or_abort(
  scenarios : Array[ScenarioSpecV2],
  wanted : String,
) -> ScenarioSpecV2 {
  for scenario in scenarios {
    if scenario.scenario_id == wanted {
      return scenario
    }
  }
  abort("unknown scenario: " + wanted)
}

///|
fn resolve_preset_scenarios_v2(
  preset_name : String,
  scenarios : Array[ScenarioSpecV2],
  policy : BenchPolicyV2,
) -> Array[ScenarioSpecV2] {
  match policy.presets.get(preset_name) {
    Some(preset) => {
      if preset.scenario_ids.length() == 0 {
        abort("preset has no scenario_ids: " + preset_name)
      }
      let out : Array[ScenarioSpecV2] = []
      for scenario_id in preset.scenario_ids {
        out.push(find_scenario_or_abort(scenarios, scenario_id))
      }
      out
    }
    None => abort("unknown preset: " + preset_name)
  }
}

///|
fn release_binary_contract(
  runner : @command.RunnerContext,
) -> Result[BinaryContract, BenchV2Error] {
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
fn execute_run_v2(
  run_id : String,
  scenarios : Array[ScenarioSpecV2],
  opts : RunOptionsV2,
  contract : BinaryContract,
  policy : BenchPolicyV2,
) -> Result[Json, BenchV2Error] {
  ensure_v2_dirs(run_id) catch {
    err =>
      return Err(RuntimeFailure("init run dirs failed: " + err.to_string()))
  }
  if scenarios.length() == 1 && scenarios[0].scenario_kind == "doctor" {
    let summary = summarize_doctor_run(run_id, scenarios[0], opts, contract)
    write_summary_and_report_v2(run_id, summary) catch {
      err =>
        return Err(
          RuntimeFailure("write doctor summary failed: " + err.to_string()),
        )
    }
    return Ok(
      Json::object({
        "run_id": run_id.to_json(),
        "summary_json": summary_json_path_v2(run_id).to_json(),
        "report_md": report_markdown_path_v2(run_id).to_json(),
        "trust_status": summary.trust_status.to_json(),
      }),
    )
  }
  let samples : Array[SampleRowV2] = []
  for scenario in scenarios {
    let rows = select_rows_v2(scenario, opts)
    let scenario_samples = match
      run_samples_v2(run_id, scenario, rows, opts, contract) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    samples.append(scenario_samples)
  }
  write_jsonl_v2(
    samples_jsonl_path(run_id),
    samples.map(item => item.to_json()),
  ) catch {
    err =>
      return Err(RuntimeFailure("write samples failed: " + err.to_string()))
  }
  let cases = aggregate_cases_v2(run_id, samples, scenarios, policy)
  write_jsonl_v2(cases_jsonl_path(run_id), cases.map(item => item.to_json())) catch {
    err => return Err(RuntimeFailure("write cases failed: " + err.to_string()))
  }
  let summary = summarize_run_v2(
    run_id,
    scenarios,
    samples,
    cases,
    contract,
    opts.preset,
    opts.baseline_run_id,
  )
  write_summary_and_report_v2(run_id, summary) catch {
    err =>
      return Err(RuntimeFailure("write summary failed: " + err.to_string()))
  }
  Ok(
    Json::object({
      "run_id": run_id.to_json(),
      "samples_jsonl": samples_jsonl_path(run_id).to_json(),
      "cases_jsonl": cases_jsonl_path(run_id).to_json(),
      "summary_json": summary_json_path_v2(run_id).to_json(),
      "report_md": report_markdown_path_v2(run_id).to_json(),
      "trust_status": summary.trust_status.to_json(),
    }),
  )
}

///|
fn select_rows_v2(
  scenario : ScenarioSpecV2,
  opts : RunOptionsV2,
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
    @manifest.SelectOutput::Jsonl,
    false,
  )
  @manifest.select_rows(request)
}

///|
fn run_samples_v2(
  run_id : String,
  scenario : ScenarioSpecV2,
  rows : Array[@manifest.BenchRow],
  opts : RunOptionsV2,
  contract : BinaryContract,
) -> Result[Array[SampleRowV2], BenchV2Error] {
  let config = @tools.make_tool_registry_config(opts.markitdown_path)
  let out : Array[SampleRowV2] = []
  for row in rows {
    for tool_name in scenario.tool_names {
      let tool = @tools.find_tool(tool_name, config~).unwrap_or_else(fn() {
        abort("missing tool registration: " + tool_name)
      })
      if scenario.official_membership == "official-compare" &&
        tool_name == "markitdown" &&
        !tool.is_available() {
        return Err(
          TrustFailure(
            "official-compare requires markitdown adapter availability",
          ),
        )
      }
      if tool_name == "moonbit-engine" {
        out.append(run_engine_samples_v2(run_id, scenario, row, opts, contract))
      } else {
        out.append(
          run_process_samples_v2(run_id, scenario, row, tool, opts, contract),
        )
      }
    }
  }
  Ok(out)
}

///|
fn run_process_samples_v2(
  run_id : String,
  scenario : ScenarioSpecV2,
  row : @manifest.BenchRow,
  tool : @tools.BenchTool,
  opts : RunOptionsV2,
  contract : BinaryContract,
) -> Array[SampleRowV2] {
  let out : Array[SampleRowV2] = []
  let provenance_path = provenance_output_path_v2(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  let stdout_path = stdout_output_path_v2(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  let stderr_path = stderr_output_path_v2(
    run_id,
    scenario.scenario_id,
    tool.name,
    row.bench_id,
  )
  ensure_parent_dir_v2(provenance_path) catch {
    _ => ()
  }
  ensure_parent_dir_v2(stdout_path) catch {
    _ => ()
  }
  ensure_parent_dir_v2(stderr_path) catch {
    _ => ()
  }
  for _ in 0..<opts.warmup_count {
    if tool.is_available() {
      let warmup_path = output_path_v2(
        run_id,
        scenario.scenario_id,
        tool.name,
        row.bench_id,
        0,
        1,
      )
      ensure_parent_dir_v2(warmup_path) catch {
        _ => ()
      }
      let warmup = tool.build_command(row, warmup_path, opts.timeout_ms)
      let command = cli_command_with_provenance_v2(
        warmup,
        tool.name,
        provenance_path,
      )
      ignore(native_measure_command_v2(command, stdout_path, stderr_path))
    }
  }
  for repeat_index in 0..<opts.repeat_count {
    let output_path = output_path_v2(
      run_id,
      scenario.scenario_id,
      tool.name,
      row.bench_id,
      repeat_index,
      opts.repeat_count,
    )
    ensure_parent_dir_v2(output_path) catch {
      _ => ()
    }
    let base = tool.build_command(row, output_path, opts.timeout_ms)
    let command = cli_command_with_provenance_v2(
      base,
      tool.name,
      provenance_path,
    )
    let measured = if tool.is_available() {
      Some(native_measure_command_v2(command, stdout_path, stderr_path))
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
    out.push({
      schema_version: 2,
      run_id,
      scenario_id: scenario.scenario_id,
      scenario_kind: scenario.scenario_kind,
      official_membership: scenario.official_membership,
      tool: tool.name,
      measurement_mode: "process-cli",
      measurement_policy: measurement_policy_v2(opts),
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
      output_bytes: file_size_or_zero_v2(output_path),
      error: tool.availability_note,
      route_provenance: if tool.name == "moonbit-cli" {
        read_json_or_default_v2(
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
    })
  }
  out
}

///|
fn run_engine_samples_v2(
  run_id : String,
  scenario : ScenarioSpecV2,
  row : @manifest.BenchRow,
  opts : RunOptionsV2,
  contract : BinaryContract,
) -> Array[SampleRowV2] {
  let out : Array[SampleRowV2] = []
  let source = @input.input_from_path(row.input_path)
  let options = @convert.default_convert_options()
  for _ in 0..<opts.warmup_count {
    ignore(@convert.convert_input_with_provenance(source, options))
  }
  for repeat_index in 0..<opts.repeat_count {
    let started = @measure.monotonic_start()
    let execution = @convert.convert_input_with_provenance(source, options)
    let wall_us = @measure.monotonic_elapsed_us(started).to_int64()
    match execution {
      Ok(value) =>
        out.push({
          schema_version: 2,
          run_id,
          scenario_id: scenario.scenario_id,
          scenario_kind: scenario.scenario_kind,
          official_membership: scenario.official_membership,
          tool: "moonbit-engine",
          measurement_mode: "inprocess-engine",
          measurement_policy: measurement_policy_v2(opts),
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
          peak_rss_kb: None,
          output_bytes: @utf8.encode(value.result.content).length().to_int64(),
          error: None,
          route_provenance: @convert.convert_provenance_to_json(
            value.provenance,
          ),
          runner_artifact_identity: contract.runner_path,
          cli_artifact_path: None,
        })
      Err(err) =>
        out.push({
          schema_version: 2,
          run_id,
          scenario_id: scenario.scenario_id,
          scenario_kind: scenario.scenario_kind,
          official_membership: scenario.official_membership,
          tool: "moonbit-engine",
          measurement_mode: "inprocess-engine",
          measurement_policy: measurement_policy_v2(opts),
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
          peak_rss_kb: None,
          output_bytes: 0L,
          error: Some(err.to_string()),
          route_provenance: Json::object({ "missing": true.to_json() }),
          runner_artifact_identity: contract.runner_path,
          cli_artifact_path: None,
        })
    }
  }
  out
}

///|
fn cli_command_with_provenance_v2(
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
fn native_measure_command_v2(
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

///|
fn aggregate_cases_v2(
  run_id : String,
  samples : Array[SampleRowV2],
  scenarios : Array[ScenarioSpecV2],
  policy : BenchPolicyV2,
) -> Array[CaseAggregateV2] {
  let scenario_map = scenario_map_v2(scenarios)
  let groups : Map[String, Array[SampleRowV2]] = {}
  for sample in samples {
    let key = sample.scenario_id + "|" + sample.tool + "|" + sample.bench_id
    groups[key] = match groups.get(key) {
      Some(existing) => {
        let next = existing.copy()
        next.push(sample)
        next
      }
      None => [sample]
    }
  }
  let out : Array[CaseAggregateV2] = []
  for entry in groups {
    let rows = entry.1
    let first = rows[0]
    let ok_rows = rows.filter(item => item.status == "ok")
    let walls = ok_rows.map(item => item.wall_us.unwrap_or(0L))
    walls.sort()
    let output_values = ok_rows.map(item => item.output_bytes)
    output_values.sort()
    let scenario = scenario_map
      .get(first.scenario_id)
      .unwrap_or_else(fn() {
        abort("missing scenario metadata for " + first.scenario_id)
      })
    let expected_route = expected_route_for_case_v2(first, scenario, policy)
    let actual_route = actual_route_name_v2(first.route_provenance)
    let route_fidelity_status = route_fidelity_status_v2(first.route_provenance)
    let provenance_complete = route_provenance_complete_v2(
      first.route_provenance,
    )
    let median_output = median_sorted_int64_v2(output_values)
    let density = output_density_v2(median_output, first.input_bytes)
    let semantic_coverage = semantic_coverage_v2(first, median_output, density)
    let coverage_status = route_coverage_status_v2(
      first.tool,
      first.route_provenance,
      expected_route,
      actual_route,
    )
    out.push({
      schema_version: 2,
      run_id,
      scenario_id: first.scenario_id,
      tool: first.tool,
      bench_id: first.bench_id,
      format: first.format,
      size_class: first.size_class,
      input_bytes: first.input_bytes,
      sample_count: rows.length(),
      success_count: ok_rows.length(),
      median_wall_us: median_sorted_int64_v2(walls),
      min_wall_us: first_sorted_int64_v2(walls),
      max_wall_us: last_sorted_int64_v2(walls),
      median_output_bytes: median_output,
      output_density: density,
      comparable_status: if ok_rows.length() == rows.length() {
        "comparable"
      } else if ok_rows.length() == 0 {
        "non_ok"
      } else {
        "partial"
      },
      route_coverage_status: coverage_status,
      semantic_coverage,
      render_path: render_path_v2(first.route_provenance),
      trust_status: case_trust_status_v2(
        first.tool,
        coverage_status,
        semantic_coverage,
        route_fidelity_status,
        provenance_complete,
      ),
      trust_failure_reason: case_trust_failure_reason_v2(
        first.tool,
        coverage_status,
        semantic_coverage,
        route_fidelity_status,
        provenance_complete,
      ),
      expected_route,
      actual_route,
      route_fidelity_status,
      provenance_complete,
      route_provenance: first.route_provenance,
    })
  }
  out
}

///|
fn summarize_run_v2(
  run_id : String,
  scenarios : Array[ScenarioSpecV2],
  samples : Array[SampleRowV2],
  cases : Array[CaseAggregateV2],
  contract : BinaryContract,
  preset : String?,
  baseline_run_id : String?,
) -> RunSummaryV2 {
  ignore(samples)
  let scenario_summaries = summarize_scenarios_v2(scenarios, cases)
  {
    schema_version: 2,
    run_id,
    preset,
    scenario_ids: scenarios.map(item => item.scenario_id),
    binary_only_contract: Json::object({
      "runner_path": contract.runner_path.to_json(),
      "cli_path": contract.cli_path.to_json(),
      "runner_release_ok": contract.runner_release_ok.to_json(),
      "cli_release_ok": contract.cli_release_ok.to_json(),
      "used_moon_delegate": contract.used_moon_delegate.to_json(),
    }),
    trust_status: if cases
      .filter(item => item.trust_status == "failed")
      .length() ==
      0 {
      "trusted"
    } else {
      "failed"
    },
    gate_summary: Json::object({
      "selected_rows": bench_row_count_v2(cases).to_json(),
      "comparable_rows": comparable_row_count_v2(cases).to_json(),
      "status": gate_status_v2(cases).to_json(),
    }),
    route_coverage_summary: Json::object({
      "covered_cases": cases
      .filter(item => item.route_coverage_status == "covered")
      .length()
      .to_json(),
      "mismatch_cases": cases
      .filter(item => item.route_coverage_status == "mismatch")
      .length()
      .to_json(),
      "missing_cases": cases
      .filter(item => item.route_coverage_status == "missing")
      .length()
      .to_json(),
      "not_applicable_cases": cases
      .filter(item => item.route_coverage_status == "not_applicable")
      .length()
      .to_json(),
    }),
    truth_summary: Json::object({
      "trusted_cases": cases
      .filter(item => item.trust_status == "trusted")
      .length()
      .to_json(),
      "failed_cases": cases
      .filter(item => item.trust_status == "failed")
      .length()
      .to_json(),
      "low_density_cases": cases
      .filter(item => item.semantic_coverage == "low_density_untrusted")
      .length()
      .to_json(),
      "missing_provenance_cases": cases
      .filter(item => item.trust_failure_reason == "missing_provenance")
      .length()
      .to_json(),
      "route_mismatch_cases": cases
      .filter(item => item.trust_failure_reason == "route_mismatch")
      .length()
      .to_json(),
      "fidelity_mismatch_cases": cases
      .filter(item => item.trust_failure_reason == "fidelity_mismatch")
      .length()
      .to_json(),
    }),
    diff_summary: baseline_run_id.map(id => {
      Json::object({ "baseline_run_id": id.to_json() })
    }),
    scenarios: scenario_summaries,
    tools: summarize_tools_v2(cases),
    by_format: summarize_formats_v2(cases),
  }
}

///|
fn summarize_doctor_run(
  run_id : String,
  scenario : ScenarioSpecV2,
  opts : RunOptionsV2,
  contract : BinaryContract,
) -> RunSummaryV2 {
  ignore(opts)
  {
    schema_version: 2,
    run_id,
    preset: Some("doctor"),
    scenario_ids: [scenario.scenario_id],
    binary_only_contract: Json::object({
      "runner_path": contract.runner_path.to_json(),
      "cli_path": contract.cli_path.to_json(),
      "runner_release_ok": contract.runner_release_ok.to_json(),
      "cli_release_ok": contract.cli_release_ok.to_json(),
      "used_moon_delegate": contract.used_moon_delegate.to_json(),
    }),
    trust_status: "trusted",
    gate_summary: Json::object({ "status": "ok".to_json() }),
    route_coverage_summary: Json::object({
      "status": "not_applicable".to_json(),
    }),
    truth_summary: Json::object({ "status": "not_applicable".to_json() }),
    diff_summary: None,
    scenarios: [
      {
        scenario_id: scenario.scenario_id,
        scenario_kind: scenario.scenario_kind,
        official_membership: scenario.official_membership,
        selected_rows: 0,
        comparable_rows: 0,
        trust_status: "trusted",
        gate_status: "ok",
      },
    ],
    tools: [],
    by_format: [],
  }
}

///|
fn summarize_scenarios_v2(
  scenarios : Array[ScenarioSpecV2],
  cases : Array[CaseAggregateV2],
) -> Array[ScenarioSummaryV2] {
  let out : Array[ScenarioSummaryV2] = []
  for scenario in scenarios {
    let scenario_cases = cases.filter(item => {
      item.scenario_id == scenario.scenario_id
    })
    out.push({
      scenario_id: scenario.scenario_id,
      scenario_kind: scenario.scenario_kind,
      official_membership: scenario.official_membership,
      selected_rows: bench_row_count_v2(scenario_cases),
      comparable_rows: comparable_row_count_v2(scenario_cases),
      trust_status: if scenario_cases
        .filter(item => item.trust_status == "failed")
        .length() ==
        0 {
        "trusted"
      } else {
        "failed"
      },
      gate_status: gate_status_v2(scenario_cases),
    })
  }
  out
}

///|
fn summarize_tools_v2(cases : Array[CaseAggregateV2]) -> Array[ToolSummaryV2] {
  let groups : Map[String, Array[CaseAggregateV2]] = {}
  for case_ in cases {
    groups[case_.tool] = match groups.get(case_.tool) {
      Some(existing) => {
        let next = existing.copy()
        next.push(case_)
        next
      }
      None => [case_]
    }
  }
  let out : Array[ToolSummaryV2] = []
  for entry in groups {
    let medians = entry.1
      .map(item => item.median_wall_us.unwrap_or(0L))
      .filter(value => value > 0L)
    medians.sort()
    out.push({
      tool: entry.0,
      rows: entry.1.length(),
      success_rows: entry.1.filter(item => item.success_count > 0).length(),
      median_wall_us: median_sorted_int64_v2(medians),
    })
  }
  out
}

///|
fn summarize_formats_v2(
  cases : Array[CaseAggregateV2],
) -> Array[FormatSummaryV2] {
  let groups : Map[String, Array[CaseAggregateV2]] = {}
  for case_ in cases {
    groups[case_.format] = match groups.get(case_.format) {
      Some(existing) => {
        let next = existing.copy()
        next.push(case_)
        next
      }
      None => [case_]
    }
  }
  let out : Array[FormatSummaryV2] = []
  for entry in groups {
    let speedups = speedups_for_format_v2(entry.1, "moonbit-cli")
    let engine_speedups = speedups_for_format_v2(entry.1, "moonbit-engine")
    let rows = bench_rows_for_format_v2(entry.1)
    let comparable_rows = comparable_rows_for_format_v2(entry.1)
    out.push({
      format: entry.0,
      rows,
      comparable_rows,
      cli_geomean_speedup: geomean_speedup_v2(speedups),
      engine_geomean_speedup: geomean_speedup_v2(engine_speedups),
      status: if comparable_rows == rows {
        "ok"
      } else if comparable_rows == 0 {
        "non_comparable"
      } else {
        "partial"
      },
    })
  }
  out
}

///|
fn speedups_for_format_v2(
  cases : Array[CaseAggregateV2],
  tool_name : String,
) -> Array[Double] {
  let out : Array[Double] = []
  let markitdown = cases.filter(item => item.tool == "markitdown")
  let tool_rows = cases.filter(item => item.tool == tool_name)
  for left in tool_rows {
    for right in markitdown {
      if left.bench_id == right.bench_id &&
        left.median_wall_us is Some(lhs) &&
        right.median_wall_us is Some(rhs) &&
        lhs > 0L {
        out.push(rhs.to_double() / lhs.to_double())
      }
    }
  }
  out
}

///|
fn bench_row_count_v2(cases : Array[CaseAggregateV2]) -> Int {
  let keys : Array[String] = []
  for case_ in cases {
    let key = case_.scenario_id + "|" + case_.bench_id
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.length()
}

///|
fn comparable_row_count_v2(cases : Array[CaseAggregateV2]) -> Int {
  let grouped : Map[String, Bool] = {}
  for case_ in cases {
    let key = case_.scenario_id + "|" + case_.bench_id
    let ok = case_.comparable_status == "comparable"
    grouped[key] = match grouped.get(key) {
      Some(existing) => existing && ok
      None => ok
    }
  }
  grouped.values().filter(item => item).length()
}

///|
fn gate_status_v2(cases : Array[CaseAggregateV2]) -> String {
  let selected = bench_row_count_v2(cases)
  let comparable = comparable_row_count_v2(cases)
  if comparable == selected {
    "ok"
  } else if comparable == 0 {
    "failed"
  } else {
    "partial"
  }
}

///|
fn bench_rows_for_format_v2(cases : Array[CaseAggregateV2]) -> Int {
  let keys : Array[String] = []
  for case_ in cases {
    let key = case_.bench_id + "|" + case_.format
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.length()
}

///|
fn comparable_rows_for_format_v2(cases : Array[CaseAggregateV2]) -> Int {
  let grouped : Map[String, Bool] = {}
  for case_ in cases {
    let key = case_.bench_id + "|" + case_.format
    let ok = case_.comparable_status == "comparable"
    grouped[key] = match grouped.get(key) {
      Some(existing) => existing && ok
      None => ok
    }
  }
  grouped.values().filter(item => item).length()
}

///|
fn regenerate_report_v2(
  run_id : String,
  baseline_run_id : String?,
) -> Result[RunSummaryV2, BenchV2Error] {
  let policy = match load_policy_v2() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let samples = match
    load_sample_rows_v2(samples_jsonl_path(run_id), "sample") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let run_scenarios = scenario_specs_for_run_v2(samples, policy)
  let cases = aggregate_cases_v2(run_id, samples, run_scenarios, policy)
  write_jsonl_v2(cases_jsonl_path(run_id), cases.map(item => item.to_json())) catch {
    err =>
      return Err(RuntimeFailure("rewrite cases failed: " + err.to_string()))
  }
  let previous = match load_summary_v2(run_id) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let contract = match
    binary_contract_from_summary_v2(previous.binary_only_contract) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let baseline = match baseline_run_id {
    Some(value) => Some(value)
    None =>
      previous.diff_summary.bind(fn(diff) {
        json_optional_string_field_v2(diff, "baseline_run_id")
      })
  }
  let next = summarize_run_v2(
    run_id,
    run_scenarios,
    samples,
    cases,
    contract,
    previous.preset,
    baseline,
  )
  write_summary_and_report_v2(run_id, next) catch {
    err =>
      return Err(RuntimeFailure("rewrite report failed: " + err.to_string()))
  }
  Ok(next)
}

///|
fn write_summary_and_report_v2(
  run_id : String,
  summary : RunSummaryV2,
) -> Unit raise {
  @fs.write_string_to_file(
    summary_json_path_v2(run_id),
    summary.to_json().stringify(indent=2) + "\n",
    encoding="utf8",
  )
  @fs.write_string_to_file(
    report_markdown_path_v2(run_id),
    render_markdown_report_v2(summary),
    encoding="utf8",
  )
}

///|
fn render_markdown_report_v2(summary : RunSummaryV2) -> String {
  let lines : Array[String] = [
    "# Bench v2 Report",
    "",
    "- run_id: `" + summary.run_id + "`",
    "- preset: `" + summary.preset.unwrap_or("n/a") + "`",
    "- scenarios: `" + summary.scenario_ids.join(", ") + "`",
    "- trust_status: `" + summary.trust_status + "`",
    "- gate_status: `" +
    json_string_field_v2(summary.gate_summary, "status") +
    "`",
    "",
    "## Scenarios",
  ]
  for scenario in summary.scenarios {
    lines.push(
      "- `" +
      scenario.scenario_id +
      "` selected=`" +
      scenario.selected_rows.to_string() +
      "` comparable=`" +
      scenario.comparable_rows.to_string() +
      "` trust=`" +
      scenario.trust_status +
      "` gate=`" +
      scenario.gate_status +
      "`",
    )
  }
  lines.push("")
  lines.push("## Tools")
  for tool in summary.tools {
    lines.push(
      "- `" +
      tool.tool +
      "` rows=`" +
      tool.rows.to_string() +
      "` success=`" +
      tool.success_rows.to_string() +
      "` median_wall_us=`" +
      tool.median_wall_us.map(v => v.to_string()).unwrap_or("n/a") +
      "`",
    )
  }
  lines.push("")
  lines.push("## Route Coverage")
  lines.push(
    "- covered_cases=`" +
    json_int_field_v2(summary.route_coverage_summary, "covered_cases").to_string() +
    "` mismatch_cases=`" +
    json_int_field_v2(summary.route_coverage_summary, "mismatch_cases").to_string() +
    "` missing_cases=`" +
    json_int_field_v2(summary.route_coverage_summary, "missing_cases").to_string() +
    "` not_applicable_cases=`" +
    json_int_field_v2(summary.route_coverage_summary, "not_applicable_cases").to_string() +
    "`",
  )
  lines.push("")
  lines.push("## Truth Guard")
  lines.push(
    "- trusted_cases=`" +
    json_int_field_v2(summary.truth_summary, "trusted_cases").to_string() +
    "` failed_cases=`" +
    json_int_field_v2(summary.truth_summary, "failed_cases").to_string() +
    "` low_density_cases=`" +
    json_int_field_v2(summary.truth_summary, "low_density_cases").to_string() +
    "` missing_provenance_cases=`" +
    json_int_field_v2(summary.truth_summary, "missing_provenance_cases").to_string() +
    "` route_mismatch_cases=`" +
    json_int_field_v2(summary.truth_summary, "route_mismatch_cases").to_string() +
    "` fidelity_mismatch_cases=`" +
    json_int_field_v2(summary.truth_summary, "fidelity_mismatch_cases").to_string() +
    "`",
  )
  lines.push("")
  lines.push("## By Format")
  for row in summary.by_format {
    lines.push(
      "- `" +
      row.format +
      "` comparable=`" +
      row.comparable_rows.to_string() +
      "/" +
      row.rows.to_string() +
      "` cli_geomean=`" +
      format_optional_speedup_v2(row.cli_geomean_speedup) +
      "` engine_geomean=`" +
      format_optional_speedup_v2(row.engine_geomean_speedup) +
      "` status=`" +
      row.status +
      "`",
    )
  }
  lines.join("\n") + "\n"
}

///|
fn format_optional_speedup_v2(value : Double?) -> String {
  match value {
    Some(v) => v.to_string() + "x"
    None => "n/a"
  }
}

///|
fn measurement_policy_v2(opts : RunOptionsV2) -> String {
  "warmup=" +
  opts.warmup_count.to_string() +
  ";samples=" +
  opts.repeat_count.to_string() +
  ";order=row_major_interleaved"
}

///|
fn median_sorted_int64_v2(values : Array[Int64]) -> Int64? {
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
fn first_sorted_int64_v2(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn last_sorted_int64_v2(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[values.length() - 1])
  }
}

///|
fn geomean_speedup_v2(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let positive = values.filter(item => item > 0.0)
  if positive.length() == 0 {
    return None
  }
  let total_ln = positive.fold(init=0.0, fn(acc, value) {
    acc + @math.ln(value)
  })
  Some(@math.exp(total_ln / positive.length().to_double()))
}

///|
fn ensure_v2_dirs(run_id : String) -> Unit raise @fs.IOError {
  ensure_dir_tree_v2(run_root_v2(run_id))
  ensure_dir_tree_v2(results_root_v2(run_id))
  ensure_dir_tree_v2(reports_root_v2(run_id))
  ensure_dir_tree_v2(outputs_root_v2(run_id))
}

///|
fn ensure_parent_dir_v2(path : String) -> Unit raise @fs.IOError {
  ensure_dir_tree_v2(dirname_v2(path))
}

///|
fn dirname_v2(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn ensure_dir_tree_v2(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." || @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn run_root_v2(run_id : String) -> String {
  ".tmp/bench/v2/runs/" + run_id
}

///|
fn results_root_v2(run_id : String) -> String {
  run_root_v2(run_id) + "/results"
}

///|
fn reports_root_v2(run_id : String) -> String {
  run_root_v2(run_id) + "/reports"
}

///|
fn outputs_root_v2(run_id : String) -> String {
  run_root_v2(run_id) + "/outputs"
}

///|
fn samples_jsonl_path(run_id : String) -> String {
  results_root_v2(run_id) + "/samples.jsonl"
}

///|
fn cases_jsonl_path(run_id : String) -> String {
  results_root_v2(run_id) + "/cases.jsonl"
}

///|
fn summary_json_path_v2(run_id : String) -> String {
  results_root_v2(run_id) + "/summary.json"
}

///|
fn report_markdown_path_v2(run_id : String) -> String {
  reports_root_v2(run_id) + "/report.md"
}

///|
fn output_path_v2(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
  repeat_index : Int,
  repeat_count : Int,
) -> String {
  let suffix = if repeat_count <= 1 {
    ".md"
  } else {
    "-repeat-" + (repeat_index + 1).to_string() + ".md"
  }
  outputs_root_v2(run_id) +
  "/" +
  scenario_path_token_v2(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  suffix
}

///|
fn provenance_output_path_v2(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root_v2(run_id) +
  "/" +
  scenario_path_token_v2(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".provenance.json"
}

///|
fn stdout_output_path_v2(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root_v2(run_id) +
  "/" +
  scenario_path_token_v2(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".stdout.log"
}

///|
fn stderr_output_path_v2(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root_v2(run_id) +
  "/" +
  scenario_path_token_v2(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".stderr.log"
}

///|
fn file_size_or_zero_v2(path : String) -> Int64 {
  if !@fs.path_exists(path) {
    return 0L
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return 0L }
  bytes.length().to_int64()
}

///|
fn read_json_or_default_v2(path : String, fallback : Json) -> Json {
  if !@fs.path_exists(path) {
    return fallback
  }
  let text = @fs.read_file_to_string(path, encoding="utf8") catch {
    _ => return fallback
  }
  @json.parse(text) catch {
    _ => fallback
  }
}

///|
fn route_provenance_complete_v2(json : Json) -> Bool {
  match json {
    Json::Object(map) => {
      let route_plan_ok = match map.get("route_plan") {
        Some(Json::Object(route_plan)) =>
          route_plan.get("selected_route") is Some(_) &&
          route_plan.get("route_reason") is Some(_) &&
          route_plan.get("route_probe_summary") is Some(_)
        _ => false
      }
      route_plan_ok &&
      map.get("effective_parser_mode") is Some(_) &&
      map.get("parse_result_kind") is Some(_) &&
      map.get("pipeline_output_kind") is Some(_) &&
      map.get("render_input_kind") is Some(_) &&
      map.get("route_fidelity_status") is Some(_)
    }
    _ => false
  }
}

///|
fn policy_scenarios_v2(policy : BenchPolicyV2) -> Array[ScenarioSpecV2] {
  policy.scenarios.map(item => {
    scenario_id: item.scenario_id,
    scenario_kind: item.scenario_kind,
    tool_names: policy.tool_matrix.get(item.tool_set).unwrap_or([]),
    exact_tiers: item.exact_tiers,
    format_filters: item.format_filters,
    official_membership: item.official_membership,
    route_expectation: item.route_expectation,
  })
}

///|
fn load_policy_v2() -> Result[BenchPolicyV2, BenchV2Error] {
  let text = @fs.read_file_to_string(
    "bench/config/policy.json",
    encoding="utf8",
  ) catch {
    err =>
      return Err(
        RuntimeFailure(
          "read bench/config/policy.json failed: " + err.to_string(),
        ),
      )
  }
  let json = @json.parse(text) catch {
    err =>
      return Err(
        RuntimeFailure(
          "parse bench/config/policy.json failed: " + err.to_string(),
        ),
      )
  }
  Ok(decode_policy_v2(json))
}

///|
fn decode_policy_v2(json : Json) -> BenchPolicyV2 {
  let root = json_object_value_required_v2(json, "bench policy root")
  {
    defaults: {
      repeat_count: json_int_required_in_v2(
        json_object_required_v2(root, "defaults"),
        "repeat_count",
        "defaults",
      ),
      warmup_count: json_int_required_in_v2(
        json_object_required_v2(root, "defaults"),
        "warmup_count",
        "defaults",
      ),
      timeout_ms: json_int_required_in_v2(
        json_object_required_v2(root, "defaults"),
        "timeout_ms",
        "defaults",
      ),
      tiers: json_string_array_v2(
        json_object_required_v2(root, "defaults"),
        "tiers",
      ),
    },
    tool_matrix: decode_tool_matrix_v2(
      json_object_required_v2(root, "tool_matrix"),
    ),
    presets: decode_presets_v2(json_object_required_v2(root, "gate_presets")),
    scenarios: decode_scenarios_v2(json_array_required_v2(root, "scenarios")),
    row_expected_routes: decode_row_expected_routes_v2(
      json_object_required_v2(root, "row_overrides"),
    ),
  }
}

///|
fn decode_tool_matrix_v2(
  json : Map[String, Json],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for entry in json {
    out[entry.0] = json_string_array_value_v2(entry.1)
  }
  out
}

///|
fn decode_presets_v2(json : Map[String, Json]) -> Map[String, PresetPolicyV2] {
  let out : Map[String, PresetPolicyV2] = {}
  for entry in json {
    let object = json_object_value_required_v2(
      entry.1,
      "gate preset `" + entry.0 + "`",
    )
    out[entry.0] = {
      scenario_ids: json_string_array_v2(object, "scenario_ids"),
      tiers: json_string_array_v2(object, "tiers"),
      repeat_count: json_int_required_in_v2(
        object,
        "repeat_count",
        "gate preset `" + entry.0 + "`",
      ),
      warmup_count: json_int_required_in_v2(
        object,
        "warmup_count",
        "gate preset `" + entry.0 + "`",
      ),
      timeout_ms: json_int_required_in_v2(
        object,
        "timeout_ms",
        "gate preset `" + entry.0 + "`",
      ),
    }
  }
  out
}

///|
fn decode_scenarios_v2(json : Array[Json]) -> Array[ScenarioPolicyV2] {
  json.map(item => {
    let object = json_object_value_required_v2(item, "scenario")
    let row_selector = json_object_required_v2(object, "row_selector")
    {
      scenario_id: json_string_required_in_v2(object, "scenario_id", "scenario"),
      scenario_kind: json_string_required_in_v2(
        object, "scenario_kind", "scenario",
      ),
      tool_set: json_string_required_in_v2(object, "tool_set", "scenario"),
      exact_tiers: if row_selector.get("tiers") is Some(_) {
        json_string_array_v2(row_selector, "tiers")
      } else {
        []
      },
      format_filters: if row_selector.get("formats") is Some(_) {
        json_string_array_v2(row_selector, "formats")
      } else {
        []
      },
      official_membership: json_string_required_in_v2(
        object, "official_membership", "scenario",
      ),
      route_expectation: json_string_required_in_v2(
        object, "route_expectation", "scenario",
      ),
    }
  })
}

///|
fn decode_row_expected_routes_v2(
  json : Map[String, Json],
) -> Map[String, String] {
  let out : Map[String, String] = {}
  for entry in json {
    let object = json_object_value_required_v2(
      entry.1,
      "row override `" + entry.0 + "`",
    )
    match object.get("route_expectation") {
      Some(Json::String(value)) => out[entry.0] = value
      Some(Json::Object(route_object)) =>
        match route_object.get("selected_route") {
          Some(Json::String(value)) => out[entry.0] = value
          _ => ()
        }
      _ => ()
    }
  }
  out
}

///|
fn apply_policy_defaults_v2(
  opts : RunOptionsV2,
  policy : BenchPolicyV2,
) -> RunOptionsV2 {
  let preset = opts.preset.bind(fn(name) { policy.presets.get(name) })
  {
    ..opts,
    exact_tiers: if opts.exact_tiers.length() > 0 {
      opts.exact_tiers
    } else {
      preset.map(item => item.tiers).unwrap_or(policy.defaults.tiers)
    },
    repeat_count: if opts.repeat_count == 3 {
      preset
      .map(item => item.repeat_count)
      .unwrap_or(policy.defaults.repeat_count)
    } else {
      opts.repeat_count
    },
    warmup_count: if opts.warmup_count == 1 {
      preset
      .map(item => item.warmup_count)
      .unwrap_or(policy.defaults.warmup_count)
    } else {
      opts.warmup_count
    },
    timeout_ms: if opts.timeout_ms == 60000 {
      preset.map(item => item.timeout_ms).unwrap_or(policy.defaults.timeout_ms)
    } else {
      opts.timeout_ms
    },
  }
}

///|
fn expected_route_for_case_v2(
  sample : SampleRowV2,
  scenario : ScenarioSpecV2,
  policy : BenchPolicyV2,
) -> String? {
  if sample.tool != "moonbit-cli" && sample.tool != "moonbit-engine" {
    return None
  }
  match policy.row_expected_routes.get(sample.bench_id) {
    Some(value) => Some(value)
    None =>
      if scenario.route_expectation == "product_default" ||
        scenario.route_expectation == "not_applicable" {
        None
      } else {
        Some(scenario.route_expectation)
      }
  }
}

///|
fn actual_route_name_v2(route_provenance : Json) -> String? {
  match route_provenance {
    Json::Object(map) =>
      match map.get("route_plan") {
        Some(Json::Object(route_plan)) =>
          match route_plan.get("selected_route") {
            Some(Json::String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn route_coverage_status_v2(
  tool_name : String,
  _route_provenance : Json,
  expected_route : String?,
  actual_route : String?,
) -> String {
  if tool_name != "moonbit-cli" && tool_name != "moonbit-engine" {
    return "not_applicable"
  }
  match expected_route {
    Some(expected) =>
      if actual_route == Some(expected) {
        "covered"
      } else {
        "mismatch"
      }
    None => "covered"
  }
}

///|
fn output_density_v2(output_bytes : Int64?, input_bytes : Int) -> Double? {
  match output_bytes {
    Some(value) =>
      if input_bytes > 0 {
        Some(value.to_double() / input_bytes.to_double())
      } else {
        None
      }
    None => None
  }
}

///|
fn semantic_coverage_v2(
  sample : SampleRowV2,
  output_bytes : Int64?,
  density : Double?,
) -> String {
  if sample.tool != "moonbit-cli" && sample.tool != "moonbit-engine" {
    return "not_applicable"
  }
  if sample.status != "ok" {
    return "not_applicable"
  }
  if !structured_text_format_requires_density_guard_v2(sample.format) {
    return "ok"
  }
  if sample.size_class != "large" && sample.size_class != "huge" {
    return "ok"
  }
  let bytes = output_bytes.unwrap_or(0L)
  let ratio = density.unwrap_or(0.0)
  if bytes < 256L && ratio < 0.001 {
    "low_density_untrusted"
  } else {
    "ok"
  }
}

///|
fn structured_text_format_requires_density_guard_v2(format : String) -> Bool {
  format == "json" || format == "yaml" || format == "xml"
}

///|
fn render_path_v2(route_provenance : Json) -> String {
  match route_provenance {
    Json::Object(map) =>
      match map.get("render_input_kind") {
        Some(Json::String(value)) => value
        _ => "unknown"
      }
    _ => "unknown"
  }
}

///|
fn case_trust_status_v2(
  tool_name : String,
  route_coverage_status : String,
  semantic_coverage : String,
  route_fidelity_status : String?,
  provenance_complete : Bool,
) -> String {
  if case_trust_failure_reason_v2(
      tool_name, route_coverage_status, semantic_coverage, route_fidelity_status,
      provenance_complete,
    ) !=
    "none" {
    "failed"
  } else {
    "trusted"
  }
}

///|
fn case_trust_failure_reason_v2(
  tool_name : String,
  route_coverage_status : String,
  semantic_coverage : String,
  route_fidelity_status : String?,
  provenance_complete : Bool,
) -> String {
  if tool_name == "moonbit-cli" || tool_name == "moonbit-engine" {
    if !provenance_complete {
      return "missing_provenance"
    }
    if route_fidelity_status != Some("matched") {
      return "fidelity_mismatch"
    }
    if route_coverage_status == "mismatch" {
      return "route_mismatch"
    }
  }
  if semantic_coverage == "low_density_untrusted" {
    return "low_density_untrusted"
  }
  "none"
}

///|
fn route_fidelity_status_v2(route_provenance : Json) -> String? {
  json_optional_string_field_v2(route_provenance, "route_fidelity_status")
}

///|
fn scenario_map_v2(
  scenarios : Array[ScenarioSpecV2],
) -> Map[String, ScenarioSpecV2] {
  let out : Map[String, ScenarioSpecV2] = {}
  for scenario in scenarios {
    out[scenario.scenario_id] = scenario
  }
  out
}

///|
fn scenario_specs_for_run_v2(
  samples : Array[SampleRowV2],
  policy : BenchPolicyV2,
) -> Array[ScenarioSpecV2] {
  let catalog = scenario_map_v2(policy_scenarios_v2(policy))
  let out : Array[ScenarioSpecV2] = []
  for sample in samples {
    let key = sample.scenario_id
    if out.any(fn(item) { item.scenario_id == key }) {
      continue
    }
    match catalog.get(key) {
      Some(scenario) => out.push(scenario)
      None => abort("unknown scenario recorded in run: " + key)
    }
  }
  out
}

///|
fn scenario_path_token_v2(scenario_id : String) -> String {
  let chars = scenario_id.to_array()
  let out : Array[Char] = []
  for char in chars {
    if (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '-' ||
      char == '_' {
      out.push(char)
    } else {
      out.push('_')
    }
  }
  String::from_array(out)
}

///|
fn load_summary_v2(run_id : String) -> Result[RunSummaryV2, BenchV2Error] {
  let content = @fs.read_file_to_string(
    summary_json_path_v2(run_id),
    encoding="utf8",
  ) catch {
    err => return Err(RuntimeFailure("read summary failed: " + err.to_string()))
  }
  let json = @json.parse(content) catch {
    err =>
      return Err(RuntimeFailure("parse summary failed: " + err.to_string()))
  }
  let summary = (@json.from_json(json) : RunSummaryV2) catch {
    err =>
      return Err(RuntimeFailure("decode summary failed: " + err.to_string()))
  }
  Ok(summary)
}

///|
fn binary_contract_from_summary_v2(
  json : Json,
) -> Result[BinaryContract, BenchV2Error] {
  match json {
    Json::Object(map) => {
      let runner_path = json_string_required_from_json_v2(
        map, "runner_path", "binary_only_contract",
      )
      let cli_path = json_string_required_from_json_v2(
        map, "cli_path", "binary_only_contract",
      )
      let runner_release_ok = json_bool_required_from_json_v2(
        map, "runner_release_ok", "binary_only_contract",
      )
      let cli_release_ok = json_bool_required_from_json_v2(
        map, "cli_release_ok", "binary_only_contract",
      )
      let used_moon_delegate = json_bool_required_from_json_v2(
        map, "used_moon_delegate", "binary_only_contract",
      )
      Ok({
        runner_path,
        cli_path,
        runner_release_ok,
        cli_release_ok,
        used_moon_delegate,
      })
    }
    _ =>
      Err(
        RuntimeFailure("binary_only_contract must decode from summary object"),
      )
  }
}

///|
fn load_sample_rows_v2(
  path : String,
  label : String,
) -> Result[Array[SampleRowV2], BenchV2Error] {
  let content = @fs.read_file_to_string(path, encoding="utf8") catch {
    err =>
      return Err(
        RuntimeFailure("read " + label + " jsonl failed: " + err.to_string()),
      )
  }
  let out : Array[SampleRowV2] = []
  for line in content.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let json = @json.parse(trimmed) catch {
      err =>
        return Err(
          RuntimeFailure(
            "parse " + label + " jsonl row failed: " + err.to_string(),
          ),
        )
    }
    let row = (@json.from_json(json) : SampleRowV2) catch {
      err =>
        return Err(
          RuntimeFailure(
            "decode " + label + " jsonl row failed: " + err.to_string(),
          ),
        )
    }
    out.push(row)
  }
  Ok(out)
}

///|
fn json_optional_string_field_v2(json : Json, key : String) -> String? {
  match json {
    Json::Object(map) =>
      match map.get(key) {
        Some(Json::String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn json_string_required_from_json_v2(
  json : Map[String, Json],
  key : String,
  label : String,
) -> String {
  match json.get(key) {
    Some(Json::String(value)) => value
    _ => abort(label + " missing string field `" + key + "`")
  }
}

///|
fn json_bool_required_from_json_v2(
  json : Map[String, Json],
  key : String,
  label : String,
) -> Bool {
  match json.get(key) {
    Some(Json::True) => true
    Some(Json::False) => false
    _ => abort(label + " missing bool field `" + key + "`")
  }
}

///|
fn json_object_required_v2(
  json : Map[String, Json],
  key : String,
) -> Map[String, Json] {
  match json.get(key) {
    Some(Json::Object(value)) => value
    _ => abort("bench policy missing object field: " + key)
  }
}

///|
fn json_array_required_v2(
  json : Map[String, Json],
  key : String,
) -> Array[Json] {
  match json.get(key) {
    Some(Json::Array(value)) => value
    _ => abort("bench policy missing array field: " + key)
  }
}

///|
fn json_object_value_required_v2(
  json : Json,
  label : String,
) -> Map[String, Json] {
  match json {
    Json::Object(value) => value
    _ => abort(label + " must be an object")
  }
}

///|
fn json_string_array_v2(
  json : Map[String, Json],
  key : String,
) -> Array[String] {
  match json.get(key) {
    Some(value) => json_string_array_value_v2(value)
    None => abort("bench policy missing array field: " + key)
  }
}

///|
fn json_string_array_value_v2(json : Json) -> Array[String] {
  match json {
    Json::Array(items) =>
      items.map(item => {
        match item {
          Json::String(value) => value
          _ => abort("bench policy string array contains non-string value")
        }
      })
    _ => abort("bench policy value must be a string array")
  }
}

///|
fn json_string_required_in_v2(
  json : Map[String, Json],
  key : String,
  label : String,
) -> String {
  match json.get(key) {
    Some(Json::String(value)) => value
    _ => abort(label + " missing string field `" + key + "`")
  }
}

///|
fn json_int_required_in_v2(
  json : Map[String, Json],
  key : String,
  label : String,
) -> Int {
  match json.get(key) {
    Some(Json::Number(value, ..)) => value.to_int()
    _ => abort(label + " missing integer field `" + key + "`")
  }
}

///|
fn write_jsonl_v2(path : String, rows : Array[Json]) -> Unit raise {
  let out = Ref("")
  for row in rows {
    out.val += row.stringify() + "\n"
  }
  @fs.write_string_to_file(path, out.val, encoding="utf8")
}

///|
fn parse_report_run_id_v2(args : Array[String]) -> String raise {
  let i = Ref(0)
  while i.val < args.length() {
    if args[i.val] == "--run" {
      ensure_next_arg_v2(args, i.val, "--run")
      return args[i.val + 1].trim().to_owned()
    }
    i.val += 1
  }
  raise InvalidArgument("report requires --run <run_id>")
}

///|
fn parse_report_baseline_v2(args : Array[String]) -> String? {
  let i = Ref(0)
  while i.val < args.length() {
    if args[i.val] == "--baseline" && i.val + 1 < args.length() {
      return Some(args[i.val + 1].trim().to_owned())
    }
    i.val += 1
  }
  None
}

///|
fn json_string_field_v2(json : Json, key : String) -> String {
  match json {
    Json::Object(map) =>
      match map.get(key) {
        Some(Json::String(value)) => value
        _ => "unknown"
      }
    _ => "unknown"
  }
}

///|
fn json_int_field_v2(json : Json, key : String) -> Int {
  match json {
    Json::Object(map) =>
      match map.get(key) {
        Some(Json::Number(value, ..)) => value.to_int()
        _ => 0
      }
    _ => 0
  }
}

///|
fn make_run_id_v2(args : Array[String]) -> String {
  let fingerprint = args.join("|")
  "run-" + @env.now().to_string() + "-" + fingerprint.length().to_string()
}
