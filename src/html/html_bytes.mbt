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
fn starts_with_bytes(hay : Bytes, pos : Int, needle : Bytes) -> Bool {
  let n = hay.length()
  let m = needle.length()
  if pos < 0 || pos + m > n {
    return false
  }
  let mut j = 0
  while j < m {
    if hay[pos + j] != needle[j] {
      return false
    }
    j = j + 1
  }
  true
}

///|
/// remove <...> tags from a byte slice (keep text bytes)
fn strip_tags_bytes(inner : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  let n = inner.length()
  let lt = pat("<")
  let gt = pat(">")

  while i < n {
    let p0 = find_bytes(inner, lt, i)
    match p0 {
      None => {
        let tail = inner[i:n].to_bytes().to_array()
        for b in tail {
          out.push(b)
        }
        break
      }
      Some(p) => {
        let head = inner[i:p].to_bytes().to_array()
        for b in head {
          out.push(b)
        }
        let q0 = find_bytes(inner, gt, p)
        match q0 {
          None => break
          Some(q) => i = q + 1
        }
      }
    }
  }

  Bytes::from_array(out)
}

///|
fn replace_bytes(hay : Bytes, from : Bytes, to : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  let n = hay.length()
  let m = from.length()

  while i < n {
    let hit = m > 0 && i <= n - m && starts_with_bytes(hay, i, from)
    if hit {
      let arr = to.to_array()
      for b in arr {
        out.push(b)
      }
      i = i + m
    } else {
      out.push(hay[i])
      i = i + 1
    }
  }

  Bytes::from_array(out)
}

///|
fn html_unescape(s : String) -> String raise {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

