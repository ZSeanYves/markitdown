///|
/// Logical root executable used by `moonx ZSeanYves/markitdown@<version>`.
/// The CLI package owns parsing and execution; this file only supplies the
/// package-level process entrypoint.
async fn main {
  let status = @cli.run_cli_app(@host.args())
  if status != 0 {
    @process.exit_process(status)
  }
}
