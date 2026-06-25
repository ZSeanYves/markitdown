///|
async fn main {
  let status = run_bench_cli(@sys.get_cli_args())
  if status != 0 {
    @sys.exit(status)
  }
}

///|
pub async fn run_bench_cli(raw_args : Array[String]) -> Int {
  let runner = @command.detect_runner_context(raw_args)
  let args = normalize_main_args(raw_args)
  if args.length() == 0 {
    print_main_help(runner)
    return 0
  }
  match args[0] {
    "help" | "--help" | "-h" => {
      print_main_help(runner)
      0
    }
    "select" => run_select_command(args[1:].to_owned())
    "run" => run_run_command(args[1:].to_owned(), runner)
    "compare" => run_compare_command(args[1:].to_owned(), runner)
    "diagnose-overhead" | "overhead" =>
      run_diagnose_command(args[1:].to_owned(), runner)
    "report" => run_report_command(args[1:].to_owned())
    _ => {
      println("unknown bench/runner command: " + args[0])
      print_main_help(runner)
      2
    }
  }
}

///|
fn normalize_main_args(raw_args : Array[String]) -> Array[String] {
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
fn print_main_help(runner : @command.RunnerContext) -> Unit {
  println("MoonBit-native benchmark toolchain for mb-markitdown.")
  println(
    "Current runner mode: " +
    runner.runner_mode +
    " (canonical_performance=" +
    runner.canonical_performance.to_string() +
    ")",
  )
  if runner.runner_path is Some(path) {
    println("Current runner path: " + path)
  }
  if !runner.canonical_performance {
    println(
      "Warning: non-release runner mode is suitable for dev smoke only and can distort in-process engine timing and fixed-overhead calculations.",
    )
  }
  println("Usage:")
  println("  moon build bench/runner --target native --release")
  println("  moon build cli --target native --release")
  println(
    "  RUNNER=\"$(find _build/native/release -type f \\( -name 'runner.exe' -o -name 'runner' \\) | grep '/bench/runner/' | head -1)\"",
  )
  println(
    "  \"$RUNNER\" select [--tier smoke] [--format csv] [--limit 3] [--stats] [--output jsonl|tsv]",
  )
  println(
    "  \"$RUNNER\" run --tool moonbit-cli|moonbit-engine|markitdown [--tier smoke] [--format csv] [--limit 3] [--repeat 3] [--timeout-ms 60000|--timeout-sec 60] [--cli-output-mode file|stdout_capture] [--engine-output-mode file|memory|none] [--markitdown-path <path>]",
  )
  println(
    "  \"$RUNNER\" compare [--tier smoke] [--format csv] [--limit 3] [--repeat 3] [--timeout-ms 60000|--timeout-sec 60] [--cli-output-mode file|stdout_capture] [--engine-output-mode file|memory|none] [--markitdown-path <path>]",
  )
  println(
    "  \"$RUNNER\" diagnose-overhead [--repeat 20] [--timeout-ms 60000|--timeout-sec 60] [--cli-output-mode file|stdout_capture] [--engine-output-mode file|memory|none]",
  )
  println(
    "  \"$RUNNER\" report --input .tmp/bench/runs/<run_id>/results/<run>.jsonl[,more.jsonl]",
  )
  println("Dev smoke only:")
  println("  moon run bench/runner -- help")
  println("  moon run bench/runner -- diagnose-overhead --repeat 3")
}

///|
fn run_select_command(args : Array[String]) -> Int {
  let request = @manifest.parse_select_request(args) catch {
    err => {
      println("select argument error: " + err.to_string())
      return 2
    }
  }
  if request.stats_only {
    println(@manifest.selector_stats_json(request).stringify())
  } else if request.output == @manifest.SelectOutput::Tsv {
    for line in @manifest.selector_rows_tsv(request) {
      println(line)
    }
  } else {
    for row in @manifest.select_rows(request) {
      println(row.to_json().stringify())
    }
  }
  0
}

///|
async fn run_run_command(
  args : Array[String],
  runner : @command.RunnerContext,
) -> Int {
  let request = @command.parse_run_request_with_context(args, runner) catch {
    err => {
      println("run argument error: " + err.to_string())
      return 2
    }
  }
  let tool = @tools.find_tool(
    request.tool_name,
    config=@tools.make_tool_registry_config(request.markitdown_path),
  )
  if tool is None {
    println("unknown benchmark tool: " + request.tool_name)
    return 2
  }
  let result_path = @process.run_tool(request, tool.unwrap())
  println(result_path)
  0
}

///|
async fn run_compare_command(
  args : Array[String],
  runner : @command.RunnerContext,
) -> Int {
  let request = @command.parse_compare_request_with_context(args, runner) catch {
    err => {
      println("compare argument error: " + err.to_string())
      return 2
    }
  }
  let payload = @process.run_compare(request)
  println(payload.to_json().stringify())
  0
}

///|
async fn run_diagnose_command(
  args : Array[String],
  runner : @command.RunnerContext,
) -> Int {
  let request = @command.parse_diagnose_request_with_context(args, runner) catch {
    err => {
      println("diagnose-overhead argument error: " + err.to_string())
      return 2
    }
  }
  let payload = @process.run_overhead_diagnostics(request)
  println(payload.to_json().stringify())
  0
}

///|
fn run_report_command(args : Array[String]) -> Int {
  let request = @result.parse_report_request(args) catch {
    err => {
      println("report argument error: " + err.to_string())
      return 2
    }
  }
  let payload = @result.generate_report_from_request(request)
  println(payload.to_json().stringify())
  0
}
