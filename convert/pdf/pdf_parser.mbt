///|
pub async fn parse_pdf(
  path : String,
  out_dir : String,
  _max_heading : Int,
  enhance_mode : String?,
  extract_debug : Bool,
  dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let extracted = match extract_pdf_text_result(path, debug=extract_debug) {
    Ok(res) => res
    Err(e) => raise e
  }

  let mode = parse_pdf_enhance_mode(enhance_mode)
  let selected_raw = select_pdf_debug_raw_text(path, extracted, mode)
  if dump_selected_raw || pipeline_debug {
    dump_pdf_debug_stage(path, out_dir, "selected_raw", selected_raw)
  }

  match extracted._native_stats {
    Some(native) =>
      native_document_to_ir_document_with_debug(path, out_dir, native, pipeline_debug)
    None => {
      // should not happen with current native extractor, keep a clear guard.
      let doc = @cor.new_document()
      let t = selected_raw.trim().to_string()
      if t != "" {
        @cor.push(doc, @cor.Block::Paragraph(t))
      }
      doc
    }
  }
}

///|
fn select_pdf_debug_raw_text(
  path : String,
  extracted : PdfExtractResult,
  mode : PdfEnhanceMode,
) -> String {
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
  apply_pdf_enhancement(selected_raw, mode)
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
