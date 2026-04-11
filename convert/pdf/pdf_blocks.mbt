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
  let para_lines : Array[String] = []
  let mut para_start = -1
  let mut para_end = -1

  for line in page.lines {
    let text = normalize_line_text(line.text)
    if line.is_explicit_break || text == "" {
      flush_paragraph_block(blocks, page.page_index, para_lines, para_start, para_end)
      para_lines.clear()
      para_start = -1
      para_end = -1
      continue
    }

    if should_be_heading_line(text, para_lines.length() == 0) {
      flush_paragraph_block(blocks, page.page_index, para_lines, para_start, para_end)
      para_lines.clear()
      para_start = -1
      para_end = -1

      blocks.push(make_block(
        PdfConvertBlockKind::Heading,
        text,
        page.page_index,
        line.line_index,
        line.line_index,
      ))
      continue
    }

    if para_start < 0 {
      para_start = line.line_index
    }
    para_end = line.line_index
    para_lines.push(text)
  }

  flush_paragraph_block(blocks, page.page_index, para_lines, para_start, para_end)
  blocks
}

///|
fn flush_paragraph_block(
  blocks : Array[PdfConvertBlock],
  page_index : Int,
  para_lines : Array[String],
  line_start : Int,
  line_end : Int,
) -> Unit {
  if para_lines.length() == 0 || line_start < 0 || line_end < 0 {
    return
  }

  let text = para_lines.join(" ") |> normalize_inline_spaces
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
    is_cross_page_continuation_candidate: false,
  }
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
