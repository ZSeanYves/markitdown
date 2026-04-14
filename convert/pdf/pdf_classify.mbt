///|
pub fn classify_convert_blocks(
  pages : Array[PdfConvertPage],
) -> Array[PdfConvertPage] {
  let out = Array::new()

  for page in pages {
    let blocks = Array::new()
    for b in page.blocks {
      let kind = if b.kind == PdfConvertBlockKind::Heading && is_false_heading(b.text) {
        PdfConvertBlockKind::Paragraph
      } else {
        b.kind
      }
      blocks.push({
        page_index: b.page_index,
        kind,
        text: b.text,
        heading_level: b.heading_level,
        line_count: b.line_count,
      })
    }
    out.push({ page_index: page.page_index, lines: page.lines, blocks })
  }

  out
}

///|
fn is_false_heading(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return true
  }

  if t.to_array().length() > 80 {
    return true
  }

  if is_list_like_line(t) {
    return true
  }

  if ends_with_sentence_punct(t) {
    return true
  }

  false
}

///|
fn is_list_like_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
  if cs.length() < 2 {
    return false
  }

  if is_ascii_digit(cs[0]) && (cs[1] == '.' || cs[1] == ')') {
    return true
  }

  false
}

///|
fn ends_with_sentence_punct(s : String) -> Bool {
  let cs = s.to_array()
  if cs.length() == 0 {
    return false
  }
  let c = cs[cs.length() - 1]
  c == '。' ||
  c == '！' ||
  c == '？' ||
  c == '.' ||
  c == '!' ||
  c == '?' ||
  c == ';' ||
  c == '；'
}

///|
fn is_ascii_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}
