///|
/// Padding bytes used by PDF encryption.
let paddings : Array[Int] = [
  0x28, 0xbf, 0x4e, 0x5e, 0x4e, 0x75, 0x8a, 0x41, 0x64, 0x00, 0x4e, 0x56, 0xff, 0xfa,
  0x01, 0x08, 0x2e, 0x2e, 0x00, 0xb6, 0xd0, 0x68, 0x3e, 0x80, 0x2f, 0x0c, 0xa9, 0xfe,
  0x64, 0x53, 0x69, 0x7a,
]

///|
fn bytes_of_int_arrays(values : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let mut total = 0
  for v in values {
    total = total + v.length()
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for v in values {
    for i in 0..<v.length() {
      @pdfio.bset(out, pos, v[i])
      pos = pos + 1
    }
  }
  out
}

///|
fn int_array_prefix(values : Array[Int], len : Int) -> Array[Int] {
  values[:len].to_array()
}

///|
fn bytes_prefix(values : @pdfio.MutableBytes, len : Int) -> @pdfio.MutableBytes {
  values[:len].to_array()
}

///|
fn array_equal(a : Array[Int], b : Array[Int]) -> Bool {
  a[:].equal(b[:])
}

///|
fn bytes_equal(a : @pdfio.MutableBytes, b : @pdfio.MutableBytes) -> Bool {
  a[:].equal(b[:])
}

///|
fn pad_password(password : Array[Int]) -> Array[Int] {
  let pw = Array::make(32, 0)
  let len = Int::min(password.length(), 32)
  for i in 0..<len {
    pw[i] = password[i]
  }
  if len < 32 {
    for j in len..<32 {
      pw[j] = paddings[j - len]
    }
  }
  pw
}

///|
fn mkkey(key : Array[Int], x : Int) -> Array[Int] {
  let out = key.copy()
  for k in 0..<out.length() {
    out[k] = out[k] ^ x
  }
  out
}

///|

///|
fn make_utf8(pw : String) -> String {
  let bytes = @pdfio.bytes_of_string(pw)
  if bytes.length() > 127 {
    @pdfio.string_of_bytes(bytes_prefix(bytes, 127))
  } else {
    pw
  }
}

///|
let zero_iv : String = @pdfio.string_of_bytes(@pdfio.mkbytes(16))

///|
let rand_state : Ref[@random.Rand] = Ref::new(@random.Rand::new())

///|
fn mksalt() -> String {
  let out = @pdfio.mkbytes(8)
  for i in 0..<8 {
    out[i] = rand_state.val.int(limit=256).to_byte()
  }
  @pdfio.string_of_bytes(out)
}

///|
fn mkfilekey() -> String {
  let out = @pdfio.mkbytes(32)
  for i in 0..<32 {
    out[i] = rand_state.val.int(limit=256).to_byte()
  }
  @pdfio.string_of_bytes(out)
}
