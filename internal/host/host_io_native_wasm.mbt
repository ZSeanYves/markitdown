///|
#warnings("-unused_package")
/// Write one exact UTF-8 payload to stdout on the two supported CLI targets.
#cfg(any(target="native", target="wasm"))
pub async fn write_stdout(message : String) -> Unit {
  @stdio.stdout.write(message)
}

///|
/// Write one exact UTF-8 payload to stderr on the two supported CLI targets.
#cfg(any(target="native", target="wasm"))
pub async fn write_stderr(message : String) -> Unit {
  if message == "" {
    return
  }
  @stdio.stderr.write(message)
}
