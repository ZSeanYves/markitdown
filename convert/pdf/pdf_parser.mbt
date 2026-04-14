///|
pub async fn parse_pdf(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
  _enhance_mode : String?,
  _extract_debug : Bool,
  _dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf: file not found: " + input_path)
  }

  let core_doc = extract_pdf_core_document(input_path)
  let pages0 = build_convert_pages_from_pdf_core(core_doc)
  let pages1 = build_convert_blocks_for_pages(pages0)
  let pages2 = classify_convert_blocks(pages1)
  let pages3 = filter_noise_blocks(pages2)
  let merged = merge_convert_blocks(pages3)

  if pipeline_debug {
    println(debug_convert_document_summary(merged))
  }

  convert_pdf_blocks_to_ir(merged, max_heading)
}
