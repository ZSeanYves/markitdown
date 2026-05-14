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
  simple_font_gbk_signal : Bool
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
  @pdfio.string_of_int_array(bytes[start:start + length].to_owned())
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
fn is_unicode_noncharacter(codepoint : Int) -> Bool {
  (codepoint >= 0xfdd0 && codepoint <= 0xfdef) ||
  (codepoint >= 0xfffe && (codepoint & 0xffff) >= 0xfffe)
}

///|
fn usable_tounicode_codepoints(value : String) -> Array[Int]? {
  try {
    let codepoints = PdfTextUtil::new().codepoints_of_utf16be(value)
    for codepoint in codepoints {
      if is_unicode_noncharacter(codepoint) {
        return None
      }
    }
    Some(codepoints)
  } catch {
    _ => None
  }
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
  let convert = (i : Int) => {
    try {
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
  }
  let tounicode = PdfTextUtil::new().find_tounicode_bytes(font)
  let tounicode_lengths = match PdfTextUtil::new().find_tounicode_cmap(font) {
    Some(cmap) =>
      if cmap.code_space_lengths.is_empty() {
        match tounicode {
          Some(map) => tounicode_length_list(map)
          None => []
        }
      } else {
        cmap.code_space_lengths
      }
    None =>
      match tounicode {
        Some(map) => tounicode_length_list(map)
        None => []
      }
  }
  let simple_font_gbk_signal = simple_font_may_use_gbk(font)
  { convert, tounicode, tounicode_lengths, font, simple_font_gbk_signal }
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
fn is_ascii_latin_letter(codepoint : Int) -> Bool {
  (codepoint >= 65 && codepoint <= 90) || (codepoint >= 97 && codepoint <= 122)
}

///|
fn is_cjk_codepoint(codepoint : Int) -> Bool {
  (codepoint >= 0x3400 && codepoint <= 0x4dbf) ||
  (codepoint >= 0x4e00 && codepoint <= 0x9fff) ||
  (codepoint >= 0xf900 && codepoint <= 0xfaff)
}

///|
fn is_east_asian_wide_or_punct_codepoint(codepoint : Int) -> Bool {
  (codepoint >= 0x3000 && codepoint <= 0x303f) ||
  (codepoint >= 0xff01 && codepoint <= 0xffee) ||
  (codepoint >= 0x2010 && codepoint <= 0x203b) ||
  codepoint == 0x00b7
}

///|
fn is_gbk_signal_codepoint(codepoint : Int) -> Bool {
  is_cjk_codepoint(codepoint) ||
  is_east_asian_wide_or_punct_codepoint(codepoint)
}

///|
fn count_high_bit_bytes(bytes : Array[Int]) -> Int {
  let mut count = 0
  for b in bytes {
    if b >= 0x80 {
      count = count + 1
    }
  }
  count
}

///|
fn count_cjk_codepoints(codepoints : Array[Int]) -> Int {
  let mut count = 0
  for codepoint in codepoints {
    if is_gbk_signal_codepoint(codepoint) {
      count = count + 1
    }
  }
  count
}

///|
fn has_only_single_byte_ascii_tail(bytes : Array[Int]) -> Bool {
  if bytes.length() <= 1 {
    return false
  }
  let last = bytes[bytes.length() - 1]
  if last > 0x7f {
    return false
  }
  let prefix_len = bytes.length() - 1
  prefix_len % 2 == 0
}

///|
fn trim_single_ascii_tail(bytes : Array[Int]) -> (Array[Int], Array[Int]) {
  if !has_only_single_byte_ascii_tail(bytes) {
    return (bytes, [])
  }
  (bytes[:bytes.length() - 1].to_owned(), [bytes[bytes.length() - 1]])
}

///|
fn decoded_bytes_have_useful_ascii_word_signal(codepoints : Array[Int]) -> Bool {
  let mut ascii_letters = 0
  for codepoint in codepoints {
    if is_ascii_latin_letter(codepoint) {
      ascii_letters = ascii_letters + 1
    }
  }
  let common_words = count_common_ascii_words(codepoints)
  let words = count_ascii_words(codepoints)
  common_words > 0 || (words >= 2 && ascii_letters >= 6)
}

///|
fn is_pdf_name_hex_escape(s : String, start : Int) -> Bool {
  let chars = s.to_array()
  start + 2 < s.length() &&
  chars[start] == '#' &&
  is_hex_digit(chars[start + 1]) &&
  is_hex_digit(chars[start + 2])
}

///|
fn is_hex_digit(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'a' && ch <= 'f') ||
  (ch >= 'A' && ch <= 'F')
}

///|
fn count_pdf_name_hex_escapes(name : String) -> Int {
  let mut count = 0
  let mut i = 0
  while i + 2 < name.length() {
    if is_pdf_name_hex_escape(name, i) {
      count = count + 1
      i = i + 3
    } else {
      i = i + 1
    }
  }
  count
}

///|
fn count_non_ascii_bytes_in_string(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch.to_int() > 0x7f {
      count = count + 1
    }
  }
  count
}

///|
fn contains_ascii_ci(haystack : String, needle : String) -> Bool {
  let hay = haystack.to_array()
  let ned = needle.to_array()
  if ned.length() == 0 || hay.length() < ned.length() {
    return false
  }
  let mut i = 0
  while i + ned.length() <= hay.length() {
    let mut matched = true
    let mut j = 0
    while matched && j < ned.length() {
      let h = ascii_lower_codepoint(hay[i + j].to_int())
      let n = ascii_lower_codepoint(ned[j].to_int())
      if h != n {
        matched = false
      }
      j = j + 1
    }
    if matched {
      return true
    }
    i = i + 1
  }
  false
}

///|
fn basefont_has_gbk_signal(basefont : String) -> Bool {
  contains_ascii_ci(basefont, "gb2312") ||
  contains_ascii_ci(basefont, "gbk") ||
  contains_ascii_ci(basefont, "song") ||
  contains_ascii_ci(basefont, "fang") ||
  contains_ascii_ci(basefont, "hei") ||
  contains_ascii_ci(basefont, "kai") ||
  count_non_ascii_bytes_in_string(basefont) >= 2 ||
  count_pdf_name_hex_escapes(basefont) >= 2
}

///|
fn simple_font_may_use_gbk(font : @pdffont.Font) -> Bool {
  match font {
    SimpleFont(simple) => basefont_has_gbk_signal(simple.basefont)
    _ => false
  }
}

///|
fn conservative_gbk_codepoints(
  extractor : TextExtractor,
  text : String,
) -> Array[Int]? {
  if !extractor.simple_font_gbk_signal || extractor.tounicode is Some(_) {
    return None
  }
  let bytes = @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(text))
  if bytes.length() < 2 || count_high_bit_bytes(bytes) < 2 {
    return None
  }
  let (main_bytes, ascii_tail) = trim_single_ascii_tail(bytes)
  if main_bytes.length() < 2 || main_bytes.length() % 2 != 0 {
    return None
  }
  let baseline = Array::new(capacity=main_bytes.length())
  for b in main_bytes {
    baseline.push((extractor.convert)(b).1[0])
  }
  if decoded_bytes_have_useful_ascii_word_signal(baseline) {
    return None
  }
  match PdfTextUtil::new().codepoints_of_gbk(main_bytes) {
    Some(codepoints) => {
      let cjk_count = count_cjk_codepoints(codepoints)
      if cjk_count == 0 || cjk_count * 2 < codepoints.length() {
        return None
      }
      let out = Array::new(capacity=codepoints.length() + ascii_tail.length())
      out.append(codepoints)
      out.append(ascii_tail)
      Some(out)
    }
    None => None
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
fn TextExtractor::uses_multibyte_tounicode_fallback(
  self : TextExtractor,
) -> Bool {
  match self.font {
    CIDKeyedFont(_, _, _) => true
    _ => false
  }
}

///|
fn TextExtractor::fallback_tounicode_length(
  self : TextExtractor,
  lengths : Array[Int],
  remaining : Int,
) -> Int {
  if self.uses_multibyte_tounicode_fallback() &&
    lengths.length() == 1 &&
    lengths[0] > 1 &&
    lengths[0] <= remaining {
    lengths[0]
  } else {
    1
  }
}

///|
fn TextExtractor::fallback_pair_for_code_unit(
  self : TextExtractor,
  bytes : Array[Int],
  start : Int,
  length : Int,
) -> (String, Array[Int]) {
  if !self.uses_multibyte_tounicode_fallback() {
    return (self.convert)(bytes[start])
  }
  let raw = bytes_slice_to_string(bytes, start, length)
  match codepoints_of_predefined_cmap(self.font, raw) {
    Some(codepoints) =>
      if codepoints.length() > 0 {
        (".notdef", codepoints)
      } else if length > 1 || is_identity_h(self.font) {
        (self.convert)(code_int_of_string(raw))
      } else {
        (self.convert)(bytes[start])
      }
    None =>
      if length > 1 || is_identity_h(self.font) {
        (self.convert)(code_int_of_string(raw))
      } else {
        (self.convert)(bytes[start])
      }
  }
}

///|
fn ascii_lower_codepoint(codepoint : Int) -> Int {
  if codepoint >= 65 && codepoint <= 90 {
    codepoint + 32
  } else {
    codepoint
  }
}

///|
fn lower_ascii_word_equals(word : Array[Int], expected : String) -> Bool {
  let chars = expected.to_array()
  if word.length() != chars.length() {
    return false
  }
  for i in 0..<word.length() {
    if word[i] != chars[i].to_int() {
      return false
    }
  }
  true
}

///|
fn is_common_ascii_word(word : Array[Int]) -> Bool {
  lower_ascii_word_equals(word, "a") ||
  lower_ascii_word_equals(word, "an") ||
  lower_ascii_word_equals(word, "and") ||
  lower_ascii_word_equals(word, "are") ||
  lower_ascii_word_equals(word, "as") ||
  lower_ascii_word_equals(word, "at") ||
  lower_ascii_word_equals(word, "be") ||
  lower_ascii_word_equals(word, "by") ||
  lower_ascii_word_equals(word, "for") ||
  lower_ascii_word_equals(word, "from") ||
  lower_ascii_word_equals(word, "have") ||
  lower_ascii_word_equals(word, "in") ||
  lower_ascii_word_equals(word, "is") ||
  lower_ascii_word_equals(word, "not") ||
  lower_ascii_word_equals(word, "of") ||
  lower_ascii_word_equals(word, "on") ||
  lower_ascii_word_equals(word, "or") ||
  lower_ascii_word_equals(word, "that") ||
  lower_ascii_word_equals(word, "the") ||
  lower_ascii_word_equals(word, "this") ||
  lower_ascii_word_equals(word, "to") ||
  lower_ascii_word_equals(word, "will") ||
  lower_ascii_word_equals(word, "with")
}

///|
fn count_common_ascii_words(codepoints : Array[Int]) -> Int {
  let mut count = 0
  let mut word = Array::new()
  for codepoint in codepoints {
    let lowered = ascii_lower_codepoint(codepoint)
    if lowered >= 97 && lowered <= 122 {
      word.push(lowered)
    } else if word.length() > 0 {
      if is_common_ascii_word(word) {
        count = count + 1
      }
      word = Array::new()
    }
  }
  if word.length() > 0 && is_common_ascii_word(word) {
    count = count + 1
  }
  count
}

///|
fn count_ascii_words(codepoints : Array[Int]) -> Int {
  let mut count = 0
  let mut inside_word = false
  for codepoint in codepoints {
    let lowered = ascii_lower_codepoint(codepoint)
    if lowered >= 97 && lowered <= 122 {
      if !inside_word {
        count = count + 1
        inside_word = true
      }
    } else {
      inside_word = false
    }
  }
  count
}

///|
fn ascii_shift_score(codepoints : Array[Int]) -> (Int, Int, Int, Int, Int)? {
  let mut spaces = 0
  let mut lowercase = 0
  let mut uppercase = 0
  let mut digits = 0
  let mut punctuation = 0
  for codepoint in codepoints {
    if codepoint < 32 || codepoint > 126 {
      return None
    }
    if codepoint == 32 {
      spaces = spaces + 1
    } else if codepoint >= 97 && codepoint <= 122 {
      lowercase = lowercase + 1
    } else if codepoint >= 65 && codepoint <= 90 {
      uppercase = uppercase + 1
    } else if codepoint >= 48 && codepoint <= 57 {
      digits = digits + 1
    } else {
      punctuation = punctuation + 1
    }
  }
  let common_words = count_common_ascii_words(codepoints)
  let words = count_ascii_words(codepoints)
  let score = spaces * 6 +
    lowercase * 3 +
    uppercase +
    digits +
    punctuation +
    common_words * 12
  Some((score, spaces, lowercase, common_words, words))
}

///|
fn rescued_identity_h_ascii_codepoints(raw_codes : Array[Int]) -> Array[Int]? {
  if raw_codes.length() < 8 {
    return None
  }
  for code in raw_codes {
    if code <= 0 || code > 255 {
      return None
    }
  }
  let mut baseline_score = -1000
  let mut baseline_spaces = 0
  let mut baseline_common_words = 0
  match ascii_shift_score(raw_codes) {
    Some((score, spaces, _, common_words, _)) => {
      baseline_score = score
      baseline_spaces = spaces
      baseline_common_words = common_words
    }
    None => ()
  }
  if baseline_spaces > 0 && baseline_common_words > 0 {
    return None
  }
  let mut best_score = baseline_score
  let mut best_shift = 0
  let mut best_spaces = 0
  let mut best_lowercase = 0
  let mut best_common_words = 0
  let mut best_words = 0
  for shift in 1..<=95 {
    let shifted = Array::new(capacity=raw_codes.length())
    for code in raw_codes {
      shifted.push(code + shift)
    }
    match ascii_shift_score(shifted) {
      Some((score, spaces, lowercase, common_words, words)) =>
        if score > best_score {
          best_score = score
          best_shift = shift
          best_spaces = spaces
          best_lowercase = lowercase
          best_common_words = common_words
          best_words = words
        }
      None => ()
    }
  }
  if best_shift == 0 {
    return None
  }
  if best_score < baseline_score + 24 {
    return None
  }
  if best_spaces == 0 || best_lowercase < 3 {
    return None
  }
  if best_common_words == 0 {
    return None
  }
  if best_common_words == 1 &&
    (best_words < 2 || raw_codes.length() < 12 || best_lowercase < 6) {
    return None
  }
  let rescued = Array::new(capacity=raw_codes.length())
  for code in raw_codes {
    rescued.push(code + best_shift)
  }
  Some(rescued)
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
                match usable_tounicode_codepoints(value) {
                  Some(codepoints) => {
                    out.push(("/" + value, codepoints))
                    i = i + length
                  }
                  None => {
                    let fallback_length = if self.uses_multibyte_tounicode_fallback() {
                      length
                    } else {
                      1
                    }
                    out.push(
                      self.fallback_pair_for_code_unit(
                        bytes, i, fallback_length,
                      ),
                    )
                    i = i + fallback_length
                  }
                }
                matched = true
                break
              }
              None => ()
            }
          }
        }
        if !matched {
          let length = self.fallback_tounicode_length(
            self.tounicode_lengths,
            bytes.length() - i,
          )
          out.push(self.fallback_pair_for_code_unit(bytes, i, length))
          i = i + length
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
            let raw_codes = Array::new(capacity=bytes.length() / 2)
            let out = Array::new(capacity=bytes.length() / 2)
            let mut i = 0
            while i < bytes.length() {
              let code = (bytes[i] << 8) | bytes[i + 1]
              raw_codes.push(code)
              out.push((self.convert)(code))
              i = i + 2
            }
            let mut rescue_allowed = true
            for i in 0..<out.length() {
              let pair = out[i]
              if pair.1.length() != 1 || pair.1[0] != raw_codes[i] {
                rescue_allowed = false
                break
              }
            }
            if rescue_allowed {
              match rescued_identity_h_ascii_codepoints(raw_codes) {
                Some(rescued) => {
                  let rescued_pairs = Array::new(capacity=out.length())
                  for i in 0..<out.length() {
                    rescued_pairs.push((out[i].0, [rescued[i]]))
                  }
                  rescued_pairs
                }
                None => out
              }
            } else {
              out
            }
          } else if self.simple_font_gbk_signal {
            match conservative_gbk_codepoints(self, text) {
              Some(codepoints) => codepoints.map(cp => (".notdef", [cp]))
              None => {
                let out = Array::new(capacity=text.length())
                for c in text {
                  out.push((self.convert)(c.to_int()))
                }
                out
              }
            }
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
      let reversed = Array::new()
      for pair in parsed_list {
        match usable_tounicode_codepoints(pair.1) {
          Some(codepoints) =>
            reversed.push((codepoints, code_int_of_string(pair.0)))
          None => ()
        }
      }
      (
        @pdfutil.PdfUtil::new().hashtable_of_dictionary(reversed),
        reversed.length() > 0,
      )
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
    let body = s[2:].to_owned()
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
