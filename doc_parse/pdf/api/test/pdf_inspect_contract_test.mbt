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
async fn write_malformed_annotation_pdf(path : String) -> Unit {
  let pdf0 = @pdf.Pdf::empty()
  let page = @pdfpage.Page::custom(
    Array([Real(0.0), Real(0.0), Real(200.0), Real(200.0)]),
  )
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let annot : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Contents", String("Missing rect annotation")),
    (
      "/A",
      Dictionary([
        ("/S", Name(@pdf.PdfName::of_string("/URI"))),
        ("/URI", String("https://example.com/bad-annot")),
      ]),
    ),
  ])
  let annot_num = pdf.addobj(annot)
  let page_obj = pdf.lookup_obj(refs[0])
  let updated_page = page_obj.add_entry("/Annots", Array([Indirect(annot_num)]))
  pdf.addobj_given_num((refs[0], updated_page))
  @mbtpdf.write_file(pdf, path)
}

///|
async fn create_malformed_annotation_fixture(name : String) -> String {
  let dir = test_tmp_root() + "/pdf"
  ensure_test_dir_tree(dir)
  let path = dir + "/" + name + ".pdf"
  write_malformed_annotation_pdf(path)
  path
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
  if report.text_page_count <= 0 {
    fail("text_simple should expose text page count")
  }
  if report.empty_page_count != 0 || report.low_signal_page_count != 0 {
    fail("text_simple should not report empty/low-signal page counts")
  }
  if !report.has_text_signal || !report.has_any_signal {
    fail("text_simple should have text and structural signal")
  }
  if report.has_image_signal || report.has_annotation_signal {
    fail("text_simple should not claim image or annotation signal")
  }
  if report.is_low_signal || report.is_empty_signal {
    fail("text_simple should not be low-signal or empty-signal")
  }
  if report.issue_count != 0 {
    fail("text_simple should not surface inspect issues")
  }
  if report.raw_issue_count != 0 || report.model_issue_count != 0 {
    fail("text_simple should not surface raw/model issue counts")
  }

  let page = report.pages[0]
  if page.page_index != 0 {
    fail("first page index should be 0")
  }
  if page.effective_width <= 0.0 || page.effective_height <= 0.0 {
    fail("page effective dimensions should be positive")
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
  if page.link_annotation_count != 0 {
    fail("text_simple should not expose link annotations")
  }
  if page.issue_count != 0 {
    fail("text_simple first page should not surface issues")
  }
  if page.raw_issue_count != 0 || page.model_issue_count != 0 {
    fail("text_simple first page should not surface raw/model issue counts")
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
  if image_info.source_ref_count != 0 {
    fail("image-only synthetic page should not expose source refs")
  }
  if image_info.issue_count != 1 {
    fail("image-only synthetic page should surface issue count")
  }
  if image_info.raw_issue_count != 0 || image_info.model_issue_count != 1 {
    fail("image-only synthetic page should surface only one model issue")
  }
  match image_info.issues[0].kind {
    @api.PdfInspectIssueKind::LowSignalPage => ()
    _ => fail("image-only synthetic page should report low-signal page")
  }
  match image_info.issues[0].source {
    @api.PdfInspectIssueSource::Model => ()
    _ => fail("image-only synthetic page issue should be model-sourced")
  }
  if image_info.issues[0].object_ref is Some(_) ||
    image_info.issues[0].source_ref is Some(_) {
    fail("synthetic model issue should not expose raw refs")
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
  if empty_info.issue_count != 1 {
    fail("empty synthetic page should surface issue count")
  }
  if empty_info.raw_issue_count != 0 || empty_info.model_issue_count != 1 {
    fail("empty synthetic page should surface only one model issue")
  }
  match empty_info.issues[0].kind {
    @api.PdfInspectIssueKind::EmptyPage => ()
    _ => fail("empty synthetic page should report empty page")
  }
  match empty_info.issues[0].severity {
    @api.PdfInspectSeverity::Error => ()
    _ => fail("empty extraction issue should be error severity")
  }

  let image_doc : @model.PdfDocumentModel = {
    version: "1.7",
    page_count: 1,
    metadata: {
      title: None,
      author: None,
      subject: None,
      keywords: [],
      creator: None,
      producer: None,
      creation_date: None,
      mod_date: None,
    },
    is_encrypted: false,
    has_xref_stream: false,
    has_object_stream: false,
    outlines: [],
    pages: [image_page],
  }
  let image_report = @api.inspect_pdf_document(image_doc)
  if image_report.text_page_count != 0 {
    fail("image-only document should not expose text pages")
  }
  if image_report.empty_page_count != 0 ||
    image_report.low_signal_page_count != 1 {
    fail("image-only document should expose low-signal page counts")
  }
  if image_report.has_text_signal || !image_report.has_image_signal {
    fail("image-only document should expose only image signal")
  }
  if image_report.issue_count != 2 {
    fail("image-only document should expose page and document issues")
  }
  if image_report.raw_issue_count != 0 || image_report.model_issue_count != 2 {
    fail("image-only document should surface only model-derived issues")
  }
  match image_report.issues[0].kind {
    @api.PdfInspectIssueKind::LowSignalPage => ()
    _ => fail("image-only document should keep page-level issue first")
  }
  match image_report.issues[1].kind {
    @api.PdfInspectIssueKind::LowSignalExtraction => ()
    _ =>
      fail(
        "image-only document should surface document-level low-signal extraction issue",
      )
  }

  let partial_doc : @model.PdfDocumentModel = { ..image_doc, page_count: 2 }
  let partial_report = @api.inspect_pdf_document(partial_doc)
  if partial_report.page_failure_count != 1 {
    fail("partial synthetic document should expose page failure count")
  }
  if partial_report.issue_count != 3 {
    fail("partial synthetic document should add a partial page failure issue")
  }
  if partial_report.model_issue_count != 3 {
    fail("partial synthetic document should keep all issues model-derived")
  }
  match partial_report.issues[1].kind {
    @api.PdfInspectIssueKind::PartialPageFailure => ()
    _ => fail("partial synthetic document should surface partial page failure")
  }
  match partial_report.issues[1].source {
    @api.PdfInspectIssueSource::Model => ()
    _ => fail("partial page failure should be model-sourced")
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
  if page.link_annotation_count <= 0 {
    fail("annotation sample should expose link annotation signal")
  }
  if !report.has_annotation_signal {
    fail("annotation sample should set document annotation signal")
  }
  if report.total_link_annotation_count <= 0 {
    fail("annotation sample should expose total link annotation count")
  }
  if report.raw_issue_count != 0 {
    fail("valid annotation sample should not surface raw issue count")
  }
  if !page.has_any_signal {
    fail("annotation sample should have some structural signal")
  }
}

///|
async test "pdf inspect report surfaces raw annotation parse warnings" {
  let input = create_malformed_annotation_fixture(
    "pdf_inspect_malformed_annotation",
  )
  let report = match
    @api.extract_document_inspect_report(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_report failed: " + e.to_string())
  }

  if report.raw_issue_count <= 0 {
    fail("malformed annotation fixture should surface raw issues")
  }
  let mut found_raw_annotation = false
  for issue in report.issues {
    match (issue.source, issue.kind) {
      (
        @api.PdfInspectIssueSource::Raw,
        @api.PdfInspectIssueKind::AnnotationParseWarning,
      ) => {
        found_raw_annotation = true
        if issue.page_index != Some(0) {
          fail("raw annotation warning should keep page index")
        }
        if issue.object_ref is None {
          fail("raw annotation warning should preserve object ref")
        }
      }
      _ => ()
    }
  }
  if !found_raw_annotation {
    fail(
      "malformed annotation fixture should expose raw annotation parse warning",
    )
  }
}
