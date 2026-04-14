///|
pub fn merge_convert_blocks(
  pages : Array[PdfConvertPage],
) -> PdfConvertDocument {
  let flattened = Array::new()
  for page in pages {
    for b in page.blocks {
      if b.kind != PdfConvertBlockKind::Noise {
        flattened.push(b)
      }
    }
  }

  let merged = Array::new()
  for b in flattened {
    if merged.is_empty() {
      merged.push(b)
      continue
    }

    let prev = merged[merged.length() - 1]
    if should_merge_paragraph(prev, b) {
      merged[merged.length() - 1] = {
        page_index: prev.page_index,
        kind: PdfConvertBlockKind::Paragraph,
        text: join_with_space(prev.text, b.text),
        heading_level: 0,
        line_count: prev.line_count + b.line_count,
      }
    } else {
      merged.push(b)
    }
  }

  { pages, blocks: merged }
}

///|
fn should_merge_paragraph(prev : PdfConvertBlock, next : PdfConvertBlock) -> Bool {
  if prev.kind != PdfConvertBlockKind::Paragraph {
    return false
  }
  if next.kind != PdfConvertBlockKind::Paragraph {
    return false
  }

  if prev.page_index == next.page_index {
    return false
  }

  if ends_with_strong_sentence(prev.text) {
    return false
  }

  if looks_like_heading_start(next.text) {
    return false
  }

  true
}

///|
fn join_with_space(a : String, b : String) -> String {
  let left = a.trim().to_string()
  let right = b.trim().to_string()
  if left == "" {
    return right
  }
  if right == "" {
    return left
  }
  left + " " + right
}

///|
fn ends_with_strong_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
  if cs.length() == 0 {
    return false
  }
  let c = cs[cs.length() - 1]
  c == '.' || c == '!' || c == '?' || c == '。' || c == '！' || c == '？'
}

///|
fn looks_like_heading_start(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t.to_array().length() <= 28 && !ends_with_strong_sentence(t) {
    return true
  }

  if t.has_prefix("第") ||
    t.has_prefix("Chapter") ||
    t.has_prefix("CHAPTER") {
    return true
  }

  if t.has_prefix("1.") || t.has_prefix("2.") || t.has_prefix("3.") {
    return true
  }

  false
}
