///|
fn fixture_path_pdfread_malformed(path : String) -> String {
  "doc_parse/pdf/vendor/mbtpdf/" + path
}

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
  let pdf = @pdfe.with_silenced_logs(fn() raise {
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
  let pdf = @pdfe.with_silenced_logs(fn() raise {
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
  let res : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
    })
    |> Ok
  catch {
    e => Err(e)
  }
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
  let pdf = @pdfe.with_silenced_logs(fn() raise {
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
test "revision -1 returns revisions error" {
  let path = fixture_path_pdfread_malformed(
    "testdata/pdfjs_identity_tounicode.pdf",
  )
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read fixture failed: " + e.to_string())
  }
  let input = @pdfio.Input::of_bytes(bytes.to_array(), source=path)
  let res : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      PdfRead::new(logger=_ => ()).pdf_of_input(revision=-1, None, None, input)
    })
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}
