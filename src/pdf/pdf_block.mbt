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
fn split_blocks_smart(page : String) -> Array[PdfBlock] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let lines : Array[PdfLine] = []
  for sv in s.split("\n") {
    let raw0 = sv.to_string()
    for raw in split_compound_pseudo_column_line(raw0) {
      let line = raw.trim().to_string()

      if line == PDF_PAGE_BREAK_MARKER {
        lines.push(PdfLine::PageBreak)
      } else if line == "" {
        lines.push(PdfLine::Blank)
      } else if !is_noise_line(line) {
        lines.push(PdfLine::Text(line))
      }
    }
  }

  let out : Array[PdfBlock] = []
  let mut buf = ""
  let mut buf_is_page_lead = false
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
          buf_is_page_lead = prev_was_page_break || out.length() == 0
          prev_was_page_break = false
        } else if should_start_new_block(buf, cur, prev_was_page_break) {
          let promote_page_start_heading = buf_is_page_lead &&
            looks_like_list_item_sentence(cur.trim().to_string()) &&
            looks_like_short_page_start_section_title(buf)
          flush_pdf_block_with_hint(
            out,
            buf,
            promote_page_start_heading,
          )
          buf = cur
          buf_is_page_lead = prev_was_page_break
          prev_was_page_break = false
        } else if should_flush_buf_before_appending(buf, cur, buf_is_page_lead) {
          flush_pdf_block(out, buf)
          buf = cur
          buf_is_page_lead = prev_was_page_break
          prev_was_page_break = false
        } else {
          buf = append_line(buf, cur)
          buf_is_page_lead = false
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
fn flush_pdf_block(out : Array[PdfBlock], buf : String) -> Unit {
  flush_pdf_block_with_hint(out, buf, false)
}

///|
fn flush_pdf_block_with_hint(
  out : Array[PdfBlock],
  buf : String,
  prefer_heading : Bool,
) -> Unit {
  let raw = buf.trim().to_string()
  if raw == "" {
    return
  }

  match parse_pdf_list_item(raw) {
    Some((ordered, level, text)) => {
      if ordered && !should_accept_ordered_list_item(out, raw) {
        // keep it as paragraph-like text instead of forcing ordered list
      } else {
        let t = trim_string_for_pdf_block(text)
        if t != "" {
          out.push(PdfBlock::ListItem(ordered, level, t))
        }
        return
      }
    }
    None => ()
  }

  if prefer_heading {
    let h = finalize_heading(raw)
    if h != "" {
      out.push(PdfBlock::Heading(2, h))
    }
    return
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
fn should_accept_ordered_list_item(out : Array[PdfBlock], raw : String) -> Bool {
  let t = raw.trim().to_string()
  if !looks_like_list_item_sentence(t) {
    return false
  }

  if out.length() == 0 {
    return false
  }

  match out[out.length() - 1] {
    PdfBlock::ListItem(true, _, _) => return true
    PdfBlock::Heading(_, _) => return true
    _ => ()
  }

  false
}

///|
fn looks_like_short_page_start_section_title(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" || ends_like_sentence(t) || is_probable_page_number(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_side_marker_label_line(t) {
    return false
  }

  let n = t.to_array().length()
  n >= 6 && n <= 40
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

  if looks_like_label_token_line_start(t) {
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

  if should_break_numbered_sentence_and_emphasis(buf, t) {
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

  if looks_like_label_token_line_start(t) {
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

  if looks_like_section_marker_like(r) {
    return false
  }

  if looks_like_list_item_sentence(r) {
    return false
  }

  if guess_numbered_heading_level(r) > 0 {
    return false
  }

  if looks_like_short_uppercase_title_like(r) {
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
fn should_flush_buf_before_appending(
  buf : String,
  cur : String,
  buf_is_page_lead : Bool,
) -> Bool {
  let b = buf.trim().to_string()
  let t = cur.trim().to_string()

  if b == "" || t == "" {
    return false
  }

  // page-leading heading-like lines should stay standalone;
  // avoid being absorbed by following paragraph lines.
  if buf_is_page_lead && looks_like_page_leading_heading(b) &&
    !looks_like_list_item_sentence(t) {
    return true
  }

  // pseudo two-column labels should not be linearized into one big paragraph.
  if looks_like_pseudo_column_line(b) && looks_like_pseudo_column_line(t) {
    return true
  }

  // a heading candidate should usually stand alone
  if is_strong_heading_candidate(b) &&
    !is_strong_heading_candidate(t) &&
    !looks_like_list_item_sentence(t) {
    return true
  }

  // a single list item should not absorb following prose
  if looks_like_list_item_sentence(b) &&
    !looks_like_list_item_sentence(t) &&
    !should_continue_previous_list_item(b, t) {
    return true
  }
  if ends_like_sentence(b) && looks_like_figure_or_table_caption(t) {
    return true
  }

  if ends_like_sentence(b) && looks_like_intro_phrase(t) {
    return true
  }

  if looks_like_uppercase_emphasis_line(b) &&
    !looks_like_uppercase_emphasis_line(t) {
    return true
  }

  false
}

///|
fn split_compound_pseudo_column_line(raw : String) -> Array[String] {
  let t = raw.trim().to_string()
  if !t.contains("LEFT-") || !t.contains("RIGHT-") {
    return [raw]
  }

  let cs = raw.to_array()
  let mut i = 0
  let n = cs.length()
  let mut split_at = -1
  while i + 5 < n {
    if cs[i] == 'R' &&
      cs[i + 1] == 'I' &&
      cs[i + 2] == 'G' &&
      cs[i + 3] == 'H' &&
      cs[i + 4] == 'T' &&
      cs[i + 5] == '-' {
      split_at = i
      break
    }
    i += 1
  }

  if split_at <= 0 {
    return [raw]
  }

  let left = String::from_array(cs[:split_at].to_array()).trim().to_string()
  let right = String::from_array(cs[split_at:].to_array()).trim().to_string()
  if left == "" || right == "" {
    return [raw]
  }

  [left, right]
}

///|
fn looks_like_label_token_line_start(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" || !t.contains("-") || !t.contains(" ") {
    return false
  }

  let mut first = ""
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      first = w
      break
    }
  }
  if first == "" {
    return false
  }

  if first.has_prefix("LEFT-") || first.has_prefix("RIGHT-") {
    return true
  }

  // generic marker like ABC-12 / ABC-A3
  let cs = first.to_array()
  let n = cs.length()
  if n < 4 {
    return false
  }

  let mut i = 0
  let mut has_upper_prefix = false
  while i < n {
    let c = cs[i]
    if c >= 'A' && c <= 'Z' {
      has_upper_prefix = true
      i += 1
      continue
    }
    break
  }
  if !has_upper_prefix || i >= n || cs[i] != '-' {
    return false
  }
  i += 1
  if i >= n {
    return false
  }

  // optional single uppercase letter after '-'
  if cs[i] >= 'A' && cs[i] <= 'Z' {
    i += 1
    if i >= n {
      return false
    }
  }

  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    return false
  }

  has_digit
}

///|
fn should_continue_previous_list_item(prev : String, cur : String) -> Bool {
  let p = prev.trim().to_string()
  let t = cur.trim().to_string()
  if !looks_like_list_item_sentence(p) || t == "" {
    return false
  }

  if looks_like_list_item_sentence(t) ||
    is_strong_heading_candidate(t) ||
    guess_numbered_heading_level(t) > 0 ||
    looks_like_section_marker_like(t) {
    return false
  }

  // wrapped continuation line often starts lowercase and is not sentence-ended
  // (e.g. "be attached to previous page paragraph.")
  !starts_like_new_block(t)
}

///|
fn looks_like_page_leading_heading(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_strong_heading_candidate(t) {
    return true
  }

  if guess_numbered_heading_level(t) > 0 {
    return true
  }

  if looks_like_section_marker_like(t) {
    return true
  }

  if looks_like_document_title(t) {
    return true
  }

  false
}

///|
fn looks_like_short_uppercase_title_like(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
  let n = cs.length()
  if n < 4 || n > 48 {
    return false
  }

  let mut alpha = 0
  let mut upper = 0
  for c in cs {
    if c >= 'A' && c <= 'Z' {
      alpha += 1
      upper += 1
    } else if c >= 'a' && c <= 'z' {
      alpha += 1
    }
  }

  alpha >= 4 && upper * 10 >= alpha * 8
}

///|
fn looks_like_section_marker_like(s : String) -> Bool {
  let t = s.trim().to_string()
  if t.has_prefix("page ") ||
    t.has_prefix("Page ") ||
    t.has_prefix("section ") ||
    t.has_prefix("Section ") ||
    t.has_prefix("part ") ||
    t.has_prefix("Part ") ||
    t.has_prefix("chapter ") ||
    t.has_prefix("Chapter ") {
    return true
  }
  looks_like_heading_marker(t)
}

///|
fn looks_like_pseudo_column_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t.to_array().length() < 6 || !t.contains("-") || !t.contains(" ") {
    return false
  }

  let mut head = ""
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      head = w
      break
    }
  }
  if head == "" || !head.contains("-") {
    return false
  }

  let mut has_upper = false
  for c in head.to_array() {
    let ok = (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-'
    if !ok {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      has_upper = true
    }
  }
  has_upper
}
