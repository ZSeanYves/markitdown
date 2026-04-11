///|
fn classify_convert_blocks(
  pages : Array[PdfConvertPage],
  page_blocks : Array[Array[PdfConvertBlock]],
) -> Array[Array[PdfConvertBlock]] {
  let (head_keys, tail_keys) = detect_repeated_block_noise_keys(page_blocks)

  let out : Array[Array[PdfConvertBlock]] = []
  let mut p = 0
  while p < page_blocks.length() {
    let page = pages[p]
    let blocks = page_blocks[p]
    let page_out : Array[PdfConvertBlock] = []

    let mut i = 0
    while i < blocks.length() {
      let block = blocks[i]
      let t = block.text.trim().to_string()
      let noise_reason = classify_noise_reason(
        t,
        i,
        blocks.length(),
        head_keys,
        tail_keys,
      )
      let noise = match noise_reason {
        Some(_) => true
        None => false
      }

      let continuation = !noise &&
        block.kind == PdfConvertBlockKind::Paragraph &&
        i == blocks.length() - 1 &&
        is_block_near_page_end(page, block) &&
        !ends_like_sentence(t)

      page_out.push({
        kind: block.kind,
        text: block.text,
        page_index: block.page_index,
        line_start: block.line_start,
        line_end: block.line_end,
        char_count: block.char_count,
        is_noise: noise,
        noise_reason,
        is_cross_page_continuation_candidate: continuation,
      })

      i = i + 1
    }

    out.push(page_out)
    p = p + 1
  }

  out
}

///|
fn classify_noise_reason(
  text : String,
  idx : Int,
  page_len : Int,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> String? {
  let t = text.trim().to_string()
  if t == "" {
    return Some("empty")
  }

  if is_probable_page_number(t) {
    return Some("page_number")
  }

  if is_high_confidence_repeated_edge_noise(t, idx, page_len, head_keys, tail_keys) {
    return Some("repeated_edge")
  }

  None
}

///|
fn is_block_near_page_end(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  let total = page.lines.length()
  total > 0 && block.line_end >= total - 2
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
      c == ':' ||
      c == '：'
    None => false
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
  starts_with_numbered_heading(t)
}

///|
fn starts_with_numbered_heading(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n < 3 {
    return false
  }

  let mut i = 0
  while i < n && cs[i] >= '0' && cs[i] <= '9' {
    i = i + 1
  }

  if i == 0 || i >= n {
    return false
  }

  let c = cs[i]
  c == '.' || c == '、' || c == ')' || c == '）' || c == ' '
}

///|
fn looks_like_short_title_case_line(s : String) -> Bool {
  let t = s.trim().to_string()
  let n = t.to_array().length()
  if n < 3 || n > 42 {
    return false
  }

  if t.contains("，") || t.contains(",") {
    return false
  }

  if t.contains(" ") {
    let ws : Array[String] = []
    for sv in t.split(" ") {
      let w = sv.to_string().trim().to_string()
      if w != "" {
        ws.push(w)
      }
    }

    if ws.length() == 0 || ws.length() > 8 {
      return false
    }

    let mut good = 0
    for w in ws {
      let cs = w.to_array()
      if cs.length() > 0 {
        let c = cs[0]
        if c >= 'A' && c <= 'Z' {
          good = good + 1
        }
      }
    }
    return good * 2 >= ws.length()
  }

  // short compact CJK line can still be a title
  n <= 20
}
