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
/// 去掉中文/全角符号之间的“字间空格”
pub fn remove_cjk_inner_spaces(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }

  let mut out = ""
  let mut i = 0
  while i < n {
    let c = cs[i]

    if c == ' ' {
      if i > 0 && i + 1 < n {
        let prev = cs[i - 1]
        let next = cs[i + 1]
        if is_cjkish(prev) && is_cjkish(next) {
          i = i + 1
          continue
        }
      }
      out = out + " "
      i = i + 1
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}

///|
/// 粗略判断“中文相关字符”：CJK 汉字,全角区（含中文标点）,常见中文标点
pub fn is_cjkish(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) || // CJK Unified
  (x >= 0x3400 && x <= 0x4DBF) || // Extension A
  (x >= 0xF900 && x <= 0xFAFF) || // Compatibility
  (x >= 0xFF00 && x <= 0xFFEF) || // Half/Full width
  c == '，' ||
  c == '。' ||
  c == '；' ||
  c == '：' ||
  c == '！' ||
  c == '？'
}

///|
pub fn normalize_text(s : String) -> String {
  s.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}

///|
/// 段落最后做一次清理：多空格折叠 + trim（字符级，不走 bytes）
pub fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  remove_cjk_inner_spaces(out.trim().to_string())
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

///|
/// “短行”判断：<=2 个字符（对付中文被切成单字/两字的情况）
pub fn is_short(s : String) -> Bool {
  let t = s.trim()
  if t == "" {
    return true
  }
  t.to_array().length() <= 2
}

///|
/// 决定拼接时加不加空格：
/// - CJK + CJK：不加空格（中文不应该被强行加空格）
/// - 其他情况：加一个空格
pub fn glue_between(left : String, right : String) -> String {
  let lc = last_char(left)
  let rc = first_char(right)
  match (lc, rc) {
    (Some(a), Some(b)) =>
      if is_cjk(a) && is_cjk(b) { "" } else { " " }
    _ => " "
  }
}

pub fn first_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  if arr.length() == 0 { None } else { Some(arr[0]) }
}

///|
pub fn last_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  let n = arr.length()
  if n == 0 {
    None
  } else {
    Some(arr[n - 1])
  }
}

///|
/// 粗略 CJK 判定（足够 MVP）
/// 覆盖：CJK Unified / Extensions / 常用全角符号区
pub fn is_cjk(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) ||
  (x >= 0x3400 && x <= 0x4DBF) ||
  (x >= 0xF900 && x <= 0xFAFF) ||
  (x >= 0xFF00 && x <= 0xFFEF)
}


