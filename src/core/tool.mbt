///|
pub fn trim_string(s : String) -> String {
  let normalized = s.replace(old="\u3000", new=" ")
  normalized.trim().to_string()
}

///|
fn escape_pipes(s : String) -> String {
  s.replace(old="|", new="\\|")
}

///|
fn normalize_cell(s : String) -> String {
  trim_string(escape_pipes(s))
}

///|
pub fn is_blank(s : String) -> Bool {
  trim_string(s) == ""
}

///|
pub fn normalize_text(s : String) -> String {
  s.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}

///|
pub fn slice_to_string(chars : Array[Char], l : Int, r : Int) -> String {
  let buf : Ref[Array[Char]] = { val: [] }
  let mut i = l
  while i < r && i < chars.length() {
    buf.val.push(chars[i])
    i += 1
  }
  String::from_array(buf.val)
}

///|
pub fn basename(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' {
      last = i
    }
  }
  if last < 0 {
    path
  } else {
    // 取 last+1 到末尾
    let buf : Array[Char] = []
    for j in (last + 1)..<chars.length() {
      buf.push(chars[j])
    }
    String::from_array(buf)
  }
}

///|
pub fn utf8_bytes_to_string(b : Bytes) -> String raise Utf8DecodeError {
  let mut result = ""
  let mut i = 0
  let data = b.to_array()
  let len = data.length()

  fn u8(x : Byte) -> Int {
    let mut v = x.to_int()
    if v < 0 {
      v = v + 256
    }
    v
  }

  fn append_codepoint(s : String, cp : Int) -> String {
    if cp <= 0xFFFF {
      s + Int::unsafe_to_char(cp).to_string()
    } else {
      // encode as UTF-16 surrogate pair
      let v = cp - 0x10000
      let hi = 0xD800 + (v >> 10)
      let lo = 0xDC00 + (v & 0x3FF)
      s +
      Int::unsafe_to_char(hi).to_string() +
      Int::unsafe_to_char(lo).to_string()
    }
  }

  while i < len {
    let byte = u8(data[i])

    if byte < 0x80 {
      result = append_codepoint(result, byte)
      i += 1
    } else if byte >> 5 == 0x6 { // 2-byte
      if i + 1 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 2-byte sequence",
        )
      }
      let byte2 = u8(data[i + 1])
      if byte2 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation byte at 2-byte sequence",
        )
      }
      let cp = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
      result = append_codepoint(result, cp)
      i += 2
    } else if byte >> 4 == 0xE { // 3-byte
      if i + 2 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 3-byte sequence",
        )
      }
      let byte2 = u8(data[i + 1])
      let byte3 = u8(data[i + 2])
      if byte2 >> 6 != 0x2 || byte3 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation bytes at 3-byte sequence",
        )
      }
      let cp = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
      result = append_codepoint(result, cp)
      i += 3
    } else if byte >> 3 == 0x1E { // 4-byte
      if i + 3 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 4-byte sequence",
        )
      }
      let byte2 = u8(data[i + 1])
      let byte3 = u8(data[i + 2])
      let byte4 = u8(data[i + 3])
      if byte2 >> 6 != 0x2 || byte3 >> 6 != 0x2 || byte4 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation bytes at 4-byte sequence",
        )
      }
      let cp = ((byte & 0x07) << 18) |
        ((byte2 & 0x3F) << 12) |
        ((byte3 & 0x3F) << 6) |
        (byte4 & 0x3F)

      // ✅关键：cp 可能 > 0xFFFF，必须用代理对
      result = append_codepoint(result, cp)
      i += 4
    } else {
      raise Utf8DecodeError("Invalid UTF-8: Unknown byte pattern")
    }
  }

  result
}

///|
/// Decode numeric character references: &#1234; and &#x1F600;
pub fn decode_numeric_entities(s : String) -> String raise {
  let n = s.length()
  let out : Array[Char] = []
  let mut i = 0

  while i < n {
    // try "&#...;"
    if i + 1 < n && s[i] == '&' && s[i + 1] == '#' {
      // find ';'
      let mut j = i + 2
      while j < n && s[j] != ';' {
        j = j + 1
      }

      if j < n && s[j] == ';' {
        let body = s[i + 2:j].to_string().trim().to_string()

        let cp_opt = if body.has_prefix("x") || body.has_prefix("X") {
          parse_hex_int(body[1:].to_string())
        } else {
          parse_dec_int(body)
        }

        match cp_opt {
          Some(cp) => {
            out.push(Int::unsafe_to_char(cp))
            i = j + 1
            continue
          }
          None => () // fallthrough
        }
      }
    }

    // normal char: push char directly (DO NOT use to_string here)
    out.push(
      match s[i].to_char() {
        None => '_' // should not happen for valid UTF-8
        Some(c) => c
      },
    )
    i = i + 1
  }

  String::from_array(out)
}

///|
fn parse_dec_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      acc = acc * 10 + (c.to_int() - '0'.to_int())
      i = i + 1
    } else {
      return None
    }
  }
  Some(acc)
}

///|
fn hex_val(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    return Some(c.to_int() - '0'.to_int())
  }
  if c >= 'a' && c <= 'f' {
    return Some(c.to_int() - 'a'.to_int() + 10)
  }
  if c >= 'A' && c <= 'F' {
    return Some(c.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn parse_hex_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    match hex_val(chars[i]) {
      None => return None
      Some(v) => {
        acc = (acc << 4) | v
        i = i + 1
      }
    }
  }
  Some(acc)
}
