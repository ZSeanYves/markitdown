///|
type PdfObject = @pdf.PdfObject

///|
pub struct PdfMergeDoc {
  pdf : @pdf.Pdf
}

///|
pub fn PdfMergeDoc::new(pdf : @pdf.Pdf) -> PdfMergeDoc {
  { pdf, }
}

///|
pub struct PdfMerger {
  names : Array[String]
  pdfs : Array[@pdf.Pdf]
  ranges : Array[Array[Int]]
}

///|
pub fn PdfMerger::new(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
) -> PdfMerger {
  { names, pdfs, ranges }
}
