///|
fn zip_builder_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn zip_builder_byte_to_unsigned_int(value : Byte) -> Int32 {
  let raw = value.to_int()
  if raw >= 0 {
    raw
  } else {
    raw + 256
  }
}

///|
fn zip_builder_crc32_update_uint(crc : UInt32, value : UInt32) -> UInt32 {
  let mut acc = UInt32::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt32::land(acc, 1) != 0 {
      acc = UInt32::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i = i + 1
  }
  acc
}

///|
fn zip_builder_crc32(bytes : Bytes) -> Int32 {
  let mut crc : UInt32 = 0xFFFFFFFF
  for value in bytes {
    crc = zip_builder_crc32_update_uint(
      crc,
      zip_builder_byte_to_unsigned_int(value).reinterpret_as_uint(),
    )
  }
  UInt32::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn zip_builder_append_u16_le(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn zip_builder_append_u32_le(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn zip_builder_add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int32, Int32, Int32)],
  name : String,
  data : Bytes,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = zip_builder_bytes_of_string(name)
  let crc32 = zip_builder_crc32(data)
  let size = data.length()

  zip_builder_append_u32_le(out, 0x04034b50)
  zip_builder_append_u16_le(out, 20)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u32_le(out, crc32)
  zip_builder_append_u32_le(out, size)
  zip_builder_append_u32_le(out, size)
  zip_builder_append_u16_le(out, name_bytes.length())
  zip_builder_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data {
    out.push(b)
  }

  central.push((name, size, local_offset, crc32))
}

///|
pub fn build_store_zip_bytes(entries : Array[(String, Bytes)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int32, Int32, Int32)] = []

  for entry in entries {
    let (name, data) = entry
    zip_builder_add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = zip_builder_bytes_of_string(name)

    zip_builder_append_u32_le(out, 0x02014b50)
    zip_builder_append_u16_le(out, 20)
    zip_builder_append_u16_le(out, 20)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u32_le(out, crc32)
    zip_builder_append_u32_le(out, size)
    zip_builder_append_u32_le(out, size)
    zip_builder_append_u16_le(out, name_bytes.length())
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u16_le(out, 0)
    zip_builder_append_u32_le(out, 0)
    zip_builder_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  zip_builder_append_u32_le(out, 0x06054b50)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, 0)
  zip_builder_append_u16_le(out, central.length())
  zip_builder_append_u16_le(out, central.length())
  zip_builder_append_u32_le(out, cd_size)
  zip_builder_append_u32_le(out, cd_offset)
  zip_builder_append_u16_le(out, 0)

  Bytes::from_array(out)
}
