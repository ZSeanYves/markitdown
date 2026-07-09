///|
fn normalize_bench_args(raw_args : Array[String]) -> Array[String] {
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
fn print_bench_help() -> Unit {
  println("Bench binary-only runner for mb-markitdown.")
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
fn run_catalog(args : Array[String]) -> Int {
  let policy = unwrap_or_report(load_policy(), "catalog failed to load policy")
  if policy is None {
    return 1
  }
  if args.length() == 0 {
    println("catalog requires rows|scenarios")
    return 2
  }
  match args[0] {
    "rows" => {
      let opts = parse_run_options(args[1:].to_owned()) catch {
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
      for scenario in policy_scenarios(policy.unwrap()) {
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
fn run_command(args : Array[String], runner : @command.RunnerContext) -> Int {
  let opts = parse_run_options(args) catch {
    err => {
      println("run argument error: " + err.to_string())
      return 2
    }
  }
  let policy = unwrap_or_report(load_policy(), "load bench policy failed")
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
  let effective_opts = apply_policy_defaults(opts, policy.unwrap())
  let scenarios = resolve_scenarios(effective_opts, policy.unwrap())
  let run_id = unwrap_or_report(allocate_run_id(args), "run failed")
  if run_id is None {
    return 1
  }
  let payload = unwrap_or_report(
    execute_run(
      run_id.unwrap(),
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
fn report_command(args : Array[String]) -> Int {
  let run_id = parse_report_run_id(args) catch {
    err => {
      println("report argument error: " + err.to_string())
      return 2
    }
  }
  let baseline = parse_report_baseline(args)
  let summary = unwrap_or_report(
    regenerate_report(run_id, baseline),
    "report failed",
  )
  if summary is None {
    return 1
  }
  println(summary.unwrap().to_json().stringify())
  0
}

///|
fn doctor_command(runner : @command.RunnerContext) -> Int {
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
fn[T] unwrap_or_report(result : Result[T, BenchError], label : String) -> T? {
  match result {
    Ok(value) => Some(value)
    Err(err) => {
      println(label + ": " + err.to_string())
      None
    }
  }
}
