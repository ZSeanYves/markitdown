///|
fn pat(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn pptx_source_key(part_name : String, node_key : String) -> PptxSourceKey {
  { part_name, node_key }
}

///|
fn pptx_source_span(part_name : String, node_key : String) -> PptxSourceSpan {
  { part_name, node_key, start_offset: None, end_offset: None }
}

///|
fn pptx_warning(
  kind : PptxWarningKind,
  severity : PptxWarningSeverity,
  part_name : String,
  node_key : String,
  relationship_id : String?,
  object_ref : String?,
  message : String,
) -> PptxWarning {
  {
    kind,
    severity,
    message,
    source_span: Some(pptx_source_span(part_name, node_key)),
    relationship_id,
    object_ref,
  }
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
    let mut ok = true
    let mut j = 0
    while j < m {
      if hay[i + j] != needle[j] {
        ok = false
        break
      }
      j += 1
    }
    if ok {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn contains_bytes(hay : Bytes, needle : Bytes) -> Bool {
  match find_bytes(hay, needle, 0) {
    Some(_) => true
    None => false
  }
}

///|
fn bytes_slice_to_string(bs : Bytes, start : Int, end_ : Int) -> String raise {
  let len = end_ - start
  if len <= 0 {
    return ""
  }
  @utf8.decode(bs[start:end_].to_owned(), ignore_bom=false)
}

///|
fn xml_unescape(s : String) -> String {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  t
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
          return Some(xml_unescape(bytes_slice_to_string(tag, start, i)))
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
              return Some(xml_unescape(bytes_slice_to_string(tag, start, i)))
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
fn read_attr_value_in_first_tag_bytes(
  block : Bytes,
  tag_prefix : String,
  attr_name : String,
) -> String? raise {
  let start = find_bytes(block, pat(tag_prefix), 0).unwrap_or(-1)
  if start < 0 {
    return None
  }
  let end_ = find_bytes(block, pat(">"), start).unwrap_or(-1)
  if end_ < 0 {
    return None
  }
  read_attr_value_in_tag_bytes(block[start:end_ + 1].to_owned(), attr_name)
}

///|
fn read_open_tag_name(xml : Bytes, start : Int) -> String? raise {
  if start < 0 || start >= xml.length() || xml[start] != '<'.to_int().to_byte() {
    return None
  }
  let mut i = start + 1
  while i < xml.length() {
    let b = xml[i]
    if b == ' '.to_int().to_byte() ||
      b == '>'.to_int().to_byte() ||
      b == '/'.to_int().to_byte() ||
      b == '\n'.to_int().to_byte() ||
      b == '\r'.to_int().to_byte() ||
      b == '\t'.to_int().to_byte() {
      return Some(bytes_slice_to_string(xml, start + 1, i))
    }
    i += 1
  }
  None
}

///|
fn find_matching_named_element_close(
  xml : Bytes,
  open_start : Int,
  tag_name : String,
) -> Int? raise {
  let gt = find_bytes(xml, pat(">"), open_start)
  match gt {
    None => None
    Some(gt0) => {
      if gt0 > open_start && xml[gt0 - 1] == '/'.to_int().to_byte() {
        return Some(gt0 + 1)
      }
      let close_pat = pat("</" + tag_name + ">")
      let mut depth = 1
      let mut pos = gt0 + 1
      while pos < xml.length() {
        let next_lt = find_bytes(xml, pat("<"), pos)
        match next_lt {
          None => return None
          Some(i0) =>
            if i0 + close_pat.length() <= xml.length() &&
              xml[i0:i0 + close_pat.length()] == close_pat {
              depth -= 1
              if depth == 0 {
                return Some(i0 + close_pat.length())
              }
              pos = i0 + close_pat.length()
            } else if i0 + 1 < xml.length() &&
              xml[i0 + 1] != '/'.to_int().to_byte() &&
              xml[i0 + 1] != '?'.to_int().to_byte() &&
              xml[i0 + 1] != '!'.to_int().to_byte() {
              match read_open_tag_name(xml, i0) {
                Some(name) => {
                  let gt1 = find_bytes(xml, pat(">"), i0)
                  match gt1 {
                    None => return None
                    Some(gt10) => {
                      if name == tag_name &&
                        !(gt10 > i0 && xml[gt10 - 1] == '/'.to_int().to_byte()) {
                        depth += 1
                      }
                      pos = gt10 + 1
                    }
                  }
                }
                None => pos = i0 + 1
              }
            } else {
              pos = i0 + 1
            }
        }
      }
      None
    }
  }
}

///|
fn slice_full_element(
  xml : Bytes,
  start : Int,
  tag_name : String,
) -> (Bytes, Int)? raise {
  let gt = find_bytes(xml, pat(">"), start)
  match gt {
    None => None
    Some(gt0) =>
      if gt0 > start && xml[gt0 - 1] == '/'.to_int().to_byte() {
        Some((xml[start:gt0 + 1].to_owned(), gt0 + 1))
      } else {
        match find_matching_named_element_close(xml, start, tag_name) {
          Some(end_) => Some((xml[start:end_].to_owned(), end_))
          None => None
        }
      }
  }
}

///|
fn find_element_inner(
  xml : Bytes,
  open_prefix : String,
  close_tag : String,
) -> Bytes? raise {
  let p0 = find_bytes(xml, pat(open_prefix), 0).unwrap_or(-1)
  if p0 < 0 {
    return None
  }
  let gt = find_bytes(xml, pat(">"), p0).unwrap_or(-1)
  if gt < 0 {
    return None
  }
  let tag_name = open_prefix[1:].to_owned()
  match find_matching_named_element_close(xml, p0, tag_name) {
    Some(end0) => {
      let close_len = pat(close_tag).length()
      if end0 < close_len || end0 - close_len < gt + 1 {
        None
      } else {
        Some(xml[gt + 1:end0 - close_len].to_owned())
      }
    }
    None => {
      let end0 = find_bytes(xml, pat(close_tag), gt + 1).unwrap_or(-1)
      if end0 < 0 {
        None
      } else {
        Some(xml[gt + 1:end0].to_owned())
      }
    }
  }
}

///|
fn parse_int_or_zero(s : String?) -> Int {
  let raw = s.unwrap_or("0").trim().to_owned()
  if raw == "" {
    return 0
  }
  let mut n = 0
  let mut sign = 1
  let chars = raw.to_array()
  let mut i = 0
  if chars.length() > 0 && chars[0] == '-' {
    sign = -1
    i = 1
  }
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return 0
    }
    n = n * 10 + (c.to_int() - '0'.to_int())
    i += 1
  }
  n * sign
}

///|
fn normalize_optional_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let t = raw.trim().to_owned()
      if t == "" {
        None
      } else {
        Some(t)
      }
    }
    None => None
  }
}
