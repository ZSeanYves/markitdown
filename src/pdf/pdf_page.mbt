///|
/// Internal marker inserted between cleaned pages.
/// split_blocks_smart() should recognize this marker later.
const PDF_PAGE_BREAK_MARKER = "__PDF_PAGE_BREAK__"

///|
fn merge_clean_pages_with_breaks(pages : Array[String]) -> String {
  if pages.length() == 0 {
    return ""
  }

  let out : Array[String] = []
  let n = pages.length()

  for i in 0..<n {
    let page = pages[i].trim().to_string()
    if page != "" {
      out.push(page)
    }

    if i + 1 < n {
      out.push(PDF_PAGE_BREAK_MARKER)
    }
  }

  out.join("\n")
}

///|
fn strip_page_noise(
  page : String,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> String {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let raw_lines : Array[String] = []
  for sv in s.split("\n") {
    raw_lines.push(sv.to_string())
  }

  let n = raw_lines.length()
  if n == 0 {
    return ""
  }

  // 找到前两个非空行的位置
  let head_pos : Array[Int] = []
  let mut i = 0
  while i < n && head_pos.length() < 2 {
    let t = raw_lines[i].trim().to_string()
    if t != "" {
      head_pos.push(i)
    }
    i += 1
  }

  // 找到后两个非空行的位置
  let tail_pos : Array[Int] = []
  let mut j = n - 1
  while j >= 0 && tail_pos.length() < 2 {
    let t = raw_lines[j].trim().to_string()
    if t != "" {
      tail_pos.push(j)
    }
    if j == 0 {
      break
    }
    j -= 1
  }

  // 删页眉
  for idx in head_pos {
    let t = raw_lines[idx].trim().to_string()
    let key = normalize_noise_key(t)
    if key != "" && contains_string(head_keys, key) {
      raw_lines[idx] = ""
    }
  }

  // 删页脚
  for idx in tail_pos {
    let t = raw_lines[idx].trim().to_string()
    let key = normalize_noise_key(t)
    if key != "" && contains_string(tail_keys, key) {
      raw_lines[idx] = ""
    }
  }

  // 只清理噪声行，但保留原始空行结构
  let out : Array[String] = []
  let mut prev_blank = false

  for line in raw_lines {
    let t = line.trim().to_string()
    if t == "" {
      if !prev_blank {
        out.push("")
        prev_blank = true
      }
    } else if is_noise_line(t) {
      if !prev_blank {
        out.push("")
        prev_blank = true
      }
    } else {
      out.push(t)
      prev_blank = false
    }
  }

  out.join("\n")
}

///|
fn is_probable_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_fraction_page_number(t) {
    return true
  }

  if looks_like_page_number_phrase(t) {
    return true
  }

  if t.contains("第") && t.contains("页") {
    return true
  }

  let cs = t.to_array()
  let mut all_digit = true
  for c in cs {
    if !(c >= '0' && c <= '9') {
      all_digit = false
      break
    }
  }
  all_digit
}

///|
/// match phrases like:
/// - Page 2
/// - page 2
/// - Page 2 of 3
/// - page 2 / 3
fn looks_like_page_number_phrase(s : String) -> Bool {
  let t = s.trim().to_string()
  if !(t.has_prefix("Page ") || t.has_prefix("page ")) {
    return false
  }

  let rest = if t.has_prefix("Page ") {
    String::from_array(t.to_array()[5:].to_array()).trim().to_string()
  } else {
    String::from_array(t.to_array()[5:].to_array()).trim().to_string()
  }

  if rest == "" {
    return false
  }

  // rest must only contain digits / spaces / slash / "of"
  for c in rest.to_array() {
    let ok = (c >= '0' && c <= '9') ||
      c == ' ' ||
      c == '/' ||
      c == 'o' ||
      c == 'f' ||
      c == 'O' ||
      c == 'F'
    if !ok {
      return false
    }
  }

  true
}

///|
fn looks_like_fraction_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
  let n = cs.length()

  if n < 3 {
    return false
  }

  let mut slash_pos = -1
  let mut i = 0
  while i < n {
    if cs[i] == '/' {
      slash_pos = i
      break
    }
    i += 1
  }

  if slash_pos <= 0 || slash_pos >= n - 1 {
    return false
  }

  let mut left_ok = true
  for j in 0..<slash_pos {
    let c = cs[j]
    if !(c >= '0' && c <= '9') && c != ' ' {
      left_ok = false
      break
    }
  }

  let mut right_ok = true
  for j in (slash_pos + 1)..<n {
    let c = cs[j]
    if !(c >= '0' && c <= '9') && c != ' ' {
      right_ok = false
      break
    }
  }

  left_ok && right_ok
}

///|
fn is_noise_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number(t) {
    return true
  }

  let cs = t.to_array()
  if cs.length() <= 3 {
    let mut ok = true
    for c in cs {
      let is_digit = c >= '0' && c <= '9'
      let is_sym = c == '-' || c == '_' || c == '.' || c == '·'
      if !(is_digit || is_sym) {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
  }

  false
}
