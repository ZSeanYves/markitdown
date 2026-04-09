///|
pub async fn parse_pdf(
  path : String,
  _out_dir : String,
  _max_heading : Int,
  enhance_mode : String?,
) -> @cor.Document {
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let text = match extract_pdf_text(path) {
    Ok(t) => t
    Err(e) => raise e
  }

  let mode = parse_pdf_enhance_mode(enhance_mode)

  let enhanced_text = match mode {
    PdfEnhanceMode::TextOnly => apply_pdf_enhancement(text, mode)
    PdfEnhanceMode::Experimental => {
      if is_effectively_empty_pdf_text(text) {
        match try_ocr_pdf_to_text(path) {
          Some(ocr_text) =>
            if is_effectively_empty_pdf_text(ocr_text) {
              apply_experimental_empty_text_fallback(path)
            } else {
              apply_pdf_enhancement(ocr_text, mode)
            }
          None => apply_experimental_empty_text_fallback(path)
        }
      } else {
        apply_pdf_enhancement(text, mode)
      }
    }
  }

  text_to_ir_document(enhanced_text)
}
