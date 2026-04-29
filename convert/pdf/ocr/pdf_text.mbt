///|
/// Strong heading candidate for block decisions.
/// This must stay conservative.
fn is_strong_heading_candidate(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if is_probable_page_number(t) {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if guess_numbered_heading_level(t) > 0 {
    return true
  }

  if looks_like_heading_marker(t) {
    return true
  }

  if looks_like_english_title(t) {
    return true
  }

  false
}

///|
fn looks_like_figure_or_table_caption(s : String) -> Bool {
  let t = s.trim().to_owned()
  t.has_prefix("Figure ") ||
  t.has_prefix("FIGURE ") ||
  t.has_prefix("Table ") ||
  t.has_prefix("TABLE ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("图") ||
  t.has_prefix("表 ")
}

///|
fn looks_like_intro_phrase(s : String) -> Bool {
  let t = s.trim().to_owned()
  t == "In conclusion," ||
  t == "In summary," ||
  t == "For example," ||
  t == "For instance," ||
  t == "However," ||
  t == "Therefore," ||
  t == "Moreover," ||
  t == "Nevertheless,"
}

///|
fn looks_like_list_intro_line(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if !t.has_suffix(":") && !t.has_suffix("：") {
    return false
  }

  let n = t.to_array().length()

  // 典型短引导句
  if n <= 30 {
    return true
  }

  false
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
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_owned()
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
  String::from_array(cs[:n - 1].to_owned())
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

  remove_cjk_inner_spaces(out.trim().to_owned())
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

  out.trim().to_owned()
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

///|
fn contains_sentence_punct_inside(s : String) -> Bool {
  for c in s.to_array() {
    if c == '，' ||
      c == '。' ||
      c == '；' ||
      c == '：' ||
      c == ',' ||
      c == ';' ||
      c == ':' {
      return true
    }
  }
  false
}
