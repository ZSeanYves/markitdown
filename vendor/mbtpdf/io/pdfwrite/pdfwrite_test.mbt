///|
test "string_of_pdf basic" {
  let obj : @pdf.PdfObject = String("a(b)\\c")
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(obj)
  assert_eq(s, "(a\\(b\\)\\\\c)")
}

///|
test "string_of_pdf dictionary" {
  let obj : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Example"))),
    ("/Count", Integer(2)),
  ])
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(obj)
  assert_eq(s, "<</Type /Example /Count 2>>")
}

///|
test "string_of_pdf escapes names" {
  let obj : @pdf.PdfObject = Name(@pdf.PdfName::of_string("/A B#C/D"))
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(obj)
  assert_eq(s, "/A#20B#23C#2FD")
}

///|
test "pdf_to_output writes binary header" {
  let pdf = build_minimal_pdf()
  let (output, buffer) = @pdfio.Output::of_bytes(128)
  @pdfwrite.PdfWrite::new().pdf_to_output(None, false, pdf, output)
  let bytes = output.extract_bytes(buffer)
  let expected = [
    '%'.to_int(),
    'P'.to_int(),
    'D'.to_int(),
    'F'.to_int(),
    '-'.to_int(),
    '2'.to_int(),
    '.'.to_int(),
    '0'.to_int(),
    '\n'.to_int(),
    '%'.to_int(),
    128,
    129,
    130,
    131,
    '\n'.to_int(),
  ]
  if bytes.length() < expected.length() {
    fail("expected header length \{expected.length()}")
  }
  let mut i = 0
  while i < expected.length() {
    if bytes[i].to_int() != expected[i] {
      fail("unexpected header byte at \{i}")
    }
    i = i + 1
  }
}

///|
test "string_of_pdf formats reals without exponent" {
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(Real(1.0e-6))
  assert_true(!s.contains("e") && !s.contains("E"))
}

///|
test "string_of_pdf trims trailing zeros" {
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(Real(2.0))
  assert_eq(s, "2")
}

///|
test "string_of_pdf invalid name" {
  let write_ctx = @pdfwrite.PdfWrite::new(logger=_ => ())
  let name = @pdfe.with_silenced_logs(fn() {
    @pdf.PdfName::of_string("Example")
  })
  let s = write_ctx.string_of_pdf(Name(name))
  assert_eq(s, "/Example")
}

///|
test "string_of_pdf normalizes -0.0" {
  let s = @pdfwrite.PdfWrite::new().string_of_pdf(Real(-0.0))
  assert_eq(s, "0")
}
