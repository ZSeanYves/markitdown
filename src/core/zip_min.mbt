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
  path : String
  bytes : Bytes
  entries : Map[String, ZipEntry]
}

///|
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

// Bytes -> ASCII/UTF8 string 
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

///|
const SIG_EOCD : Int = 0x06054b50

///|
const SIG_CEN : Int = 0x02014b50

///|
const SIG_LOC : Int = 0x04034b50

///|
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
      if s == SIG_EOCD {
        return i
      }
    }
    i -= 1
  }
  raise ZipError("zip: EOCD not found (not a standard zip?)")
}

// ---------- parse central directory ----------

///|
fn parse_entries(b : Bytes) -> Map[String, ZipEntry] raise {
  let eocd = find_eocd_offset(b)

  // EOCD layout:
  // 0: sig(4)
  // 10: total entries (2)
  // 12: central dir size (4)
  // 16: central dir offset (4)
  let total = u16le(b, eocd + 10)
  let cd_size = u32le(b, eocd + 12)
  let cd_off = u32le(b, eocd + 16)

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
      raise ZipError(
        "zip: invalid central directory signature at " + p.to_string(),
      )
    }

    let gp_flags = u16le(b, p + 8)
    let comp_method = u16le(b, p + 10)
    let comp_sz = u32le(b, p + 20)
    let uncomp_sz = u32le(b, p + 24)
    let name_len = u16le(b, p + 28)
    let extra_len = u16le(b, p + 30)
    let cmt_len = u16le(b, p + 32)
    let lho = u32le(b, p + 42)

    let name_start = p + 46
    let name_end = name_start + name_len
    if name_end > b.length() {
      raise ZipError("zip: filename out of range")
    }

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
  { path, bytes, entries }
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
  //println("zip entry = " + e.name)
  //println(
  //  "  method=" +
  //  e.comp_method.to_string() +
  //  " flags=" +
  //  e.gp_flags.to_string() +
  //  " comp_size=" +
  //  e.comp_size.to_string() +
  //  " uncomp_size=" +
  //  e.uncomp_size.to_string() +
  //  " data_start=" +
  //  data_start.to_string(),
  //)

  slice_bytes(b, data_start, data_end)
}

///|
pub async fn ZipReader::read_entry_bytes(
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
        @z.deflate_decompress(comp) catch {
          raw_err => {
            println(
              "!! zip: raw deflate failed for " +
              name +
              ": " +
              raw_err.to_string(),
            )

            let ext = external_read_entry_bytes(z.path, name)
            match ext {
              Ok(bs) => {
                println(
                  "!! zip: external fallback OK for " +
                  name +
                  ", bytes=" +
                  bs.length().to_string(),
                )
                bs
              }
              Err(ext_err) =>
                raise ZipError(
                  "zip: deflate decompress failed: " +
                  name +
                  " (raw=" +
                  raw_err.to_string() +
                  ", ext=" +
                  ext_err.to_string() +
                  ")",
                )
            }
          }
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

///|
/// Capture stdout as Bytes (binary-safe).
async fn run_and_capture_bytes(
  cmd : String,
  args : Array[String],
) -> Result[Bytes, ZipError] {
  let res = @proc.collect_output(cmd, args[:]) catch {
    e => return Err(ZipError("spawn failed: " + e.to_string()))
  }

  let (status, out_data, err_data) = res

  if status != 0 {
    let stderr : String = err_data.text() catch { _ => "" }
    return Err(
      ZipError("Command failed: " + cmd + " " + args.join(" ") + "\n" + stderr),
    )
  }

  Ok(out_data.binary())
}

///|
/// Try external tools to read a zip entry when internal deflate fails.
/// Order:
/// 1) unzip -p (macOS/Linux; may exist on Windows too)
/// 2) powershell + .NET ZipArchive -> Base64 (Windows)
///|
/// Try external tools to read a zip entry when internal deflate fails.
/// Order:
/// 1) unzip -p (macOS/Linux; may exist on Windows too)
/// 2) powershell + .NET ZipArchive -> Base64 (Windows)
async fn external_read_entry_bytes(
  zip_path : String,
  entry : String,
) -> Result[Bytes, ZipError] {
  println(".. zip: external fallback start: " + entry)

  // 1) unzip -p <zip> <entry>  (binary)
  println(".. zip: try unzip -p")
  let unzip_res = run_and_capture_bytes("unzip", ["-p", zip_path, entry])
  match unzip_res {
    Ok(bs) => {
      println(".. zip: unzip OK, bytes=" + bs.length().to_string())
      if bs.length() == 0 {
        // 有些环境 unzip 可能输出空但 status=0，这里兜一下
        println(".. zip: unzip returned empty, continue fallback")
      } else {
        return Ok(bs)
      }
    }
    Err(e) => println(".. zip: unzip failed: " + e.to_string())
  }

  // 2) Windows PowerShell: output base64 text, then decode
  println(".. zip: try powershell base64")
  let script = ps_read_entry_base64_script(zip_path, entry)
  let b64_res = run_and_capture("powershell", [
    "-NoProfile", "-NonInteractive", "-Command", script,
  ])

  match b64_res {
    Err(e) => {
      println(".. zip: powershell failed: " + e.to_string())
      Err(e)
    }
    Ok(b64) => {
      println(".. zip: powershell OK, base64_len=" + b64.length().to_string())

      let bs_res : Result[Bytes, ZipError] = Ok(
        base64_decode(b64) catch {
          e => return Err(e)
        },
      )

      match bs_res {
        Ok(bs) => {
          println(".. zip: base64 decode OK, bytes=" + bs.length().to_string())
          Ok(bs)
        }
        Err(e) => {
          println(".. zip: base64 decode failed: " + e.to_string())
          Err(e)
        }
      }
    }
  }
}

///|
/// Capture stdout as UTF-8 text.
async fn run_and_capture(
  cmd : String,
  args : Array[String],
) -> Result[String, ZipError] {
  let res = @proc.collect_output(cmd, args[:]) catch {
    e => return Err(ZipError("spawn failed: " + e.to_string()))
  }

  let (status, out_data, err_data) = res

  let stdout : String = out_data.text() catch {
    _ => return Err(ZipError("invalid utf-8 stdout"))
  }
  let stderr : String = err_data.text() catch { _ => "" }

  if status != 0 {
    return Err(
      ZipError("Command failed: " + cmd + " " + args.join(" ") + "\n" + stderr),
    )
  }

  Ok(stdout)
}

///|
/// Decode base64 string into raw bytes.
/// - ignores whitespace
/// - supports '=' padding
fn base64_decode(s0 : String) -> Bytes raise ZipError {
  // 1) strip whitespace
  let chars0 = s0.trim().to_string().to_array()
  let chars : Array[Char] = []
  for c in chars0 {
    if !is_ws(c) {
      chars.push(c)
    }
  }

  if chars.length() == 0 {
    return Bytes::from_array([])
  }
  if chars.length() % 4 != 0 {
    raise ZipError("base64: invalid length")
  }

  let out : Array[Byte] = []
  let mut i = 0
  while i < chars.length() {
    let c0 = chars[i]
    let c1 = chars[i + 1]
    let c2 = chars[i + 2]
    let c3 = chars[i + 3]

    let v0 = b64_index(c0)
    let v1 = b64_index(c1)
    if v0 < 0 || v1 < 0 {
      raise ZipError("base64: invalid char")
    }

    let v2 = if c2 == '=' { -2 } else { b64_index(c2) }
    let v3 = if c3 == '=' { -2 } else { b64_index(c3) }
    if v2 == -1 || v3 == -1 {
      raise ZipError("base64: invalid char")
    }

    let b0 = (v0 << 2) | (v1 >> 4)
    out.push(b0.to_byte())

    if v2 != -2 {
      let b1 = ((v1 & 0x0F) << 4) | (v2 >> 2)
      out.push(b1.to_byte())
    }

    if v3 != -2 && v2 != -2 {
      let b2 = ((v2 & 0x03) << 6) | v3
      out.push(b2.to_byte())
    }

    i = i + 4
  }

  Bytes::from_array(out)
}

///|
/// PowerShell script: read one entry and print Base64 to stdout.
fn ps_read_entry_base64_script(zip_path : String, entry : String) -> String {
  fn esc(s : String) -> String {
    s.replace(old="'", new="''")
  }
  let zp = esc(zip_path)
  let en = esc(entry)

  "Add-Type -AssemblyName System.IO.Compression.FileSystem; " +
  "$z=[System.IO.Compression.ZipFile]::OpenRead('" +
  zp +
  "'); " +
  "try { " +
  "$e=$z.Entries | Where-Object { $_.FullName -eq '" +
  en +
  "' } | Select-Object -First 1; " +
  "if ($null -eq $e) { exit 2 }; " +
  "$s=$e.Open(); $ms=New-Object System.IO.MemoryStream; $s.CopyTo($ms); $s.Dispose(); " +
  "[Convert]::ToBase64String($ms.ToArray()); " +
  "} finally { $z.Dispose() }"
}
