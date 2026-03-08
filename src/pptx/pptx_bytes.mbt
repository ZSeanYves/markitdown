///|
fn pat(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn find_bytes(hay : Bytes, needle : Bytes, start : Int) -> Int? {
  let n = hay.length()
  let m = needle.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start > n - m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    // compare bytes
    let mut ok = true
    let mut j = 0
    while j < m {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

///|
fn xml_unescape(s : String) -> String raise {
  // 先基础实体，再数字实体（复用你 xlsx 的实现）
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

///|
fn looks_like_slide_title(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  let n = t.to_array().length()
  if n > 40 {
    return false
  }

  if is_bullet_like(t) {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if is_probable_slide_number(t) {
    return false
  }

  true
}

///|
fn is_bullet_like(s : String) -> Bool {
  let t = s.trim().to_string()
  t.has_prefix("• ") ||
  t.has_prefix("· ") ||
  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  t.has_prefix("‣ ") ||
  t.has_prefix("▪ ") ||
  t.has_prefix("● ") ||
  t.has_prefix("○ ") ||
  t.has_prefix("（1）") ||
  t.has_prefix("（2）") ||
  t.has_prefix("（3）") ||
  starts_with_numbered_bullet(t)
}

///|
fn strip_bullet_prefix(s : String) -> String raise {
  let t = s.trim().to_string()

  if t.has_prefix("• ") ||
    t.has_prefix("· ") ||
    t.has_prefix("- ") ||
    t.has_prefix("* ") ||
    t.has_prefix("‣ ") ||
    t.has_prefix("▪ ") ||
    t.has_prefix("● ") ||
    t.has_prefix("○ ") {
    return t[2:].to_string().trim().to_string()
  }

  if t.has_prefix("（1）") ||
    t.has_prefix("（2）") ||
    t.has_prefix("（3）") {
    return t[3:].to_string().trim().to_string()
  }

  let idx = find_numbered_bullet_end(t)
  if idx > 0 {
    return t[idx:].to_string().trim().to_string()
  }

  t
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  let arr = t.to_array()
  let n = arr.length()
  if n == 0 {
    return false
  }
  let c = arr[n - 1]
  c == '。' ||
  c == '！' ||
  c == '？' ||
  c == '.' ||
  c == '!' ||
  c == '?' ||
  c == '；' ||
  c == ';' ||
  c == '：' ||
  c == ':'
}

///|
fn is_probable_slide_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  let cs = t.to_array()
  let mut all_digit = true
  for c in cs {
    if !(c >= '0' && c <= '9') {
      all_digit = false
      break
    }
  }
  all_digit
}

///|
fn starts_with_numbered_bullet(s : String) -> Bool {
  find_numbered_bullet_end(s) > 0
}

///|
/// 返回正文起始下标；不是编号 bullet 则返回 -1
fn find_numbered_bullet_end(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return -1
  }

  let mut i = 0
  let mut has_digit = false

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return -1
  }

  if cs[i] == '.' || cs[i] == '、' || cs[i] == ')' || cs[i] == '）' {
    i += 1
    while i < n && cs[i] == ' ' {
      i += 1
    }
    return i
  }

  -1
}

///|
fn bytes_slice_to_string(bs : Bytes, start : Int, end_ : Int) -> String raise {
  let len = end_ - start
  if len <= 0 {
    return ""
  }
  @cor.utf8_bytes_to_string(bs[start:end_].to_bytes())
}

///|
fn read_attr_value_in_tag_bytes(
  tag : Bytes,
  attr_name : String,
) -> String? raise {
  let p1 = pat(attr_name + "=\"")
  let p2 = pat(attr_name + "='")

  match find_bytes(tag, p1, 0) {
    Some(i0) => {
      let start = i0 + p1.length()
      let mut i = start
      while i < tag.length() {
        if tag[i] == '"'.to_int().to_byte() {
          return Some(bytes_slice_to_string(tag, start, i))
        }
        i += 1
      }
      None
    }
    None =>
      match find_bytes(tag, p2, 0) {
        Some(i0) => {
          let start = i0 + p2.length()
          let mut i = start
          while i < tag.length() {
            if tag[i] == '\''.to_int().to_byte() {
              return Some(bytes_slice_to_string(tag, start, i))
            }
            i += 1
          }
          None
        }
        None => None
      }
  }
}

///|
fn normalize_ppt_target(target : String) -> String raise {
  if target.has_prefix("ppt/") {
    target
  } else if target.has_prefix("/") {
    target[1:].to_string()
  } else {
    "ppt/" + target
  }
}

///|
fn normalize_slide_text(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
fn contains_bytes(hay : Bytes, needle : Bytes) -> Bool {
  match find_bytes(hay, needle, 0) {
    Some(_) => true
    None => false
  }
}

///|
fn shape_is_title_like(xml : Bytes) -> Bool {
  contains_bytes(xml, pat("type=\"title\"")) ||
  contains_bytes(xml, pat("type=\"ctrTitle\"")) ||
  contains_bytes(xml, pat("type=\"subTitle\""))
}

///|
fn shape_is_body_like(xml : Bytes) -> Bool {
  contains_bytes(xml, pat("type=\"body\""))
}
