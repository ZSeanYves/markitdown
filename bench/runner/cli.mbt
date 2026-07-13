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
  bench_println("Bench binary-only runner for mb-markitdown.")
  bench_println("Usage:")
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe catalog rows [--tiers regular,release,stress] [--bench-id <id[,more]>] [--format <fmt[,more]>] [--comparison-class external_compare|self_baseline] [--limit N]",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe catalog scenarios",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe run --preset official-internal [--limit N]",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe run --preset official-external-compare [--limit N] [--markitdown-path <path>]",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe run --preset official-self-baseline [--limit N] [--baseline <run_id>]",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe run --scenario <scenario_id> [--bench-id <id>] [--limit N]",
  )
  bench_println(
    "  run options: [--progress auto|json|off] [--keep-outputs failures|all|none] [--resume <run_id>] [--max-disk-mb N]",
  )
  bench_println(
    "  _build/native/release/build/bench/runner/runner.exe report --run <run_id> [--baseline <run_id>]",
  )
  bench_println("  _build/native/release/build/bench/runner/runner.exe doctor")
}

///|
fn run_catalog(args : Array[String]) -> Int {
  let policy = unwrap_or_report(load_policy(), "catalog failed to load policy")
  if policy is None {
    return 1
  }
  if args.length() == 0 {
    bench_println("catalog requires rows|scenarios")
    return 2
  }
  match args[0] {
    "rows" => {
      let request = @manifest.parse_select_request(args[1:].to_owned()) catch {
        err => {
          bench_println("catalog rows argument error: " + err.to_string())
          return 2
        }
      }
      for row in @manifest.select_rows(request) {
        bench_println(row.to_json().stringify())
      }
      0
    }
    "scenarios" => {
      for scenario in policy_scenarios(policy.unwrap()) {
        bench_println(
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
      bench_println("unsupported catalog target: " + args[0])
      2
    }
  }
}

///|
fn run_command(args : Array[String], runner : @command.RunnerContext) -> Int {
  let opts = parse_run_options(args) catch {
    err => {
      bench_println("run argument error: " + err.to_string())
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
  let run_id = unwrap_or_report(
    match effective_opts.resume_run_id {
      Some(value) if @fs.path_exists(run_root(value)) => Ok(value)
      Some(value) => Err(InvalidArgument("resume run does not exist: " + value))
      None => allocate_run_id(args)
    },
    "run failed",
  )
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
  bench_println(payload.unwrap().stringify())
  0
}

///|
fn report_command(args : Array[String]) -> Int {
  let run_id = parse_report_run_id(args) catch {
    err => {
      bench_println("report argument error: " + err.to_string())
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
  bench_println(summary.unwrap().to_json().stringify())
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
  bench_println(
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
fn run_engine_worker(args : Array[String]) -> Int {
  if args.length() != 3 {
    return 2
  }
  let detected_format = @input.parse_detected_format(args[0])
  if detected_format == @input.DetectedFormat::Unknown {
    return 2
  }
  let source = @input.input_from_path_with_format(
    args[1],
    Some(detected_format),
  )
  let execution = @convert.convert_input_with_provenance(
    source,
    bench_convert_options(detected_format),
  )
  match execution {
    Ok(value) => {
      ensure_parent_dir(args[2]) catch {
        _ => return 1
      }
      @fs.write_string_to_file(args[2], value.result.content, encoding="utf8") catch {
        _ => return 1
      }
      0
    }
    Err(_) => 1
  }
}

///|
fn[T] unwrap_or_report(result : Result[T, BenchError], label : String) -> T? {
  match result {
    Ok(value) => Some(value)
    Err(err) => {
      bench_println(label + ": " + err.to_string())
      None
    }
  }
}
