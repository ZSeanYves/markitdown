///|
/// Convert ZIP entry bytes to XML text.
///
/// Reject invalid UTF-8 before package XML enters the text caches.
fn bytes_to_xml_text(bytes : Bytes) -> String raise OoxmlError {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise InvalidEncoding("utf8 decode failed")
  }
}

///|
fn start_tag_local_name(tag : String) -> String {
  let chars = tag.to_array()
  if chars.length() < 3 {
    return ""
  }

  let mut i = 1
  while i < chars.length() && is_space(chars[i]) {
    i = i + 1
  }

  let mut j = i
  while j < chars.length() &&
        !is_space(chars[j]) &&
        chars[j] != '/' &&
        chars[j] != '>' {
    j = j + 1
  }

  if j <= i {
    return ""
  }

  local_name_from_raw(String::from_array(chars[i:j]))
}

///|
fn end_tag_local_name(tag : String) -> String {
  let chars = tag.to_array()
  if chars.length() < 4 {
    return ""
  }

  let mut i = 2
  while i < chars.length() && is_space(chars[i]) {
    i = i + 1
  }

  let mut j = i
  while j < chars.length() && !is_space(chars[j]) && chars[j] != '>' {
    j = j + 1
  }

  if j <= i {
    return ""
  }

  local_name_from_raw(String::from_array(chars[i:j]))
}

///|
fn parse_tag_attributes(tag : String) -> Map[String, String] {
  let attrs : Map[String, String] = Map([])
  let chars = tag.to_array()
  let n = chars.length()

  let mut i = 1
  while i < n && chars[i] != '>' && !is_space(chars[i]) {
    i = i + 1
  }

  while i < n {
    while i < n && is_space(chars[i]) {
      i = i + 1
    }

    if i >= n || chars[i] == '>' || chars[i] == '/' {
      break
    }

    let key_start = i
    while i < n && chars[i] != '=' && !is_space(chars[i]) && chars[i] != '>' {
      i = i + 1
    }
    if i >= n || chars[i] == '>' {
      break
    }

    let key_end = i
    while i < n && is_space(chars[i]) {
      i = i + 1
    }
    if i >= n || chars[i] != '=' {
      break
    }
    i = i + 1

    while i < n && is_space(chars[i]) {
      i = i + 1
    }
    if i >= n {
      break
    }

    let quote = chars[i]
    if quote != '"' && quote != '\'' {
      break
    }
    i = i + 1

    let value_start = i
    while i < n && chars[i] != quote {
      i = i + 1
    }
    if i >= n {
      break
    }
    let value_end = i
    i = i + 1

    let key = String::from_array(chars[key_start:key_end])
    let value = String::from_array(chars[value_start:value_end])
    attrs.set(key, value)
  }

  attrs
}

///|
fn tag_text(xml : String, local_name : String) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i = i + 1
      continue
    }

    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i = i + 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end = tag_end + 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = String::from_array(chars[i:tag_end + 1])
    let name = start_tag_local_name(start_tag)

    if name == local_name {
      let content_start = tag_end + 1

      if start_tag_is_self_closing(start_tag) {
        return None
      }

      let end = find_closing_tag_by_local_name(chars, local_name, content_start)
      match end {
        Some(pos) =>
          return Some(
            xml_entity_decode(
              String::from_array(chars[content_start:pos]).trim().to_owned(),
            ),
          )
        None => ()
      }
    }

    i = tag_end + 1
  }

  None
}

///|
fn start_tag_is_self_closing(tag : String) -> Bool {
  let chars = tag.to_array()
  let mut i = chars.length() - 2
  while i >= 0 {
    if is_space(chars[i]) {
      i = i - 1
      continue
    }
    return chars[i] == '/'
  }
  false
}

///|
fn find_closing_tag_by_local_name(
  chars : Array[Char],
  local_name : String,
  start : Int32,
) -> Int32? {
  let n = chars.length()
  let mut i = start

  while i < n {
    if chars[i] != '<' || i + 1 >= n || chars[i + 1] != '/' {
      i = i + 1
      continue
    }

    let mut tag_end = i + 2
    while tag_end < n && chars[tag_end] != '>' {
      tag_end = tag_end + 1
    }
    if tag_end >= n {
      return None
    }

    let tag = String::from_array(chars[i:tag_end + 1])
    if end_tag_local_name(tag) == local_name {
      return Some(i)
    }

    i = tag_end + 1
  }

  None
}

///|
fn xml_entity_decode(s : String) -> String {
  s
  .replace(old="&amp;", new="&")
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
}

///|
fn local_name_from_raw(raw_name : String) -> String {
  let raw_chars = raw_name.to_array()
  let mut colon = -1
  for k in 0..<raw_chars.length() {
    if raw_chars[k] == ':' {
      colon = k
    }
  }

  if colon < 0 {
    raw_name
  } else {
    String::from_array(raw_chars[colon + 1:])
  }
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}
