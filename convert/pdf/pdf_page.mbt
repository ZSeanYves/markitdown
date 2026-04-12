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

  let raw_lines_after_repeated = strip_page_repeated_noise_only_as_lines(
    raw_lines, head_keys, tail_keys,
  )
  cleanup_page_noise_lines(raw_lines_after_repeated)
}

///|
fn strip_page_repeated_noise_only(
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

  let lines = strip_page_repeated_noise_only_as_lines(
    raw_lines, head_keys, tail_keys,
  )
  lines.join("\n")
}

///|
fn strip_page_repeated_noise_only_as_lines(
  raw_lines : Array[String],
  head_keys : Array[String],
  tail_keys : Array[String],
) -> Array[String] {
  // 找到前两个非空行的位置
  let head_pos : Array[Int] = []
  let n = raw_lines.length()
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
    if key != "" &&
      contains_string(head_keys, key) &&
      !should_preserve_short_page_edge_block(t) {
      raw_lines[idx] = ""
    }
  }

  // 删页脚
  for idx in tail_pos {
    let t = raw_lines[idx].trim().to_string()
    let key = normalize_noise_key(t)
    if key != "" &&
      contains_string(tail_keys, key) &&
      !should_preserve_short_page_edge_block(t) {
      raw_lines[idx] = ""
    }
  }

  raw_lines
}

///|
fn cleanup_page_noise_lines(raw_lines : Array[String]) -> String {
  // 只清理噪声行，但保留原始空行结构
  let out : Array[String] = []
  let original_non_empty_lines : Array[String] = []
  let non_noise_lines : Array[String] = []
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
      non_noise_lines.push(t)
      prev_blank = false
    }

    if t != "" {
      original_non_empty_lines.push(t)
    }
  }

  let cleaned = out.join("\n")
  if cleaned.trim() != "" {
    return cleaned
  }

  // Conservative fallback:
  // if page-level cleanup cleared the whole page, but page had non-empty lines
  // before cleanup, keep original lines to avoid deleting
  // short real-content pages in multipage documents.
  if non_noise_lines.length() > 0 {
    return non_noise_lines.join("\n")
  }

  if original_non_empty_lines.length() > 0 {
    return original_non_empty_lines.join("\n")
  }

  cleaned
}

///|
/// Protect short real content from repeated-header/footer cleanup.
/// Keep this narrow: only very short non-page-number lines are preserved.
fn should_preserve_short_page_edge_block(s : String) -> Bool {
  let t = s.trim().to_string()
  let n = t.to_array().length()
  n > 0 && n <= 6 && !is_probable_page_number(t)
}

///|
fn is_probable_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_artifact_page_noise(t) {
    return true
  }

  if looks_like_fraction_page_number(t) {
    return true
  }

  if looks_like_spaced_page_number(t) {
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
fn looks_like_spaced_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  let tokens : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      tokens.push(w)
    }
  }

  if tokens.length() != 2 {
    return false
  }

  let mut ok = true
  for tok in tokens {
    let n = tok.to_array().length()
    if n == 0 || n > 3 {
      ok = false
      break
    }
    for c in tok.to_array() {
      if !(c >= '0' && c <= '9') {
        ok = false
        break
      }
    }
    if !ok {
      break
    }
  }
  ok
}

///|
fn looks_like_artifact_page_noise(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t == "页" {
    return true
  }

  // common PDF extraction artifact char U+FFFC shown as "￼"
  if t.contains("￼") {
    let mut non_noise = 0
    for c in t.to_array() {
      let ok = c == '￼' ||
        c == ' ' ||
        c == '/' ||
        c == '-' ||
        c == '_' ||
        c == '页' ||
        (c >= '0' && c <= '9')
      if !ok {
        non_noise += 1
      }
    }
    return non_noise == 0
  }

  // narrow guard for standalone page-tail fragments like "页", "1/3", "页/3"
  let mut only_noise = true
  let mut has_pageish = false
  for c in t.to_array() {
    let ok = c == '页' || c == '/' || (c >= '0' && c <= '9') || c == ' '
    if !ok {
      only_noise = false
      break
    }
    if c == '页' || c == '/' || (c >= '0' && c <= '9') {
      has_pageish = true
    }
  }
  if only_noise && has_pageish {
    return true
  }

  false
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

  let tokens : Array[String] = []
  for sv in rest.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      tokens.push(w)
    }
  }

  if tokens.length() == 1 {
    let only = tokens[0]
    if is_ascii_digits_word(only) {
      return true
    }
    if looks_like_fraction_page_number(only) {
      return true
    }
    return false
  }

  if tokens.length() == 3 {
    if !is_ascii_digits_word(tokens[0]) {
      return false
    }
    let sep = tokens[1]
    if !(sep == "of" || sep == "OF" || sep == "Of" || sep == "oF" || sep == "/") {
      return false
    }
    return is_ascii_digits_word(tokens[2])
  }

  false
}

///|
fn is_ascii_digits_word(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if !(c >= '0' && c <= '9') {
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
