///|
/// Raised on an error in either compression or decompression.
pub suberror FlateError {
  Error(String, String)
}

///|
pub struct PdfFlate {
  unit : Unit
}

///|
pub fn PdfFlate::new() -> PdfFlate {
  { unit: () }
}

///|
priv struct BitReader {
  data : @pdfio.MutableBytes
  mut byte_pos : Int
  mut bit_pos : Int
}

///|
fn BitReader::read_bit(self : BitReader) -> Int raise FlateError {
  if self.byte_pos >= self.data.length() {
    raise FlateError::Error("uncompress", "unexpected end of input")
  }
  let byte = self.data[self.byte_pos].to_int()
  let bit = (byte >> self.bit_pos) & 1
  self.bit_pos = self.bit_pos + 1
  if self.bit_pos == 8 {
    self.bit_pos = 0
    self.byte_pos = self.byte_pos + 1
  }
  bit
}

///|
fn BitReader::read_bits(self : BitReader, count : Int) -> Int raise FlateError {
  let mut value = 0
  for i in 0..<count {
    let bit = self.read_bit()
    value = value | (bit << i)
  }
  value
}

///|
fn BitReader::align_byte(self : BitReader) -> Unit {
  if self.bit_pos != 0 {
    self.bit_pos = 0
    self.byte_pos = self.byte_pos + 1
  }
}

///|
fn BitReader::read_u16_le(self : BitReader) -> Int raise FlateError {
  let lo = self.read_bits(8)
  let hi = self.read_bits(8)
  lo | (hi << 8)
}

///|
priv struct Huffman {
  max_bits : Int
  table : Array[Map[Int, Int]]
}

///|
fn reverse_bits(code : Int, length : Int) -> Int {
  let mut rev = 0
  for i in 0..<length {
    let bit = (code >> i) & 1
    rev = (rev << 1) | bit
  }
  rev
}

///|
fn build_huffman(lengths : Array[Int]) -> Huffman {
  let mut max_len = 0
  for len in lengths {
    if len > max_len {
      max_len = len
    }
  }
  let count = Array::make(max_len + 1, 0)
  for len in lengths {
    if len > 0 {
      count[len] = count[len] + 1
    }
  }
  let next = Array::make(max_len + 1, 0)
  let mut code = 0
  for bits = 1; bits <= max_len; bits = bits + 1 {
    code = (code + count[bits - 1]) << 1
    next[bits] = code
  }
  let table = Array::makei(max_len + 1, _i => Map::new())
  for i in 0..<lengths.length() {
    let len = lengths[i]
    if len > 0 {
      let code_val = next[len]
      next[len] = code_val + 1
      let rev = reverse_bits(code_val, len)
      table[len].set(rev, i)
    }
  }
  { max_bits: max_len, table }
}

///|
fn decode_symbol(reader : BitReader, huff : Huffman) -> Int raise FlateError {
  let mut code = 0
  for len = 1; len <= huff.max_bits; len = len + 1 {
    let bit = reader.read_bit()
    code = code | (bit << (len - 1))
    match huff.table[len].get(code) {
      Some(sym) => return sym
      None => ()
    }
  }
  raise FlateError::Error("uncompress", "invalid huffman code")
}

///|
fn fixed_literal_lengths() -> Array[Int] {
  let lengths = Array::make(288, 0)
  for i in 0..<=143 {
    lengths[i] = 8
  }
  for i in 144..<=255 {
    lengths[i] = 9
  }
  for i in 256..<=279 {
    lengths[i] = 7
  }
  for i in 280..<=287 {
    lengths[i] = 8
  }
  lengths
}

///|
fn fixed_distance_lengths() -> Array[Int] {
  Array::make(32, 5)
}

///|
let fixed_literal_huffman : Huffman = build_huffman(fixed_literal_lengths())

///|
let fixed_distance_huffman : Huffman = build_huffman(fixed_distance_lengths())

///|
let length_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let dist_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let dist_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
fn copy_from_output(
  out : @pdfio.MutableBytes,
  distance : Int,
  length : Int,
) -> Unit raise FlateError {
  if distance <= 0 {
    raise FlateError::Error("uncompress", "invalid distance")
  }
  for _ in 0..<length {
    let src = out.length() - distance
    if src < 0 {
      raise FlateError::Error("uncompress", "distance beyond output")
    }
    out.push(out[src])
  }
}

///|
fn inflate_stored(
  reader : BitReader,
  out : @pdfio.MutableBytes,
) -> Unit raise FlateError {
  reader.align_byte()
  let len = reader.read_u16_le()
  let nlen = reader.read_u16_le()
  if ((len ^ 0xFFFF) & 0xFFFF) != nlen {
    raise FlateError::Error("uncompress", "stored block length mismatch")
  }
  for _ in 0..<len {
    let b = reader.read_bits(8)
    out.push(b.to_byte())
  }
}

///|
fn inflate_fixed(
  reader : BitReader,
  out : @pdfio.MutableBytes,
) -> Unit raise FlateError {
  fn decode_loop(
    reader : BitReader,
    out : @pdfio.MutableBytes,
  ) -> Unit raise FlateError {
    let symbol = decode_symbol(reader, fixed_literal_huffman)
    if symbol < 256 {
      out.push(symbol.to_byte())
      decode_loop(reader, out)
    } else if symbol == 256 {
      ()
    } else if symbol <= 285 {
      let index = symbol - 257
      let base = length_base[index]
      let extra = length_extra[index]
      let length = base + (if extra > 0 { reader.read_bits(extra) } else { 0 })
      let dist_symbol = decode_symbol(reader, fixed_distance_huffman)
      if dist_symbol < 0 || dist_symbol >= dist_base.length() {
        raise FlateError::Error("uncompress", "invalid distance symbol")
      }
      let dist = dist_base[dist_symbol] +
        (if dist_extra[dist_symbol] > 0 {
          reader.read_bits(dist_extra[dist_symbol])
        } else {
          0
        })
      copy_from_output(out, dist, length)
      decode_loop(reader, out)
    } else {
      raise FlateError::Error("uncompress", "invalid literal/length symbol")
    }
  }

  decode_loop(reader, out)
}

///|
fn inflate_dynamic(
  reader : BitReader,
  out : @pdfio.MutableBytes,
) -> Unit raise FlateError {
  let hlit = reader.read_bits(5) + 257
  let hdist = reader.read_bits(5) + 1
  let hclen = reader.read_bits(4) + 4
  let code_length_order : Array[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  let code_lengths = Array::make(19, 0)
  for i in 0..<hclen {
    let symbol = code_length_order[i]
    code_lengths[symbol] = reader.read_bits(3)
  }
  let code_length_huff = build_huffman(code_lengths)
  let total = hlit + hdist
  let lengths = Array::new(capacity=total)
  let mut prev = 0
  while lengths.length() < total {
    let sym = decode_symbol(reader, code_length_huff)
    if sym <= 15 {
      lengths.push(sym)
      prev = sym
    } else if sym == 16 {
      if lengths.length() == 0 {
        raise FlateError::Error(
          "uncompress", "repeat with no previous code length",
        )
      }
      let repeat = 3 + reader.read_bits(2)
      for _ in 0..<repeat {
        if lengths.length() >= total {
          raise FlateError::Error("uncompress", "code length overflow")
        }
        lengths.push(prev)
      }
    } else if sym == 17 {
      let repeat = 3 + reader.read_bits(3)
      for _ in 0..<repeat {
        if lengths.length() >= total {
          raise FlateError::Error("uncompress", "code length overflow")
        }
        lengths.push(0)
      }
      prev = 0
    } else if sym == 18 {
      let repeat = 11 + reader.read_bits(7)
      for _ in 0..<repeat {
        if lengths.length() >= total {
          raise FlateError::Error("uncompress", "code length overflow")
        }
        lengths.push(0)
      }
      prev = 0
    } else {
      raise FlateError::Error("uncompress", "invalid code length symbol")
    }
  }
  let lit_lengths = Array::new(capacity=hlit)
  for i in 0..<hlit {
    lit_lengths.push(lengths[i])
  }
  let dist_lengths = Array::new(capacity=hdist)
  for i in 0..<hdist {
    dist_lengths.push(lengths[hlit + i])
  }
  let lit_huff = build_huffman(lit_lengths)
  let dist_huff = build_huffman(dist_lengths)
  fn decode_loop(
    reader : BitReader,
    out : @pdfio.MutableBytes,
  ) -> Unit raise FlateError {
    let symbol = decode_symbol(reader, lit_huff)
    if symbol < 256 {
      out.push(symbol.to_byte())
      decode_loop(reader, out)
    } else if symbol == 256 {
      ()
    } else if symbol <= 285 {
      let index = symbol - 257
      let base = length_base[index]
      let extra = length_extra[index]
      let length = base + (if extra > 0 { reader.read_bits(extra) } else { 0 })
      let dist_symbol = decode_symbol(reader, dist_huff)
      if dist_symbol < 0 || dist_symbol >= dist_base.length() {
        raise FlateError::Error("uncompress", "invalid distance symbol")
      }
      let dist = dist_base[dist_symbol] +
        (if dist_extra[dist_symbol] > 0 {
          reader.read_bits(dist_extra[dist_symbol])
        } else {
          0
        })
      copy_from_output(out, dist, length)
      decode_loop(reader, out)
    } else {
      raise FlateError::Error("uncompress", "invalid literal/length symbol")
    }
  }

  decode_loop(reader, out)
}

///|
fn read_all_input(input : (@pdfio.MutableBytes) -> Int) -> @pdfio.MutableBytes {
  let out = Array::new()
  let buf = @pdfio.mkbytes(4096)
  fn read_more(
    out : @pdfio.MutableBytes,
    buf : @pdfio.MutableBytes,
    input : (@pdfio.MutableBytes) -> Int,
  ) -> Unit {
    let n = input(buf)
    if n <= 0 {
      return
    }
    out.append(buf[:n])
    read_more(out, buf, input)
  }

  read_more(out, buf, input)
  out
}

///|
fn zlib_start_offset(data : @pdfio.MutableBytes) -> Int raise FlateError {
  if data.length() < 2 {
    raise FlateError::Error("uncompress", "zlib header too short")
  }
  let cmf = data[0].to_int()
  let flg = data[1].to_int()
  if (cmf & 0x0F) != 8 {
    raise FlateError::Error("uncompress", "unsupported compression method")
  }
  if ((cmf << 8) + flg) % 31 != 0 {
    raise FlateError::Error("uncompress", "invalid zlib header")
  }
  if (flg & 0x20) != 0 {
    raise FlateError::Error("uncompress", "preset dictionary not supported")
  }
  2
}

///|
/// Compress data using a streaming interface (stored blocks only).
pub fn PdfFlate::compress(
  _self : PdfFlate,
  level? : Int = 6,
  header? : Bool = true,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit,
) -> Unit {
  let _ = level
  let data = read_all_input(input)
  let one = @pdfio.mkbytes(1)
  fn write_byte(value : Int) -> Unit {
    one[0] = value.to_byte()
    output(one, 1)
  }

  fn write_u16_le(value : Int) -> Unit {
    write_byte(value & 0xff)
    write_byte((value >> 8) & 0xff)
  }

  fn write_bytes(
    data : @pdfio.MutableBytes,
    offset : Int,
    length : Int,
  ) -> Unit {
    if length == 0 {
      return
    }
    let chunk = @pdfio.mkbytes(length)
    for i in 0..<length {
      chunk[i] = data[offset + i]
    }
    output(chunk, length)
  }

  fn adler32(data : @pdfio.MutableBytes) -> Int {
    let mod_adler = 65521
    let mut s1 = 1
    let mut s2 = 0
    for b in data {
      s1 = (s1 + b.to_int()) % mod_adler
      s2 = (s2 + s1) % mod_adler
    }
    (s2 << 16) | s1
  }

  fn write_stored_block(
    data : @pdfio.MutableBytes,
    offset : Int,
    length : Int,
    is_final : Bool,
  ) -> Unit {
    let header_byte = if is_final { 1 } else { 0 }
    write_byte(header_byte)
    write_u16_le(length)
    write_u16_le(0xffff - length)
    write_bytes(data, offset, length)
  }

  if header {
    let zlib_header = @pdfio.mkbytes(2)
    zlib_header[0] = (0x78).to_byte()
    zlib_header[1] = (0x01).to_byte()
    output(zlib_header, 2)
  }
  let total = data.length()
  if total == 0 {
    write_stored_block(data, 0, 0, true)
  } else {
    let mut offset = 0
    while offset < total {
      let remaining = total - offset
      let block_len = if remaining > 65535 { 65535 } else { remaining }
      let is_final = offset + block_len == total
      write_stored_block(data, offset, block_len, is_final)
      offset = offset + block_len
    }
  }
  if header {
    let checksum = adler32(data)
    let adler_bytes = @pdfio.mkbytes(4)
    adler_bytes[0] = ((checksum >> 24) & 0xff).to_byte()
    adler_bytes[1] = ((checksum >> 16) & 0xff).to_byte()
    adler_bytes[2] = ((checksum >> 8) & 0xff).to_byte()
    adler_bytes[3] = (checksum & 0xff).to_byte()
    output(adler_bytes, 4)
  }
}

///|
/// Uncompress data using a streaming interface.
pub fn PdfFlate::uncompress(
  _self : PdfFlate,
  header? : Bool = true,
  input : (@pdfio.MutableBytes) -> Int,
  output : (@pdfio.MutableBytes, Int) -> Unit,
) -> Unit raise FlateError {
  let data = read_all_input(input)
  let start = if header { zlib_start_offset(data) } else { 0 }
  let reader = { data, byte_pos: start, bit_pos: 0 }
  let out : @pdfio.MutableBytes = Array::new()
  fn read_blocks(
    reader : BitReader,
    out : @pdfio.MutableBytes,
  ) -> Unit raise FlateError {
    let bfinal = reader.read_bits(1)
    let btype = reader.read_bits(2)
    match btype {
      0 => inflate_stored(reader, out)
      1 => inflate_fixed(reader, out)
      2 => inflate_dynamic(reader, out)
      _ => raise FlateError::Error("uncompress", "invalid block type")
    }
    if bfinal == 1 {
      return
    }
    read_blocks(reader, out)
  }

  read_blocks(reader, out)
  output(out, out.length())
}
