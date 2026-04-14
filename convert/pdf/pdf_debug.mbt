///|
pub fn debug_convert_document_summary(doc : PdfConvertDocument) -> String {
  let mut heading = 0
  let mut paragraph = 0
  let mut noise = 0

  for b in doc.blocks {
    match b.kind {
      PdfConvertBlockKind::Heading => heading = heading + 1
      PdfConvertBlockKind::Paragraph => paragraph = paragraph + 1
      PdfConvertBlockKind::Noise => noise = noise + 1
    }
  }

  "PdfConvertDocument(" +
  "pages=" +
  doc.pages.length().to_string() +
  ", blocks=" +
  doc.blocks.length().to_string() +
  ", heading=" +
  heading.to_string() +
  ", paragraph=" +
  paragraph.to_string() +
  ", noise=" +
  noise.to_string() +
  ")"
}
