///|
#cfg(not(target="native"))
pub fn read_stdin(_max_bytes : Int) -> Bytes {
  Bytes::new(0)
}
