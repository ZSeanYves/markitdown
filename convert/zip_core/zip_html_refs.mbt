///|
fn html_entry_has_local_image_refs(entry_bytes : Bytes) -> Bool {
  let html = @utf8.decode(entry_bytes, ignore_bom=false) catch {
    _ => return false
  }
  let mut pos = 0

  while true {
    let img0 = find_ascii_case_insensitive(html, "<img", pos)
    match img0 {
      None => break
      Some(start) =>
        match find_substring(html, ">", start + 4) {
          None => break
          Some(end_) => {
            let tag = html[start:end_ + 1].to_owned()
            match read_html_attr_value(tag, "src") {
              Some(src) => if is_local_html_image_src(src) { return true }
              None => ()
            }
            pos = end_ + 1
          }
        }
    }
  }

  false
}

///|
fn find_substring(s : String, pat : String, start : Int) -> Int? {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    if s[i:i + m] == pat {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn find_ascii_case_insensitive(s : String, pat : String, start : Int) -> Int? {
  let s_chars = s.to_array()
  let pat_chars = pat.to_array()
  let n = s_chars.length()
  let m = pat_chars.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    let mut matched = true
    let mut j = 0
    while j < m {
      if ascii_lower_char(s_chars[i + j]) != ascii_lower_char(pat_chars[j]) {
        matched = false
        break
      }
      j += 1
    }
    if matched {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn ascii_lower_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + ('a'.to_int() - 'A'.to_int()))
  } else {
    ch
  }
}

///|
fn read_html_attr_value(tag : String, key : String) -> String? {
  let chars = tag.to_array()
  let key_lower = ascii_lower_string(key)
  let mut i = 0

  while i < chars.length() {
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    while i < chars.length() &&
          (chars[i] == '<' || chars[i] == '>' || chars[i] == '/') {
      i += 1
    }

    let name_start = i
    while i < chars.length() && is_html_attr_name_char(chars[i]) {
      i += 1
    }
    if name_start == i {
      i += 1
      continue
    }

    let name = ascii_lower_string(String::from_array(chars[name_start:i]))
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    if i >= chars.length() || chars[i] != '=' {
      continue
    }
    i += 1
    while i < chars.length() && is_html_attr_space(chars[i]) {
      i += 1
    }
    if i >= chars.length() {
      return None
    }

    let value = if chars[i] == '"' || chars[i] == '\'' {
      let quote = chars[i]
      i += 1
      let value_start = i
      while i < chars.length() && chars[i] != quote {
        i += 1
      }
      let out = String::from_array(chars[value_start:i])
      if i < chars.length() {
        i += 1
      }
      out
    } else {
      let value_start = i
      while i < chars.length() &&
            !is_html_attr_space(chars[i]) &&
            chars[i] != '>' {
        i += 1
      }
      String::from_array(chars[value_start:i])
    }

    if name == key_lower {
      return Some(value)
    }
  }

  None
}

///|
fn ascii_lower_string(s : String) -> String {
  let out : Array[Char] = []
  for ch in s.to_array() {
    out.push(ascii_lower_char(ch))
  }
  String::from_array(out)
}

///|
fn is_html_attr_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' || ch == '\f'
}

///|
fn is_html_attr_name_char(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == ':' ||
  ch == '.'
}

///|
pub fn is_local_html_image_src(src : String) -> Bool {
  let trimmed = normalize_html_src(src)
  if trimmed == "" {
    return false
  }
  let lower = trimmed.to_lower()
  !(trimmed.contains("\\") ||
  lower.has_prefix("http://") ||
  lower.has_prefix("https://") ||
  lower.has_prefix("data:") ||
  lower.has_prefix("//") ||
  lower.has_prefix("/") ||
  trimmed.contains("..") ||
  has_scheme_like_prefix(lower))
}

///|
fn normalize_html_src(src : String) -> String {
  let trimmed = src.trim()
  let mut end = trimmed.length()
  for i in 0..<trimmed.length() {
    if trimmed[i] == '?' || trimmed[i] == '#' {
      end = i
      break
    }
  }
  trimmed[:end].trim().to_owned()
}

///|
fn has_scheme_like_prefix(src : String) -> Bool {
  for i in 0..<src.length() {
    match src[i] {
      ':' => return i > 0
      '/' | '?' | '#' => return false
      _ => ()
    }
  }
  false
}
