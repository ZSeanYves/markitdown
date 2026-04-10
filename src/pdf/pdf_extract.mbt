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
  match extract_pdf_text_result(path, backend=None, debug=false) {
    Ok(picked) => Ok(picked.text)
    Err(e) => Err(e)
  }
}

///|
async fn extract_pdf_text_result(
  path : String,
  backend? : String? = None,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let backend_mode = match backend {
    Some(s) => s.trim().to_string()
    None => ""
  }
  if backend_mode == "pdf-native" || backend_mode == "native" {
    return extract_pdf_text_native(path)
  }

  let all_results = collect_pdf_backend_results(path)
  let decision = select_pdf_backend_result(all_results, debug~)

  match decision.selected {
    Some(sel) => {
      let quality = sel.quality.unwrap_or(analyze_pdf_text_quality(sel.text))
      Ok({
        backend_name: sel.backend_name,
        text: cleanup_pdf_text(sel.text),
        exit_status: sel.exit_status,
        stderr: sel.stderr,
        quality,
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

///|
fn map_native_error(e : @pdfc.PdfNativeError) -> @cor.AppError {
  @cor.AppError("PDF native backend failed: " + e.to_string())
}

///|
async fn extract_pdf_text_native(
  path : String,
) -> Result[PdfExtractResult, @cor.AppError] {
  let bytes = @fs.read_bytes(path) catch {
    e => return Err(@cor.AppError("read pdf failed: " + e.to_string()))
  }

  let doc = @pdfc.open_pdf(bytes) catch {
    _ =>
      return Err(
        map_native_error(
          @pdfc.PdfNativeError::ExtractionFailed("unable to open pdf"),
        ),
      )
  }

  let text = @pdfc.extract_text_from_document(doc) catch {
    _ =>
      return Err(
        map_native_error(
          @pdfc.PdfNativeError::ExtractionFailed("unable to extract text"),
        ),
      )
  }

  let quality = analyze_pdf_text_quality(text)
  Ok({
    backend_name: "pdf-native",
    text: cleanup_pdf_text(text),
    exit_status: 0,
    stderr: "",
    quality,
    quality_accepted: true,
  })
}
