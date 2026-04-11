///|
fn merge_classified_blocks(
  pages : Array[Array[PdfConvertBlock]],
) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []

  for page_blocks in pages {
    for block in page_blocks {
      if block.is_noise {
        continue
      }

      if out.length() == 0 {
        out.push(block)
        continue
      }

      let prev = out[out.length() - 1]
      if should_merge_cross_page_blocks(prev, block) {
        out[out.length() - 1] = merge_cross_page_blocks(prev, block)
      } else {
        out.push(block)
      }
    }
  }

  out
}

///|
fn should_merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> Bool {
  prev.page_index + 1 == next.page_index &&
  prev.kind == PdfConvertBlockKind::Paragraph &&
  next.kind == PdfConvertBlockKind::Paragraph &&
  prev.is_cross_page_continuation_candidate &&
  starts_with_continuation(next.text)
}

///|
fn merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> PdfConvertBlock {
  let merged_text = (prev.text.trim().to_string() + " " + next.text.trim().to_string())
    |> normalize_inline_spaces

  {
    kind: PdfConvertBlockKind::Paragraph,
    text: merged_text,
    page_index: prev.page_index,
    line_start: prev.line_start,
    line_end: prev.line_end,
    char_count: merged_text.to_array().length(),
    is_noise: false,
    is_cross_page_continuation_candidate: false,
  }
}

///|
fn starts_with_continuation(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_heading_marker(t) {
    return false
  }

  match first_char(t) {
    Some(c) =>
      (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      is_cjkish(c)
    None => false
  }
}

///|
fn is_cjkish(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x3400 && code <= 0x9FFF) ||
  (code >= 0xF900 && code <= 0xFAFF)
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
