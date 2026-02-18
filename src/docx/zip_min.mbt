// ============================
// Minimal ZIP Reader (no zip64, no encryption)
// Supports: Stored(0), Deflate(8)
// ============================

///|
pub struct ZipEntry {
  name : String
  comp_method : Int
  gp_flags : Int
  comp_size : Int
  uncomp_size : Int
  local_header_offset : Int
}

///|
pub struct ZipReader {
  bytes : Bytes
  // name -> entry
  entries : Map[String, ZipEntry]
}

pub(all) suberror ZipError {
  ZipError(String)
}
///|
pub impl Show for ZipError with to_string(self : ZipError) -> String {
  match self {
    ZipError(msg) => msg
  }
}

///|
pub impl Show for ZipError with output(self : ZipError, logger : &Logger) -> Unit {
  match self {
    ZipError(msg) => logger.write_string(msg)
  }
}

// ---------- little-endian readers ----------
///|
fn b2u(x : Byte) -> Int {
  let mut v = x.to_int()
  if v < 0 {
    v = v + 256
  }
  v
}

///|
fn u16le(b : Bytes, off : Int) -> Int raise {
  if off + 1 >= b.length() {
    raise ZipError("zip: u16le out of range")
  }
  let x0 = b2u(b[off])
  let x1 = b2u(b[off + 1])
  x0 | (x1 << 8)
}

///|
fn u32le(b : Bytes, off : Int) -> Int raise {
  if off + 3 >= b.length() {
    raise ZipError("zip: u32le out of range")
  }
  let x0 = b2u(b[off])
  let x1 = b2u(b[off + 1])
  let x2 = b2u(b[off + 2])
  let x3 = b2u(b[off + 3])
  x0 | (x1 << 8) | (x2 << 16) | (x3 << 24)
}


///|
fn slice_bytes(b : Bytes, l : Int, r : Int) -> Bytes raise {
  if l < 0 || r < l || r > b.length() {
    raise ZipError("zip: slice out of range")
  }
  b[l:r].to_bytes()
}

// Bytes -> ASCII/UTF8 string (ZIP 文件名一般是 UTF-8；docx 基本都可按 UTF-8 读)
///|
fn bytes_to_string_utf8_lossy(b : Bytes) -> String {
  let arr = b.to_array()
  let chars : Array[Char] = []
  for x in arr {
    let mut v = x.to_int()
    if v < 0 {
      v = v + 256
    }
    chars.push(Int::unsafe_to_char(v))
  }
  String::from_array(chars)
}


// ---------- find EOCD ----------
const SIG_EOCD : Int = 0x06054b50
const SIG_CEN  : Int = 0x02014b50
const SIG_LOC  : Int = 0x04034b50

fn find_eocd_offset(b : Bytes) -> Int raise {
  // EOCD 在文件尾部 64KB+22 范围内
  let n = b.length()
  let max_back = 65535 + 22
  let start = if n > max_back { n - max_back } else { 0 }
  let mut i = n - 22
  while i >= start {
    // compare signature bytes: 50 4b 05 06
    if i + 3 < n {
      let s = u32le(b, i) catch { _ => -1 }
      if s == SIG_EOCD { return i }
    }
    i -= 1
  }
  raise ZipError("zip: EOCD not found (not a standard zip?)")
}

// ---------- parse central directory ----------
fn parse_entries(b : Bytes) -> Map[String, ZipEntry] raise {
  let eocd = find_eocd_offset(b)

  // EOCD layout:
  // 0: sig(4)
  // 10: total entries (2)
  // 12: central dir size (4)
  // 16: central dir offset (4)
  let total = u16le(b, eocd + 10)
  let cd_size = u32le(b, eocd + 12)
  let cd_off  = u32le(b, eocd + 16)

  // basic sanity
  if cd_off < 0 || cd_off + cd_size > b.length() {
    raise ZipError("zip: central directory out of range")
  }

  let m : Map[String, ZipEntry] = Map::new()
  let mut p = cd_off
  let mut count = 0

  // Central directory file header minimum 46 bytes
  while p + 46 <= b.length() && count < total {
    let sig = u32le(b, p)
    if sig != SIG_CEN {
      raise ZipError("zip: invalid central directory signature at " + p.to_string())
    }

    let gp_flags = u16le(b, p + 8)
    let comp_method   = u16le(b, p + 10)
    let comp_sz  = u32le(b, p + 20)
    let uncomp_sz= u32le(b, p + 24)
    let name_len = u16le(b, p + 28)
    let extra_len= u16le(b, p + 30)
    let cmt_len  = u16le(b, p + 32)
    let lho      = u32le(b, p + 42)

    let name_start = p + 46
    let name_end   = name_start + name_len
    if name_end > b.length() { raise ZipError("zip: filename out of range") }

    let name_bytes = slice_bytes(b, name_start, name_end)
    let name = bytes_to_string_utf8_lossy(name_bytes)

    let entry : ZipEntry = {
      name,
      comp_method,
      gp_flags,
      comp_size: comp_sz,
      uncomp_size: uncomp_sz,
      local_header_offset: lho,
    }
    m.set(name, entry)

    p = name_end + extra_len + cmt_len
    count += 1
  }

  m
}

///|
pub fn open_zip(path : String) -> ZipReader raise @fs.IOError {
  let bytes = @fs.read_file_to_bytes(path)
  let entries = parse_entries(bytes) catch {
    e => raise @fs.IOError("zip: parse failed: " + e.to_string())
  }
  { bytes, entries }
}

// ---------- read entry raw bytes ----------
///|
fn read_entry_compressed(z : ZipReader, e : ZipEntry) -> Bytes raise Error {
  let b = z.bytes
  let off = e.local_header_offset
  if off + 30 > b.length() {
    raise ZipError("zip: local header out of range")
  }

  let sig = u32le(b, off)
  if sig != SIG_LOC {
    raise ZipError("zip: invalid local header signature at " + off.to_string())
  }

  // local header:
  // 26: file name length (2)
  // 28: extra length (2)
  let name_len = u16le(b, off + 26)
  let extra_len = u16le(b, off + 28)

  let data_start = off + 30 + name_len + extra_len
  let data_end = data_start + e.comp_size
  if data_end > b.length() {
    raise ZipError("zip: file data out of range")
  }
  println("zip entry = " + e.name)
  println(
    "  method=" +
    e.comp_method.to_string() +
    " flags=" +
    e.gp_flags.to_string() +
    " comp_size=" +
    e.comp_size.to_string() +
    " uncomp_size=" +
    e.uncomp_size.to_string() +
    " data_start=" +
    data_start.to_string(),
  )

  slice_bytes(b, data_start, data_end)
}

///|
pub fn ZipReader::read_entry_bytes(
  z : ZipReader,
  name : String,
) -> Bytes raise Error {
  match z.entries.get(name) {
    None => raise ZipError("zip: entry not found: " + name)
    Some(e) => {
      let comp = read_entry_compressed(z, e)

      if e.comp_method == 0 {
        // stored
        comp
      } else if e.comp_method == 8 {
        // ZIP deflate = raw deflate stream
        @z.deflate_decompress(comp) catch {
          err =>
            raise ZipError(
              "zip: deflate decompress failed: " + name + ": " + err.to_string(),
            )
        }
      } else {
        raise ZipError(
          "zip: unsupported compression method: " + e.comp_method.to_string(),
        )
      }
    }
  }
}




///|
pub fn ZipReader::has_entry(z : ZipReader, name : String) -> Bool {
  z.entries.get(name) is Some(_)
}

///|
pub fn ZipReader::list_entries(z : ZipReader) -> Array[String] {
  let out : Array[String] = []
  for kv in z.entries {
    out.push(kv.0)
  }
  out
}
