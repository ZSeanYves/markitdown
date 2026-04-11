///|
fn convert_pages_to_blocks(
  pages : Array[PdfConvertPage],
) -> Array[Array[PdfConvertBlock]] {
  let out : Array[Array[PdfConvertBlock]] = []
  for page in pages {
    out.push(page_lines_to_blocks(page))
  }
  out
}

///|
fn page_lines_to_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let blocks : Array[PdfConvertBlock] = []
  let mut para_text = ""
  let mut para_line_count = 0
  let mut para_start = -1
  let mut para_end = -1

  let mut i = 0
  while i < page.lines.length() {
    let line = page.lines[i]
    let text = normalize_line_text(line.text)
    if line.is_explicit_break || text == "" {
      flush_paragraph_block(blocks, page.page_index, para_text, para_start, para_end)
      para_text = ""
      para_line_count = 0
      para_start = -1
      para_end = -1
      i = i + 1
      continue
    }

    if should_be_heading_line(text, para_line_count == 0) {
      flush_paragraph_block(blocks, page.page_index, para_text, para_start, para_end)
      para_text = ""
      para_line_count = 0
      para_start = -1
      para_end = -1

      blocks.push(make_block(
        PdfConvertBlockKind::Heading,
        text,
        page.page_index,
        line.line_index,
        line.line_index,
      ))
      i = i + 1
      continue
    }

    if para_start < 0 {
      para_start = line.line_index
    }
    para_end = line.line_index
    para_text = append_pdf_text(para_text, text)
    para_line_count = para_line_count + 1

    let next = next_nonempty_line_text(page.lines, i + 1)
    if should_flush_paragraph_after_line(
      para_text,
      para_line_count,
      text,
      next,
    ) {
      flush_paragraph_block(blocks, page.page_index, para_text, para_start, para_end)
      para_text = ""
      para_line_count = 0
      para_start = -1
      para_end = -1
    }
    i = i + 1
  }

  flush_paragraph_block(blocks, page.page_index, para_text, para_start, para_end)
  blocks
}

///|
fn flush_paragraph_block(
  blocks : Array[PdfConvertBlock],
  page_index : Int,
  para_text : String,
  line_start : Int,
  line_end : Int,
) -> Unit {
  if para_text == "" || line_start < 0 || line_end < 0 {
    return
  }

  let text = normalize_inline_spaces(para_text)
  if text == "" {
    return
  }

  blocks.push(make_block(
    PdfConvertBlockKind::Paragraph,
    text,
    page_index,
    line_start,
    line_end,
  ))
}

///|
fn make_block(
  kind : PdfConvertBlockKind,
  text : String,
  page_index : Int,
  line_start : Int,
  line_end : Int,
) -> PdfConvertBlock {
  let t = text.trim().to_string()
  {
    kind,
    text: t,
    page_index,
    line_start,
    line_end,
    char_count: t.to_array().length(),
    is_noise: false,
    noise_reason: None,
    is_cross_page_continuation_candidate: false,
  }
}

///|
fn next_nonempty_line_text(lines : Array[PdfConvertLine], from : Int) -> String? {
  let mut i = from
  while i < lines.length() {
    let line = lines[i]
    let t = normalize_line_text(line.text)
    if !line.is_explicit_break && t != "" {
      return Some(t)
    }
    i = i + 1
  }
  None
}

///|
fn should_flush_paragraph_after_line(
  para_text : String,
  para_line_count : Int,
  current_line : String,
  next_line : String?,
) -> Bool {
  let next = match next_line {
    Some(s) => s
    None => return true
  }

  let cur = current_line.trim().to_string()
  let total_chars = para_text.to_array().length()

  if para_line_count >= 10 && ends_like_sentence(cur) {
    return true
  }

  if total_chars >= 600 && ends_like_sentence(cur) {
    return true
  }

  if ends_like_sentence(cur) {
    if starts_like_new_paragraph(next) {
      return true
    }
  }

  false
}

///|
fn starts_like_new_paragraph(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  match first_char(t) {
    Some(c) =>
      // latin capitalized start or explicit indentation marker
      (c >= 'A' && c <= 'Z') ||
      c == '"' ||
      c == '\'' ||
      c == '“' ||
      c == '‘' ||
      c == '（'
    None => false
  }
}

///|
fn append_pdf_text(prev : String, cur : String) -> String {
  let a = prev.trim().to_string()
  let b = cur.trim().to_string()
  if a == "" {
    return b
  }
  if b == "" {
    return a
  }

  if ends_with_hyphen(a) && starts_with_latin(b) {
    return drop_last_char(a) + b
  }

  if should_join_without_space(a, b) {
    a + b
  } else {
    a + " " + b
  }
}

///|
fn should_join_without_space(a : String, b : String) -> Bool {
  let lc = last_char(a)
  let rc = first_char(b)

  match (lc, rc) {
    (Some(l), Some(r)) =>
      if is_cjkish(l) && is_cjkish(r) {
        true
      } else if is_cjkish(l) && is_common_open_punct(r) {
        true
      } else if is_common_close_punct(l) {
        true
      } else {
        false
      }
    _ => false
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
  String::from_array(cs[:n - 1].to_array())
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
fn is_cjkish(c : Char) -> Bool {
  let code = c.to_int()
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
fn should_be_heading_line(text : String, at_block_start : Bool) -> Bool {
  if !at_block_start {
    return false
  }

  let t = text.trim().to_string()
  let n = t.to_array().length()
  if n < 3 || n > 64 {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  looks_like_heading_marker(t) || looks_like_short_title_case_line(t)
}

///|
fn normalize_line_text(s : String) -> String {
  s
  .replace(old="\u00A0", new=" ")
  .replace(old="\t", new=" ")
  .trim()
  .to_string()
}

///|
fn normalize_inline_spaces(s : String) -> String {
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
  out
}
