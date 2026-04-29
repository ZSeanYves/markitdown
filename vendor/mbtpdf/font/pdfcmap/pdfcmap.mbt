///|
/// Parse /ToUnicode CMaps.

///|
pub struct CMap {
  map : Array[(String, String)]
  wmode : Int?
} derive(Debug)

///|
priv enum Section {
  BfChar(ArrayView[Char])
  BfRange(ArrayView[Char])
}

///|
fn is_whitespace(c : Char) -> Bool {
  let v = c.to_int()
  v == 0 || v == 9 || v == 10 || v == 12 || v == 13 || v == 32
}

///|
fn match_at(
  chars : ArrayView[Char],
  index : Int,
  token : ArrayView[Char],
) -> Bool {
  if index + token.length() > chars.length() {
    return false
  }
  for i in 0..<token.length() {
    if chars[index + i] != token[i] {
      return false
    }
  }
  true
}

///|
fn get_until(
  chars : ArrayView[Char],
  start : Int,
  end_token : ArrayView[Char],
) -> (ArrayView[Char], Int) {
  let mut i = start
  while i + end_token.length() <= chars.length() {
    if match_at(chars, i, end_token) {
      return (chars[start:i], i + end_token.length())
    }
    i = i + 1
  }
  (chars[start:], chars.length())
}

///|
let bfchar_token : Array[Char] = "beginbfchar".to_array()

///|
let end_bfchar_token : Array[Char] = "endbfchar".to_array()

///|
let bfrange_token : Array[Char] = "beginbfrange".to_array()

///|
let end_bfrange_token : Array[Char] = "endbfrange".to_array()

///|
let wmode_token : Array[Char] = "/WMode ".to_array()

///|
fn get_section(chars : ArrayView[Char], start : Int) -> (Section, Int)? {
  let mut i = start
  while i < chars.length() {
    if match_at(chars, i, bfchar_token) {
      let (numbers, next) = get_until(
        chars,
        i + bfchar_token.length(),
        end_bfchar_token,
      )
      return Some((Section::BfChar(numbers), next))
    }
    if match_at(chars, i, bfrange_token) {
      let (numbers, next) = get_until(
        chars,
        i + bfrange_token.length(),
        end_bfrange_token,
      )
      return Some((Section::BfRange(numbers), next))
    }
    i = i + 1
  }
  None
}

///|
fn get_sections(chars : ArrayView[Char]) -> Array[Section] {
  let sections = Array::new()
  let mut pos = 0
  while true {
    match get_section(chars, pos) {
      None => break
      Some((section, next)) => {
        sections.push(section)
        pos = next
      }
    }
  }
  sections
}

///|
fn skip_whitespace(chars : ArrayView[Char], start : Int) -> Int {
  let mut i = start
  while i < chars.length() && is_whitespace(chars[i]) {
    i = i + 1
  }
  i
}

///|
fn read_hex_bytes(
  chars : ArrayView[Char],
  start : Int,
) -> (Array[Int], Int) raise {
  let mut i = skip_whitespace(chars, start)
  if i >= chars.length() {
    fail("Not_found")
  }
  if chars[i] != '<' {
    raise @pdf.PdfError::Msg("Unknown number in /ToUnicode")
  }
  i = i + 1
  let hex_chars = Array::new()
  while i < chars.length() && chars[i] != '>' {
    if !is_hex_digit(chars[i]) {
      raise @pdf.PdfError::Msg("Bad hex value")
    }
    hex_chars.push(chars[i])
    i = i + 1
  }
  if i >= chars.length() {
    raise @pdf.PdfError::Msg("Unknown number in /ToUnicode")
  }
  if hex_chars.length() == 0 || hex_chars.length() % 2 != 0 {
    raise @pdf.PdfError::Msg("Bad hex value")
  }
  let bytes = Array::new()
  for j = 0; j < hex_chars.length(); j = j + 2 {
    let hex_str = String::from_array(hex_chars[j:j + 2].to_array())
    let value = @strconv.parse_int(hex_str, base=16)
    bytes.push(value)
  }
  (bytes, i + 1)
}

///|
fn is_hex_digit(c : Char) -> Bool {
  c.is_ascii_hexdigit()
}

///|
fn read_code(chars : ArrayView[Char], start : Int) -> (String, Int) raise {
  let (bytes, next) = read_hex_bytes(chars, start)
  (@pdfio.string_of_int_array(bytes), next)
}

///|
fn read_code_opt(chars : ArrayView[Char], start : Int) -> (String, Int)? {
  let mut i = skip_whitespace(chars, start)
  while i < chars.length() {
    if chars[i] == '<' {
      let result : Result[(String, Int), Error] = try? read_code(chars, i)
      match result {
        Ok(value) => return Some(value)
        Err(_) => i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  None
}

///|
fn read_unicode_opt(chars : ArrayView[Char], start : Int) -> (String, Int)? {
  let mut i = skip_whitespace(chars, start)
  while i < chars.length() {
    if chars[i] == '<' {
      let result : Result[(String, Int), Error] = try? read_code(chars, i)
      match result {
        Ok(value) => return Some(value)
        Err(_) => i = i + 1
      }
    } else {
      i = i + 1
    }
  }
  None
}

///|
fn code_bytes_of_string(code : String) -> Array[Int] {
  @pdfio.int_array_of_bytes(@pdfio.bytes_of_string(code))
}

///|
fn code_int_of_string(code : String) -> Int {
  let bytes = code_bytes_of_string(code)
  let mut value = 0
  for b in bytes {
    value = (value << 8) | b
  }
  value
}

///|
fn code_string_of_int(value : Int, length : Int) -> String {
  let bytes = Array::new(capacity=length)
  let mut v = value
  for _ in 0..<length {
    bytes.push(v & 0xff)
    v = v >> 8
  }
  @pdfio.string_of_int_array(bytes.rev())
}

///|
fn increment_code(code : String, delta : Int) -> String {
  if code.length() == 0 {
    return ""
  }
  let length = @pdfio.bytes_of_string(code).length()
  code_string_of_int(code_int_of_string(code) + delta, length)
}

///|
fn pairs_of_section(section : Section) -> Array[(String, String)] {
  match section {
    Section::BfChar(numbers) => {
      let results = Array::new()
      let mut pos = 0
      while true {
        match read_code_opt(numbers, pos) {
          None => break
          Some((code, rest)) =>
            match read_unicode_opt(numbers, rest) {
              Some((str, rest2)) => {
                results.push((code, str))
                pos = rest2
              }
              None => pos = rest
            }
        }
      }
      results
    }
    Section::BfRange(numbers) => {
      let results = Array::new()
      let mut pos = 0
      fn find_dest_marker(
        chars : ArrayView[Char],
        start : Int,
      ) -> (Char, Int)? {
        let mut i = skip_whitespace(chars, start)
        while i < chars.length() {
          match chars[i] {
            '<' | '[' => return Some((chars[i], i))
            _ => i = i + 1
          }
        }
        None
      }

      fn skip_to_close_bracket(chars : ArrayView[Char], start : Int) -> Int {
        let mut i = start
        while i < chars.length() && chars[i] != ']' {
          i = i + 1
        }
        if i < chars.length() {
          i + 1
        } else {
          chars.length()
        }
      }

      while true {
        match read_code_opt(numbers, pos) {
          None => break
          Some((src1, rest1)) =>
            match read_code_opt(numbers, rest1) {
              None => break
              Some((src2, rest2)) => {
                let src1_value = code_int_of_string(src1)
                let src2_value = code_int_of_string(src2)
                if src1_value > src2_value {
                  pos = rest2
                  continue
                }
                match find_dest_marker(numbers, rest2) {
                  None => break
                  Some((marker, idx)) =>
                    match marker {
                      '<' =>
                        match read_unicode_opt(numbers, idx) {
                          Some((code, rest3)) => {
                            let src_len = @pdfio.bytes_of_string(src1).length()
                            let dest_len = @pdfio.bytes_of_string(code).length()
                            let mut d = 0
                            while d <= src2_value - src1_value {
                              results.push(
                                (
                                  code_string_of_int(src1_value + d, src_len),
                                  code_string_of_int(
                                    code_int_of_string(code) + d,
                                    dest_len,
                                  ),
                                ),
                              )
                              d = d + 1
                            }
                            pos = rest3
                          }
                          None => pos = idx + 1
                        }
                      '[' => {
                        let mut rest = idx + 1
                        let mut d = 0
                        while d <= src2_value - src1_value {
                          match read_unicode_opt(numbers, rest) {
                            Some((num, rest3)) => {
                              let src_code = increment_code(src1, d)
                              results.push((src_code, num))
                              rest = rest3
                              d = d + 1
                            }
                            None => break
                          }
                        }
                        pos = skip_to_close_bracket(numbers, rest)
                      }
                      _ => pos = rest2
                    }
                }
              }
            }
        }
      }
      results
    }
  }
}

///|
fn extract_specifics(data : @pdfio.MutableBytes) -> Int? {
  let chars = @pdfio.charlist_of_bytes(data)
  let mut i = 0
  while i + wmode_token.length() <= chars.length() {
    if match_at(chars, i, wmode_token) {
      let mut j = i + wmode_token.length()
      let digits = Array::new()
      while j < chars.length() && chars[j].is_ascii_digit() {
        digits.push(chars[j])
        j = j + 1
      }
      if digits.length() > 0 {
        let parsed : Result[Int, Error] = try? @strconv.parse_int(
          String::from_array(digits),
          base=10,
        )
        match parsed {
          Ok(value) => return Some(value)
          Err(_) => return None
        }
      }
    }
    i = i + 1
  }
  None
}

///|
pub fn CMap::parse(pdf : @pdf.Pdf, cmap : @pdf.PdfObject) -> CMap raise {
  match cmap {
    @pdf.PdfObject::Stream(_) => {
      @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, cmap)
      match cmap {
        @pdf.PdfObject::Stream(r) => {
          let (_dict, contents) = r.val
          match contents {
            @pdf.Stream::Got(data) => {
              let wmode = extract_specifics(data)
              let chars = @pdfio.charlist_of_bytes(data).filter(c => !is_whitespace(
                c,
              ))
              let sections = get_sections(chars)
              let pairs = Array::new()
              for section in sections {
                pairs.append(pairs_of_section(section))
              }
              { map: pairs, wmode }
            }
            @pdf.Stream::ToGet(_) => {
              cmap.getstream()
              CMap::parse(pdf, cmap)
            }
          }
        }
        _ => raise @pdf.PdfError::Msg("Bad /ToUnicode")
      }
    }
    _ => raise @pdf.PdfError::Msg("Bad /ToUnicode \{cmap.to_string()}")
  }
}
