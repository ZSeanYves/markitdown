///|
fn pages_to_blocks(pages : Array[PdfConvertPage]) -> Array[Array[PdfConvertBlock]] {
  let out : Array[Array[PdfConvertBlock]] = []
  for page in pages {
    out.push(lines_to_blocks(page))
  }
  out
}

///|
fn lines_to_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []

  let mut buf = ""
  let mut start = -1
  let mut end = -1

  for line in page.lines {
    if line.is_paragraph_break {
      flush_paragraph(out, page.page_index, buf, start, end)
      buf = ""
      start = -1
      end = -1
      continue
    }

    let t = line.text.trim().to_string()
    if t == "" {
      continue
    }

    if start < 0 {
      start = line.line_index
    }
    end = line.line_index
    buf = append_line(buf, t)
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
  })
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

///|
fn should_join_without_space(a : String, b : String) -> Bool {
  match (last_char(a), first_char(b)) {
    (Some(l), Some(r)) =>
      (is_cjkish(l) && is_cjkish(r)) || is_common_close_punct(l) || is_common_open_punct(r)
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

///|
fn is_cjkish(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x3400 && code <= 0x9FFF) || (code >= 0xF900 && code <= 0xFAFF)
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
