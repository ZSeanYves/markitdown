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
        let tail = inner[i:n].to_owned().to_array()
        for b in tail {
          out.push(b)
        }
        break
      }
      Some(p) => {
        let head = inner[i:p].to_owned().to_array()
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
fn find_tag_block_inner(bs : Bytes, tag_name : String) -> Bytes? {
  let open_pat = pat("<" + tag_name)
  let close_pat = pat("</" + tag_name + ">")
  let gt_pat = pat(">")

  let open0 = find_bytes_case_insensitive(bs, open_pat, 0)
  match open0 {
    None => None
    Some(open_idx) => {
      let gt0 = find_bytes(bs, gt_pat, open_idx)
      match gt0 {
        None => None
        Some(gt_idx) => {
          let inner_start = gt_idx + 1
          let close0 = find_bytes_case_insensitive(bs, close_pat, inner_start)
          match close0 {
            None => None
            Some(close_idx) => Some(bs[inner_start:close_idx].to_owned())
          }
        }
      }
    }
  }
}

///|
fn find_matching_tag_end(
  bs : Bytes,
  start_open : Int,
  tag_name : String,
) -> Int? {
  let open_pat = pat("<" + tag_name)
  let close_pat = pat("</" + tag_name + ">")
  let gt_pat = pat(">")

  let mut depth = 0
  let mut pos = start_open
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes_case_insensitive(bs, open_pat, pos)
    let close0 = find_bytes_case_insensitive(bs, close_pat, pos)

    match (open0, close0) {
      (None, None) => return None
      (Some(i), None) => {
        let gt0 = find_bytes(bs, gt_pat, i)
        match gt0 {
          None => return None
          Some(gt) => {
            depth = depth + 1
            pos = gt + 1
          }
        }
      }
      (None, Some(j)) => {
        depth = depth - 1
        if depth == 0 {
          return Some(j)
        }
        pos = j + close_pat.length()
      }
      (Some(i), Some(j)) =>
        if i < j {
          let gt0 = find_bytes(bs, gt_pat, i)
          match gt0 {
            None => return None
            Some(gt) => {
              depth = depth + 1
              pos = gt + 1
            }
          }
        } else {
          depth = depth - 1
          if depth == 0 {
            return Some(j)
          }
          pos = j + close_pat.length()
        }
    }
  }

  None
}

///|
fn find_bytes_case_insensitive(
  hay : Bytes,
  needle_ascii : Bytes,
  start : Int,
) -> Int? {
  let n = hay.length()
  let m = needle_ascii.length()
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
      if ascii_lower_byte(hay[i + j]) != needle_ascii[j] {
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
fn ascii_lower_byte(b : Byte) -> Byte {
  let k = b.to_int()
  if k >= 65 && k <= 90 {
    (k + 32).to_byte()
  } else {
    b
  }
}

///|
fn html_unescape(s : String) -> String {
  let t = s
    .replace_all(old="&lt;", new="<")
    .replace_all(old="&gt;", new=">")
    .replace_all(old="&amp;", new="&")
    .replace_all(old="&quot;", new="\"")
    .replace_all(old="&nbsp;", new=" ")
    .replace_all(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

///|
/// find matching close tag for a list block starting at `start_open`
/// tag_name must be "ul" or "ol"
fn find_matching_list_end(
  bs : Bytes,
  start_open : Int,
  tag_name : String,
) -> Int? {
  let open_pat = pat("<" + tag_name)
  let close_pat = pat("</" + tag_name + ">")
  let gt_pat = pat(">")

  let mut depth = 0
  let mut pos = start_open
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes(bs, open_pat, pos)
    let close0 = find_bytes(bs, close_pat, pos)

    match (open0, close0) {
      (None, None) => return None
      (Some(i), None) => {
        let gt0 = find_bytes(bs, gt_pat, i)
        match gt0 {
          None => return None
          Some(gt) => {
            depth = depth + 1
            pos = gt + 1
          }
        }
      }
      (None, Some(j)) => {
        depth = depth - 1
        if depth == 0 {
          return Some(j)
        }
        pos = j + close_pat.length()
      }
      (Some(i), Some(j)) =>
        if i < j {
          let gt0 = find_bytes(bs, gt_pat, i)
          match gt0 {
            None => return None
            Some(gt) => {
              depth = depth + 1
              pos = gt + 1
            }
          }
        } else {
          depth = depth - 1
          if depth == 0 {
            return Some(j)
          }
          pos = j + close_pat.length()
        }
    }
  }

  None
}

///|
/// find matching </li> for a <li ...> starting at start_open
fn find_matching_li_end(bs : Bytes, start_open : Int) -> Int? {
  let open_li = pat("<li")
  let close_li = pat("</li>")
  let gt_pat = pat(">")

  let mut depth = 0
  let mut pos = start_open
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes(bs, open_li, pos)
    let close0 = find_bytes(bs, close_li, pos)

    match (open0, close0) {
      (None, None) => return None
      (Some(i), None) => {
        let gt0 = find_bytes(bs, gt_pat, i)
        match gt0 {
          None => return None
          Some(gt) => {
            depth = depth + 1
            pos = gt + 1
          }
        }
      }
      (None, Some(j)) => {
        depth = depth - 1
        if depth == 0 {
          return Some(j)
        }
        pos = j + close_li.length()
      }
      (Some(i), Some(j)) =>
        if i < j {
          let gt0 = find_bytes(bs, gt_pat, i)
          match gt0 {
            None => return None
            Some(gt) => {
              depth = depth + 1
              pos = gt + 1
            }
          }
        } else {
          depth = depth - 1
          if depth == 0 {
            return Some(j)
          }
          pos = j + close_li.length()
        }
    }
  }

  None
}
