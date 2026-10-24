///|
extern "C" fn read_stdin_ffi(max_bytes : Int32) -> Bytes = "markitdown_cli_read_stdin"

///|
pub fn read_stdin(max_bytes : Int32) -> Bytes {
  read_stdin_ffi(max_bytes)
}
