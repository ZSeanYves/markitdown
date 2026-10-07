///|
#cfg(target="native")
extern "C" fn read_stdin_ffi(max_bytes : Int) -> Bytes = "markitdown_cli_read_stdin"

///|
pub async fn read_stdin(max_bytes : Int) -> Bytes {
  read_stdin_ffi(max_bytes)
}
