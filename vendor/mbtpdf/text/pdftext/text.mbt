///|
/// Text extraction and encoding conversions.

///|
type Encoding = @pdffont.Encoding

///|
type CMapEncoding = @pdffont.CMapEncoding

///|
pub struct PdfTextUtil {
  unit : Unit
}

///|
pub fn PdfTextUtil::new() -> PdfTextUtil {
  { unit: () }
}

///|
pub struct TextExtractor {
  convert : (Int) -> (String, Array[Int])
  tounicode : Map[String, String]?
  tounicode_lengths : Array[Int]
  font : @pdffont.Font
}

///|
fn odd(n : Int) -> Bool {
  n % 2 != 0
}

///|
fn flatten_int_arrays(arrays : Array[Array[Int]]) -> Array[Int] {
  let mut total = 0
  for arr in arrays {
    total = total + arr.length()
  }
  let out = Array::new(capacity=total)
  for arr in arrays {
    out.append(arr[:])
  }
  out
}

///|
fn tounicode_length_list(map : Map[String, String]) -> Array[Int] {
  let lengths = Array::new(capacity=map.length())
  for key, _ in map {
    let len = @pdfio.bytes_of_string(key).length()
    if !lengths.contains(len) {
      lengths.push(len)
    }
  }
  lengths.sort_by((a, b) => b - a)
  lengths
}

///|
fn bytes_slice_to_string(
  bytes : Array[Int],
  start : Int,
  length : Int,
) -> String {
  @pdfio.string_of_int_array(
    bytes[:].sub(start~, end=start + length).to_array(),
  )
}

///|
fn code_int_of_string(code : String) -> Int {
  let bytes = @pdfio.bytes_of_string(code)
  let mut value = 0
  for b in bytes {
    value = (value << 8) | b.to_int()
  }
  value
}

///|
pub fn PdfTextUtil::utf16be_of_codepoint(
  _self : PdfTextUtil,
  u : Int,
) -> Array[Int] raise {
  if u < 0 || u > 0x10ffff {
    raise Failure::Failure("utf16be_of_codepoints")
  }
  let bytes_of_double = (x : Int) => [x >> 8, x & 255]
  if u < 0x10000 {
    bytes_of_double(u)
  } else {
    let u2 = u - 0x10000
    let w1 = 0xd800 | (u2 >> 10)
    let w2 = 0xdc00 | (u2 & 0x3ff)
    bytes_of_double(w1).add(bytes_of_double(w2))
  }
}

///|
pub fn PdfTextUtil::utf16be_of_codepoints(
  self : PdfTextUtil,
  codepoints : Array[Int],
) -> String raise {
  // Each codepoint expands to <= 4 bytes, plus BOM.
  let bytes = Array::new(capacity=2 + codepoints.length() * 4)
  bytes.push(0xfe)
  bytes.push(0xff)
  for cp in codepoints {
    bytes.append(self.utf16be_of_codepoint(cp))
  }
  @pdfio.string_of_bytes(@pdfio.bytes_of_int_array(bytes))
}

///|
fn codepoints_of_utf16be_inner(bytes : Array[Int]) -> Array[Int] raise {
  let out = Array::new(capacity=bytes.length() / 2)
  let len = bytes.length()
  let mut i = 0
  while i < len {
    if i + 1 >= len {
      raise Failure::Failure("codepoints_of_utf16be")
    }
    let w1 = (bytes[i] << 8) | bytes[i + 1]
    match w1 {
      0xd800..=0xdbff => {
        if i + 3 >= len {
          raise Failure::Failure("codepoints_of_utf16be")
        }
        let w2 = (bytes[i + 2] << 8) | bytes[i + 3]
        if w2 >= 0xdc00 && w2 <= 0xdfff {
          let ho = w1 & 0x3ff
          let lo = w2 >> 6
          out.push(((ho << 10) | lo) + 0x10000)
          i = i + 4
        } else {
          raise Failure::Failure("codepoints_of_utf16be")
        }
      }
      0xdc00..=0xdfff => raise Failure::Failure("codepoints_of_utf16be")
      _ => {
        out.push(w1)
        i = i + 2
      }
    }
  }
  out
}

///|
pub fn PdfTextUtil::codepoints_of_utf16be(
  _self : PdfTextUtil,
  str : String,
) -> Array[Int] raise {
  let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(str))
  codepoints_of_utf16be_inner(bytes)
}

///|
pub fn PdfTextUtil::table_of_encoding(
  _self : PdfTextUtil,
  encoding : @pdffont.Encoding,
) -> Map[Int, String] {
  Encoding::table(encoding)
}

///|
pub fn PdfTextUtil::reverse_table_of_encoding(
  _self : PdfTextUtil,
  encoding : @pdffont.Encoding,
) -> Map[String, Int] {
  Encoding::reverse_table(encoding)
}

///|
pub fn TextExtractor::new(font : @pdffont.Font) -> TextExtractor {
  let encoding = match font {
    StandardFont(_, e) => e
    SimpleFont(simple) => simple.encoding
    _ => ImplicitInFontFile
  }
  let table = PdfTextUtil::new().table_of_encoding(encoding)
  let convert = (i : Int) => try {
    match table.get(i) {
      Some(decoded) =>
        match @pdfglyphlist.PdfGlyphList::new().glyph_hashes().get(decoded) {
          Some(codepoints) => (decoded, codepoints)
          None => ("/" + decoded, [i])
        }
      None => (".notdef", [i])
    }
  } catch {
    _ => (".notdef", [i])
  }
  let tounicode = PdfTextUtil::new().find_tounicode_bytes(font)
  let tounicode_lengths = match tounicode {
    Some(map) => tounicode_length_list(map)
    None => []
  }
  { convert, tounicode, tounicode_lengths, font }
}

///|
pub fn PdfText::text_extractor_of_font(
  self : PdfText,
  fontdict : @pdf.PdfObject,
) -> TextExtractor raise {
  TextExtractor::new(self.read_font(fontdict))
}

///|
fn is_identity_h(font : @pdffont.Font) -> Bool {
  match font {
    CIDKeyedFont(_, _, Predefined("/Identity-H")) => true
    _ => false
  }
}

///|
fn is_shift_jis_cmap(name : String) -> Bool {
  match name {
    "/83pv-RKSJ-H"
    | "/83pv-RKSJ-V"
    | "/90ms-RKSJ-H"
    | "/90ms-RKSJ-V"
    | "/90msp-RKSJ-H"
    | "/90msp-RKSJ-V"
    | "/90pv-RKSJ-H"
    | "/90pv-RKSJ-V" => true
    _ => false
  }
}

///|
fn codepoints_of_predefined_cmap(
  font : @pdffont.Font,
  text : String,
) -> Array[Int]? {
  match font {
    CIDKeyedFont(_, _, Predefined(name)) =>
      if is_shift_jis_cmap(name) {
        let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(text))
        Some(PdfTextUtil::new().codepoints_of_shift_jis(bytes))
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn TextExtractor::glyphnames_and_codepoints_of_text(
  self : TextExtractor,
  text : String,
) -> Array[(String, Array[Int])] raise {
  match self.tounicode {
    Some(map) => {
      let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(text))
      let out = Array::new()
      let mut i = 0
      while i < bytes.length() {
        let mut matched = false
        for length in self.tounicode_lengths {
          if i + length <= bytes.length() {
            let key = bytes_slice_to_string(bytes, i, length)
            match map.get(key) {
              Some(value) => {
                out.push(
                  ("/" + value, PdfTextUtil::new().codepoints_of_utf16be(value)),
                )
                i = i + length
                matched = true
                break
              }
              None => ()
            }
          }
        }
        if !matched {
          out.push((".notdef", [bytes[i]]))
          i = i + 1
        }
      }
      out
    }
    None =>
      match codepoints_of_predefined_cmap(self.font, text) {
        Some(codepoints) => codepoints.map(cp => (".notdef", [cp]))
        None =>
          if is_identity_h(self.font) {
            let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(text))
            if odd(bytes.length()) {
              raise @pdf.PdfError::Msg("Bad Text")
            }
            let out = Array::new()
            let mut i = 0
            while i < bytes.length() {
              let code = (bytes[i] << 8) | bytes[i + 1]
              out.push((self.convert)(code))
              i = i + 2
            }
            out
          } else {
            let out = Array::new(capacity=text.length())
            for c in text {
              out.push((self.convert)(c.to_int()))
            }
            out
          }
      }
  }
}

///|
pub fn TextExtractor::codepoints_of_text(
  self : TextExtractor,
  text : String,
) -> Array[Int] raise {
  let pairs = self.glyphnames_and_codepoints_of_text(text)
  let out = Array::new()
  for pair in pairs {
    out.append(pair.1)
  }
  out
}

///|
pub fn TextExtractor::glyphnames_of_text(
  self : TextExtractor,
  text : String,
) -> Array[String] raise {
  self.glyphnames_and_codepoints_of_text(text).map(pair => pair.0)
}

///|
fn charcode_extractor_of_font_real(
  font : @pdffont.Font,
  debug? : Bool = false,
) -> ((Int) -> Int?) raise {
  if debug {
    @pdfutil.PdfUtil::new().flprint(font.to_string() + "\n")
  }
  let encoding = match font {
    StandardFont(_, e) => e
    SimpleFont(simple) => simple.encoding
    _ => ImplicitInFontFile
  }
  let tounicode_reverse_table = match
    PdfTextUtil::new().find_tounicode_bytes(font) {
    Some(parsed) => {
      if debug {
        @pdfutil.PdfUtil::new().flprint("Found a /ToUnicode table here.\n")
      }
      let parsed_list = @pdfutil.PdfUtil::new().list_of_hashtbl(parsed)
      try {
        let reversed = parsed_list.map(pair => (
          PdfTextUtil::new().codepoints_of_utf16be(pair.1),
          code_int_of_string(pair.0),
        ))
        (@pdfutil.PdfUtil::new().hashtable_of_dictionary(reversed), true)
      } catch {
        err => {
          let _ = err
          @pdfe.log("bad tounicode\n")
          (@pdfutil.PdfUtil::new().null_hash(), false)
        }
      }
    }
    None => (@pdfutil.PdfUtil::new().null_hash(), false)
  }
  let reverse_table = PdfTextUtil::new().reverse_table_of_encoding(encoding)
  let reverse_glyph_hashes = @pdfglyphlist.PdfGlyphList::new().reverse_glyph_hashes()
  (codepoint : Int) => {
    if debug {
      @pdfutil.PdfUtil::new().flprint("Input codepoint: \{codepoint}\n")
    }
    let key = [codepoint]
    if tounicode_reverse_table.1 {
      tounicode_reverse_table.0.get(key)
    } else {
      match reverse_glyph_hashes.get(key) {
        Some(glyphname) => {
          if debug {
            @pdfutil.PdfUtil::new().flprint("Found glyph name \{glyphname}\n")
          }
          reverse_table.get(glyphname)
        }
        None => {
          if debug {
            @pdfe.log("Found no charcode for unicode codepoint.\n")
          }
          None
        }
      }
    }
  }
}

///|
pub fn PdfText::charcode_extractor_of_font(
  self : PdfText,
  fontdict : @pdf.PdfObject,
  debug? : Bool = false,
) -> ((Int) -> Int?) raise {
  charcode_extractor_of_font_real(self.read_font(fontdict), debug~)
}

///|
pub fn PdfTextUtil::is_unicode(_self : PdfTextUtil, s : String) -> Bool {
  let bytes = @pdfio.bytes_of_string(s)
  bytes is [b'\xfe', b'\xff', ..]
}

///|
pub fn PdfTextUtil::codepoint_of_pdfdocencoding_character(
  _self : PdfTextUtil,
  i : Int,
) -> Int raise {
  if i < 0 || i > 255 {
    raise Failure::Failure("codepoint_of_pdfdocencoding_character out of range")
  }
  try {
    match @pdfglyphlist.reverse_name_to_pdf_hashes.get(i) {
      Some(name) =>
        match @pdfglyphlist.PdfGlyphList::new().glyph_hashes().get(name) {
          Some(codepoints) =>
            if codepoints.length() == 1 {
              codepoints[0]
            } else {
              raise @pdf.PdfError::Msg(
                "codepoint_of_pdfdocencoding: bad text string (char \{i})",
              )
            }
          None =>
            raise @pdf.PdfError::Msg(
              "codepoint_of_pdfdocencoding: bad text string 2 (char \{i})",
            )
        }
      None =>
        raise @pdf.PdfError::Msg(
          "codepoint_of_pdfdocencoding: bad text string 2 (char \{i})",
        )
    }
  } catch {
    _ =>
      raise @pdf.PdfError::Msg(
        "codepoint_of_pdfdocencoding: bad text string 2 (char \{i})",
      )
  }
}

///|
pub fn PdfTextUtil::get_utf8_chars(
  _self : PdfTextUtil,
  c : Int,
) -> Array[Int] raise {
  if c <= 0x7f {
    [c]
  } else if c <= 0x7ff {
    [(c >> 6) | 0b1100_0000, (c & 0b11_1111) | 0b1000_0000]
  } else if c <= 0xffff {
    [
      (c >> 12) | 0b1110_0000,
      ((c >> 6) & 0b00_1111_11) | 0b1000_0000,
      (c & 0b00_1111_11) | 0b1000_0000,
    ]
  } else if c <= 0x10ffff {
    [
      (c >> 18) | 0b1111_0000,
      ((c >> 12) & 0b00_1111_11) | 0b1000_0000,
      ((c >> 6) & 0b00_1111_11) | 0b1000_0000,
      (c & 0b00_1111_11) | 0b1000_0000,
    ]
  } else {
    raise @pdf.PdfError::Msg("bad unicode codepoint")
  }
}

///|
pub fn PdfTextUtil::utf8_of_codepoints(
  self : PdfTextUtil,
  codepoints : Array[Int],
) -> String raise {
  let bytes = @pdfio.bytes_of_int_array(
    flatten_int_arrays(codepoints.map(cp => self.get_utf8_chars(cp))),
  )
  @utf8.decode(Bytes::from_array(bytes[:])[:], ignore_bom=true)
}

///|
pub fn PdfTextUtil::codepoints_of_pdfdocstring(
  self : PdfTextUtil,
  s : String,
) -> Array[Int] raise {
  if self.is_unicode(s) {
    let body = s[2:].to_string()
    self.codepoints_of_utf16be(body)
  } else {
    let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(s))
    bytes.map(cp => self.codepoint_of_pdfdocencoding_character(cp))
  }
}

///|
pub fn PdfTextUtil::utf8_of_pdfdocstring(
  self : PdfTextUtil,
  s : String,
) -> String raise {
  self.utf8_of_codepoints(self.codepoints_of_pdfdocstring(s))
}

///|
fn codepoints_of_utf8_inner(values : Array[Int]) -> Array[Int] raise {
  let out = Array::new()
  let mut i = 0
  while i < values.length() {
    let c = values[i]
    if c >> 7 == 0 {
      out.push(c)
      i = i + 1
    } else if i + 1 < values.length() &&
      c >> 5 == 0b110 &&
      values[i + 1] >> 6 == 0b10 {
      let c2 = values[i + 1]
      out.push(((c & 0b0001_1111) << 6) | (c2 & 0b00_1111_11))
      i = i + 2
    } else if i + 2 < values.length() &&
      c >> 4 == 0b1110 &&
      values[i + 1] >> 6 == 0b10 &&
      values[i + 2] >> 6 == 0b10 {
      let c2 = values[i + 1]
      let c3 = values[i + 2]
      out.push(
        ((c & 0b0000_1111) << 12) |
        ((c2 & 0b00_1111_11) << 6) |
        (c3 & 0b00_1111_11),
      )
      i = i + 3
    } else if i + 3 < values.length() &&
      c >> 3 == 0b11110 &&
      values[i + 1] >> 6 == 0b10 &&
      values[i + 2] >> 6 == 0b10 &&
      values[i + 3] >> 6 == 0b10 {
      let c2 = values[i + 1]
      let c3 = values[i + 2]
      let c4 = values[i + 3]
      out.push(
        ((c & 0b00000_111) << 18) |
        ((c2 & 0b00_1111_11) << 12) |
        ((c3 & 0b00_1111_11) << 6) |
        (c4 & 0b00_1111_11),
      )
      i = i + 4
    } else {
      raise @pdf.PdfError::Msg("Bad UTF8 in codepoints_of_utf8")
    }
  }
  out
}

///|
pub fn PdfTextUtil::codepoints_of_utf8(
  _self : PdfTextUtil,
  s : String,
) -> Array[Int] raise {
  let bytes = @utf8.encode(s)
  let values = @pdfio.int_array_of_bytes(@pdfio.bytes_of_caml_bytes(bytes))
  codepoints_of_utf8_inner(values)
}

///|
pub fn PdfTextUtil::pdfdocstring_of_codepoints(
  self : PdfTextUtil,
  codepoints : Array[Int],
) -> String raise {
  let reverse_glyph_hashes = @pdfglyphlist.PdfGlyphList::new().reverse_glyph_hashes()
  let encoded = Array::new()
  for c in codepoints {
    match reverse_glyph_hashes.get([c]) {
      Some(name) =>
        match @pdfglyphlist.name_to_pdf_hashes.get(name) {
          Some(code) => encoded.push(code)
          None => return self.utf16be_of_codepoints(codepoints)
        }
      None => return self.utf16be_of_codepoints(codepoints)
    }
  }
  @pdfio.string_of_bytes(@pdfio.bytes_of_int_array(encoded))
}

///|
pub fn PdfTextUtil::pdfdocstring_of_utf8(
  self : PdfTextUtil,
  s : String,
) -> String raise {
  self.pdfdocstring_of_codepoints(self.codepoints_of_utf8(s))
}

///|
pub fn PdfTextUtil::simplify_utf16be(
  self : PdfTextUtil,
  s : String,
) -> String raise {
  if self.is_unicode(s) {
    self.pdfdocstring_of_utf8(self.utf8_of_pdfdocstring(s))
  } else {
    s
  }
}
