///|
priv struct PdfExtractResult {
  _backend_name : String
  text : String
  _exit_status : Int
  _stderr : String
  _quality : PdfTextQuality
  quality_accepted : Bool
}

///|
async fn extract_pdf_text_result(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let all_results = collect_pdf_backend_results(path)
  let decision = select_pdf_backend_result(all_results, debug~)

  match decision.selected {
    Some(sel) => {
      let quality = sel.quality.unwrap_or(analyze_pdf_text_quality(sel.text))
      Ok({
        _backend_name: sel.backend_name,
        text: cleanup_pdf_text(sel.text),
        _exit_status: sel.exit_status,
        _stderr: sel.stderr,
        _quality: quality,
        quality_accepted: decision.accepted,
      })
    }
    None =>
      Err(
        @cor.AppError(
          "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
        ),
      )
  }
}
