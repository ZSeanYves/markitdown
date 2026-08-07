///|
const PDF_PNG_MAX_PIXELS : Int = 32 * 1024 * 1024

///|
fn pdf_png_u32be_byte(value : UInt, offset : Int) -> Byte {
  ((value >> ((3 - offset) * 8)) & 0xFF).reinterpret_as_int().to_byte()
}

///|
fn pdf_png_crc32_update(crc : UInt, byte : Byte) -> UInt {
  let mut next = crc ^ byte.to_int().reinterpret_as_uint()
  for _ in 0..<8 {
    next = if (next & 1) != 0 { (next >> 1) ^ 0xEDB88320 } else { next >> 1 }
  }
  next
}

///|
fn pdf_png_crc32(kind : Bytes, data : Bytes) -> UInt {
  let mut crc : UInt = 0xFFFFFFFF
  for byte in kind {
    crc = pdf_png_crc32_update(crc, byte)
  }
  for byte in data {
    crc = pdf_png_crc32_update(crc, byte)
  }
  crc ^ 0xFFFFFFFF
}

///|
fn pdf_png_chunk(kind : String, data : Bytes) -> Bytes {
  let kind_bytes = @utf8.encode(kind)
  let crc = pdf_png_crc32(kind_bytes, data)
  Bytes::makei(12 + data.length(), fn(index) {
    if index < 4 {
      pdf_png_u32be_byte(data.length().reinterpret_as_uint(), index)
    } else if index < 8 {
      kind_bytes[index - 4]
    } else if index < 8 + data.length() {
      data[index - 8]
    } else {
      pdf_png_u32be_byte(crc, index - 8 - data.length())
    }
  })
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
  let row_size = width * channels
  let encoded_row_size = row_size + 1
  let raw = Bytes::makei(encoded_row_size * height, fn(index) {
    let column = index % encoded_row_size
    if column == 0 {
      (0).to_byte()
    } else {
      let row = index / encoded_row_size
      pixels[row * row_size + column - 1]
    }
  })
  let compressed = @zlib.compress(raw) catch { _ => return None }
  let signature = Bytes::from_array([
    (0x89).to_byte(),
    (0x50).to_byte(),
    (0x4E).to_byte(),
    (0x47).to_byte(),
    (0x0D).to_byte(),
    (0x0A).to_byte(),
    (0x1A).to_byte(),
    (0x0A).to_byte(),
  ])
  let color_type : Byte = match channels {
    1 => (0).to_byte()
    3 => (2).to_byte()
    _ => (6).to_byte()
  }
  let ihdr = Bytes::makei(13, fn(index) {
    if index < 4 {
      pdf_png_u32be_byte(width.reinterpret_as_uint(), index)
    } else if index < 8 {
      pdf_png_u32be_byte(height.reinterpret_as_uint(), index - 4)
    } else {
      match index {
        8 => (8).to_byte()
        9 => color_type
        _ => (0).to_byte()
      }
    }
  })
  Some(
    signature
    .add(pdf_png_chunk("IHDR", ihdr))
    .add(pdf_png_chunk("IDAT", compressed))
    .add(pdf_png_chunk("IEND", Bytes::new(0))),
  )
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
