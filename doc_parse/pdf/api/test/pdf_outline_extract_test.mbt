///|
fn outline_test_tmp_dir() -> String {
  ".tmp/doc_parse_pdf_api"
}

///|
fn ensure_outline_test_dir(path : String) -> Unit raise {
  if path.trim() == "" {
    return
  }
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn outline_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(200.0), Real(200.0)])
}

///|
fn write_outline_fixture(path : String) -> Unit raise {
  let page1 = @pdfpage.Page::custom(outline_rect())
  let page2 = @pdfpage.Page::custom(outline_rect())
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      page1, page2,
    ],
  )
  let pdf1 = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  let page1_obj = match @pdfpage.PdfPageDoc::new(pdf1).page_object_number(1) {
    Some(obj) => obj
    None => fail("missing page 1 object")
  }
  let page2_obj = match @pdfpage.PdfPageDoc::new(pdf1).page_object_number(2) {
    Some(obj) => obj
    None => fail("missing page 2 object")
  }
  let pdf = @pdfmarks.PdfMarks::new(pdf1).add_bookmarks([
    {
      level: 0,
      text: "Parent",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(page1_obj),
      ),
      isopen: true,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Child",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(page2_obj),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ])
  write_pdf_api_test_fixture(path, pdf)
}

///|
async test "extract document model keeps pdf bookmark outlines" {
  ensure_outline_test_dir(".tmp")
  ensure_outline_test_dir(outline_test_tmp_dir())
  let path = outline_test_tmp_dir() + "/outline_bookmarks.pdf"
  write_outline_fixture(path)

  let doc = match @api.extract_document_model(path, @api.default_pdf_config()) {
    Ok(doc) => doc
    Err(err) => fail("extract_document_model failed: " + err.to_string())
  }

  if doc.outlines.length() != 1 {
    fail(
      "expected 1 top-level outline, got " + doc.outlines.length().to_string(),
    )
  }
  let parent = doc.outlines[0]
  if parent.title != "Parent" {
    fail("unexpected parent outline title: " + parent.title)
  }
  if parent.page_index != Some(0) {
    fail("expected parent outline page index 0")
  }
  if parent.children.length() != 1 {
    fail("expected 1 child outline")
  }
  let child = parent.children[0]
  if child.title != "Child" {
    fail("unexpected child outline title: " + child.title)
  }
  if child.page_index != Some(1) {
    fail("expected child outline page index 1")
  }
}

///|
async test "extract document raw model carries raw bookmark outlines" {
  ensure_outline_test_dir(".tmp")
  ensure_outline_test_dir(outline_test_tmp_dir())
  let path = outline_test_tmp_dir() + "/outline_bookmarks_raw.pdf"
  write_outline_fixture(path)

  let (raw, doc) = match
    @api.extract_document_raw_model(path, @api.default_pdf_config()) {
    Ok(v) => v
    Err(err) => fail("extract_document_raw_model failed: " + err.to_string())
  }

  if raw.outlines.length() != 1 {
    fail(
      "expected 1 raw top-level outline, got " +
      raw.outlines.length().to_string(),
    )
  }
  let raw_parent = raw.outlines[0]
  if raw_parent.title != "Parent" || raw_parent.page_index != Some(0) {
    fail("unexpected raw parent outline")
  }
  if raw_parent.children.length() != 1 {
    fail("expected 1 raw child outline")
  }
  let raw_child = raw_parent.children[0]
  if raw_child.title != "Child" || raw_child.page_index != Some(1) {
    fail("unexpected raw child outline")
  }
  if doc.outlines.length() != raw.outlines.length() {
    fail("model outlines should be mapped from raw outlines")
  }
}
