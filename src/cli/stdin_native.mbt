///|
#cfg(target="native")
extern "C" fn cli_read_stdin_ffi(max_bytes : Int) -> Bytes = "markitdown_cli_read_stdin"

///|
fn cli_read_stdin(max_bytes : Int) -> Bytes {
  cli_read_stdin_ffi(max_bytes)
}
