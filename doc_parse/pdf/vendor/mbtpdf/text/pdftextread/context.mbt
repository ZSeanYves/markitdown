///|
/// Pdf text processing context.

///|
pub struct PdfText {
  pdf : @pdf.Pdf
}

///|
pub fn PdfText::new(pdf : @pdf.Pdf) -> PdfText {
  { pdf, }
}
