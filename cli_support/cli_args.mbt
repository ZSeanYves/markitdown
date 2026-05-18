///|
/// Keep cli_support's public surface stable while sharing the single
/// implementation from cli_common.
pub fn normalize_cli_args(args : Array[String]) -> Array[String] {
  @clicom.normalize_cli_args(args)
}
