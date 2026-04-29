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
fn xml_unescape(s : String) -> String {
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
fn bytes_slice_to_string(bs : Bytes, start : Int, end_ : Int) -> String raise {
  let len = end_ - start
  if len <= 0 {
    return ""
  }
  @cor.utf8_bytes_to_string(bs[start:end_].to_owned())
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

  out.trim().to_owned()
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

///|
fn abs_int(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}
