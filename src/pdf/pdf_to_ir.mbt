///|
/// Convert plain text into IR.
/// New strategy:
/// - Normalize line endings
/// - Split pages by formfeed \f
/// - Detect repeated header/footer noise across pages
/// - Strip page-level noise page by page
/// - Merge cleaned pages with an internal page-break marker
/// - Recover blocks once on the merged text
fn text_to_ir_document(text0 : String) -> @cor.Document {
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let pages : Array[String] = []
  for page_sv in text.split("\f") {
    let page = page_sv.to_string()
    if page.trim() != "" {
      pages.push(page)
    }
  }

  if pages.length() == 0 {
    return doc
  }

  let (head_keys, tail_keys) = detect_repeated_page_noise(pages)

  let clean_pages : Array[String] = []
  let mut _page_idx = 0
  for page in pages {
    let clean_page = strip_page_noise(page, head_keys, tail_keys)
    if clean_page.trim() != "" {
      clean_pages.push(clean_page)

      //println("[pdf-cross-debug] clean page " + page_idx.to_string())
      let mut shown = 0
      for sv in clean_page.split("\n") {
        let line = sv.to_string().trim().to_string()
        if line != "" {
          //println("[pdf-cross-debug]   " + line)
          shown += 1
          if shown >= 8 {
            break
          }
        }
      }
    }
    _page_idx += 1
  }

  let merged = merge_clean_pages_with_breaks(clean_pages)
  //println("[pdf-cross-debug] merged preview")
  let mut shown = 0
  for sv in merged.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      //println("[pdf-cross-debug]   " + line)
      shown += 1
      if shown >= 15 {
        break
      }
    }
  }

  let mut first_block = true
  for b in split_blocks_smart(merged) {
    if !first_block {
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_block = false
    }

    match b {
      PdfBlock::Heading(level, text) =>
        @cor.push(doc, @cor.Block::Heading(level, text))
      PdfBlock::Paragraph(text) => @cor.push(doc, @cor.Block::Paragraph(text))
      PdfBlock::ListItem(ordered, level, text) =>
        @cor.push(doc, @cor.Block::ListItem(ordered, level, text))
    }
  }

  doc
}
