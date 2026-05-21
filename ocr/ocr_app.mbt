///|
fn cmd_ocr(input : String, output : String?) -> Unit {
  match run_ocr_cli(input, output) {
    Ok(_) => ()
    Err(msg) => @clicom.exit_error(msg)
  }
}

///|
fn run_ocr_cli(input : String, output : String?) -> Result[Unit, String] {
  ignore(input)
  ignore(output)
  println(ocr_rebuild_message())
  Ok(())
}

///|
fn ocr_rebuild_message() -> String {
  "OCR is being rebuilt around OCRPageModel; current OCR provider execution is not wired in this build."
}
