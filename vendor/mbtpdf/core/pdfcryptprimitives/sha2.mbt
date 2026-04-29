///|
let sha256_k : Array[UInt] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
let sha512_k : Array[UInt64] = [
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc,
  0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118,
  0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694,
  0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
  0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4,
  0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x06ca6351e003826f, 0x142929670a0e6e70,
  0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
  0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30,
  0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8,
  0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3,
  0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b,
  0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178,
  0x06f067aa72176fba, 0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c,
  0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817,
]

///|
let u32_mask : UInt = 0xffff_ffff

///|
fn u32(x : UInt) -> UInt {
  UInt::land(x, u32_mask)
}

///|
fn rotr32(x : UInt, n : Int) -> UInt {
  u32(UInt::lor(x >> n, x << (32 - n)))
}

///|
fn rotr64(x : UInt64, n : Int) -> UInt64 {
  UInt64::lor(x >> n, x << (64 - n))
}

///|
fn be_u32(bytes : @pdfio.MutableBytes, offset : Int) -> UInt {
  let b0 = @pdfio.bget(bytes, offset).reinterpret_as_uint()
  let b1 = @pdfio.bget(bytes, offset + 1).reinterpret_as_uint()
  let b2 = @pdfio.bget(bytes, offset + 2).reinterpret_as_uint()
  let b3 = @pdfio.bget(bytes, offset + 3).reinterpret_as_uint()
  UInt::lor(UInt::lor(b0 << 24, b1 << 16), UInt::lor(b2 << 8, b3))
}

///|
fn be_u64(bytes : @pdfio.MutableBytes, offset : Int) -> UInt64 {
  let mut out : UInt64 = 0
  let mut i = 0
  while i < 8 {
    let v = @pdfio.bget(bytes, offset + i).reinterpret_as_uint()
    out = UInt64::lor(out << 8, UInt64::extend_uint(v))
    i = i + 1
  }
  out
}

///|
fn sha256_pad(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
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
    let shift = (7 - j) * 8
    let v = (bit_len >> shift).to_int()
    @pdfio.bset(out, total - 8 + j, Int::land(v, 0xff))
    j = j + 1
  }
  out
}

///|
fn sha512_pad(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let len = @pdfio.bytes_size(data)
  let bit_len = UInt64::mul(UInt64::extend_uint(len.reinterpret_as_uint()), 8)
  let pad_len = (112 - (len + 1) % 128 + 128) % 128
  let total = len + 1 + pad_len + 16
  let out = @pdfio.mkbytes(total)
  let mut i = 0
  while i < len {
    @pdfio.bset(out, i, @pdfio.bget(data, i))
    i = i + 1
  }
  @pdfio.bset(out, len, 0x80)
  let mut j = 0
  while j < 16 {
    let shift = (15 - j) * 8
    let value = if j < 8 { 0 } else { (bit_len >> shift).to_int() }
    @pdfio.bset(out, total - 16 + j, Int::land(value, 0xff))
    j = j + 1
  }
  out
}

///|
fn sha256_bytes(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let padded = sha256_pad(data)
  let mut h0 : UInt = 0x6a09e667
  let mut h1 : UInt = 0xbb67ae85
  let mut h2 : UInt = 0x3c6ef372
  let mut h3 : UInt = 0xa54ff53a
  let mut h4 : UInt = 0x510e527f
  let mut h5 : UInt = 0x9b05688c
  let mut h6 : UInt = 0x1f83d9ab
  let mut h7 : UInt = 0x5be0cd19
  let mut offset = 0
  while offset < @pdfio.bytes_size(padded) {
    let w : Array[UInt] = Array::make(64, 0)
    let mut i = 0
    while i < 16 {
      w[i] = be_u32(padded, offset + i * 4)
      i = i + 1
    }
    while i < 64 {
      let s0 = u32(
        UInt::lxor(
          UInt::lxor(rotr32(w[i - 15], 7), rotr32(w[i - 15], 18)),
          w[i - 15] >> 3,
        ),
      )
      let s1 = u32(
        UInt::lxor(
          UInt::lxor(rotr32(w[i - 2], 17), rotr32(w[i - 2], 19)),
          w[i - 2] >> 10,
        ),
      )
      w[i] = u32(UInt::add(UInt::add(UInt::add(w[i - 16], s0), w[i - 7]), s1))
      i = i + 1
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    let mut t = 0
    while t < 64 {
      let s1 = u32(
        UInt::lxor(UInt::lxor(rotr32(e, 6), rotr32(e, 11)), rotr32(e, 25)),
      )
      let ch = u32(UInt::lxor(UInt::land(e, f), UInt::land(UInt::lnot(e), g)))
      let temp1 = u32(
        UInt::add(UInt::add(UInt::add(UInt::add(h, s1), ch), sha256_k[t]), w[t]),
      )
      let s0 = u32(
        UInt::lxor(UInt::lxor(rotr32(a, 2), rotr32(a, 13)), rotr32(a, 22)),
      )
      let maj = u32(
        UInt::lxor(
          UInt::lxor(UInt::land(a, b), UInt::land(a, c)),
          UInt::land(b, c),
        ),
      )
      let temp2 = u32(UInt::add(s0, maj))
      h = g
      g = f
      f = e
      e = u32(UInt::add(d, temp1))
      d = c
      c = b
      b = a
      a = u32(UInt::add(temp1, temp2))
      t = t + 1
    }
    h0 = u32(UInt::add(h0, a))
    h1 = u32(UInt::add(h1, b))
    h2 = u32(UInt::add(h2, c))
    h3 = u32(UInt::add(h3, d))
    h4 = u32(UInt::add(h4, e))
    h5 = u32(UInt::add(h5, f))
    h6 = u32(UInt::add(h6, g))
    h7 = u32(UInt::add(h7, h))
    offset = offset + 64
  }
  let out = @pdfio.mkbytes(32)
  let words = [h0, h1, h2, h3, h4, h5, h6, h7]
  let mut w = 0
  while w < words.length() {
    let word = words[w]
    let mut i = 0
    while i < 4 {
      let shift = (3 - i) * 8
      let v = (word >> shift).reinterpret_as_int()
      @pdfio.bset(out, w * 4 + i, Int::land(v, 0xff))
      i = i + 1
    }
    w = w + 1
  }
  out
}

///|
fn sha512_bytes(
  data : @pdfio.MutableBytes,
  initial : Array[UInt64],
  out_len : Int,
) -> @pdfio.MutableBytes {
  let padded = sha512_pad(data)
  let h = initial.copy()
  let mut offset = 0
  while offset < @pdfio.bytes_size(padded) {
    let w : Array[UInt64] = Array::make(80, 0)
    let mut i = 0
    while i < 16 {
      w[i] = be_u64(padded, offset + i * 8)
      i = i + 1
    }
    while i < 80 {
      let s0 = UInt64::lxor(
        UInt64::lxor(rotr64(w[i - 15], 1), rotr64(w[i - 15], 8)),
        w[i - 15] >> 7,
      )
      let s1 = UInt64::lxor(
        UInt64::lxor(rotr64(w[i - 2], 19), rotr64(w[i - 2], 61)),
        w[i - 2] >> 6,
      )
      w[i] = UInt64::add(UInt64::add(UInt64::add(w[i - 16], s0), w[i - 7]), s1)
      i = i + 1
    }
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]
    let mut t = 0
    while t < 80 {
      let s1 = UInt64::lxor(
        UInt64::lxor(rotr64(e, 14), rotr64(e, 18)),
        rotr64(e, 41),
      )
      let ch = UInt64::lxor(
        UInt64::land(e, f),
        UInt64::land(UInt64::lnot(e), g),
      )
      let temp1 = UInt64::add(
        UInt64::add(UInt64::add(UInt64::add(hh, s1), ch), sha512_k[t]),
        w[t],
      )
      let s0 = UInt64::lxor(
        UInt64::lxor(rotr64(a, 28), rotr64(a, 34)),
        rotr64(a, 39),
      )
      let maj = UInt64::lxor(
        UInt64::lxor(UInt64::land(a, b), UInt64::land(a, c)),
        UInt64::land(b, c),
      )
      let temp2 = UInt64::add(s0, maj)
      hh = g
      g = f
      f = e
      e = UInt64::add(d, temp1)
      d = c
      c = b
      b = a
      a = UInt64::add(temp1, temp2)
      t = t + 1
    }
    h[0] = UInt64::add(h[0], a)
    h[1] = UInt64::add(h[1], b)
    h[2] = UInt64::add(h[2], c)
    h[3] = UInt64::add(h[3], d)
    h[4] = UInt64::add(h[4], e)
    h[5] = UInt64::add(h[5], f)
    h[6] = UInt64::add(h[6], g)
    h[7] = UInt64::add(h[7], hh)
    offset = offset + 128
  }
  let out = @pdfio.mkbytes(out_len)
  let words = h
  let mut w = 0
  while w * 8 < out_len {
    let word = words[w]
    let mut i = 0
    while i < 8 && w * 8 + i < out_len {
      let shift = (7 - i) * 8
      let v = (word >> shift).to_int()
      @pdfio.bset(out, w * 8 + i, Int::land(v, 0xff))
      i = i + 1
    }
    w = w + 1
  }
  out
}

///|
/// SHA-256 digest of the input stream.
pub fn PdfCryptPrimitives::sha256(
  _self : PdfCryptPrimitives,
  input : @pdfio.Input,
) -> String raise {
  let bytes = input.bytes_of_input(0, input.in_channel_length)
  @pdfio.string_of_bytes(sha256_bytes(bytes))
}

///|
/// SHA-384 digest of the input stream.
pub fn PdfCryptPrimitives::sha384(
  _self : PdfCryptPrimitives,
  input : @pdfio.Input,
) -> String raise {
  let bytes = input.bytes_of_input(0, input.in_channel_length)
  let initial : Array[UInt64] = [
    0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939,
    0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4,
  ]
  @pdfio.string_of_bytes(sha512_bytes(bytes, initial, 48))
}

///|
/// SHA-512 digest of the input stream.
pub fn PdfCryptPrimitives::sha512(
  _self : PdfCryptPrimitives,
  input : @pdfio.Input,
) -> String raise {
  let bytes = input.bytes_of_input(0, input.in_channel_length)
  let initial : Array[UInt64] = [
    0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
    0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
  ]
  @pdfio.string_of_bytes(sha512_bytes(bytes, initial, 64))
}
