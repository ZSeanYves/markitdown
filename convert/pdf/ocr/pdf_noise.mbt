///|
/// 检测跨页重复页眉/页脚
fn detect_repeated_page_noise(
  pages : Array[String],
) -> (Array[String], Array[String]) {
  let head_count = Map::new()
  let tail_count = Map::new()

  for page in pages {
    let lines = normalized_nonempty_lines(page)
    let n = lines.length()
    if n == 0 {
      continue
    }

    let head_take = if n >= 2 { 2 } else { 1 }
    let tail_take = if n >= 2 { 2 } else { 1 }

    for i in 0..<head_take {
      let line = lines[i]
      let key = normalize_noise_key(line)
      if key != "" && is_repeated_noise_candidate_line(line) {
        let old = head_count.get(key) |> Option::unwrap_or(0)
        head_count.set(key, old + 1)
      }
    }

    for i in 0..<tail_take {
      let idx = n - tail_take + i
      let line = lines[idx]
      let key = normalize_noise_key(line)
      if key != "" && is_repeated_noise_candidate_line(line) {
        let old = tail_count.get(key) |> Option::unwrap_or(0)
        tail_count.set(key, old + 1)
      }
    }
  }

  let page_n = pages.length()
  let threshold = if page_n <= 2 { 2 } else { (page_n + 1) / 2 }

  let heads : Array[String] = []
  let tails : Array[String] = []

  for entry in head_count {
    let (k, v) = entry
    if v >= threshold && k.to_array().length() <= 80 {
      heads.push(k)
    }
  }

  for entry in tail_count {
    let (k, v) = entry
    if v >= threshold && k.to_array().length() <= 80 {
      tails.push(k)
    }
  }

  (heads, tails)
}

///|
fn is_repeated_noise_candidate_line(line : String) -> Bool {
  let t = line.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number(t) {
    return true
  }

  let n = t.to_array().length()
  let words = count_words(t)

  // protect long/body-like sentences from repeated-cleanup deletion
  if n > 60 {
    return false
  }
  if words >= 10 {
    return false
  }
  if ends_like_sentence(t) && words >= 8 {
    return false
  }

  true
}

///|
fn count_words(s : String) -> Int {
  let mut n = 0
  for sv in s.split(" ") {
    if sv.to_string().trim().to_string() != "" {
      n += 1
    }
  }
  n
}

///|
fn normalized_nonempty_lines(page : String) -> Array[String] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let out : Array[String] = []
  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      out.push(line)
    }
  }
  out
}

///|
/// 页眉页脚 key 归一化：
/// - trim
/// - 压缩空白
/// - 数字替换成 '#'
/// - 英文转小写
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
