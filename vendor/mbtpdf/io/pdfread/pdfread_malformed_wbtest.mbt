///|
test "malformed pdf without xref uses fallback" {
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R /Size 3 >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    PdfRead::new(logger=_ => ()).pdf_of_input(
      None,
      None,
      @pdfio.Input::of_string(data),
    )
  })
  assert_eq(pdf.root, 1)
  assert_eq(pdf.objcard(), 2)
  match (pdf.lookup_obj(1) : @pdf.PdfObject) {
    Dictionary(_) => ()
    _ => fail("expected catalog dictionary")
  }
}

///|
test "malformed pdf without trailer infers root" {
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    PdfRead::new(logger=_ => ()).pdf_of_input(
      None,
      None,
      @pdfio.Input::of_string(data),
    )
  })
  assert_eq(pdf.root, 1)
  match (pdf.trailerdict.lookup_immediate("/Root") : @pdf.PdfObject?) {
    Some(Indirect(1)) => ()
    _ => fail("expected /Root in trailer")
  }
}

///|
test "malformed pdf honors error_on_malformed" {
  let reader = PdfRead::new(error_on_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|%%EOF
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_true(res is Err(_))
}

///|
test "malformed pdf skips bad objects and trailers" {
  let data =
    #|trailer %PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|3 0 obj
    #|>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R
  let pdf = @pdfe.with_silenced_logs(fn() {
    PdfRead::new(logger=_ => ()).pdf_of_input(
      None,
      None,
      @pdfio.Input::of_string(data),
    )
  })
  assert_eq(pdf.root, 1)
  assert_eq(pdf.objcard(), 2)
}

///|
async test "revision -1 returns revisions error" {
  let input = @pdfiofs.input_of_file("testdata/pdfjs_identity_tounicode.pdf")
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    PdfRead::new(logger=_ => ()).pdf_of_input(revision=-1, None, None, input)
  })
  assert_true(res is Err(_))
}
