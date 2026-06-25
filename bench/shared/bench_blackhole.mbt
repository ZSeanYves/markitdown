///|
pub fn keep_string(b : @bench.T, value : String) -> Unit {
  b.keep(value)
}

///|
pub fn keep_int(b : @bench.T, value : Int) -> Unit {
  b.keep(value)
}

///|
pub fn keep_bytes_len(b : @bench.T, bytes : Bytes) -> Unit {
  b.keep(bytes.length())
}
