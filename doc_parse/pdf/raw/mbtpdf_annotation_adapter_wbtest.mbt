///|
fn utf16be_pdf_string(text : String) -> String raise {
  let codepoints = @pdftext.PdfTextUtil::new().codepoints_of_utf8(text)
  @pdftext.PdfTextUtil::new().utf16be_of_codepoints(codepoints)
}

///|
fn legacy_pdfjs_external_fixture_candidates(path : String) -> Array[String] {
  if !path.has_prefix(".external/quality_corpus/pdf_external/pdfjs/") {
    return []
  }

  let name = path.split("/").last().unwrap_or("").to_owned()
  if name == "" {
    []
  } else {
    ["doc_parse/pdf/testdata/pdfjs/" + name, "../testdata/pdfjs/" + name]
  }
}

///|
async fn open_sample_pdf(path : String) -> @pdf.Pdf {
  let candidates = [path, "../../" + path] +
    legacy_pdfjs_external_fixture_candidates(path)
  let mut last_error = ""
  for candidate in candidates {
    let input = @pdfiofs.input_of_file(candidate, source=candidate) catch {
      e => {
        last_error = e.to_string()
        continue
      }
    }
    return @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(None, None, input)
  }
  fail(
    "optional repo-local PDF fixture missing; expected doc_parse/pdf/testdata/pdfjs fixture: " +
    path +
    " (" +
    last_error +
    ")",
  )
}

///|
fn build_annotation_target_pdf() -> @pdf.Pdf {
  let pdf : @pdf.Pdf = {
    major: 1,
    minor: 4,
    root: 4,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: @pdf.pdfobjmap_empty(),
      object_stream_ids: Map([]),
    },
    trailerdict: Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let media_box : @pdf.PdfObject = Array([
    Integer(0),
    Integer(0),
    Integer(300),
    Integer(300),
  ])
  let page1 : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", Indirect(1)),
    ("/MediaBox", media_box),
  ])
  let page2 : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", Indirect(1)),
    ("/MediaBox", media_box),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(2), Indirect(3)])),
    ("/Count", Integer(2)),
  ])
  let catalog : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Catalog"))),
    ("/Pages", Indirect(1)),
  ])
  pdf.addobj_given_num((1, pages))
  pdf.addobj_given_num((2, page1))
  pdf.addobj_given_num((3, page2))
  pdf.addobj_given_num((4, catalog))
  pdf
}

///|
test "annotation adapter decodes utf16be contents and subject" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_ref : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Highlight"))),
    ("/Rect", rect),
    ("/Contents", String(utf16be_pdf_string("Highlight content"))),
    ("/Subj", String(utf16be_pdf_string("Reviewer"))),
  ])

  let annotation = match annotation_from_pdf_object(pdf, annot_ref, 0, 0) {
    Ok(v) => v
    Err(e) => fail("expected decoded annotation, got issue: " + e.message)
  }

  match annotation.contents {
    Some("Highlight content") => ()
    _ => fail("expected decoded contents")
  }
  match annotation.subject {
    Some("Reviewer") => ()
    _ => fail("expected decoded subject")
  }
}

///|
test "annotation adapter resolves target page for GoTo link annotations" {
  let pdf = build_annotation_target_pdf()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_ref : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    (
      "/A",
      Dictionary([
        ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
        ("/D", Array([Indirect(3), Name(@pdf.PdfName::of_string("/Fit"))])),
      ]),
    ),
  ])

  let annotation = match annotation_from_pdf_object(pdf, annot_ref, 0, 0) {
    Ok(v) => v
    Err(e) => fail("expected parsed annotation, got issue: " + e.message)
  }

  match annotation.target_page {
    Some(2) => ()
    _ => fail("expected GoTo annotation target_page to resolve to page 2")
  }
}

///|
test "annotation adapter resolves widget fields through parent chain" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let parent : @pdf.PdfObject = Dictionary([
    ("/FT", Name(@pdf.PdfName::of_string("/Tx"))),
    ("/T", String("InternalName")),
    ("/TU", String("Visible label")),
    ("/V", String("Filled value")),
  ])
  pdf.addobj_given_num((1, parent))
  let annot_ref : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Widget"))),
    ("/Rect", rect),
    ("/Parent", Indirect(1)),
  ])

  let form = match form_field_from_pdf_object(pdf, annot_ref, 0, 0) {
    Some(v) => v
    None => fail("expected widget form field")
  }

  match form.field_type {
    "/Tx" => ()
    _ => fail("expected inherited /FT field type")
  }
  match form.field_name {
    Some("InternalName") => ()
    _ => fail("expected inherited /T field name")
  }
  match form.field_label {
    Some("Visible label") => ()
    _ => fail("expected inherited /TU field label")
  }
  match form.field_value {
    Some("Filled value") => ()
    _ => fail("expected inherited /V field value")
  }
}

///|
test "annotation adapter resolves button state and options through parent chain" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let parent : @pdf.PdfObject = Dictionary([
    ("/FT", Name(@pdf.PdfName::of_string("/Btn"))),
    ("/TU", String("Accept terms")),
    ("/V", Name(@pdf.PdfName::of_string("/Yes"))),
    ("/Opt", Array([String("Yes"), String("No")])),
  ])
  pdf.addobj_given_num((1, parent))
  let annot_ref : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Widget"))),
    ("/Rect", rect),
    ("/Parent", Indirect(1)),
  ])

  let form = match form_field_from_pdf_object(pdf, annot_ref, 0, 0) {
    Some(v) => v
    None => fail("expected widget form field")
  }

  match form.checked_state {
    Some(true) => ()
    _ => fail("expected inherited button checked_state")
  }
  match form.field_value {
    Some("/Yes") => ()
    _ => fail("expected inherited button field value")
  }
  if form.options.length() != 2 ||
    form.options[0] != "Yes" ||
    form.options[1] != "No" {
    fail("expected inherited options")
  }
}

///|
test "annotation adapter parses widget annotation flags from /F" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_ref : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Widget"))),
    ("/Rect", rect),
    ("/FT", Name(@pdf.PdfName::of_string("/Tx"))),
    ("/T", String("HiddenField")),
    ("/V", String("Secret")),
    ("/F", Integer(36)),
  ])

  let form = match form_field_from_pdf_object(pdf, annot_ref, 0, 0) {
    Some(v) => v
    None => fail("expected widget form field")
  }
  if form.flags != 36 {
    fail("expected widget /F flags=36, got " + form.flags.to_string())
  }

  let annotation = match annotation_from_pdf_object(pdf, annot_ref, 0, 0) {
    Ok(v) => v
    Err(e) => fail("expected widget annotation, got issue: " + e.message)
  }
  if annotation.flags != 36 {
    fail("expected annotation /F flags=36, got " + annotation.flags.to_string())
  }
}

///|
async test "annotation adapter sees direct text widget /V strings in real pdfjs sample" {
  let pdf = open_sample_pdf(
    "doc_parse/pdf/testdata/pdfjs/annotation-text-widget.pdf",
  )
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree() catch {
    e => fail("pages_of_pagetree failed: " + e.to_string())
  }
  if pages.length() != 1 {
    fail("expected one page")
  }

  let annots = match pdf.lookup_direct("/Annots", pages[0].rest) {
    Some(@pdf.PdfObject::Array(items)) => items
    _ => fail("expected page /Annots array")
  }
  if annots.length() < 7 {
    fail("expected at least 7 annotations")
  }

  let first = pdf.direct(annots[0])
  let value_obj = pdf.lookup_direct("/V", first)
  let subtype_obj = pdf.lookup_direct("/Subtype", first)
  let field_type_obj = pdf.lookup_direct("/FT", first)
  let label_obj = pdf.lookup_direct("/TU", first)
  let immediate_values = first.lookup_immediate_all("/V")
  let subtype_str = match subtype_obj {
    Some(v) => v.to_string()
    None => "None"
  }
  let field_type_str = match field_type_obj {
    Some(v) => v.to_string()
    None => "None"
  }
  let label_str = match label_obj {
    Some(v) => v.to_string()
    None => "None"
  }
  match value_obj {
    Some(@pdf.PdfObject::String(s)) =>
      if s == "" {
        fail("expected non-empty direct /V string")
      }
    Some(other) =>
      fail(
        "expected first text widget /V to be String, got " + other.to_string(),
      )
    None =>
      fail(
        "expected first text widget /V; subtype=" +
        subtype_str +
        "; field_type=" +
        field_type_str +
        "; label=" +
        label_str +
        "; immediate_v_count=" +
        immediate_values.length().to_string() +
        "; annot=" +
        first.to_string(),
      )
  }

  match field_value_from_pdf_object(pdf, value_obj) {
    Some("Lorem ipsum dolor sit amet, consectetur adipiscing elit.") => ()
    Some(v) => fail("unexpected decoded value: " + v)
    None => fail("expected field_value_from_pdf_object to decode direct /V")
  }
}
