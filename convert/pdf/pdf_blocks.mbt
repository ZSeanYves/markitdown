///|
fn pages_to_blocks(pages : Array[PdfConvertPage]) -> Array[Array[PdfConvertBlock]] {
  let out : Array[Array[PdfConvertBlock]] = []
  for page in pages {
    out.push(lines_to_blocks(page))
  }
  out
}

///|
/// 第一阶段：
/// - block 层只做“最小断块”
/// - 不做 heading/list/noise/cross-page 解释
fn lines_to_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []

  let mut buf = ""
  let mut start = -1
  let mut end = -1
  let mut prev_text = ""
  let mut prev_strong_break_after = false

  for line in page.lines {
    if line.is_paragraph_break {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = ""
      start = -1
      end = -1
      prev_text = ""
      prev_strong_break_after = false
      continue
    }

    let t = normalize_spaces(line.text)
    if t == "" {
      prev_strong_break_after = line.strong_break_after
      continue
    }

    if prev_strong_break_after {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = ""
      start = -1
      end = -1
      prev_text = ""
    }

    if start < 0 {
      start = line.line_index
      end = line.line_index
      buf = t
      prev_text = t
      prev_strong_break_after = line.strong_break_after
      continue
    }

    if should_break_before_line(prev_text, t) {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = t
      start = line.line_index
      end = line.line_index
      prev_text = t
      prev_strong_break_after = line.strong_break_after
      continue
    }

    buf = append_line(buf, t)
    end = line.line_index
    prev_text = t
    prev_strong_break_after = line.strong_break_after
  }

  flush_paragraph(out, page.page_index, buf, start, end)
  out
}

///|
fn flush_paragraph(
  out : Array[PdfConvertBlock],
  page_index : Int,
  text : String,
  line_start : Int,
  line_end : Int,
) -> Unit {
  let t = normalize_spaces(text)
  if t == "" || line_start < 0 || line_end < 0 {
    return
  }

  out.push({
    kind: detect_block_kind(t),
    text: t,
    page_index,
    line_start,
    line_end,
    heading_level: detect_heading_level_minimal(t),
  })
}

///|
fn should_break_before_line(prev : String, cur : String) -> Bool {
  let a = prev.trim().to_string()
  let b = cur.trim().to_string()

  if a == "" || b == "" {
    return false
  }

  if should_split_heading_like_lead_line(a, b) {
    return true
  }

  // 最保守：上一行明显句末，且下一行看起来是新句开头时断块
  if ends_like_sentence(a) && starts_like_new_paragraph(b) {
    return true
  }

  false
}

///|
fn should_split_heading_like_lead_line(cur : String, next : String) -> Bool {
  let a = cur.trim().to_string()
  let b = next.trim().to_string()
  if a == "" || b == "" {
    return false
  }

  if has_strong_end_punct(a) {
    return false
  }

  if !is_heading_like_lead_line(a) {
    return false
  }

  if is_heading_like_lead_line(b) {
    return false
  }

  if !is_body_like_start_line(b) {
    return false
  }

  let na = a.to_array().length()
  let nb = b.to_array().length()
  nb >= 20 && (na <= 18 || nb >= na + 8)
}

///|
fn is_heading_like_lead_line(text : String) -> Bool {
  let t = text.trim().to_string()
  let n = t.to_array().length()
  if t == "" || n > 36 {
    return false
  }

  if detect_heading_level_minimal(t) > 0 {
    return true
  }

  if looks_like_short_cjk_title_line(t) {
    return true
  }

  looks_like_short_titlecase_english_line(t)
}

///|
fn is_body_like_start_line(text : String) -> Bool {
  let t = text.trim().to_string()
  let n = t.to_array().length()
  if t == "" {
    return false
  }

  if has_strong_end_punct(t) {
    return true
  }

  let ws = split_words_simple(t)
  if ws.length() >= 6 {
    return true
  }

  if n >= 24 && ws.length() >= 4 {
    return true
  }

  // 中文长句正文形态
  n >= 16 && is_mostly_cjk_line(t)
}

///|
fn looks_like_short_cjk_title_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t.contains(" ") {
    return false
  }

  let n = t.to_array().length()
  if n < 2 || n > 10 {
    return false
  }

  !has_strong_end_punct(t) && is_mostly_cjk_line(t)
}

///|
fn looks_like_short_titlecase_english_line(text : String) -> Bool {
  let ws = split_words_simple(text)
  if ws.length() < 2 || ws.length() > 6 {
    return false
  }

  let mut titleish = 0
  for w in ws {
    let w0 = trim_simple_punct(w)
    match first_char(w0) {
      Some(c) =>
        if (c >= 'A' && c <= 'Z') || is_all_caps_ascii_word(w0) {
          titleish = titleish + 1
        }
      None => ()
    }
  }

  titleish * 2 >= ws.length()
}

///|
fn has_strong_end_punct(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  match last_char(t) {
    Some(c) =>
      c == '。' || c == '！' || c == '？' ||
      c == '.' || c == '!' || c == '?' ||
      c == ':' || c == '：' || c == ';' || c == '；'
    None => false
  }
}

///|
fn is_mostly_cjk_line(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() == 0 {
    return false
  }

  let mut cjk = 0
  for c in cs {
    if is_cjkish(c) {
      cjk = cjk + 1
    }
  }
  cjk * 3 >= text.to_array().length() * 2
}


///|
fn trim_simple_punct(s : String) -> String {
  let mut t = s.trim().to_string()
  while t != "" {
    match first_char(t) {
      Some(c) =>
        if c == '"' || c == '\'' || c == '(' || c == '[' {
          t = String::from_array(t.to_array()[1:].to_array()).trim().to_string()
          continue
        }
      None => ()
    }
    break
  }
  while t != "" {
    match last_char(t) {
      Some(c) =>
        if c == '"' || c == '\'' || c == ')' || c == ']' || c == ',' || c == '.' || c == ':' || c == ';' {
          let cs = t.to_array()
          t = String::from_array(cs[:cs.length() - 1].to_array()).trim().to_string()
          continue
        }
      None => ()
    }
    break
  }
  t
}

///|
fn is_all_caps_ascii_word(s : String) -> Bool {
  let cs = s.to_array()
  if cs.length() == 0 {
    return false
  }

  let mut has_alpha = false
  for c in cs {
    if c >= 'A' && c <= 'Z' {
      has_alpha = true
      continue
    }
    if c >= '0' && c <= '9' {
      continue
    }
    return false
  }
  has_alpha
}

///|
fn starts_like_new_paragraph(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if starts_with_titlecase_word(t) {
    return true
  }

  if starts_with_cjk_text(t) {
    return true
  }

  if t.has_prefix("第") {
    return true
  }

  false
}

///|
fn detect_block_kind(text : String) -> PdfConvertBlockKind {
  if detect_heading_level_minimal(text) > 0 {
    PdfConvertBlockKind::Heading
  } else {
    PdfConvertBlockKind::Paragraph
  }
}

///|
fn detect_heading_level_minimal(text : String) -> Int {
  let t = text.trim().to_string()
  if t == "" {
    return 0
  }

  if t.has_prefix("### ") {
    return 3
  }
  if t.has_prefix("## ") {
    return 2
  }
  if t.has_prefix("# ") {
    return 1
  }

  if t.has_prefix("第") && t.contains("章") {
    return 1
  }
  if t.has_prefix("第") && t.contains("节") {
    return 2
  }
  if t.has_prefix("Chapter ") || t.has_prefix("CHAPTER ") {
    return 1
  }

  0
}

///|
fn append_line(prev : String, cur : String) -> String {
  if prev == "" {
    return cur
  }

  if ends_with_hyphen(prev) && starts_with_latin(cur) {
    return drop_last_char(prev) + cur
  }

  if should_join_without_space(prev, cur) {
    prev + cur
  } else {
    prev + " " + cur
  }
}

///|
fn normalize_spaces(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' || c == '\t' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + normalize_char(c)
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
/// 先只做最小字符归一化，优先救当前样例里最明显的 ligature。
fn normalize_char(c : Char) -> String {
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
/// 用于处理 `uni` + `fi` + `ed` 这种被 event 切碎后不应再加空格的情况。
fn is_latin_word_piece_join(l : Char, r : Char) -> Bool {
  is_latinish(l) && is_latinish(r)
}

///|
fn is_latinish(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}


///|
fn starts_with_latin(s : String) -> Bool {
  match first_char(s) {
    Some(c) => is_latinish(c)
    None => false
  }
}

///|
fn starts_with_titlecase_word(s : String) -> Bool {
  match first_char(s) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
fn starts_with_cjk_text(s : String) -> Bool {
  match first_char(s) {
    Some(c) => is_cjkish(c)
    None => false
  }
}
