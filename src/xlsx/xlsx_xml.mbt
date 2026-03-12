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
fn find_sub(s : String, pat : String, start : Int) -> Int? {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n {
    return None
  }
  if n < m {
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

// parse attr="value" (double quotes only, MVP)

///|
fn get_attr(tag : String, key : String) -> String? {
  let pat = key + "=\""
  let i0 = find_sub(tag, pat, 0)
  match i0 {
    None => None
    Some(p) => {
      let s0 = p + pat.length()
      let i1 = find_sub(tag, "\"", s0)
      match i1 {
        None => None
        Some(q) => Some(tag[s0:q].to_string())
      }
    }
  }
}

///|
fn xml_unescape(s : String) -> String {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")

  @cor.decode_numeric_entities(t)
}

///|
