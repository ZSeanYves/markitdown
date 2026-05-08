///|
/// Build a minimal PDF with a single blank page.
pub fn PdfPageDoc::minimum_valid() -> @pdf.Pdf raise {
  let pages = [Page::blank(@pdfpaper.a4)]
  let (pdf, pageroot) = PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(pages)
  PdfPageDoc::new(pdf).add_root(pageroot, [])
}
