///|
fn classify_convert_blocks(
  pages : Array[PdfConvertPage],
  page_blocks : Array[Array[PdfConvertBlock]],
) -> Array[Array[PdfConvertBlock]] {
  let out : Array[Array[PdfConvertBlock]] = []

  let mut p = 0
  while p < page_blocks.length() {
    let blocks = page_blocks[p]
    let page = pages[p]
    let classified_page : Array[PdfConvertBlock] = []

    let mut i = 0
    while i < blocks.length() {
      let block = blocks[i]
      let t = block.text.trim().to_string()
      let prev_char_count = previous_block_char_count(blocks, i)
      let next_char_count = next_block_char_count(blocks, i)

      let is_list_candidate = match parse_pdf_list_item(t) {
        Some(_) => true
        None => false
      }

      let is_noise_candidate = is_probable_page_number(t) ||
        (is_noise_line(t) && block.char_count <= 40)

      let heading_like_short_block =
        block.char_count <= 40 &&
        block.line_count <= 2 &&
        !looks_like_sentence_line(t)

      let has_length_contrast =
        (prev_char_count >= block.char_count * 2 && prev_char_count >= 24) ||
        (next_char_count >= block.char_count * 2 && next_char_count >= 24)

      let is_heading_candidate = !is_noise_candidate && !is_list_candidate &&
        (is_strong_heading_candidate(t) ||
        looks_like_section_marker_line(t) ||
        (heading_like_short_block && has_length_contrast) ||
        (match block.kind {
          PdfConvertBlockKind::StandaloneLine => heading_like_short_block
          PdfConvertBlockKind::Paragraph => false
        }))

      let is_cross_page_continuation_candidate = !is_noise_candidate &&
        !is_heading_candidate &&
        !is_list_candidate &&
        is_block_near_page_end(page, block) &&
        !ends_like_sentence(t) &&
        starts_with_continuation_token(next_page_first_text(page_blocks, p))

      classified_page.push({
        kind: block.kind,
        text: block.text,
        page_index: block.page_index,
        line_start: block.line_start,
        line_end: block.line_end,
        line_count: block.line_count,
        char_count: block.char_count,
        is_heading_candidate,
        is_list_candidate,
        is_noise_candidate,
        is_cross_page_continuation_candidate,
      })

      i = i + 1
    }

    out.push(classified_page)
    p = p + 1
  }

  out
}

///|
fn previous_block_char_count(blocks : Array[PdfConvertBlock], i : Int) -> Int {
  let mut j = i - 1
  while j >= 0 {
    let n = blocks[j].char_count
    if n > 0 {
      return n
    }
    if j == 0 {
      break
    }
    j = j - 1
  }
  0
}

///|
fn next_block_char_count(blocks : Array[PdfConvertBlock], i : Int) -> Int {
  let mut j = i + 1
  while j < blocks.length() {
    let n = blocks[j].char_count
    if n > 0 {
      return n
    }
    j = j + 1
  }
  0
}

///|
fn is_block_near_page_end(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  let total = page.lines.length()
  if total == 0 {
    return false
  }
  block.line_end >= total - 2
}

///|
fn next_page_first_text(page_blocks : Array[Array[PdfConvertBlock]], p : Int) -> String {
  let next_idx = p + 1
  if next_idx >= page_blocks.length() {
    return ""
  }

  for block in page_blocks[next_idx] {
    let t = block.text.trim().to_string()
    if t != "" {
      return t
    }
  }

  ""
}

///|
fn starts_with_continuation_token(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_strong_heading_candidate(t) ||
    looks_like_section_marker_line(t) ||
    looks_like_list_item_sentence(t) {
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
