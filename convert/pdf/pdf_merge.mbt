///|
fn merge_blocks(pages : Array[Array[PdfConvertBlock]]) -> Array[PdfConvertBlock] {
  let merged : Array[PdfConvertBlock] = []

  for page_blocks in pages {
    for block in page_blocks {
      if block.is_noise {
        continue
      }

      if merged.length() == 0 {
        merged.push(block)
        continue
      }

      let prev = merged[merged.length() - 1]
      if should_merge(prev, block) {
        merged[merged.length() - 1] = merge_two(prev, block)
      } else {
        merged.push(block)
      }
    }
  }

  merged
}

///|
/// 这一轮别恢复同页 merge。
/// 继续只保留保守的跨页续段。
///|
fn should_merge(a : PdfConvertBlock, b : PdfConvertBlock) -> Bool {
  if a.kind != PdfConvertBlockKind::Paragraph || b.kind != PdfConvertBlockKind::Paragraph {
    return false
  }

  if a.is_noise || b.is_noise {
    return false
  }

  if a.page_index == b.page_index {
    return false
  }

  if a.page_index + 1 != b.page_index {
    return false
  }

  if !a.is_cross_page_continuation_candidate {
    return false
  }

  // 下一块如果已经很像标题，就不要跨页吞并
  if detect_heading_level(b.text, 0) > 0 {
    return false
  }

  starts_with_continuation(b.text)
}

///|
fn merge_two(a : PdfConvertBlock, b : PdfConvertBlock) -> PdfConvertBlock {
  let text = join_paragraph_text(a.text, b.text)
  {
    kind: PdfConvertBlockKind::Paragraph,
    text,
    page_index: a.page_index,
    line_start: a.line_start,
    line_end: b.line_end,
    is_noise: false,
    noise_reason: None,
    is_cross_page_continuation_candidate: false,
    list_ordered: false,
    list_level: 0,
    heading_level: 0,
  }
}

///|
fn join_paragraph_text(a : String, b : String) -> String {
  let left = a.trim().to_string()
  let right = b.trim().to_string()

  if left == "" {
    return right
  }
  if right == "" {
    return left
  }

  if left.has_suffix("-") && starts_with_latin(right) {
    return drop_last_char(left) + right
  }

  if should_join_without_space(left, right) {
    left + right
  } else {
    left + " " + right
  }
}

///|
fn starts_with_continuation(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if detect_heading_level(t, 0) > 0 {
    return false
  }

  let cs = t.to_array()
  if cs.length() == 0 {
    return false
  }

  let c = cs[0]
  (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || is_cjkish(c)
}