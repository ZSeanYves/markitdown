///|
/// Terminate the current native process with an explicit status code.
///
/// Keeping process control in this native-only package prevents executable
/// entrypoints from depending on the deprecated `moonbitlang/x/sys` shim.
pub extern "C" fn exit_process(code : Int) = "exit"
