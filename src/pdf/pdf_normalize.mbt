///|
priv enum PdfBlock {
  Heading(Int, String)
  Paragraph(String)
}

///|
fn split_blocks_smart(page : String) -> Array[PdfBlock] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let lines : Array[String] = []
  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    if !is_noise_line(line) {
      lines.push(line)
    }
  }

  let out : Array[PdfBlock] = []
  let mut buf = ""

  let n = lines.length()
  let mut i = 0
  while i < n {
    let cur = lines[i]

    if cur == "" {
      let mut k = i
      while k < n && lines[k] == "" {
        k = k + 1
      }

      if buf != "" {
        let raw = buf.trim().to_string()
        if raw != "" {
          let level = guess_heading_level(raw)
          if level > 0 {
            let text = finalize_heading(raw)
            if text != "" {
              out.push(PdfBlock::Heading(level, text))
            }
          } else {
            let text = finalize_paragraph(raw)
            if text != "" {
              out.push(PdfBlock::Paragraph(text))
            }
          }
        }
        buf = ""
      }

      i = k
      continue
    }

    if buf == "" {
      buf = cur
    } else {
      buf = append_line(buf, cur)
    }

    i = i + 1
  }

  if buf != "" {
    let raw = buf.trim().to_string()
    if raw != "" {
      let level = guess_heading_level(raw)
      if level > 0 {
        let text = finalize_heading(raw)
        if text != "" {
          out.push(PdfBlock::Heading(level, text))
        }
      } else {
        let text = finalize_paragraph(raw)
        if text != "" {
          out.push(PdfBlock::Paragraph(text))
        }
      }
    }
  }

  out
}

///|
fn append_line(buf : String, cur : String) -> String {
  if buf == "" {
    return cur
  }

  if ends_with_hyphen(buf) && starts_with_latin(cur) {
    return drop_last_char(buf) + cur
  }

  buf + glue_between(buf, cur) + cur
}

///|
fn guess_heading_level(text : String) -> Int {
  let t = text.trim().to_string()
  if t == "" {
    return 0
  }

  let n = t.to_array().length()

  if is_probable_page_number(t) {
    return 0
  }

  if ends_like_sentence(t) {
    return 0
  }

  let numbered = guess_numbered_heading_level(t)
  if numbered > 0 {
    return numbered
  }

  if looks_like_english_title(t) {
    return 1
  }

  if looks_like_heading_marker(t) {
    return if n <= 14 { 1 } else { 2 }
  }

  if n <= 10 {
    return 1
  }

  if n <= 22 {
    return 2
  }

  0
}

///|
fn guess_numbered_heading_level(s : String) -> Int {
  let t = s.trim().to_string()

  if t.has_prefix("第一章") ||
    t.has_prefix("第二章") ||
    t.has_prefix("第三章") ||
    t.has_prefix("第四章") ||
    t.has_prefix("第五章") ||
    t.has_prefix("Chapter ") ||
    t.has_prefix("CHAPTER ") {
    return 1
  }

  let dots = count_prefix_dots_in_heading_number(t)
  if dots >= 2 {
    return 3
  }
  if dots == 1 {
    return 2
  }

  if starts_with_top_level_number(t) {
    return 1
  }

  if t.has_prefix("一、") ||
    t.has_prefix("二、") ||
    t.has_prefix("三、") ||
    t.has_prefix("四、") ||
    t.has_prefix("五、") {
    return 1
  }

  if t.has_prefix("（一）") ||
    t.has_prefix("（二）") ||
    t.has_prefix("（三）") {
    return 2
  }

  0
}

///|
/// 例如 "1.1 研究目标" 返回 1
/// 例如 "1.2.3 标题" 返回 2
fn count_prefix_dots_in_heading_number(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut saw_digit = false
  let mut dots = 0

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    if c == '.' {
      dots += 1
      i += 1
      continue
    }
    break
  }

  if saw_digit {
    dots
  } else {
    0
  }
}

///|
fn starts_with_top_level_number(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  c == ' ' || c == '、' || c == ')' || c == '）' || c == '.'
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  match last_char(t) {
    Some(c) =>
      c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '；' ||
      c == ';' ||
      c == '：' ||
      c == ':'
    None => false
  }
}

///|
fn looks_like_heading_marker(s : String) -> Bool {
  let t = s.trim().to_string()
  t.has_prefix("第") ||
  t.has_prefix("Chapter") ||
  t.has_prefix("CHAPTER") ||
  t.has_prefix("Section") ||
  t.has_prefix("SECTION") ||
  t.has_prefix("一、") ||
  t.has_prefix("二、") ||
  t.has_prefix("三、") ||
  t.has_prefix("四、") ||
  t.has_prefix("五、") ||
  t.has_prefix("（一）") ||
  t.has_prefix("（二）") ||
  t.has_prefix("（三）") ||
  starts_with_numbered_heading(t)
}

///|
fn looks_like_english_title(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 2 || words.length() > 8 {
    return false
  }

  let mut latin_words = 0
  let mut good_caps = 0

  for w in words {
    if starts_with_latin(w) {
      latin_words += 1
      match first_char(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    }
  }

  latin_words >= 2 && good_caps >= 2
}

///|
fn starts_with_numbered_heading(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    if c == '.' {
      i += 1
      continue
    }
    break
  }

  has_digit && i < n
}

///|
fn is_probable_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  if t.has_prefix("Page ") ||
    t.has_prefix("page ") ||
    (t.contains("第") && t.contains("页")) {
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

///|
fn ends_with_hyphen(s : String) -> Bool {
  match last_char(s) {
    Some(c) => c == '-'
    None => false
  }
}

///|
fn starts_with_latin(s : String) -> Bool {
  match first_char(s) {
    Some(c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    None => false
  }
}

///|
fn drop_last_char(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }
  String::from_array(cs[:n - 1].to_array())
}

///|
/// 段落最后做一次清理：多空格折叠 + trim（字符级，不走 bytes）
fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  remove_cjk_inner_spaces(out.trim().to_string())
}

///|
fn finalize_heading(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
/// 去掉中文/全角符号之间的“字间空格”
fn remove_cjk_inner_spaces(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }

  let mut out = ""
  let mut i = 0
  while i < n {
    let c = cs[i]

    if c == ' ' {
      if i > 0 && i + 1 < n {
        let prev = cs[i - 1]
        let next = cs[i + 1]
        if is_cjkish(prev) && is_cjkish(next) {
          i = i + 1
          continue
        }
      }
      out = out + " "
      i = i + 1
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}

///|
/// 粗略判断“中文相关字符”：CJK 汉字,全角区（含中文标点）,常见中文标点
fn is_cjkish(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) || // CJK Unified
  (x >= 0x3400 && x <= 0x4DBF) || // Extension A
  (x >= 0xF900 && x <= 0xFAFF) || // Compatibility
  (x >= 0xFF00 && x <= 0xFFEF) || // Half/Full width
  c == '，' ||
  c == '。' ||
  c == '；' ||
  c == '：' ||
  c == '！' ||
  c == '？'
}

///|
/// 决定拼接时加不加空格：
/// - CJK + CJK：不加空格（中文不应该被强行加空格）
/// - 其他情况：加一个空格
fn glue_between(left : String, right : String) -> String {
  let lc = last_char(left)
  let rc = first_char(right)
  match (lc, rc) {
    (Some(a), Some(b)) => if is_cjk(a) && is_cjk(b) { "" } else { " " }
    _ => " "
  }
}

///|
fn first_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  if arr.length() == 0 {
    None
  } else {
    Some(arr[0])
  }
}

///|
fn last_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  let n = arr.length()
  if n == 0 {
    None
  } else {
    Some(arr[n - 1])
  }
}

///|
/// 粗略 CJK 判定（足够 MVP）
/// 覆盖：CJK Unified / Extensions / 常用全角符号区
fn is_cjk(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) ||
  (x >= 0x3400 && x <= 0x4DBF) ||
  (x >= 0xF900 && x <= 0xFAFF) ||
  (x >= 0xFF00 && x <= 0xFFEF)
}
