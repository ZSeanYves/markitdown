///|
/// Bridge from converter layer to `doc_parse/pdf`.
/// This function intentionally only maps errors and keeps no recovery heuristic,
/// so extraction capability boundaries remain owned by the PDF lower-layer parser.
async fn extract_pdf_document_model(
  input_path : String,
) -> @model.PdfDocumentModel {
  let cfg = @api.default_pdf_config()
  match @api.extract_document_model(input_path, cfg) {
    Ok(doc) => doc
    Err(e) =>
      raise @cor.AppError(
        "pdf: extract_document_model failed: " + e.to_string(),
      )
  }
}
