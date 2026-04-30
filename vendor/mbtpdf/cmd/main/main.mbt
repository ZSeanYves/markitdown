///|
pub fn run(quiet? : Bool = false) -> Unit {
  let _ = @lib.PdfWriteFs::new()
  if !quiet {
    println(
      "mbtpdf: see cmd/pdfhello, cmd/pdfmergeexample, cmd/pdfextracttext, etc.",
    )
  }
}

///|
fn main {
  run()
}
