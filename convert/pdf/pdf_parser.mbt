///|
pub async fn parse_pdf(
  path : String,
  out_dir : String,
  _max_heading : Int,
  enhance_mode : String?,
  backend : String?,
  backend_policy : String?,
  extract_debug : Bool,
  dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let extracted = match
    extract_pdf_text_result(
      path,
      backend~,
      backend_policy~,
      debug=extract_debug,
    ) {
    Ok(res) => res
    Err(e) => raise e
  }

  let mode = parse_pdf_enhance_mode(enhance_mode)

  let selected_raw = match mode {
    PdfEnhanceMode::TextOnly => extracted.text
    PdfEnhanceMode::Experimental =>
      if !extracted.quality_accepted {
        match try_ocr_pdf_to_text(path) {
          Some(ocr_text) => ocr_text
          None =>
            if is_effectively_empty_pdf_text(extracted.text) {
              apply_experimental_empty_text_fallback(path)
            } else {
              extracted.text
            }
        }
      } else {
        extracted.text
      }
  }

  let enhanced_text = apply_pdf_enhancement(selected_raw, mode)

  if dump_selected_raw || pipeline_debug {
    dump_pdf_debug_stage(path, out_dir, "selected_raw", selected_raw)
  }

  text_to_ir_document_with_debug(path, out_dir, enhanced_text, pipeline_debug)
}

///|
fn dump_pdf_debug_stage(
  input_path : String,
  out_dir : String,
  stage : String,
  content : String,
) -> Unit {
  if out_dir == "" {
    return
  }
  let base = @cor.basename(input_path)
  let out = out_dir + "/" + base + ".pdf_debug." + stage + ".txt"
  @fs.write_string_to_file(out, content, encoding="utf8") catch {
    _ => ()
  }
}
