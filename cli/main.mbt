///|
/// Native CLI program entrypoint.
fn main {
  let status = run_cli_app(@sys.get_cli_args())
  if status != 0 {
    @sys.exit(status)
  }
}
