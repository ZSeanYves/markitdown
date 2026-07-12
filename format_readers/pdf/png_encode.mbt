///|
const PDF_PNG_MAX_PIXELS : Int = 32 * 1024 * 1024

///|
fn pdf_png_push_u32be(out : Array[Byte], value : UInt) -> Unit {
  out.push(((value >> 24) & 0xFF).reinterpret_as_int().to_byte())
  out.push(((value >> 16) & 0xFF).reinterpret_as_int().to_byte())
  out.push(((value >> 8) & 0xFF).reinterpret_as_int().to_byte())
  out.push((value & 0xFF).reinterpret_as_int().to_byte())
}

///|
fn pdf_png_crc32(bytes : Array[Byte]) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for byte in bytes {
    crc = crc ^ byte.to_int().reinterpret_as_uint()
    for _ in 0..<8 {
      crc = if (crc & 1) != 0 { (crc >> 1) ^ 0xEDB88320 } else { crc >> 1 }
    }
  }
  crc ^ 0xFFFFFFFF
}

///|
fn pdf_png_adler32(bytes : Array[Byte]) -> UInt {
  let mut a : UInt = 1
  let mut b : UInt = 0
  for byte in bytes {
    a = (a + byte.to_int().reinterpret_as_uint()) % 65521
    b = (b + a) % 65521
  }
  (b << 16) | a
}

///|
fn pdf_png_append_chunk(
  out : Array[Byte],
  kind : String,
  data : Array[Byte],
) -> Unit {
  pdf_png_push_u32be(out, data.length().reinterpret_as_uint())
  let crc_input : Array[Byte] = []
  for ch in kind {
    let byte = ch.to_int().to_byte()
    out.push(byte)
    crc_input.push(byte)
  }
  out.append(data[:])
  crc_input.append(data[:])
  pdf_png_push_u32be(out, pdf_png_crc32(crc_input))
}

///|
fn pdf_png_zlib_store(raw : Array[Byte]) -> Array[Byte] {
  let out : Array[Byte] = [(0x78).to_byte(), (0x01).to_byte()]
  let mut offset = 0
  while offset < raw.length() {
    let remaining = raw.length() - offset
    let size = if remaining > 65535 { 65535 } else { remaining }
    let final_flag : Byte = if offset + size == raw.length() {
      (1).to_byte()
    } else {
      (0).to_byte()
    }
    out.push(final_flag)
    out.push((size & 0xFF).to_byte())
    out.push(((size >> 8) & 0xFF).to_byte())
    let inverse = 0xFFFF - size
    out.push((inverse & 0xFF).to_byte())
    out.push(((inverse >> 8) & 0xFF).to_byte())
    out.append(raw[offset:offset + size])
    offset += size
  }
  pdf_png_push_u32be(out, pdf_png_adler32(raw))
  out
}

///|
fn pdf_encode_png_8bit(
  pixels : Bytes,
  width : Int,
  height : Int,
  channels : Int,
) -> Bytes? {
  if width <= 0 ||
    height <= 0 ||
    (channels != 1 && channels != 3 && channels != 4) ||
    width > PDF_PNG_MAX_PIXELS / height ||
    width * height > PDF_PNG_MAX_PIXELS ||
    pixels.length() != width * height * channels {
    return None
  }
  let raw : Array[Byte] = []
  let row_size = width * channels
  for row in 0..<height {
    raw.push((0).to_byte())
    let start = row * row_size
    let mut index = start
    while index < start + row_size {
      raw.push(pixels[index])
      index += 1
    }
  }
  let out : Array[Byte] = [
    (0x89).to_byte(),
    (0x50).to_byte(),
    (0x4E).to_byte(),
    (0x47).to_byte(),
    (0x0D).to_byte(),
    (0x0A).to_byte(),
    (0x1A).to_byte(),
    (0x0A).to_byte(),
  ]
  let ihdr : Array[Byte] = []
  pdf_png_push_u32be(ihdr, width.reinterpret_as_uint())
  pdf_png_push_u32be(ihdr, height.reinterpret_as_uint())
  ihdr.push((8).to_byte())
  let color_type : Byte = match channels {
    1 => (0).to_byte()
    3 => (2).to_byte()
    _ => (6).to_byte()
  }
  ihdr.push(color_type)
  ihdr.append([(0).to_byte(), (0).to_byte(), (0).to_byte()])
  pdf_png_append_chunk(out, "IHDR", ihdr)
  pdf_png_append_chunk(out, "IDAT", pdf_png_zlib_store(raw))
  pdf_png_append_chunk(out, "IEND", [])
  Some(Bytes::from_array(out))
}

///|
fn pdf_expand_1bit_grayscale(
  packed : Bytes,
  width : Int,
  height : Int,
  invert : Bool,
) -> Bytes? {
  if width <= 0 ||
    height <= 0 ||
    width > PDF_PNG_MAX_PIXELS / height ||
    width * height > PDF_PNG_MAX_PIXELS {
    return None
  }
  let row_bytes = (width + 7) / 8
  if packed.length() < row_bytes * height {
    return None
  }
  let pixels : Array[Byte] = []
  for row in 0..<height {
    let row_start = row * row_bytes
    for column in 0..<width {
      let byte = packed[row_start + column / 8].to_int()
      let set = ((byte >> (7 - column % 8)) & 1) == 1
      let white = if invert { !set } else { set }
      pixels.push(if white { (255).to_byte() } else { (0).to_byte() })
    }
  }
  Some(Bytes::from_array(pixels))
}
