///|
pub fn trim_string(s : String) -> String {
  let normalized = s.replace(old="\u3000", new=" ")
  normalized.trim().to_string()
}

///|
pub fn escape_pipes(s : String) -> String {
  s.replace(old="|", new="\\|")
}

///|
pub fn normalize_cell(s : String) -> String {
  trim_string(escape_pipes(s))
}

///|
pub fn is_blank(s : String) -> Bool {
  trim_string(s) == ""
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
pub fn basename(path: String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' { last = i }
  }
  if last < 0 {
    path
  } else {
    // 取 last+1 到末尾
    let buf: Array[Char] = []
    for j in (last + 1)..<chars.length() {
      buf.push(chars[j])
    }
    String::from_array(buf)
  }
}

///将字节数组转换为字符串，假设它是有效的UTF-8编码。
pub fn utf8_bytes_to_string(b: Bytes) -> String raise Utf8DecodeError {
  let mut result = ""
  let mut i = 0
  let data = b.to_array()
  let len = data.length()

  while i < len {
    let byte = data[i].to_int()
    if byte < 0x80 {
      result = result + Int::unsafe_to_char(byte).to_string()
      i += 1
    } else if (byte >> 5) == 0x6 { // 2-byte
      if i + 1 >= len {
        raise Utf8DecodeError("Invalid UTF-8: Unexpected end at 2-byte sequence")
      }
      let byte2 = data[i+1].to_int()
      if (byte2 >> 6) != 0x2 {
        raise Utf8DecodeError("Invalid UTF-8: Bad continuation byte at 2-byte sequence")
      }
      let cp = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
      result = result + Int::unsafe_to_char(cp).to_string()
      i += 2
    } else if (byte >> 4) == 0xE { // 3-byte
      if i + 2 >= len {
        raise Utf8DecodeError("Invalid UTF-8: Unexpected end at 3-byte sequence")
      }
      let byte2 = data[i+1].to_int()
      let byte3 = data[i+2].to_int()
      if (byte2 >> 6) != 0x2 || (byte3 >> 6) != 0x2 {
        raise Utf8DecodeError("Invalid UTF-8: Bad continuation bytes at 3-byte sequence")
      }
      let cp = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
      result = result + Int::unsafe_to_char(cp).to_string()
      i += 3
    } else if (byte >> 3) == 0x1E { // 4-byte
      if i + 3 >= len {
        raise Utf8DecodeError("Invalid UTF-8: Unexpected end at 4-byte sequence")
      }
      let byte2 = data[i+1].to_int()
      let byte3 = data[i+2].to_int()
      let byte4 = data[i+3].to_int()
      if (byte2 >> 6) != 0x2 || (byte3 >> 6) != 0x2 || (byte4 >> 6) != 0x2 {
        raise Utf8DecodeError("Invalid UTF-8: Bad continuation bytes at 4-byte sequence")
      }
      let cp = ((byte & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F)
      result = result + Int::unsafe_to_char(cp).to_string()
      i += 4
    } else {
      raise Utf8DecodeError("Invalid UTF-8: Unknown byte pattern")
    }
  }

  result
}