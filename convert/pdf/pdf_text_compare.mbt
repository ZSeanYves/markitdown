///|
fn normalize_pdf_comparison_text(text : String) -> String {
  let normalized = @cor.normalize_text_with_profile(
    text,
    @cor.NormalizeProfile::PdfText,
  )
  collapse_pdf_comparison_whitespace(normalized).trim().to_owned()
}

///|
fn lowercase_pdf_comparison_text(text : String) -> String {
  let out = StringBuilder::new()
  for ch in normalize_pdf_comparison_text(text) {
    if ch >= 'A' && ch <= 'Z' {
      out.write_char(Int::unsafe_to_char(ch.to_int() + 32))
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn collapse_pdf_comparison_whitespace(text : String) -> String {
  let out = StringBuilder::new()
  let mut prev_space = false

  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !prev_space {
        out.write_char(' ')
        prev_space = true
      }
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }

  out.to_string()
}
