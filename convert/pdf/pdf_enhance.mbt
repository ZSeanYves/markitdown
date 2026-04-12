///|
priv enum PdfEnhanceMode {
  TextOnly
  Experimental
}

///|
fn parse_pdf_enhance_mode(mode : String?) -> PdfEnhanceMode {
  match mode {
    None => PdfEnhanceMode::TextOnly
    Some(raw) => {
      let m = raw.trim().to_lower()
      if m == "experimental" || m == "exp" || m == "ocr" {
        PdfEnhanceMode::Experimental
      } else {
        PdfEnhanceMode::TextOnly
      }
    }
  }
}

///|
fn apply_pdf_enhancement(text : String, mode : PdfEnhanceMode) -> String {
  match mode {
    PdfEnhanceMode::TextOnly => text
    PdfEnhanceMode::Experimental =>
      // stage-3 extension point:
      // keep default text pipeline unchanged, but leave a stable hook for
      // OCR/complex-layout plugins to inject additional text segments.
      apply_experimental_pdf_enhancement(text)
  }
}

///|
fn apply_experimental_empty_text_fallback(path : String) -> String {
  "[markitdown] PDF text layer is empty and OCR fallback did not succeed.\n" +
  "Install OCRmyPDF + Tesseract, then run again with `moon run cli -- ocr <input>`.\n" +
  "File: " +
  path
}

///|
fn apply_experimental_pdf_enhancement(text : String) -> String {
  // current minimal implementation is intentionally no-op so existing
  // regression behavior stays stable.
  text
}
