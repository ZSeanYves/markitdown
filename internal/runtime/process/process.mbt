///|
/// Terminate the current process with an explicit status code.
///
/// The official `moonbitlang/x/sys` package supplies the backend-specific
/// Native implementation. This façade keeps the project call site stable.
pub fn exit_process(code : Int32) -> Unit {
  @sys.exit(code)
}
