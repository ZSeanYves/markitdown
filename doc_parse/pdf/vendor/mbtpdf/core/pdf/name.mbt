///|
/// PDF `Name` object stored as raw bytes.
///
/// PDF names are *byte sequences* (not Unicode text). In PDF syntax they are
/// written like `/Type` and may use `#xx` hex escapes to represent arbitrary
/// bytes. Our lexer decodes `#xx` escapes into the underlying bytes.
///
/// This type keeps the bytes (including the leading `/` byte) so that:
/// - parsing/serialization is byte-faithful,
/// - we avoid accidentally applying Unicode/text semantics,
/// - comparisons can be made lexicographically by byte.
pub(all) struct PdfName {
  bytes : Bytes
} derive(Eq, Hash)

///|
fn ensure_leading_slash(bytes : Bytes) -> Bytes {
  if bytes.length() == 0 || bytes[0] != '/'.to_int().to_byte() {
    // Be tolerant of internal construction mistakes, but do not silently drop
    // information. Keep behavior aligned with the old `make_pdf_name` path.
    @pdfe.log("warning: bad name (missing leading '/'): |\{bytes}|\n")
    let out = Array::new(capacity=bytes.length() + 1)
    out.push('/'.to_int().to_byte())
    out.append(bytes.to_array())
    Bytes::from_array(out[:])
  } else {
    bytes
  }
}

///|
/// Build a `PdfName` from raw bytes.
///
/// `bytes` should include the leading `/` byte.
pub fn PdfName::of_bytes(bytes : Bytes) -> PdfName {
  { bytes: ensure_leading_slash(bytes) }
}

///|
/// Build a `PdfName` from a "bytes-in-String" representation.
///
/// This is mainly for internal construction sites and tests. Each UTF-16 code
/// unit is truncated to its low 8 bits (i.e. treated as a byte).
pub fn PdfName::of_string(value : String) -> PdfName {
  let bytes = Bytes::from_array(@pdfio.bytes_of_string(value)[:])
  PdfName::of_bytes(bytes)
}

///|
/// Raw bytes (including the leading `/`).
pub fn PdfName::to_bytes(self : PdfName) -> Bytes {
  self.bytes
}

///|
/// Convert to the historical "bytes-in-String" representation.
///
/// This maps each byte to a single UTF-16 code unit with the same numeric
/// value (0..255). It is *not* a Unicode decoding.
pub fn PdfName::to_string_bytes(self : PdfName) -> String {
  @pdfio.string_of_bytes(self.bytes.to_array())
}

///|
/// Compare by raw bytes, lexicographically (prefix order).
///
/// Note: MoonBit's default `compare` for sequences/strings is *shortlex*
/// (length-first, then element-wise). PDF name ordering (e.g. in name trees)
/// needs byte-wise lexicographic order, so we implement it explicitly.
pub fn PdfName::lexical_compare(self : PdfName, other : PdfName) -> Int {
  let a = self.bytes
  let b = other.bytes
  let a_len = a.length()
  let b_len = b.length()
  let min_len = if a_len < b_len { a_len } else { b_len }
  for i in 0..<min_len {
    let av = a[i].to_int()
    let bv = b[i].to_int()
    if av != bv {
      return av - bv
    }
  }
  a_len - b_len
}

///|
pub impl Compare for PdfName with compare(self : PdfName, other : PdfName) -> Int {
  self.lexical_compare(other)
}

///|
/// Compare a `PdfName` with a name key written as a `String` (byte-string).
///
/// This expects `key` to contain the leading `/` and to be in the same
/// "bytes-in-String" encoding as `PdfName::to_string_bytes`.
pub fn PdfName::equal_string_bytes(self : PdfName, key : String) -> Bool {
  let b = self.bytes
  if b.length() != key.length() {
    return false
  }
  for i in 0..<key.length() {
    // `key[i]` is a UTF-16 code unit (UInt16). For name keys we only use the
    // low 8 bits (0..255), matching `@pdfio.bytes_of_string`.
    if b[i].to_int() != key[i].to_int() {
      return false
    }
  }
  true
}

///|
/// Debug rendering uses the historical "bytes-in-String" encoding.
///
/// This is convenient for tests and logs, but keep in mind it is *not* a
/// Unicode decode. Non-ASCII bytes will be rendered as code units with the
/// same numeric value (0..255).
pub impl Show for PdfName with output(self : PdfName, logger : &Logger) -> Unit {
  logger.write_string(self.to_string_bytes())
}
