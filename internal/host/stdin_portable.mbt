///|
#cfg(not(target="native"))
pub async fn read_stdin(_max_bytes : Int) -> Bytes {
  Bytes::new(0)
}
