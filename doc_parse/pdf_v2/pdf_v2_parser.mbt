///|
pub fn parse_pdf_v2_document_from_bytes(bytes : Bytes) -> PdfV2DocumentModel {
  let core = open_pdf_core_v2(bytes)
  let source = parse_pdf_v2_source(core)
  let text = build_pdf_v2_text_model(source)
  let layout = recover_pdf_v2_layout(text, default_pdf_v2_layout_options())
  build_pdf_v2_document_model(source, text, layout)
}
