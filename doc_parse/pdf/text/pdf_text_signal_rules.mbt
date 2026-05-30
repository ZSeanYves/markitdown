///|
/// Shared text-level signals for PDF text-flow rules and convert-layer guards.
///
/// Keep these pure text helpers separate from line geometry and merge
/// orchestration so lower-layer and convert-layer callers share one rule
/// vocabulary.
fn starts_with_body_like_prefix(text : String) -> Bool {
  let t = text.trim()
  t.has_prefix("首先") ||
  t.has_prefix("其中") ||
  t.has_prefix("以及") ||
  t.has_prefix("并且") ||
  t.has_prefix("最后") ||
  t.has_prefix("为了") ||
  t.has_prefix("通过") ||
  t.has_prefix("使用") ||
  t.has_prefix("这是") ||
  t.has_prefix("这个") ||
  t.has_prefix("本") ||
  t.has_prefix("该") ||
  t.has_prefix("用于") ||
  t.has_prefix("对于") ||
  t.has_prefix("因为")
}

///|
fn contains_many_sentence_words(text : String) -> Bool {
  let t = text.to_lower()
  t.contains(" is ") ||
  t.contains(" are ") ||
  t.contains(" was ") ||
  t.contains(" were ") ||
  t.contains(" to ") ||
  t.contains(" of ") ||
  t.contains(" and ") ||
  t.contains(" for ") ||
  t.contains(" the ")
}

///|
fn ends_with_weak_body_suffix(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix("的") ||
  t.has_suffix("了") ||
  t.has_suffix("是") ||
  t.has_suffix("为") ||
  t.has_suffix("中") ||
  t.has_suffix("上") ||
  t.has_suffix("下") ||
  t.has_suffix("：") ||
  t.has_suffix(":") ||
  t.has_suffix("，") ||
  t.has_suffix(",")
}

///|
fn ends_with_body_like_action_char(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix("完") ||
  t.has_suffix("成") ||
  t.has_suffix("持") ||
  t.has_suffix("研") ||
  t.has_suffix("转") ||
  t.has_suffix("换")
}

///|
fn is_short_fragment(text : String) -> Bool {
  let t = text.trim()
  t != "" && t.length() <= 4
}

///|
fn ends_with_strong_sentence_punct(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn starts_with_upper_ascii(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let c = text[0]
  c >= 'A' && c <= 'Z'
}

///|
fn all_cjk_chars(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }

  for ch in text {
    if !is_cjk_char(ch) {
      return false
    }
  }

  true
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_cjk_char_opt_boundary(left : String, right : String) -> Bool {
  let lc = last_char_opt(left)
  let rc = first_char_opt(right)

  match (lc, rc) {
    (Some(a), Some(b)) => is_cjk_char(a) || is_cjk_char(b)
    _ => false
  }
}

///|
fn first_char_opt(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn last_char_opt(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn first_ascii_word(text : String) -> String {
  let mut out = ""
  let mut started = false

  for ch in text {
    if is_ascii_letter(ch) {
      out = out + ch.to_string()
      started = true
    } else if started {
      break
    }
  }

  out
}

///|
fn last_ascii_word(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return ""
  }

  let mut end = -1
  let mut start = -1
  let mut i = arr.length() - 1

  while i >= 0 {
    let ch = arr[i]
    if is_ascii_letter(ch) {
      if end < 0 {
        end = i
      }
      start = i
      if i == 0 {
        break
      }
      i = i - 1
    } else if end >= 0 {
      break
    } else {
      if i == 0 {
        break
      }
      i = i - 1
    }
  }

  if start < 0 || end < 0 {
    return ""
  }

  text[start:end + 1].to_owned()
}

///|
pub fn word_count(text : String) -> Int {
  let t = text.trim()
  if t == "" {
    return 0
  }

  let mut count = 0
  let mut in_word = false

  for ch in t {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if in_word {
        in_word = false
      }
    } else if !in_word {
      count = count + 1
      in_word = true
    }
  }

  count
}

///|
pub fn looks_like_figure_or_table_caption(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  t.has_prefix("Figure ") ||
  t.has_prefix("Fig. ") ||
  t.has_prefix("Table ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("表 ")
}

///|
fn looks_like_list_intro_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return false
  }

  t.has_suffix(":") ||
  t.has_suffix("：") ||
  t == "Key points" ||
  t == "Key points:" ||
  t == "要点" ||
  t == "要点："
}

///|
pub fn looks_like_intro_phrase(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  t.has_prefix("In conclusion,") ||
  t.has_prefix("For example,") ||
  t.has_prefix("For instance,") ||
  t.has_prefix("首先，") ||
  t.has_prefix("最后，")
}

///|
fn looks_like_numbered_body_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let prefix_ok = t.has_prefix("1. ") ||
    t.has_prefix("2. ") ||
    t.has_prefix("3. ") ||
    t.has_prefix("1)") ||
    t.has_prefix("2)") ||
    t.has_prefix("3)")

  if !prefix_ok {
    return false
  }

  word_count(t) >= 4 || ends_with_strong_sentence_punct(t)
}

///|
fn looks_like_all_caps_body_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return true
  }

  false
}
