///|
pub fn trim_string(s : String) -> String {
  let normalized = s.replace(old="\u3000", new=" ")
  normalized.trim().to_owned()
}

///|
fn escape_pipes(s : String) -> String {
  let out : Array[Char] = []
  for ch in s.to_array() {
    if ch == '|' {
      out.push('\\')
    }
    out.push(ch)
  }
  String::from_array(out)
}

///|
fn normalize_cell(s : String) -> String {
  let t = normalize_text(s)
  let parts = t
    .split("\n")
    .map(fn(x) { trim_string(escape_pipes(x.to_owned())) })
    .filter(fn(x) { x != "" })

  parts.join("<br>")
}

///|
pub fn is_blank(s : String) -> Bool {
  trim_string(s) == ""
}

///|
pub fn normalize_text(s : String) -> String {
  normalize_text_with_profile(s, NormalizeProfile::Literal)
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
pub fn file_ext_lower(path : String) -> String {
  let n = path.length()
  if n == 0 {
    return ""
  }

  let mut i = n - 1
  while i >= 0 {
    if path[i] == '.' {
      if i == n - 1 {
        return ""
      }
      return path[i + 1:].to_owned().to_lower()
    }
    i = i - 1
  }
  ""
}

///|
pub fn known_image_ext_from_path(path : String) -> String? {
  let b = basename(path).to_lower()
  if b.has_suffix(".png") {
    return Some("png")
  }
  if b.has_suffix(".jpg") {
    return Some("jpg")
  }
  if b.has_suffix(".jpeg") {
    return Some("jpeg")
  }
  if b.has_suffix(".gif") {
    return Some("gif")
  }
  if b.has_suffix(".bmp") {
    return Some("bmp")
  }
  if b.has_suffix(".tif") || b.has_suffix(".tiff") {
    return Some("tiff")
  }
  if b.has_suffix(".webp") {
    return Some("webp")
  }
  None
}

///|
pub fn next_image_asset_rel_path(
  next_idx : Ref[Int],
  ext_raw : String,
) -> String {
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
    t[1:].to_owned()
  } else {
    t.to_owned()
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
/// Decode numeric character references: &#1234; and &#x1F600;
pub fn decode_numeric_entities(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let out : Array[Char] = []
  let mut i = 0

  while i < n {
    // try "&#...;"
    if i + 1 < n && chars[i] == '&' && chars[i + 1] == '#' {
      // find ';'
      let mut j = i + 2
      while j < n && chars[j] != ';' {
        j = j + 1
      }

      if j < n && chars[j] == ';' {
        let body = slice_to_string(chars, i + 2, j).trim().to_owned()

        let cp_opt = if body.has_prefix("x") || body.has_prefix("X") {
          parse_hex_int(body[1:].to_owned())
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

    out.push(chars[i])
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
