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
async test "pdf inspect dump smoke on text_simple" {
  let input = resolve_sample_path("samples/main_process/pdf/text_simple.pdf")
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() == 0 {
    fail("PDF model should contain pages")
  }

  let page = doc.pages[0]
  if @model.page_line_count(page) <= 0 {
    fail("PDF page should expose line count")
  }
  if @model.page_span_count(page) <= 0 {
    fail("PDF page should expose span count")
  }
  if @model.page_char_count(page) <= 0 {
    fail("PDF page should expose char count")
  }

  let dump = match
    @inspect.extract_document_inspect_dump(input, @api.default_pdf_config()) {
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

///|
async test "pdf lower-layer groups hardwrapped sample into shared text blocks" {
  let input = resolve_sample_path("samples/main_process/pdf/hardwrap_en.pdf")
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("hardwrap sample should contain exactly one page")
  }

  let page = doc.pages[0]
  if page.text_blocks.length() != 3 {
    fail(
      "expected hardwrap sample to collapse into 3 text blocks, got " +
      page.text_blocks.length().to_string(),
    )
  }

  if @model.block_text(page.text_blocks[1]).trim().to_owned() !=
    "This project aims to build a unified document conversion pipeline for docx, pdf, xlsx, pptx, and html." {
    fail("expected first body block to preserve merged English hardwrap text")
  }

  if @model.block_text(page.text_blocks[2]).trim().to_owned() !=
    "The parser should support international text processing and preserve semantic structure whenever possible." {
    fail("expected second body block to preserve merged English hardwrap text")
  }
}

///|
