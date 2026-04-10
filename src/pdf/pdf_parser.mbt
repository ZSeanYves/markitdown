///|
pub async fn parse_pdf(
  path : String,
  _out_dir : String,
  _max_heading : Int,
  enhance_mode : String?,
  extract_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let extracted = match extract_pdf_text_result(path, debug=extract_debug) {
    Ok(res) => res
    Err(e) => raise e
  }

  let mode = parse_pdf_enhance_mode(enhance_mode)

  let enhanced_text = match mode {
    PdfEnhanceMode::TextOnly => apply_pdf_enhancement(extracted.text, mode)
    PdfEnhanceMode::Experimental =>
      if !extracted.quality_accepted {
        match try_ocr_pdf_to_text(path) {
          Some(ocr_text) => apply_pdf_enhancement(ocr_text, mode)
          None =>
            if is_effectively_empty_pdf_text(extracted.text) {
              apply_experimental_empty_text_fallback(path)
            } else {
              apply_pdf_enhancement(extracted.text, mode)
            }
        }
      } else {
        apply_pdf_enhancement(extracted.text, mode)
      }
  }

  text_to_ir_document(enhanced_text)
}
