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
/// - block 层负责“最小断块”
/// - 不做最终语义裁决
/// - 重点避免把 heading / list / page-number 再吞回正文
fn lines_to_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []

  let mut buf = ""
  let mut start = -1
  let mut end = -1
  let mut prev_text = ""

  for line in page.lines {
    if line.is_paragraph_break {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = ""
      start = -1
      end = -1
      prev_text = ""
      continue
    }

    let t = normalize_spaces(line.text)
    if t == "" {
      continue
    }

    if start < 0 {
      start = line.line_index
      end = line.line_index
      buf = t
      prev_text = t
      continue
    }

    if should_break_before_line(prev_text, t) {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = t
      start = line.line_index
      end = line.line_index
      prev_text = t
      continue
    }

    buf = append_line(buf, t)
    end = line.line_index
    prev_text = t
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
    kind: PdfConvertBlockKind::Paragraph,
    text: t,
    page_index,
    line_start,
    line_end,
    is_noise: false,
    noise_reason: None,
    is_cross_page_continuation_candidate: false,
    list_ordered: false,
    list_level: 0,
    heading_level: 0,
  })
}

///|
/// 这里只做“最小断块”，不要做最终 heading/list 判定。
fn should_break_before_line(prev : String, cur : String) -> Bool {
  let a = prev.trim().to_string()
  let b = cur.trim().to_string()

  if a == "" || b == "" {
    return false
  }

  if should_force_single_line_block(a) {
    return true
  }

  if starts_like_heading_or_list(b) {
    return true
  }

  if looks_like_page_number_line(b) {
    return true
  }

  if ends_like_sentence(a) && starts_like_new_paragraph(b) {
    return true
  }

  false
}

///|
fn should_force_single_line_block(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if detect_heading_level(t, 0) > 0 {
    return true
  }

  match parse_list_marker(t) {
    Some(_) => true
    None => looks_like_page_number_line(t)
  }
}

///|
fn starts_like_heading_or_list(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if detect_heading_level(t, 0) > 0 {
    return true
  }

  match parse_list_marker(t) {
    Some(_) => true
    None => false
  }
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
fn looks_like_page_number_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  is_probable_page_number(t)
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
