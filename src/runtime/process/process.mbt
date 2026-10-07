///|
/// Terminate the current process with an explicit status code.
///
/// The official `moonbitlang/x/sys` package supplies the backend-specific
/// implementation. This façade keeps the project call site stable while
/// allowing the runtime package to type-check on Wasm.
pub fn exit_process(code : Int) -> Unit {
  @sys.exit(code)
}
