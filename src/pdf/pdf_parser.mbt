///|
pub async fn parse_pdf(
  path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise{
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let text = match extract_pdf_text(path)  {
    Ok(t) => t
    Err(e) => raise e
  }

  text_to_ir_document(text)
}