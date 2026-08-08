///|
#cfg(not(target="native"))
fn cli_read_stdin(_max_bytes : Int) -> Bytes {
  Bytes::new(0)
}
