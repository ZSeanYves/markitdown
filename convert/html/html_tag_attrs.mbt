///|
fn html_open_tag_name(tag : String) -> String? {
  let s = tag.to_lower()
  let n = s.length()
  let mut i = 0

  while i < n && s[i] != '<' {
    i += 1
  }
  if i >= n {
    return None
  }
  i += 1

  while i < n && (s[i] == ' ' || s[i] == '\n' || s[i] == '\t' || s[i] == '/') {
    i += 1
  }
  if i >= n {
    return None
  }

  let start = i
  while i < n {
    let ch = s[i]
    if ch == ' ' || ch == '\n' || ch == '\t' || ch == '>' || ch == '/' {
      break
    }
    i += 1
  }

  if i <= start {
    None
  } else {
    Some(s[start:i].to_owned())
  }
}

///|
fn read_html_attr_value(tag : String, attr_name : String) -> String? {
  let lower = tag.to_lower()
  let key = attr_name.to_lower()
  let n = tag.length()
  let mut i = 0

  while i < n {
    let mut j = i
    while j < n && (lower[j] == ' ' || lower[j] == '\n' || lower[j] == '\t') {
      j += 1
    }

    if j + key.length() >= n {
      break
    }

    if lower[j:j + key.length()].to_owned() != key {
      i = j + 1
      continue
    }

    let mut k = j + key.length()
    while k < n && (lower[k] == ' ' || lower[k] == '\n' || lower[k] == '\t') {
      k += 1
    }
    if k >= n || lower[k] != '=' {
      i = j + 1
      continue
    }
    k += 1
    while k < n && (lower[k] == ' ' || lower[k] == '\n' || lower[k] == '\t') {
      k += 1
    }
    if k >= n {
      return None
    }

    if tag[k] == '"' || tag[k] == '\'' {
      let q = tag[k]
      let mut e = k + 1
      while e < n && tag[e] != q {
        e += 1
      }
      if e <= n {
        return Some(tag[k + 1:e].to_owned())
      }
      return None
    }

    let mut e = k
    while e < n {
      let c = tag[e]
      if c == ' ' || c == '\n' || c == '\t' || c == '>' {
        break
      }
      e += 1
    }
    return Some(tag[k:e].to_owned())
  }

  None
}
