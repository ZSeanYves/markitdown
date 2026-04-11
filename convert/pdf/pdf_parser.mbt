///|
pub async fn parse_pdf(
  path : String,
  out_dir : String,
  _max_heading : Int,
  _enhance_mode : String?,
  extract_debug : Bool,
  _dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(path) {
    raise @cor.AppError("PDF file not found: " + path)
  }

  let native = match extract_pdf_native_document(path, debug=extract_debug) {
    Ok(doc) => doc
    Err(e) => raise e
  }

  let pages = native_document_to_pages(native)
  let raw_blocks = pages_to_blocks(pages)
  let classified = classify_blocks(pages, raw_blocks)
  let merged = merge_blocks(classified)

  pipeline_to_ir(
    path, out_dir, pages, raw_blocks, classified, merged, pipeline_debug,
  )
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
