///|
fn main {
  let status = run_bench_cli(@sys.get_cli_args())
  if status != 0 {
    @sys.exit(status)
  }
}

///|
pub fn run_bench_cli(raw_args : Array[String]) -> Int {
  let runner = @command.detect_runner_context(raw_args)
  run_bench_cli_entry(raw_args, runner)
}
