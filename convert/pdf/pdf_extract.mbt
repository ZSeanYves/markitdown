///|
/// Bridge from converter layer to `doc_parse/pdf_core`.
/// This function intentionally only maps errors and keeps no recovery heuristic,
/// so extraction capability boundaries remain owned by pdf_core.
async fn extract_pdf_core_document(
  input_path : String,
) -> @model.PdfDocumentModel {
  let cfg = @api.default_pdf_core_config()
  match @api.extract_document_model(input_path, cfg) {
    Ok(doc) => doc
    Err(e) =>
      raise @cor.AppError(
        "pdf: extract_document_model failed: " + e.to_string(),
      )
  }
}
