///|
fn resolve_pdf_inspect_sample_path(path : String) -> String raise {
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
async test "pdf inspect report covers text simple sample" {
  let input = resolve_pdf_inspect_sample_path(
    "samples/main_process/pdf/text_simple.pdf",
  )
  let report = match
    @api.extract_document_inspect_report(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_report failed: " + e.to_string())
  }

  if report.page_count <= 0 {
    fail("report should contain pages")
  }
  if report.successful_page_count != report.page_count {
    fail("successful page count should match page count")
  }
  if report.failed_page_count != 0 {
    fail("text_simple should not report failed pages")
  }
  if report.pages.length() != report.page_count {
    fail("page report count should match page count")
  }
  if report.total_text_block_count <= 0 ||
    report.total_line_count <= 0 ||
    report.total_span_count <= 0 ||
    report.total_char_count <= 0 {
    fail("text_simple should expose non-zero text counts")
  }
  if !report.has_text_signal || !report.has_any_signal {
    fail("text_simple should have text and structural signal")
  }
  if report.is_low_signal || report.is_empty_signal {
    fail("text_simple should not be low-signal or empty-signal")
  }
  if report.issue_count != 0 {
    fail("text_simple should not surface inspect issues")
  }

  let page = report.pages[0]
  if page.page_index != 0 {
    fail("first page index should be 0")
  }
  if !page.has_text_signal || !page.has_any_signal {
    fail("first page should have signal")
  }
  if page.is_low_signal || page.is_empty_signal {
    fail("first page should not be low-signal or empty-signal")
  }
  if page.text_block_count <= 0 ||
    page.line_count <= 0 ||
    page.span_count <= 0 ||
    page.char_count <= 0 {
    fail("first page should expose text counts")
  }
}

///|
test "pdf inspect page reports low and empty signal for synthetic pages" {
  let image_page : @model.PdfPageModel = {
    page_index: 0,
    page_label: None,
    rotation: 0,
    user_unit: None,
    boxes: {
      media_box: { x0: 0.0, y0: 0.0, x1: 100.0, y1: 100.0 },
      crop_box: None,
      bleed_box: None,
      trim_box: None,
      art_box: None,
    },
    text_blocks: [],
    images: [
      {
        id: "image-0",
        bbox: { x0: 10.0, y0: 10.0, x1: 20.0, y1: 20.0 },
        width_px: 10,
        height_px: 10,
        colorspace: None,
        bits_per_component: None,
        image_filter: None,
        object_ref: None,
        alt_text: None,
        inline_image: true,
        payload: None,
        source_refs: [],
      },
    ],
    vectors: [],
    annotations: [],
    forms: [],
    reading_order_candidates: [],
    artifact_candidates: [],
    raw_content_stream_refs: [],
  }

  let image_info = @api.inspect_pdf_page(image_page)
  if image_info.has_text_signal {
    fail("image-only synthetic page should not claim text signal")
  }
  if !image_info.has_any_signal {
    fail("image-only synthetic page should still have structural signal")
  }
  if !image_info.is_low_signal || image_info.is_empty_signal {
    fail("image-only synthetic page should be low-signal, not empty")
  }
  if image_info.issues.length() != 1 {
    fail("image-only synthetic page should surface one issue")
  }
  match image_info.issues[0].kind {
    @api.PdfInspectIssueKind::LowSignalExtraction => ()
    _ => fail("image-only synthetic page should report low-signal extraction")
  }
  match image_info.issues[0].severity {
    @api.PdfInspectSeverity::Warning => ()
    _ => fail("low-signal issue should be warning severity")
  }

  let empty_page : @model.PdfPageModel = { ..image_page, images: [] }
  let empty_info = @api.inspect_pdf_page(empty_page)
  if empty_info.has_any_signal {
    fail("empty synthetic page should not have structural signal")
  }
  if empty_info.has_text_signal || !empty_info.is_empty_signal {
    fail("empty synthetic page should be empty-signal")
  }
  if empty_info.issues.length() != 1 {
    fail("empty synthetic page should surface one issue")
  }
  match empty_info.issues[0].kind {
    @api.PdfInspectIssueKind::EmptyExtraction => ()
    _ => fail("empty synthetic page should report empty extraction")
  }
  match empty_info.issues[0].severity {
    @api.PdfInspectSeverity::Error => ()
    _ => fail("empty extraction issue should be error severity")
  }
}

///|
async test "pdf inspect report exposes annotation signal" {
  let input = resolve_pdf_inspect_sample_path(
    "samples/main_process/pdf/pdf_uri_link_basic.pdf",
  )
  let report = match
    @api.extract_document_inspect_report(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_report failed: " + e.to_string())
  }

  let page = report.pages[0]
  if page.annotation_count <= 0 {
    fail("annotation sample should expose annotation signal")
  }
  if !page.has_any_signal {
    fail("annotation sample should have some structural signal")
  }
}
