///|
priv struct PdfExtractResult {
  backend_name : String
  text : String
  exit_status : Int
  stderr : String
  quality : PdfTextQuality
  quality_accepted : Bool
}

///|
async fn extract_pdf_text(path : String) -> Result[String, @cor.AppError] {
  let picked = extract_pdf_text_result(path)?
  Ok(picked.text)
}

///|
async fn extract_pdf_text_result(path : String) -> Result[PdfExtractResult, @cor.AppError] {
  let all_results = collect_pdf_backend_results(path)
  let decision = select_pdf_backend_result(all_results)

  for r in decision.attempted {
    debug_print_backend_result(r)
  }

  match decision.selected {
    Some(sel) => {
      let quality = sel.quality.unwrap_or(analyze_pdf_text_quality(sel.text))
      Ok({
        backend_name: sel.backend_name,
        text: cleanup_pdf_text(sel.text),
        exit_status: sel.exit_status,
        stderr: sel.stderr,
        quality: quality,
        quality_accepted: decision.accepted,
      })
    }
    None => Err(
      @cor.AppError(
        "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
      ),
    )
  }
}
