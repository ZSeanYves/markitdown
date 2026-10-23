///|
#warnings("-struct_never_constructed")
pub struct CommandLimits {
  /// Resource ceilings for one external command invocation.
  timeout_ms : Int32
  max_stdout_bytes : Int32
  max_stderr_bytes : Int32
  termination_grace_ms : Int32
}

///|
#warnings("-struct_never_constructed")
pub struct CommandOutput {
  /// Captured command result after the child process has been reaped.
  exit_code : Int32
  signal : Int32
  stdout : String
  stderr : String
  timed_out : Bool
  stdout_limit_exceeded : Bool
  stderr_limit_exceeded : Bool
}

///|
pub fn default_command_limits() -> CommandLimits {
  {
    timeout_ms: 300000,
    max_stdout_bytes: 8 * 1024 * 1024,
    max_stderr_bytes: 8 * 1024 * 1024,
    termination_grace_ms: 2000,
  }
}

///|
pub fn make_command_limits(
  timeout_ms~ : Int32 = 300000,
  max_stdout_bytes~ : Int32 = 8 * 1024 * 1024,
  max_stderr_bytes~ : Int32 = 8 * 1024 * 1024,
  termination_grace_ms~ : Int32 = 2000,
) -> CommandLimits {
  { timeout_ms, max_stdout_bytes, max_stderr_bytes, termination_grace_ms, }
}
