///|
let md5_s : Array[Int] = [
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
  14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
]

///|
let md5_k : Array[UInt] = [
  0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
  0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193,
  0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d,
  0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
  0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
  0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
  0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244,
  0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
  0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
  0xeb86d391,
]

///|
fn md5_u32(x : UInt) -> UInt {
  UInt::land(x, 0xffff_ffff)
}

///|
fn rotl32(x : UInt, n : Int) -> UInt {
  md5_u32(UInt::lor(x << n, x >> (32 - n)))
}

///|
fn le_u32(bytes : @pdfio.MutableBytes, offset : Int) -> UInt {
  let b0 = @pdfio.bget(bytes, offset).reinterpret_as_uint()
  let b1 = @pdfio.bget(bytes, offset + 1).reinterpret_as_uint()
  let b2 = @pdfio.bget(bytes, offset + 2).reinterpret_as_uint()
  let b3 = @pdfio.bget(bytes, offset + 3).reinterpret_as_uint()
  UInt::lor(UInt::lor(b0, b1 << 8), UInt::lor(b2 << 16, b3 << 24))
}

///|
fn add_u32(a : UInt, b : UInt) -> UInt {
  md5_u32(UInt::add(a, b))
}

///|
fn md5_pad(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let len = @pdfio.bytes_size(data)
  let bit_len = UInt64::mul(UInt64::extend_uint(len.reinterpret_as_uint()), 8)
  let pad_len = (56 - (len + 1) % 64 + 64) % 64
  let total = len + 1 + pad_len + 8
  let out = @pdfio.mkbytes(total)
  let mut i = 0
  while i < len {
    @pdfio.bset(out, i, @pdfio.bget(data, i))
    i = i + 1
  }
  @pdfio.bset(out, len, 0x80)
  let mut j = 0
  while j < 8 {
    let shift = j * 8
    let v = (bit_len >> shift).to_int()
    @pdfio.bset(out, total - 8 + j, Int::land(v, 0xff))
    j = j + 1
  }
  out
}

///|
/// MD5 digest of bytes, returning 16 raw bytes.
pub fn PdfCryptPrimitives::md5(
  _self : PdfCryptPrimitives,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let padded = md5_pad(data)
  let mut a0 : UInt = 0x67452301
  let mut b0 : UInt = 0xefcdab89
  let mut c0 : UInt = 0x98badcfe
  let mut d0 : UInt = 0x10325476
  let mut offset = 0
  while offset < @pdfio.bytes_size(padded) {
    let m : Array[UInt] = Array::make(16, 0)
    let mut i = 0
    while i < 16 {
      m[i] = le_u32(padded, offset + i * 4)
      i = i + 1
    }
    let mut a = a0
    let mut b = b0
    let mut c = c0
    let mut d = d0
    let mut idx = 0
    while idx < 64 {
      let mut f : UInt = 0
      let mut g : Int = 0
      if idx < 16 {
        f = UInt::lor(UInt::land(b, c), UInt::land(UInt::lnot(b), d))
        g = idx
      } else if idx < 32 {
        f = UInt::lor(UInt::land(d, b), UInt::land(UInt::lnot(d), c))
        g = (5 * idx + 1) % 16
      } else if idx < 48 {
        f = UInt::lxor(UInt::lxor(b, c), d)
        g = (3 * idx + 5) % 16
      } else {
        f = UInt::lxor(c, UInt::lor(b, UInt::lnot(d)))
        g = 7 * idx % 16
      }
      let temp = d
      let sum = add_u32(add_u32(add_u32(a, f), md5_k[idx]), m[g])
      d = c
      c = b
      b = add_u32(b, rotl32(sum, md5_s[idx]))
      a = temp
      idx = idx + 1
    }
    a0 = add_u32(a0, a)
    b0 = add_u32(b0, b)
    c0 = add_u32(c0, c)
    d0 = add_u32(d0, d)
    offset = offset + 64
  }
  let out = @pdfio.mkbytes(16)
  let words = [a0, b0, c0, d0]
  let mut w = 0
  while w < 4 {
    let word = words[w]
    let mut i = 0
    while i < 4 {
      let byte_val = (word >> (i * 8)).reinterpret_as_int()
      @pdfio.bset(out, w * 4 + i, Int::land(byte_val, 0xff))
      i = i + 1
    }
    w = w + 1
  }
  out
}
