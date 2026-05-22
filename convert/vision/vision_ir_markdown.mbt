///|
pub fn render_ocr_ir_document_markdown(doc : @cor.Document) -> String {
  @cor.emit_markdown(doc)
}

///|
pub fn render_ocr_layout_page_via_ir_markdown(page : OcrLayoutPage) -> String {
  render_ocr_ir_document_markdown(convert_ocr_layout_page_to_ir(page))
}

///|
pub fn render_ocr_layout_pages_via_ir_markdown(
  pages : Array[OcrLayoutPage],
) -> String {
  render_ocr_ir_document_markdown(convert_ocr_layout_pages_to_ir(pages))
}
