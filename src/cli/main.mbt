///|
/// Native CLI program entrypoint.
fn main {
  let status = run_cli_app(@env.args())
  if status != 0 {
    @process.exit_process(status)
  }
}
