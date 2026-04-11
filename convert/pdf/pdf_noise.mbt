///|
fn detect_repeated_block_noise_keys(
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

  for entry in head_count {
    let (k, v) = entry
    if v >= threshold {
      heads.push(k)
    }
  }
  for entry in tail_count {
    let (k, v) = entry
    if v >= threshold {
      tails.push(k)
    }
  }

  (heads, tails)
}

///|
fn is_repeated_edge_noise(
  s : String,
  idx : Int,
  page_len : Int,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> Bool {
  let key = normalize_noise_key(s)
  if key == "" {
    return false
  }

  if idx == 0 && contains_string(head_keys, key) {
    return true
  }

  idx == page_len - 1 && contains_string(tail_keys, key)
}

///|
fn normalize_noise_key(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    let ch = if c >= 'A' && c <= 'Z' {
      Int::unsafe_to_char(c.to_int() + 32)
    } else if c >= '0' && c <= '9' {
      '#'
    } else if c == ' ' || c == '\t' {
      ' '
    } else {
      c
    }

    if ch == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + ch.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
fn contains_string(xs : Array[String], x : String) -> Bool {
  for s in xs {
    if s == x {
      return true
    }
  }
  false
}

///|
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

  let cs = t.to_array()
  let n = cs.length()

  let mut all_digit = true
  for c in cs {
    if c < '0' || c > '9' {
      all_digit = false
      break
    }
  }
  if all_digit {
    return true
  }

  // 12 / 314
  let mut slash_idx = -1
  let mut i = 0
  while i < n {
    if cs[i] == '/' {
      slash_idx = i
      break
    }
    i = i + 1
  }

  if slash_idx > 0 && slash_idx + 1 < n {
    let left = String::from_array(cs[:slash_idx].to_array()).trim().to_string()
    let right = String::from_array(cs[slash_idx + 1:].to_array()).trim().to_string()
    return is_digits_only(left) && is_digits_only(right)
  }

  false
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
