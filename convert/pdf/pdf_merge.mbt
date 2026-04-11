///|
fn merge_classified_blocks(
  pages : Array[Array[PdfConvertBlock]],
) -> Array[PdfConvertBlock] {
  let out : Array[PdfConvertBlock] = []
  for page_blocks in pages {
    for block in page_blocks {
      if out.length() == 0 {
        if !is_high_confidence_noise_block(block) {
          out.push(block)
        }
        continue
      }

      if is_high_confidence_noise_block(block) {
        continue
      }

      let prev = out[out.length() - 1]
      if prev.page_index != block.page_index &&
        should_merge_cross_page_blocks(prev, block) {
        out[out.length() - 1] = merge_cross_page_blocks(prev, block)
      } else {
        out.push(block)
      }
    }
  }
  out
}

///|
fn is_high_confidence_noise_block(block : PdfConvertBlock) -> Bool {
  if !block.is_noise_candidate {
    return false
  }

  let t = block.text.trim().to_string()
  is_probable_page_number(t) || (block.char_count <= 3 && block.line_count == 1)
}

///|
fn should_merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> Bool {
  prev.is_cross_page_continuation_candidate &&
  !next.is_heading_candidate &&
  !next.is_list_candidate &&
  !next.is_noise_candidate &&
  !ends_like_sentence(prev.text.trim().to_string())
}

///|
fn merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> PdfConvertBlock {
  let merged_text = append_line(
    prev.text.trim().to_string(),
    next.text.trim().to_string(),
  )
  {
    kind: PdfConvertBlockKind::Paragraph,
    text: merged_text,
    page_index: prev.page_index,
    line_start: prev.line_start,
    line_end: prev.line_end,
    line_count: prev.line_count + next.line_count,
    char_count: text_len(merged_text),
    is_heading_candidate: false,
    is_list_candidate: false,
    is_noise_candidate: false,
    is_cross_page_continuation_candidate: false,
  }
}
