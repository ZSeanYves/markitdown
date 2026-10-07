///|
/// Logical root executable used by `moonx ZSeanYves/markitdown@<version>`.
/// The CLI package owns parsing and execution; this file only supplies the
/// package-level process entrypoint.
fn main {
  let status = @cli.run_cli_app(@env.args())
  if status != 0 {
    @process.exit_process(status)
  }
}
