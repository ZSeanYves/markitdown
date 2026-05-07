///|
fn normalize_pdf_comparison_text(text : String) -> String {
  @cor.normalize_text_with_profile(text, @cor.NormalizeProfile::PdfCompareText)
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
