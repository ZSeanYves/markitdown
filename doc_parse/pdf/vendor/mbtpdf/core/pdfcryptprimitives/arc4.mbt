///|
fn swap(s : Array[Int], i : Int, j : Int) -> Unit {
  let tmp = s[i]
  s[i] = s[j]
  s[j] = tmp
}

///|
fn ksa(s : Array[Int], key : Array[Int]) -> Unit {
  let keylength = key.length()
  for i in 0..<256 {
    s[i] = i
  }
  let mut j = 0
  for i in 0..<256 {
    j = (j + s[i] + key[i % keylength]) % 256
    swap(s, i, j)
  }
}

///|
fn prga(s : Array[Int], pi : Ref[Int], pj : Ref[Int]) -> Int {
  pi.val = (pi.val + 1) % 256
  pj.val = (pj.val + s[pi.val]) % 256
  swap(s, pi.val, pj.val)
  s[(s[pi.val] + s[pj.val]) % 256]
}

///|
/// ARC4 encryption/decryption given a key and some data.
/// The same function performs encryption and decryption.
pub fn PdfCryptPrimitives::crypt(
  _self : PdfCryptPrimitives,
  key : Array[Int],
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  if key.length() == 0 {
    return @pdfio.copybytes(data)
  }
  let s = Array::make(256, 0)
  let pi : Ref[Int] = Ref::new(0)
  let pj : Ref[Int] = Ref::new(0)
  let out = @pdfio.mkbytes(@pdfio.bytes_size(data))
  ksa(s, key)
  let mut x = 0
  while x < @pdfio.bytes_size(data) {
    let v = @pdfio.bget(data, x)
    let k = prga(s, pi, pj)
    @pdfio.bset(out, x, v ^ k)
    x = x + 1
  }
  out
}
