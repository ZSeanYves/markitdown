///|
/// Return the process arguments at the runtime boundary.
pub fn args() -> Array[String] {
  @env.args()
}

///|
/// Write one exact UTF-8 payload to stdout.
pub async fn write_stdout(message : String) -> Unit {
  @stdio.stdout.write(message)
}

///|
/// Write one exact UTF-8 payload to stderr.
pub async fn write_stderr(message : String) -> Unit {
  if message == "" {
    return
  }
  @stdio.stderr.write(message)
}
