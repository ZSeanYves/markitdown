///|
pub async fn parse_pdf(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
  _enhance_mode : String?,
  _extract_debug : Bool,
  _dump_selected_raw : Bool,
  pipeline_debug : Bool,
) -> @cor.Document {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("pdf: file not found: " + input_path)
  }

  if pipeline_debug {
    let cfg = @api.default_pdf_core_config()
    match @api.extract_document_block_debug(input_path, cfg) {
      Ok(s) => println(s)
      Err(e) => println("pdf_core/debug error: " + e.to_string())
    }
  }

  let core_doc = extract_pdf_core_document(input_path)

  let doc0 = build_convert_lines(core_doc, _out_dir)
  let doc1 = build_convert_blocks(doc0)

  if pipeline_debug {
    println(debug_convert_document_summary(doc1))

    for page in doc1.pages {
      debug_print_convert_lines(page)
      debug_print_convert_blocks(page)
    }

    debug_print_page_edge_blocks(doc1)
    debug_print_repeated_edge_texts(doc1)
    debug_print_header_footer_like_blocks(doc1)
  }

  let doc2 = classify_convert_blocks(doc1, max_heading)
  let doc3 = filter_noise_blocks(doc2)
  let doc4 = merge_convert_blocks(doc3)

  if pipeline_debug {
    println(debug_convert_document_summary(doc4))
  }

  convert_pdf_blocks_to_ir(doc4, max_heading)
}
