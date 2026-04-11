///|
fn classify_blocks(
  pages : Array[PdfConvertPage],
  page_blocks : Array[Array[PdfConvertBlock]],
) -> Array[Array[PdfConvertBlock]] {
  let (head_keys, tail_keys) = detect_repeated_edge_noise(page_blocks)
  let out : Array[Array[PdfConvertBlock]] = []

  let mut p = 0
  while p < page_blocks.length() {
    let page = pages[p]
    let blocks = page_blocks[p]
    let page_out : Array[PdfConvertBlock] = []

    let mut i = 0
    while i < blocks.length() {
      let b = blocks[i]
      let text = b.text.trim().to_string()

      let (kind, ordered, level) = classify_kind(text)
      let noise_reason = classify_noise(text, i, blocks.length(), head_keys, tail_keys)
      let noise = match noise_reason {
        Some(_) => true
        None => false
      }

      let cross_page = !noise &&
        kind == PdfConvertBlockKind::Paragraph &&
        i == blocks.length() - 1 &&
        block_near_page_end(page, b) &&
        !ends_like_sentence(text)

      page_out.push({
        kind,
        text: b.text,
        page_index: b.page_index,
        line_start: b.line_start,
        line_end: b.line_end,
        is_noise: noise,
        noise_reason,
        is_cross_page_continuation_candidate: cross_page,
        list_ordered: ordered,
        list_level: level,
      })
      i = i + 1
    }

    out.push(page_out)
    p = p + 1
  }

  out
}

///|
fn classify_kind(text : String) -> (PdfConvertBlockKind, Bool, Int) {
  let t = text.trim().to_string()
  if t == "" {
    return (PdfConvertBlockKind::Paragraph, false, 0)
  }

  match parse_list_marker(t) {
    Some((ordered, level)) => return (PdfConvertBlockKind::ListItem, ordered, level)
    None => ()
  }

  if is_heading_line(t) {
    return (PdfConvertBlockKind::Heading, false, 0)
  }

  (PdfConvertBlockKind::Paragraph, false, 0)
}

///|
fn classify_noise(
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

  if is_edge_repeated_noise(t, idx, page_len, head_keys, tail_keys) {
    return Some("repeated_edge")
  }

  None
}

///|
fn block_near_page_end(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  let total = page.lines.length()
  total > 0 && block.line_end >= total - 2
}

///|
fn is_heading_line(t : String) -> Bool {
  let n = t.to_array().length()
  if n < 3 || n > 80 {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if t.has_prefix("#") || t.has_prefix("第") || t.has_prefix("Chapter") || t.has_prefix("SECTION") {
    return true
  }

  let ws : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      ws.push(w)
    }
  }

  if ws.length() >= 2 && ws.length() <= 8 {
    let mut capitals = 0
    for w in ws {
      let cs = w.to_array()
      if cs.length() > 0 {
        let c = cs[0]
        if c >= 'A' && c <= 'Z' {
          capitals = capitals + 1
        }
      }
    }
    return capitals * 2 >= ws.length()
  }

  false
}

///|
fn parse_list_marker(text : String) -> (Bool, Int)? {
  let t = text.trim().to_string()
  if t == "" {
    return None
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return Some((false, 1))
  }

  let cs = t.to_array()
  let mut i = 0
  while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
    i = i + 1
  }

  if i > 0 && i + 1 < cs.length() {
    let sep = cs[i]
    let sp = cs[i + 1]
    if (sep == '.' || sep == ')') && sp == ' ' {
      return Some((true, 1))
    }
  }

  None
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  let cs = t.to_array()
  let c = cs[cs.length() - 1]
  c == '。' || c == '！' || c == '？' || c == '.' || c == '!' || c == '?'
}
