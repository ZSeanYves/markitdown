///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
async test "pdf_core inspect dump smoke on text_simple" {
  let input = resolve_sample_path("samples/main_process/pdf/text_simple.pdf")
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_core_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() == 0 {
    fail("pdf_core model should contain pages")
  }

  let page = doc.pages[0]
  if @model.page_line_count(page) <= 0 {
    fail("pdf_core page should expose line count")
  }
  if @model.page_span_count(page) <= 0 {
    fail("pdf_core page should expose span count")
  }
  if @model.page_char_count(page) <= 0 {
    fail("pdf_core page should expose char count")
  }

  let dump = match
    @api.extract_document_inspect_dump(input, @api.default_pdf_core_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_dump failed: " + e.to_string())
  }

  if !dump.contains("PdfDocumentInspect(") {
    fail("inspect dump should contain header")
  }
  if !dump.contains("signals: top_edge_threshold=") {
    fail("inspect dump should contain page edge signal")
  }
  if !dump.contains("block_source[0]=") {
    fail("inspect dump should contain block source refs")
  }
}
