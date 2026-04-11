///|
/// 小的通用文本归一化层：
/// - 空白规整
/// - 控制字符清洗
/// - 少量常见兼容字符折叠
/// - 统一片段 join
///
/// 注意：
/// 这里不做 heading/list/noise 判定。
///
/// 如果后续要升级成更完整的 Unicode compatibility normalization，
/// 也只需要扩这里。
fn normalize_pdf_text_fragment(text : String) -> String {
  let mut out = ""
  let mut prev_space = false

  for c in text.to_array() {
    let mapped = normalize_pdf_char(c)

    if mapped == "" {
      continue
    }

    if mapped == " " {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + mapped
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
/// 单字符归一化：
/// - space-like -> " "
/// - control -> ""
/// - ligature -> ASCII
/// - 其余保持原样
///
/// 这里尽量走“类别型”而不是样例白名单。
fn normalize_pdf_char(c : Char) -> String {
  if is_space_like(c) {
    return " "
  }

  if is_ignorable_control(c) {
    return ""
  }

  // 常见 latin ligature：这是通用兼容折叠，不是样例特判。
  if c == 'ﬁ' {
    return "fi"
  }
  if c == 'ﬂ' {
    return "fl"
  }
  if c == 'ﬀ' {
    return "ff"
  }
  if c == 'ﬃ' {
    return "ffi"
  }
  if c == 'ﬄ' {
    return "ffl"
  }

  c.to_string()
}

///|
/// 统一的片段拼接：
/// - CJK 连续直接拼
/// - 连字符断词直接拼
/// - 很像英文单词碎裂时直接拼
/// - 其余默认加空格
fn join_pdf_text_fragments(left : String, right : String) -> String {
  let a = normalize_pdf_text_fragment(left)
  let b = normalize_pdf_text_fragment(right)

  if a == "" {
    return b
  }
  if b == "" {
    return a
  }

  if ends_with_hyphen(a) && starts_with_ascii_letter(b) {
    return drop_last_char(a) + b
  }

  if should_join_without_space(a, b) {
    return a + b
  }

  a + " " + b
}

///|
fn should_join_without_space(a : String, b : String) -> Bool {
  match (last_char(a), first_char(b)) {
    (Some(l), Some(r)) => {
      if is_cjkish(l) && is_cjkish(r) {
        return true
      }

      if is_common_close_punct(l) || is_common_open_punct(r) {
        return true
      }

      if looks_like_broken_ascii_word(a, b) {
        return true
      }

      false
    }
    _ => false
  }
}

///|
/// 只在“很像一个英文单词被 PDF event 切碎”时直接拼。
/// 例如：uni + fied / con + firm / fina + l
/// 不把 document + conversion 之类正常词边界粘死。
fn looks_like_broken_ascii_word(a : String, b : String) -> Bool {
  if has_strong_boundary_punct(a) || has_strong_boundary_punct(b) {
    return false
  }

  let lw = last_ascii_word(a)
  let rw = first_ascii_word(b)

  if lw == "" || rw == "" {
    return false
  }

  let ln = lw.to_array().length()
  let rn = rw.to_array().length()

  if ln <= 3 || rn <= 3 {
    return true
  }

  if ln <= 4 && rn <= 4 {
    return true
  }

  false
}

///|
fn has_strong_boundary_punct(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  match last_char(t) {
    Some(c) =>
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '。' ||
      c == '！' ||
      c == '？' ||
      c == ':' ||
      c == '：' ||
      c == ';' ||
      c == '；' ||
      c == ',' ||
      c == '，'
    None => false
  }
}

///|
fn first_ascii_word(s : String) -> String {
  let parts = split_words_simple(s)
  for w in parts {
    if is_ascii_word(w) {
      return w
    }
  }
  ""
}

///|
fn last_ascii_word(s : String) -> String {
  let parts = split_words_simple(s)
  let mut i = parts.length()
  while i > 0 {
    let w = parts[i - 1]
    if is_ascii_word(w) {
      return w
    }
    i = i - 1
  }
  ""
}

///|
fn split_words_simple(s : String) -> Array[String] {
  let out : Array[String] = []
  for sv in s.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      out.push(w)
    }
  }
  out
}

///|
fn is_ascii_word(s : String) -> Bool {
  let cs = s.to_array()
  if cs.length() == 0 {
    return false
  }

  for c in cs {
    if !is_ascii_letter(c) {
      return false
    }
  }
  true
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn starts_with_ascii_letter(s : String) -> Bool {
  match first_char(s) {
    Some(c) => is_ascii_letter(c)
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
fn is_space_like(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{00A0}'
}

///|
fn is_ignorable_control(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0 && code < 32 && c != '\n' && c != '\r' && c != '\t') || code == 127
}

///|
fn is_cjkish(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x2E80 && code <= 0x2FDF) ||
  (code >= 0x3400 && code <= 0x9FFF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_common_open_punct(c : Char) -> Bool {
  c == '（' || c == '【' || c == '《' || c == '“' || c == '‘'
}

///|
fn is_common_close_punct(c : Char) -> Bool {
  c == '，' ||
  c == '。' ||
  c == '！' ||
  c == '？' ||
  c == '：' ||
  c == '；' ||
  c == '）' ||
  c == '】' ||
  c == '》'
}

///|
fn first_char(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    None
  } else {
    Some(cs[0])
  }
}

///|
fn last_char(s : String) -> Char? {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    None
  } else {
    Some(cs[n - 1])
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
