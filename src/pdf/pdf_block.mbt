///|
priv enum PdfBlock {
  Heading(Int, String)
  Paragraph(String)
  ListItem(Bool, Int, String) // ordered, level, text
}

///|
priv enum PdfLine {
  Blank
  PageBreak
  Text(String)
}

///|
fn split_blocks_smart(page : String) -> Array[PdfBlock] raise {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let lines : Array[PdfLine] = []
  for sv in s.split("\n") {
    let raw = sv.to_string()
    let line = raw.trim().to_string()

    if line == PDF_PAGE_BREAK_MARKER {
      lines.push(PdfLine::PageBreak)
    } else if line == "" {
      lines.push(PdfLine::Blank)
    } else if !is_noise_line(line) {
      lines.push(PdfLine::Text(line))
    }
  }

  let out : Array[PdfBlock] = []
  let mut buf = ""
  let mut prev_was_page_break = false

  let n = lines.length()
  let mut i = 0
  while i < n {
    match lines[i] {
      PdfLine::Blank => {
        if buf != "" {
          flush_pdf_block(out, buf)
          buf = ""
        }
        prev_was_page_break = false
      }
      PdfLine::PageBreak =>
        // 先记住跨页，不立即 flush；
        // 是否续段交给下一条正文判断
        prev_was_page_break = true
      PdfLine::Text(cur) =>
        if buf == "" {
          buf = cur
          prev_was_page_break = false
        } else if should_start_new_block(buf, cur, prev_was_page_break) {
          flush_pdf_block(out, buf)
          buf = cur
          prev_was_page_break = false
        } else if should_flush_buf_before_appending(buf, cur) {
          flush_pdf_block(out, buf)
          buf = cur
          prev_was_page_break = false
        } else {
          buf = append_line(buf, cur)
          prev_was_page_break = false
        }
    }

    i = i + 1
  }

  if buf != "" {
    flush_pdf_block(out, buf)
  }

  out
}

///|
fn flush_pdf_block(out : Array[PdfBlock], buf : String) -> Unit raise {
  let raw = buf.trim().to_string()
  if raw == "" {
    return
  }

  match parse_pdf_list_item(raw) {
    Some((ordered, level, text)) => {
      let t = trim_string_for_pdf_block(text)
      if t != "" {
        out.push(PdfBlock::ListItem(ordered, level, t))
      }
      return
    }
    None => ()
  }

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

///|
fn trim_string_for_pdf_block(s : String) -> String {
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
fn should_start_new_block(
  buf : String,
  cur : String,
  prev_was_page_break : Bool,
) -> Bool {
  let t = cur.trim().to_string()
  if t == "" {
    return true
  }

  // 列表项一定开新块
  if looks_like_list_item_sentence(t) {
    return true
  }

  // 强标题候选通常开新块
  if is_strong_heading_candidate(t) {
    return true
  }

  // 跨页：优先判断是否应续段
  if prev_was_page_break {
    if should_merge_across_page_break(buf, t) {
      return false
    } else {
      return true
    }
  }

  // 同页：当前行像新块起点，而前文又不像完整句时，开新块
  if starts_like_new_block(t) && !ends_like_sentence(buf) {
    return true
  }

  false
}

///|
/// Conservative block boundary detection.
/// Only split early for strong structural signals.
/// Do NOT use short plain title heuristics here,
/// otherwise hard-wrapped Chinese lines will be over-split.
fn starts_like_new_block(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return true
  }

  if guess_numbered_heading_level(t) > 0 {
    return true
  }

  if looks_like_heading_marker(t) && !ends_like_sentence(t) {
    return true
  }

  // English title-like lines can start a new block,
  // but exclude common false positives first.
  if looks_like_english_title(t) &&
    !looks_like_figure_or_table_caption(t) &&
    !looks_like_intro_phrase(t) &&
    !looks_like_list_intro_line(t) {
    return true
  }

  false
}

///|
fn should_merge_across_page_break(left : String, right : String) -> Bool {
  let l = left.trim().to_string()
  let r = right.trim().to_string()

  if l == "" || r == "" {
    return false
  }

  if is_strong_heading_candidate(r) {
    return false
  }

  if looks_like_list_item_sentence(r) {
    return false
  }

  if looks_like_figure_or_table_caption(r) {
    return false
  }

  // if right starts with lowercase latin, it is very likely a continuation
  match first_char(r) {
    Some(c) => if c >= 'a' && c <= 'z' { return true }
    None => ()
  }

  // if the previous page ends with a sentence terminator,
  // usually do not merge across page break
  if ends_like_sentence(l) {
    return false
  }

  true
}

///|
/// If the current buffer already looks like a complete standalone block,
/// do not keep appending normal body text to it.
fn should_flush_buf_before_appending(buf : String, cur : String) -> Bool {
  let b = buf.trim().to_string()
  let t = cur.trim().to_string()

  if b == "" || t == "" {
    return false
  }

  // a heading candidate should usually stand alone
  if is_strong_heading_candidate(b) &&
    !is_strong_heading_candidate(t) &&
    !looks_like_list_item_sentence(t) {
    return true
  }

  // a single list item should not absorb following prose
  if looks_like_list_item_sentence(b) && !looks_like_list_item_sentence(t) {
    return true
  }
  if ends_like_sentence(b) && looks_like_figure_or_table_caption(t) {
    return true
  }

  if ends_like_sentence(b) && looks_like_intro_phrase(t) {
    return true
  }

  false
}
