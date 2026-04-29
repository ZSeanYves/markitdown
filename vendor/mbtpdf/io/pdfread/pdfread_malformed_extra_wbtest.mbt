///|
test "malformed pdf honors /Version in catalog when forced" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R /Version /1.7 >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_eq(pdf.major, 1)
  assert_eq(pdf.minor, 7)
}

///|
test "malformed pdf falls back to catalog when /Root is direct" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|trailer
    #|<< /Root 99 >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_eq(pdf.root, 1)
}

///|
test "malformed pdf without /Root and catalog errors" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Size 2 >>
    #|trailer
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_true(res is Err(_))
}

///|
test "malformed pdf ignores invalid /Version name" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R /Version /1.a >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_eq(pdf.major, 1)
  assert_eq(pdf.minor, 4)
}

///|
test "malformed pdf ignores short /Version name" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R /Version / >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 1 0 R >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_eq(pdf.major, 1)
  assert_eq(pdf.minor, 4)
}

///|
test "malformed pdf errors on missing startxref digits" {
  let reader = PdfRead::new(error_on_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|startxref
    #|%%EOF
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_true(res is Err(_))
}

///|
test "malformed pdf errors on missing root and trailer" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string("trailer"))
  })
  assert_true(res is Err(_))
}

///|
test "malformed pdf parses stream with indirect length" {
  let reader = PdfRead::new(debug_always_treat_malformed=true, logger=_ => ())
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Length 2 0 R >>
    #|stream
    #|AB
    #|endstream
    #|endobj
    #|2 0 obj
    #|2
    #|endobj
    #|3 0 obj
    #|<< /Type /Catalog /Pages 4 0 R >>
    #|endobj
    #|4 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|trailer
    #|<< /Root 3 0 R >>
    #|%%EOF
  let pdf = @pdfe.with_silenced_logs(fn() {
    reader.pdf_of_input(None, None, @pdfio.Input::of_string(data))
  })
  assert_eq(pdf.root, 3)
}

///|
test "pdf_of_input rejects invalid revision" {
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    PdfRead::new(logger=_ => ()).pdf_of_input(
      revision=0,
      None,
      None,
      @pdfio.Input::of_string("%PDF-1.4"),
    )
  })
  assert_true(res is Err(_))
}
