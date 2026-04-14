///|
pub async fn extract_pdf_core_document(
  input_path : String,
) -> @pdfc.PdfDocumentModel raise {
  let cfg = @pdfc.default_pdf_core_config()
  match @pdfc.extract_document_model(input_path, cfg) {
    Ok(doc) => doc
    Err(e) =>
      raise @cor.AppError(
        "pdf: extract_document_model failed: " + e.to_string(),
      )
  }
}
