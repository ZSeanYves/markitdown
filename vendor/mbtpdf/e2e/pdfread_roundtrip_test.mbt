///|
fn pdfread_roundtrip_via_writer(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(None, false, pdf, output)
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="e2e-roundtrip")
  @pdfread.PdfRead::new().pdf_of_input(None, None, input)
}

///|
fn pdf_has_stream(pdf : @pdf.Pdf) -> Bool {
  for objnum in pdf.objnumbers() {
    let obj = pdf.lookup_obj(objnum)
    match (obj : @pdf.PdfObject) {
      Stream(_) => return true
      _ => ()
    }
  }
  false
}

///|
async test "e2e parse camlpdf intro pdf" {
  let filename = "testdata/introduction_to_camlpdf.pdf"
  let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, filename)
  let page_count = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree_quick()
  assert_true(pdf.objcard() > 0)
  assert_true(page_count > 0)
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(),
    page_count,
  )
}

///|
async test "e2e roundtrip camlpdf intro pdf" {
  let filename = "testdata/introduction_to_camlpdf.pdf"
  let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, filename)
  let roundtripped = pdfread_roundtrip_via_writer(pdf)
  assert_eq(
    @pdfpage.PdfPageDoc::new(roundtripped).pages_of_pagetree_quick(),
    @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree_quick(),
  )
}

///|
async test "e2e parse camlpdf logo pdf has stream" {
  let filename = "testdata/logo.pdf"
  let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, filename)
  assert_true(pdf_has_stream(pdf))
}

///|
test "pdf_of_input removes xref and objstm objects after eager parse" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (output, buffer) = @pdfio.Output::of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    None,
    false,
    pdf,
    output,
  )
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="objstm-cleanup")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
  for objnum in parsed.objnumbers() {
    let obj = parsed.lookup_obj(objnum)
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _) = r.val
        match (parsed.lookup_direct("/Type", dict) : @pdf.PdfObject?) {
          Some(Name(n)) if n.equal_string_bytes("/XRef") =>
            fail("expected xref streams removed")
          Some(Name(n)) if n.equal_string_bytes("/ObjStm") =>
            fail("expected objstm streams removed")
          _ => ()
        }
      }
      _ => ()
    }
  }
}
