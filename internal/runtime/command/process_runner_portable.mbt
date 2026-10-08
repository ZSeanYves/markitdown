/// External process execution is intentionally unavailable on Wasm. Returning
/// an explicit error preserves the product's fail-closed capability boundary;
/// it never falls back to an unbounded buffer or a fake successful result.

///|
pub fn run_resolved_command(
  _command : ResolvedCommand,
  _args : Array[String],
  limits? : CommandLimits = default_command_limits(),
) -> Result[CommandOutput, String] {
  if limits.timeout_ms <= 0 ||
    limits.max_stdout_bytes < 0 ||
    limits.max_stderr_bytes < 0 ||
    limits.termination_grace_ms < 0 {
    return Err(
      "external command limits must be non-negative and timeout positive",
    )
  }
  Err("external command execution is unsupported on wasm")
}

///|
pub fn run_resolved_command_async(
  _command : ResolvedCommand,
  _args : Array[String],
  limits? : CommandLimits = default_command_limits(),
) -> Result[CommandOutput, String] {
  run_resolved_command(_command, _args, limits~)
}
