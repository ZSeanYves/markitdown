///|
fn convert_pages_to_blocks(
  pages : Array[PdfConvertPage],
) -> Array[Array[PdfConvertBlock]] {
  let out : Array[Array[PdfConvertBlock]] = []
  for page in pages {
    out.push(native_page_lines_to_blocks(page.page_index, page.lines))
  }
  out
}

///|
fn native_page_lines_to_blocks(
  page_index : Int,
  lines : Array[PdfConvertLine],
) -> Array[PdfConvertBlock] {
  let blocks : Array[PdfConvertBlock] = []
  let para_lines : Array[String] = []
  let mut para_start = -1
  let mut para_end = -1

  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let text = line.text.trim().to_string()
    if line.is_explicit_break || text == "" {
      if para_lines.length() > 0 {
        let para_text = para_lines.join(" ").trim().to_string()
        if para_text != "" {
          blocks.push({
            kind: PdfConvertBlockKind::Paragraph,
            text: para_text,
            page_index,
            line_start: para_start,
            line_end: para_end,
          })
        }
        para_lines.clear()
        para_start = -1
        para_end = -1
      }
      i = i + 1
      continue
    }

    if should_be_standalone_line(lines, i) {
      if para_lines.length() > 0 {
        let para_text = para_lines.join(" ").trim().to_string()
        if para_text != "" {
          blocks.push({
            kind: PdfConvertBlockKind::Paragraph,
            text: para_text,
            page_index,
            line_start: para_start,
            line_end: para_end,
          })
        }
        para_lines.clear()
        para_start = -1
        para_end = -1
      }
      blocks.push({
        kind: PdfConvertBlockKind::StandaloneLine,
        text,
        page_index,
        line_start: i,
        line_end: i,
      })
      i = i + 1
      continue
    }

    if para_start < 0 {
      para_start = i
    }
    para_end = i
    para_lines.push(text)
    i = i + 1
  }

  if para_lines.length() > 0 {
    let para_text = para_lines.join(" ").trim().to_string()
    if para_text != "" {
      blocks.push({
        kind: PdfConvertBlockKind::Paragraph,
        text: para_text,
        page_index,
        line_start: para_start,
        line_end: para_end,
      })
    }
  }
  blocks
}

///|
fn should_be_standalone_line(lines : Array[PdfConvertLine], i : Int) -> Bool {
  if i < 0 || i >= lines.length() {
    return false
  }
  let text = lines[i].text.trim().to_string()
  if text == "" {
    return false
  }

  let cur_len = text_len(text)
  if cur_len == 0 {
    return false
  }

  if cur_len <= 36 && looks_like_section_marker_line(text) {
    return true
  }

  if cur_len <= 8 && !looks_like_sentence_line(text) {
    return true
  }

  if cur_len > 20 {
    return false
  }

  let prev_len = prev_non_break_line_len(lines, i)
  let next_len = next_non_break_line_len(lines, i)
  let long_neighbor = if prev_len > next_len { prev_len } else { next_len }
  long_neighbor >= 36 &&
  long_neighbor >= cur_len * 2 &&
  !looks_like_sentence_line(text)
}

///|
fn prev_non_break_line_len(lines : Array[PdfConvertLine], i : Int) -> Int {
  let mut j = i - 1
  while j >= 0 {
    let line = lines[j]
    let t = line.text.trim().to_string()
    if !line.is_explicit_break && t != "" {
      return text_len(t)
    }
    if j == 0 {
      break
    }
    j = j - 1
  }
  0
}

///|
fn next_non_break_line_len(lines : Array[PdfConvertLine], i : Int) -> Int {
  let mut j = i + 1
  while j < lines.length() {
    let line = lines[j]
    let t = line.text.trim().to_string()
    if !line.is_explicit_break && t != "" {
      return text_len(t)
    }
    j = j + 1
  }
  0
}

///|
fn looks_like_section_marker_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  (t.contains("第") && (t.contains("章") || t.contains("节"))) ||
  t.contains("Chapter") ||
  t.contains("CHAPTER") ||
  t.contains("Section") ||
  t.contains("SECTION") ||
  t.contains("、") ||
  t.contains(")")
}

///|
fn looks_like_sentence_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  t.contains("。") ||
  t.contains("！") ||
  t.contains("？") ||
  t.contains(".") ||
  t.contains("!") ||
  t.contains("?") ||
  t.contains("，") ||
  t.contains(",")
}

///|
fn text_len(s : String) -> Int {
  s.to_array().length()
}
