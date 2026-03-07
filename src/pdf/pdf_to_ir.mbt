///|
/// Convert plain text into IR.
/// Strategy (MVP):
/// - Normalize line endings
/// - Split by blank lines into paragraphs
/// - Insert a horizontal rule between pages if extractor outputs formfeed \f
fn text_to_ir_document(text0 : String) -> @cor.Document{
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let mut first_page = true

  for page_sv in text.split("\f") { // Iter[StringView]
    let page0 = page_sv.to_string()
    if page0.trim() == "" {
      continue
    }
    if !first_page {
      // page separator: blank line + "---" + blank line（更像 markdown）
      @cor.push(doc, @cor.Block::BlankLine)
      @cor.push(doc, @cor.Block::Paragraph("---"))
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_page = false
    }

    let page = page_sv.to_string()

    for t in split_paragraphs_smart(page) {
      if t == "" {
        continue
      }
      @cor.push(doc, @cor.Block::Paragraph(t))
      @cor.push(doc, @cor.Block::BlankLine)
    }
  }

  doc
}
