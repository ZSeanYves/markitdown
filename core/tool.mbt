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
  let t = normalize_text(s)
  let parts = t
    .split("\n")
    .map(fn(x) { trim_string(escape_pipes(x.to_string())) })
    .filter(fn(x) { x != "" })

  parts.join("<br>")
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
pub fn next_image_asset_rel_path(next_idx : Ref[Int], ext_raw : String) -> String {
  let ext = normalize_image_ext(ext_raw)
  let idx = next_idx.val + 1
  next_idx.val = idx
  "assets/" + "image" + pad_image_index(idx) + "." + ext
}

///|
pub fn next_image_asset_rel_path_unique(
  next_idx : Ref[Int],
  ext_raw : String,
  out_dir : String,
) -> String {
  let ext = normalize_image_ext(ext_raw)
  let mut idx = next_idx.val
  while true {
    idx += 1
    let rel = "assets/" + "image" + pad_image_index(idx) + "." + ext
    let abs = out_dir + "/" + rel
    if !@fs.path_exists(abs) {
      next_idx.val = idx
      return rel
    }
  }
  ""
}

///|
fn normalize_image_ext(ext_raw : String) -> String {
  let t = ext_raw.trim().to_lower()
  if t == "" {
    return "img"
  }
  if t.has_prefix(".") {
    t[1:].to_string()
  } else {
    t.to_string()
  }
}

///|
fn pad_image_index(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
pub fn utf8_bytes_to_string(b : Bytes) -> String raise Utf8DecodeError {
  let mut result = ""
  let mut i = 0
  let data = b.to_array()
  let len = data.length()

  while i < len {
    let byte = data[i].to_int()
    if byte < 0x80 {
      result = result + Int::unsafe_to_char(byte).to_string()
      i += 1
    } else if byte >> 5 == 0x6 { // 2-byte
      if i + 1 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 2-byte sequence",
        )
      }
      let byte2 = data[i + 1].to_int()
      if byte2 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation byte at 2-byte sequence",
        )
      }
      let cp = ((byte & 0x1F) << 6) | (byte2 & 0x3F)
      result = result + Int::unsafe_to_char(cp).to_string()
      i += 2
    } else if byte >> 4 == 0xE { // 3-byte
      if i + 2 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 3-byte sequence",
        )
      }
      let byte2 = data[i + 1].to_int()
      let byte3 = data[i + 2].to_int()
      if byte2 >> 6 != 0x2 || byte3 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation bytes at 3-byte sequence",
        )
      }
      let cp = ((byte & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F)
      result = result + Int::unsafe_to_char(cp).to_string()
      i += 3
    } else if byte >> 3 == 0x1E { // 4-byte
      if i + 3 >= len {
        raise Utf8DecodeError(
          "Invalid UTF-8: Unexpected end at 4-byte sequence",
        )
      }
      let byte2 = data[i + 1].to_int()
      let byte3 = data[i + 2].to_int()
      let byte4 = data[i + 3].to_int()
      if byte2 >> 6 != 0x2 || byte3 >> 6 != 0x2 || byte4 >> 6 != 0x2 {
        raise Utf8DecodeError(
          "Invalid UTF-8: Bad continuation bytes at 4-byte sequence",
        )
      }
      let cp = ((byte & 0x07) << 18) |
        ((byte2 & 0x3F) << 12) |
        ((byte3 & 0x3F) << 6) |
        (byte4 & 0x3F)
      if cp > 0xFFFF {
        // 非 BMP：先转成数字实体，交给 xml_unescape->decode_numeric_entities 还原
        result = result + "&#" + cp.to_string() + ";"
      } else {
        result = result + Int::unsafe_to_char(cp).to_string()
      }
      i += 4
    } else {
      raise Utf8DecodeError("Invalid UTF-8: Unknown byte pattern")
    }
  }

  result
}

///|
/// Decode numeric character references: &#1234; and &#x1F600;
pub fn decode_numeric_entities(s : String) -> String {
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
