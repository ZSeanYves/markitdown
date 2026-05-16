///|
fn utf16be_pdf_string(text : String) -> String raise {
  let codepoints = @pdftext.PdfTextUtil::new().codepoints_of_utf8(text)
  @pdftext.PdfTextUtil::new().utf16be_of_codepoints(codepoints)
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
    ("/A", Dictionary([
      ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
      ("/D", Array([Indirect(3), Name(@pdf.PdfName::of_string("/Fit"))])),
    ])),
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
