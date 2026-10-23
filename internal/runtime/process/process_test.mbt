///|
test "process exit boundary is available without invoking it" {
  let exit_fn : (Int32) -> Unit = @process.exit_process
  ignore(exit_fn)
}
