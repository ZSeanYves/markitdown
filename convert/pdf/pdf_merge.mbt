///|
fn merge_classified_blocks(
  pages : Array[Array[PdfConvertBlock]],
) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []

  for page_blocks in pages {
    let kept = filter_page_blocks_with_content_guard(page_blocks)
    for block in kept {

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
fn filter_page_blocks_with_content_guard(
  page_blocks : Array[PdfConvertBlock],
) -> Array[PdfConvertBlock] {
  let kept : Array[PdfConvertBlock] = []
  for block in page_blocks {
    if !block.is_noise {
      kept.push(block)
    }
  }

  if kept.length() > 0 || page_blocks.length() == 0 {
    return kept
  }

  // Safety guard: never drop a whole page.
  let rescued = pick_rescue_block(page_blocks)
  kept.push({
    kind: rescued.kind,
    text: rescued.text,
    page_index: rescued.page_index,
    line_start: rescued.line_start,
    line_end: rescued.line_end,
    char_count: rescued.char_count,
    is_noise: false,
    noise_reason: Some("rescued_page_content_guard"),
    is_cross_page_continuation_candidate: false,
  })
  kept
}

///|
fn pick_rescue_block(page_blocks : Array[PdfConvertBlock]) -> PdfConvertBlock {
  let mut best = page_blocks[0]
  for block in page_blocks {
    let t = block.text.trim().to_string()
    let cur_ok = !is_probable_page_number(t) && t.to_array().length() > 4
    let best_ok = !is_probable_page_number(best.text.trim().to_string()) &&
      best.text.trim().to_string().to_array().length() > 4

    if cur_ok && !best_ok {
      best = block
      continue
    }

    if cur_ok == best_ok && block.char_count > best.char_count {
      best = block
    }
  }
  best
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
  let merged_text = append_pdf_text(prev.text, next.text) |> normalize_inline_spaces

  {
    kind: PdfConvertBlockKind::Paragraph,
    text: merged_text,
    page_index: prev.page_index,
    line_start: prev.line_start,
    line_end: prev.line_end,
    char_count: merged_text.to_array().length(),
    is_noise: false,
    noise_reason: None,
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
