///|
fn bytes_to_xml_text(bytes : Bytes, path : String) -> String raise EpubError {
  @cor.utf8_bytes_to_string(bytes) catch {
    e =>
      raise InvalidXml(
        "utf8 decode failed for `" + path + "`: " + e.to_string(),
      )
  }
}

///|
fn collect_start_tags(xml : String, local_name : String) -> Array[String] {
  let tags : Array[String] = []
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }

    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut j = i + 1
    while j < n && chars[j] != '>' {
      j += 1
    }
    if j >= n {
      break
    }

    let tag = xml[i:j + 1].to_owned()
    if start_tag_local_name(tag) == local_name {
      tags.push(tag)
    }
    i = j + 1
  }

  tags
}

///|
fn parse_tag_attributes(tag : String) -> Map[String, String] {
  let attrs : Map[String, String] = Map::new()
  let chars = tag.to_array()
  let n = chars.length()

  let mut i = 1
  while i < n && chars[i] != '>' && !is_space(chars[i]) {
    i += 1
  }

  while i < n {
    while i < n && is_space(chars[i]) {
      i += 1
    }
    if i >= n || chars[i] == '>' || chars[i] == '/' {
      break
    }

    let key_start = i
    while i < n && chars[i] != '=' && !is_space(chars[i]) && chars[i] != '>' {
      i += 1
    }
    if i >= n || chars[i] == '>' {
      break
    }

    let key_end = i
    while i < n && is_space(chars[i]) {
      i += 1
    }
    if i >= n || chars[i] != '=' {
      break
    }
    i += 1

    while i < n && is_space(chars[i]) {
      i += 1
    }
    if i >= n {
      break
    }

    let quote = chars[i]
    if quote != '"' && quote != '\'' {
      break
    }
    i += 1

    let value_start = i
    while i < n && chars[i] != quote {
      i += 1
    }
    if i >= n {
      break
    }

    let value_end = i
    i += 1
    attrs.set(
      tag[key_start:key_end].to_owned(),
      tag[value_start:value_end].to_owned(),
    )
  }

  attrs
}

///|
fn get_required_attr(
  attrs : Map[String, String],
  key : String,
) -> String raise EpubError {
  match attrs.get(key) {
    Some(value) =>
      if value.trim() == "" {
        raise InvalidXml("missing attribute: " + key)
      } else {
        value
      }
    None => raise InvalidXml("missing attribute: " + key)
  }
}

///|
fn get_optional_attr(attrs : Map[String, String], key : String) -> String {
  match attrs.get(key) {
    Some(value) => value
    None => ""
  }
}

///|
fn tag_text(xml : String, local_name : String) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }

    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = xml[i:tag_end + 1].to_owned()
    if start_tag_local_name(start_tag) == local_name {
      if start_tag_is_self_closing(start_tag) {
        return None
      }

      let content_start = tag_end + 1
      match find_closing_tag_by_local_name(xml, local_name, content_start) {
        Some(pos) =>
          return Some(
            xml_entity_decode(xml[content_start:pos].trim().to_owned()),
          )
        None => ()
      }
    }

    i = tag_end + 1
  }

  None
}

///|
fn tag_text_with_attr(
  xml : String,
  local_name : String,
  attr_key : String,
  attr_value : String,
) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }
    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = xml[i:tag_end + 1].to_owned()
    if start_tag_local_name(start_tag) == local_name {
      let attrs = parse_tag_attributes(start_tag)
      if get_optional_attr(attrs, attr_key) == attr_value {
        if start_tag_is_self_closing(start_tag) {
          return None
        }
        let content_start = tag_end + 1
        match find_closing_tag_by_local_name(xml, local_name, content_start) {
          Some(pos) =>
            return Some(
              xml_entity_decode(xml[content_start:pos].trim().to_owned()),
            )
          None => ()
        }
      }
    }

    i = tag_end + 1
  }

  None
}

///|
fn tag_attr_with_attr(
  xml : String,
  local_name : String,
  match_attr_key : String,
  match_attr_value : String,
  target_attr_key : String,
) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }
    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = xml[i:tag_end + 1].to_owned()
    if start_tag_local_name(start_tag) == local_name {
      let attrs = parse_tag_attributes(start_tag)
      if get_optional_attr(attrs, match_attr_key) == match_attr_value {
        let target = get_optional_attr(attrs, target_attr_key).trim().to_owned()
        if target != "" {
          return Some(target)
        }
      }
    }
    i = tag_end + 1
  }

  None
}

///|
fn first_start_tag_with_attr(
  xml : String,
  local_name : String,
  attr_key : String,
  attr_value : String,
) -> String? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = 0

  while i < n {
    if chars[i] != '<' {
      i += 1
      continue
    }
    if i + 1 < n &&
      (chars[i + 1] == '/' || chars[i + 1] == '?' || chars[i + 1] == '!') {
      i += 1
      continue
    }

    let mut tag_end = i + 1
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      break
    }

    let start_tag = xml[i:tag_end + 1].to_owned()
    if start_tag_local_name(start_tag) == local_name {
      let attrs = parse_tag_attributes(start_tag)
      if get_optional_attr(attrs, attr_key) == attr_value {
        return Some(start_tag)
      }
    }
    i = tag_end + 1
  }

  None
}

///|
fn tag_content(
  xml : String,
  start_tag : String,
  local_name : String,
) -> String? {
  let start = find_substring(xml, start_tag, 0)
  match start {
    None => None
    Some(pos) => {
      let content_start = pos + start_tag.length()
      match find_closing_tag_by_local_name(xml, local_name, content_start) {
        Some(end_) => Some(xml[content_start:end_].to_owned())
        None => None
      }
    }
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
    i += 1
  }

  let mut j = i
  while j < chars.length() &&
        !is_space(chars[j]) &&
        chars[j] != '/' &&
        chars[j] != '>' {
    j += 1
  }

  if j <= i {
    return ""
  }

  local_name_from_raw(tag[i:j].to_owned())
}

///|
fn end_tag_local_name(tag : String) -> String {
  let chars = tag.to_array()
  if chars.length() < 4 {
    return ""
  }

  let mut i = 2
  while i < chars.length() && is_space(chars[i]) {
    i += 1
  }

  let mut j = i
  while j < chars.length() && !is_space(chars[j]) && chars[j] != '>' {
    j += 1
  }

  if j <= i {
    return ""
  }

  local_name_from_raw(tag[i:j].to_owned())
}

///|
fn start_tag_is_self_closing(tag : String) -> Bool {
  let chars = tag.to_array()
  let mut i = chars.length() - 2
  while i >= 0 {
    if is_space(chars[i]) {
      i -= 1
      continue
    }
    return chars[i] == '/'
  }
  false
}

///|
fn find_closing_tag_by_local_name(
  xml : String,
  local_name : String,
  start : Int,
) -> Int? {
  let chars = xml.to_array()
  let n = chars.length()
  let mut i = start

  while i < n {
    if chars[i] != '<' || i + 1 >= n || chars[i + 1] != '/' {
      i += 1
      continue
    }

    let mut tag_end = i + 2
    while tag_end < n && chars[tag_end] != '>' {
      tag_end += 1
    }
    if tag_end >= n {
      return None
    }

    let tag = xml[i:tag_end + 1].to_owned()
    if end_tag_local_name(tag) == local_name {
      return Some(i)
    }
    i = tag_end + 1
  }

  None
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
  let chars = raw_name.to_array()
  let mut colon = -1
  for i in 0..<chars.length() {
    if chars[i] == ':' {
      colon = i
    }
  }
  if colon < 0 {
    raw_name
  } else {
    raw_name[colon + 1:].to_owned()
  }
}

///|
fn is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}
