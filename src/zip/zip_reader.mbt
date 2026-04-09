///|
const EOCD_SIG : Int = 0x06054b50

///|
const CD_FILE_HEADER_SIG : Int = 0x02014b50

///|
const LOCAL_FILE_HEADER_SIG : Int = 0x04034b50

///|
pub fn open_zip(bytes : Bytes) -> ZipArchive raise ZipError {
  let eocd_offset = find_eocd(bytes)
  let (cd_offset, _cd_size, entry_count) = parse_eocd(bytes, eocd_offset)
  let entries = parse_cd_entries(bytes, cd_offset, entry_count)
  let index : Map[String, Int] = Map::new()

  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    index.set(entry.name, i)
    i = i + 1
  }

  { bytes, entries, entry_index: index }
}

///|
pub fn list_entries(archive : ZipArchive) -> Array[ZipEntryMeta] {
  archive.entries
}

///|
pub fn read_entry(
  archive : ZipArchive,
  path : String,
  max_output_size? : Int = 128 * 1024 * 1024,
) -> Bytes raise ZipError {
  let entry = match archive.entry_index.get(path) {
    Some(idx) => archive.entries[idx]
    None => raise EntryNotFound(path)
  }

  let local_offset = entry.local_header_offset
  let sig = read_u32_le(
    archive.bytes,
    local_offset,
    "local file header signature",
  )
  if sig != LOCAL_FILE_HEADER_SIG {
    raise InvalidSignature("local file header", LOCAL_FILE_HEADER_SIG, sig)
  }

  let flags = read_u16_le(
    archive.bytes,
    local_offset + 6,
    "local file header flags",
  )
  let method_code = read_u16_le(
    archive.bytes,
    local_offset + 8,
    "local file header method",
  )
  let name_len = read_u16_le(
    archive.bytes,
    local_offset + 26,
    "local file header name length",
  )
  let extra_len = read_u16_le(
    archive.bytes,
    local_offset + 28,
    "local file header extra length",
  )

  if (flags & 0x01) != 0 {
    raise InvalidStructure("encrypted zip is not supported")
  }
  if (flags & 0x08) != 0 {
    raise InvalidStructure("data descriptor is not supported in phase-1")
  }

  let local_method = compression_method_from_code(method_code)
  if local_method != entry.compression_method {
    raise InvalidStructure(
      "central/local compression method mismatch for entry: " + entry.name,
    )
  }

  let data_start = local_offset + 30 + name_len + extra_len
  let data_end = data_start + entry.compressed_size
  let compressed = subview(archive.bytes, data_start, data_end, "entry data")

  decompress(entry.compression_method, compressed, max_output_size~) catch {
    UnsupportedCompressionMethod(code) =>
      raise UnsupportedCompressionMethod(code)
    DecodeFailed(msg) =>
      raise DecodeFailed("decode failed for `" + entry.name + "`: " + msg)
    OutputTooLarge(max, actual) =>
      raise InvalidStructure(
        "decoded entry exceeds max_output_size: max=" +
        max.to_string() +
        ", actual=" +
        actual.to_string(),
      )
  }
}

///|
fn find_eocd(bytes : Bytes) -> Int raise ZipError {
  let len = bytes.length()
  if len < 22 {
    raise UnexpectedEOF("zip smaller than minimum EOCD size")
  }

  let max_back = 65535 + 22
  let scan_start = if len > max_back { len - max_back } else { 0 }
  let mut pos = len - 22

  while pos >= scan_start {
    let sig = read_u32_le(bytes, pos, "EOCD signature probe")
    if sig == EOCD_SIG {
      return pos
    }
    pos = pos - 1
  }

  raise InvalidStructure("EOCD not found")
}

///|
fn parse_eocd(
  bytes : Bytes,
  eocd_offset : Int,
) -> (Int, Int, Int) raise ZipError {
  let sig = read_u32_le(bytes, eocd_offset, "EOCD signature")
  if sig != EOCD_SIG {
    raise InvalidSignature("EOCD", EOCD_SIG, sig)
  }

  let disk_no = read_u16_le(bytes, eocd_offset + 4, "EOCD disk number")
  let cd_start_disk = read_u16_le(bytes, eocd_offset + 6, "EOCD cd start disk")
  let disk_entries = read_u16_le(bytes, eocd_offset + 8, "EOCD entries on disk")
  let total_entries = read_u16_le(bytes, eocd_offset + 10, "EOCD total entries")
  let cd_size = read_u32_le(bytes, eocd_offset + 12, "EOCD cd size")
  let cd_offset = read_u32_le(bytes, eocd_offset + 16, "EOCD cd offset")

  if disk_no != 0 || cd_start_disk != 0 {
    raise InvalidStructure("multi-disk zip is not supported")
  }
  if disk_entries != total_entries {
    raise InvalidStructure("inconsistent EOCD entry counts")
  }

  let cd_end = cd_offset + cd_size
  if cd_offset < 0 || cd_size < 0 || cd_end > bytes.length() {
    raise InvalidStructure("central directory range out of bounds")
  }

  (cd_offset, cd_size, total_entries)
}

///|
fn parse_cd_entries(
  bytes : Bytes,
  cd_offset : Int,
  entry_count : Int,
) -> Array[ZipEntryMeta] raise ZipError {
  let entries : Array[ZipEntryMeta] = []
  let mut cursor = cd_offset
  let mut i = 0

  while i < entry_count {
    let sig = read_u32_le(bytes, cursor, "central directory signature")
    if sig != CD_FILE_HEADER_SIG {
      raise InvalidSignature("central directory entry", CD_FILE_HEADER_SIG, sig)
    }

    let flags = read_u16_le(bytes, cursor + 8, "central directory flags")
    let method_code = read_u16_le(
      bytes,
      cursor + 10,
      "central directory method",
    )
    let crc32 = read_u32_le(bytes, cursor + 16, "central directory crc32")
    let compressed_size = read_u32_le(
      bytes,
      cursor + 20,
      "central directory compressed size",
    )
    let uncompressed_size = read_u32_le(
      bytes,
      cursor + 24,
      "central directory uncompressed size",
    )
    let name_len = read_u16_le(
      bytes,
      cursor + 28,
      "central directory name length",
    )
    let extra_len = read_u16_le(
      bytes,
      cursor + 30,
      "central directory extra length",
    )
    let comment_len = read_u16_le(
      bytes,
      cursor + 32,
      "central directory comment length",
    )
    let local_header_offset = read_u32_le(
      bytes,
      cursor + 42,
      "central directory local header offset",
    )

    let name_start = cursor + 46
    let name_end = name_start + name_len
    let name_bytes = subview(bytes, name_start, name_end, "entry name")
    let name = bytes_to_string(name_bytes)

    let compression_method = compression_method_from_code(method_code)

    entries.push({
      name,
      compression_method,
      compressed_size,
      uncompressed_size,
      local_header_offset,
      crc32,
      flags,
    })

    cursor = name_end + extra_len + comment_len
    i = i + 1
  }

  entries
}

///|
fn compression_method_from_code(code : Int) -> CompressionMethod {
  if code == 0 {
    Store
  } else if code == 8 {
    DeflateRaw
  } else {
    Unsupported(code)
  }
}

///|
fn read_u16_le(
  bytes : Bytes,
  offset : Int,
  context : String,
) -> Int raise ZipError {
  let tail = offset + 2
  if offset < 0 || tail > bytes.length() {
    raise UnexpectedEOF(context)
  }

  byte_to_int(bytes[offset]) | (byte_to_int(bytes[offset + 1]) << 8)
}

///|
fn read_u32_le(
  bytes : Bytes,
  offset : Int,
  context : String,
) -> Int raise ZipError {
  let tail = offset + 4
  if offset < 0 || tail > bytes.length() {
    raise UnexpectedEOF(context)
  }

  byte_to_int(bytes[offset]) |
  (byte_to_int(bytes[offset + 1]) << 8) |
  (byte_to_int(bytes[offset + 2]) << 16) |
  (byte_to_int(bytes[offset + 3]) << 24)
}

///|
fn subview(
  bytes : Bytes,
  start : Int,
  end_ : Int,
  context : String,
) -> Bytes raise ZipError {
  if start < 0 || end_ < start || end_ > bytes.length() {
    raise UnexpectedEOF(context)
  }
  bytes[start:end_].to_bytes()
}

///|
fn bytes_to_string(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for b in bytes {
    chars.push(Int::unsafe_to_char(byte_to_int(b)))
  }
  String::from_array(chars)
}

///|
fn byte_to_int(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0 {
    v
  } else {
    v + 256
  }
}
