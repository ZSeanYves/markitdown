///|
let sbox : Array[Int] = [
  0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7,
  0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf,
  0x9c, 0xa4, 0x72, 0xc0, 0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5,
  0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15, 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a,
  0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e,
  0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed,
  0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf, 0xd0, 0xef,
  0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
  0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff,
  0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d,
  0x64, 0x5d, 0x19, 0x73, 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee,
  0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c,
  0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5,
  0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08, 0xba, 0x78, 0x25, 0x2e,
  0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e,
  0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
  0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55,
  0x28, 0xdf, 0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f,
  0xb0, 0x54, 0xbb, 0x16,
]

///|
let inv_sbox : Array[Int] = [
  0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3,
  0xd7, 0xfb, 0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44,
  0xc4, 0xde, 0xe9, 0xcb, 0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c,
  0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e, 0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2,
  0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25, 0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68,
  0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92, 0x6c, 0x70, 0x48, 0x50,
  0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84, 0x90, 0xd8,
  0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
  0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13,
  0x8a, 0x6b, 0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce,
  0xf0, 0xb4, 0xe6, 0x73, 0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9,
  0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e, 0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89,
  0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b, 0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2,
  0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4, 0x1f, 0xdd, 0xa8, 0x33,
  0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f, 0x60, 0x51,
  0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
  0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53,
  0x99, 0x61, 0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63,
  0x55, 0x21, 0x0c, 0x7d,
]

///|
let rcon : Array[Int] = [
  0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab,
  0x4d,
]

///|
fn byte(x : Int) -> Int {
  Int::land(x, 0xff)
}

///|
fn gmul(a0 : Int, b0 : Int) -> Int {
  let mut a = a0
  let mut b = b0
  let mut p = 0
  let mut i = 0
  while i < 8 {
    if Int::land(b, 1) != 0 {
      p = p ^ a
    }
    let high = Int::land(a, 0x80)
    a = byte(a << 1)
    if high != 0 {
      a = a ^ 0x1b
    }
    b = b >> 1
    i = i + 1
  }
  byte(p)
}

///|
fn sub_bytes(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  for i in 0..<16 {
    out[i] = sbox[state[i]]
  }
  out
}

///|
fn inv_sub_bytes(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  for i in 0..<16 {
    out[i] = inv_sbox[state[i]]
  }
  out
}

///|
fn shift_rows(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  let mut r = 0
  while r < 4 {
    let mut c = 0
    while c < 4 {
      out[r + 4 * c] = state[r + 4 * ((c + r) % 4)]
      c = c + 1
    }
    r = r + 1
  }
  out
}

///|
fn inv_shift_rows(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  let mut r = 0
  while r < 4 {
    let mut c = 0
    while c < 4 {
      out[r + 4 * c] = state[r + 4 * ((c - r + 4) % 4)]
      c = c + 1
    }
    r = r + 1
  }
  out
}

///|
fn mix_columns(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  let mut c = 0
  while c < 4 {
    let a0 = state[0 + 4 * c]
    let a1 = state[1 + 4 * c]
    let a2 = state[2 + 4 * c]
    let a3 = state[3 + 4 * c]
    out[0 + 4 * c] = byte(gmul(a0, 2) ^ gmul(a1, 3) ^ a2 ^ a3)
    out[1 + 4 * c] = byte(a0 ^ gmul(a1, 2) ^ gmul(a2, 3) ^ a3)
    out[2 + 4 * c] = byte(a0 ^ a1 ^ gmul(a2, 2) ^ gmul(a3, 3))
    out[3 + 4 * c] = byte(gmul(a0, 3) ^ a1 ^ a2 ^ gmul(a3, 2))
    c = c + 1
  }
  out
}

///|
fn inv_mix_columns(state : Array[Int]) -> Array[Int] {
  let out = Array::make(16, 0)
  let mut c = 0
  while c < 4 {
    let a0 = state[0 + 4 * c]
    let a1 = state[1 + 4 * c]
    let a2 = state[2 + 4 * c]
    let a3 = state[3 + 4 * c]
    out[0 + 4 * c] = byte(
      gmul(a0, 14) ^ gmul(a1, 11) ^ gmul(a2, 13) ^ gmul(a3, 9),
    )
    out[1 + 4 * c] = byte(
      gmul(a0, 9) ^ gmul(a1, 14) ^ gmul(a2, 11) ^ gmul(a3, 13),
    )
    out[2 + 4 * c] = byte(
      gmul(a0, 13) ^ gmul(a1, 9) ^ gmul(a2, 14) ^ gmul(a3, 11),
    )
    out[3 + 4 * c] = byte(
      gmul(a0, 11) ^ gmul(a1, 13) ^ gmul(a2, 9) ^ gmul(a3, 14),
    )
    c = c + 1
  }
  out
}

///|
fn add_round_key(
  state : Array[Int],
  key_schedule : Array[Int],
  round : Int,
) -> Array[Int] {
  let out = Array::make(16, 0)
  let offset = round * 16
  for i in 0..<16 {
    out[i] = byte(state[i] ^ key_schedule[offset + i])
  }
  out
}

///|
fn rot_word(word : Array[Int]) -> Array[Int] {
  [word[1], word[2], word[3], word[0]]
}

///|
fn sub_word(word : Array[Int]) -> Array[Int] {
  [sbox[word[0]], sbox[word[1]], sbox[word[2]], sbox[word[3]]]
}

///|
fn expand_key(key : Array[Int], nk : Int) -> (Array[Int], Int) {
  let nb = 4
  let nr = nk + 6
  let total_words = nb * (nr + 1)
  let key_bytes = Array::make(nk * 4, 0)
  let limit = Int::min(key.length(), nk * 4)
  let mut k = 0
  while k < limit {
    key_bytes[k] = key[k]
    k = k + 1
  }
  let w = Array::make(total_words * 4, 0)
  let mut i = 0
  while i < nk * 4 {
    w[i] = key_bytes[i]
    i = i + 1
  }
  let mut word_index = nk
  while word_index < total_words {
    let base = (word_index - 1) * 4
    let mut temp = [w[base], w[base + 1], w[base + 2], w[base + 3]]
    if word_index % nk == 0 {
      temp = sub_word(rot_word(temp))
      temp[0] = byte(temp[0] ^ rcon[word_index / nk])
    } else if nk > 6 && word_index % nk == 4 {
      temp = sub_word(temp)
    }
    let prev = (word_index - nk) * 4
    let out = word_index * 4
    for j = 0; j < 4; j = j + 1 {
      w[out + j] = byte(w[prev + j] ^ temp[j])
    }
    word_index = word_index + 1
  }
  (w, nr)
}

///|
fn aes_encrypt_block(
  key_schedule : Array[Int],
  nr : Int,
  block : Array[Int],
) -> Array[Int] {
  let mut state = add_round_key(block, key_schedule, 0)
  let mut round = 1
  while round < nr {
    state = sub_bytes(state)
    state = shift_rows(state)
    state = mix_columns(state)
    state = add_round_key(state, key_schedule, round)
    round = round + 1
  }
  state = sub_bytes(state)
  state = shift_rows(state)
  state = add_round_key(state, key_schedule, nr)
  state
}

///|
fn aes_decrypt_block(
  key_schedule : Array[Int],
  nr : Int,
  block : Array[Int],
) -> Array[Int] {
  let mut state = add_round_key(block, key_schedule, nr)
  let mut round = nr - 1
  while round > 0 {
    state = inv_shift_rows(state)
    state = inv_sub_bytes(state)
    state = add_round_key(state, key_schedule, round)
    state = inv_mix_columns(state)
    round = round - 1
  }
  state = inv_shift_rows(state)
  state = inv_sub_bytes(state)
  state = add_round_key(state, key_schedule, 0)
  state
}

///|
fn get_padding(data : @pdfio.MutableBytes) -> Int? {
  let l = @pdfio.bytes_size(data)
  if l < 16 {
    None
  } else {
    let potential = @pdfio.bget(data, l - 1)
    if potential < 1 || potential > 0x10 {
      None
    } else {
      let mut i = l - potential
      let mut ok = true
      while ok && i < l {
        if @pdfio.bget(data, i) != potential {
          ok = false
        }
        i = i + 1
      }
      if ok {
        Some(potential)
      } else {
        None
      }
    }
  }
}

///|
fn cutshort(data : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let l = @pdfio.bytes_size(data)
  if l == 0 || l < 16 {
    data
  } else {
    match get_padding(data) {
      Some(padding) => {
        let out = @pdfio.mkbytes(l - padding)
        let mut i = 0
        while i < @pdfio.bytes_size(out) {
          @pdfio.bset(out, i, @pdfio.bget(data, i))
          i = i + 1
        }
        out
      }
      None => data
    }
  }
}

///|
fn get_blocks(data : @pdfio.MutableBytes) -> Array[Array[Int]] {
  let l = @pdfio.bytes_size(data)
  let blocks = Array::new()
  let full = if l < 16 { 0 } else { l / 16 }
  let mut b = 0
  while b < full {
    let block = Array::make(16, 0)
    let mut i = 0
    while i < 16 {
      block[i] = @pdfio.bget(data, b * 16 + i)
      i = i + 1
    }
    blocks.push(block)
    b = b + 1
  }
  let overflow = l % 16
  let last = Array::make(16, 0)
  let start = l - overflow
  let mut i = 0
  while i < overflow {
    last[i] = @pdfio.bget(data, start + i)
    i = i + 1
  }
  let pad = 16 - overflow
  let mut j = overflow
  while j < 16 {
    last[j] = pad
    j = j + 1
  }
  blocks.push(last)
  blocks
}

///|
fn bytes_of_blocks(blocks : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(blocks.length() * 16)
  let mut p = 0
  for block in blocks {
    let mut i = 0
    while i < 16 {
      @pdfio.bset(out, p, block[i])
      p = p + 1
      i = i + 1
    }
  }
  out
}

///|
let rand_state : Ref[@random.Rand] = Ref::new(@random.Rand::new())

///|
fn mkiv() -> Array[Int] {
  let out = Array::make(16, 0)
  let mut i = 0
  while i < 16 {
    out[i] = rand_state.val.int(limit=256)
    i = i + 1
  }
  out
}

///|
/// [aes_decrypt_data nk key data] decrypts AES data for the given key length,
/// key, and data. If [remove_padding] is true, padding is removed.
pub fn PdfCryptPrimitives::aes_decrypt_data(
  _self : PdfCryptPrimitives,
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
  remove_padding? : Bool = true,
) -> @pdfio.MutableBytes {
  let (key_schedule, nr) = expand_key(key, nk)
  let len = @pdfio.bytes_size(data)
  if len <= 16 {
    @pdfio.mkbytes(0)
  } else {
    let output = @pdfio.mkbytes(len - 16)
    let prev = Array::make(16, 0)
    let mut i = 0
    while i < 16 {
      prev[i] = @pdfio.bget(data, i)
      i = i + 1
    }
    let mut pos = 16
    while pos < len {
      let block = Array::make(16, 0)
      let mut j = 0
      while j < 16 {
        block[j] = @pdfio.bget(data, pos + j)
        j = j + 1
      }
      let plain = aes_decrypt_block(key_schedule, nr, block)
      let mut k = 0
      while k < 16 {
        @pdfio.bset(output, pos - 16 + k, byte(plain[k] ^ prev[k]))
        prev[k] = block[k]
        k = k + 1
      }
      pos = pos + 16
    }
    if remove_padding {
      cutshort(output)
    } else {
      output
    }
  }
}

///|
/// As [aes_decrypt_data] but in ECB mode.
pub fn PdfCryptPrimitives::aes_decrypt_data_ecb(
  _self : PdfCryptPrimitives,
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
  remove_padding? : Bool = true,
) -> @pdfio.MutableBytes {
  let (key_schedule, nr) = expand_key(key, nk)
  let size = @pdfio.bytes_size(data)
  if size == 0 {
    @pdfio.mkbytes(0)
  } else {
    let output = @pdfio.mkbytes(size)
    let mut pos = 0
    while pos < size {
      let block = Array::make(16, 0)
      let mut j = 0
      while j < 16 {
        block[j] = @pdfio.bget(data, pos + j)
        j = j + 1
      }
      let plain = aes_decrypt_block(key_schedule, nr, block)
      let mut k = 0
      while k < 16 {
        @pdfio.bset(output, pos + k, plain[k])
        k = k + 1
      }
      pos = pos + 16
    }
    if remove_padding {
      cutshort(output)
    } else {
      output
    }
  }
}

///|
/// [aes_encrypt_data nk key data] encrypts with AES (CBC), returning IV+data.
pub fn PdfCryptPrimitives::aes_encrypt_data(
  _self : PdfCryptPrimitives,
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
  firstblock? : Array[Int],
) -> @pdfio.MutableBytes {
  let (key_schedule, nr) = expand_key(key, nk)
  let iv = match firstblock {
    Some(block) => block
    None => mkiv()
  }
  let mut prev = iv
  let outblocks = Array::new()
  let blocks = get_blocks(data)
  for block in blocks {
    let xored = Array::make(16, 0)
    let mut i = 0
    while i < 16 {
      xored[i] = byte(block[i] ^ prev[i])
      i = i + 1
    }
    let cipher = aes_encrypt_block(key_schedule, nr, xored)
    outblocks.push(cipher)
    prev = cipher
  }
  let all = Array::new()
  all.push(iv)
  all.append(outblocks[:])
  bytes_of_blocks(all)
}

///|
/// [aes_encrypt_data_ecb nk key data] encrypts data in ECB mode.
pub fn PdfCryptPrimitives::aes_encrypt_data_ecb(
  _self : PdfCryptPrimitives,
  nk : Int,
  key : Array[Int],
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let (key_schedule, nr) = expand_key(key, nk)
  let size = @pdfio.bytes_size(data)
  if size == 0 {
    @pdfio.mkbytes(0)
  } else {
    let output = @pdfio.mkbytes(size)
    let mut pos = 0
    while pos < size {
      let block = Array::make(16, 0)
      let mut j = 0
      while j < 16 {
        block[j] = @pdfio.bget(data, pos + j)
        j = j + 1
      }
      let cipher = aes_encrypt_block(key_schedule, nr, block)
      let mut k = 0
      while k < 16 {
        @pdfio.bset(output, pos + k, cipher[k])
        k = k + 1
      }
      pos = pos + 16
    }
    output
  }
}
