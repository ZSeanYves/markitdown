///|
/// Keep cleanup isolated from quality judgement.
fn cleanup_pdf_text(text : String) -> String {
  text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}
