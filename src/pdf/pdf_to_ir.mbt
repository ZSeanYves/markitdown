///|
/// Convert plain text into IR.
/// Strategy:
/// - Normalize line endings
/// - Split pages by formfeed \f
/// - Use split_blocks_smart() to detect headings / paragraphs
/// - Insert a page separator between non-empty pages
fn text_to_ir_document(text0 : String) -> @cor.Document {
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let mut first_page = true

  for page_sv in text.split("\f") {
    let page = page_sv.to_string()
    if page.trim() == "" {
      continue
    }

    if !first_page {
      @cor.push(doc, @cor.Block::BlankLine)
      @cor.push(doc, @cor.Block::Paragraph("---"))
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_page = false
    }

    for b in split_blocks_smart(page) {
      match b {
        PdfBlock::Heading(level, text) => {
          @cor.push(doc, @cor.Block::Heading(level, text))
          @cor.push(doc, @cor.Block::BlankLine)
        }
        PdfBlock::Paragraph(text) => {
          @cor.push(doc, @cor.Block::Paragraph(text))
          @cor.push(doc, @cor.Block::BlankLine)
        }
      }
    }
  }

  doc
}
