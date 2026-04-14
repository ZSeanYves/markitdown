///|
pub fn convert_pdf_blocks_to_ir(
  doc : PdfConvertDocument,
  max_heading : Int,
) -> @cor.Document {
  let out = @cor.new_document()

  for b in doc.blocks {
    match b.kind {
      PdfConvertBlockKind::Heading => {
        let level = clamp_heading_level(b.heading_level, max_heading)
        @cor.push(out, @cor.Block::Heading(level, b.text))
      }
      PdfConvertBlockKind::Paragraph =>
        @cor.push(out, @cor.Block::Paragraph(b.text))
      PdfConvertBlockKind::Noise => ()
    }
  }

  out
}

///|
fn clamp_heading_level(level : Int, max_heading : Int) -> Int {
  if max_heading <= 0 {
    return 1
  }
  if level <= 0 {
    return 1
  }
  if level > max_heading {
    return max_heading
  }
  level
}
