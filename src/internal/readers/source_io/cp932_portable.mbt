///|
#cfg(not(target="native"))
fn decode_cp932_native(_payload : Bytes) -> Bytes {
  Bytes::new(0)
}
