///|
pub fn pdf_v2_scaffold_summary(doc : PdfV2DocumentModel) -> String {
  "PdfV2Scaffold(" +
  "pages=" +
  doc.pages.length().to_string() +
  ", warnings=" +
  doc.warnings.length().to_string() +
  ", risks=" +
  doc.risks.length().to_string() +
  ", scanned_once=" +
  doc.source_summary.scanned_once.to_string() +
  ")"
}
