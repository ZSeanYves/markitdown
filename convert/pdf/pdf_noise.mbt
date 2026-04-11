///|
fn detect_repeated_edge_noise(
  pages : Array[Array[PdfConvertBlock]],
) -> (Array[String], Array[String]) {
  let head_count = Map::new()
  let tail_count = Map::new()

  for blocks in pages {
    if blocks.length() == 0 {
      continue
    }

    let first = normalize_noise_key(blocks[0].text)
    if first != "" {
      let old = head_count.get(first) |> Option::unwrap_or(0)
      head_count.set(first, old + 1)
    }

    let last = normalize_noise_key(blocks[blocks.length() - 1].text)
    if last != "" {
      let old = tail_count.get(last) |> Option::unwrap_or(0)
      tail_count.set(last, old + 1)
    }
  }

  let threshold = if pages.length() <= 2 { 2 } else { (pages.length() + 1) / 2 }
  let heads : Array[String] = []
  let tails : Array[String] = []

  for e in head_count {
    let (k, v) = e
    if v >= threshold {
      heads.push(k)
    }
  }

  for e in tail_count {
    let (k, v) = e
    if v >= threshold {
      tails.push(k)
    }
  }

  (heads, tails)
}

///|
fn is_edge_repeated_noise(
  text : String,
  idx : Int,
  page_len : Int,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> Bool {
  let key = normalize_noise_key(text)
  if key == "" {
    return false
  }

  if idx == 0 && contains_string(head_keys, key) {
    return true
  }

  idx == page_len - 1 && contains_string(tail_keys, key)
}

///|
/// 放宽页码识别：
/// - Page 2
/// - 第 2 页
/// - 3/10
/// - - 2 -
/// - 2
fn is_probable_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("Page ") || t.has_prefix("page ") {
    return true
  }

  if t.contains("第") && t.contains("页") {
    return true
  }

  if is_digits_only(t) {
    return true
  }

  let cs = t.to_array()
  let mut slash = -1
  let mut i = 0
  while i < cs.length() {
    if cs[i] == '/' {
      slash = i
      break
    }
    i = i + 1
  }

  if slash > 0 && slash + 1 < cs.length() {
    let left = String::from_array(cs[:slash].to_array()).trim().to_string()
    let right = String::from_array(cs[slash + 1:].to_array()).trim().to_string()
    if is_digits_only(left) && is_digits_only(right) {
      return true
    }
  }

  is_symbolic_page_number(t)
}

///|
fn is_symbolic_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" || t.to_array().length() > 12 {
    return false
  }

  let mut has_digit = false
  for c in t.to_array() {
    if c >= '0' && c <= '9' {
      has_digit = true
      continue
    }

    if c == ' ' || c == '-' || c == '–' || c == '—' || c == '(' || c == ')' {
      continue
    }

    return false
  }

  has_digit
}

///|
fn normalize_noise_key(text : String) -> String {
  let t = text.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    let mapped = if c >= 'A' && c <= 'Z' {
      Int::unsafe_to_char(c.to_int() + 32)
    } else if c >= '0' && c <= '9' {
      '#'
    } else if c == ' ' || c == '\t' {
      ' '
    } else {
      c
    }

    if mapped == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + mapped.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
fn is_digits_only(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn contains_string(xs : Array[String], x : String) -> Bool {
  for v in xs {
    if v == x {
      return true
    }
  }
  false
}
