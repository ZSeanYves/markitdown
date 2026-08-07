///|
fn main {
  let status = run_bench_cli(@env.args())
  if status != 0 {
    @process.exit_process(status)
  }
}

///|
fn run_bench_cli(raw_args : Array[String]) -> Int {
  let runner = detect_runner_context(raw_args)
  run_bench_cli_entry(raw_args, runner)
}
