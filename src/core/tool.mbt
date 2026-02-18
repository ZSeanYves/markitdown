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


///|
/// 段落最后做一次清理：多空格折叠 + trim
pub fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  // 折叠连续空格（不引入 regex，手写）
  let mut out = ""
  let mut prev_space = false
  for ch in @utf8.encode(t) {
    if ch == 32 { // ' '
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + ch.to_string() // 若你的 String 没 from_char，见下方替代
      prev_space = false
    }
  }
  out.trim().to_string()
}

///|
/// buf 是否以 ASCII '-' 结尾
pub fn ends_with_hyphen(s : String) -> Bool {
  let bs = @utf8.encode(s)
  if bs.length() == 0 {
    return false
  }
  bs[bs.length() - 1] == 45 // '-'
}

///|
/// 删除最后一个字符（按字节删，适用于 ASCII '-'）
pub fn drop_last_char(s : String) -> String raise Error {
  let bs = @utf8.encode(s)
  if bs.length() == 0 {
    return s
  }
  s[:bs.length() - 1].to_string()
}
