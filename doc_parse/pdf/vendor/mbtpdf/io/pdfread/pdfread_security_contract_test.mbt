///|
fn security_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
test "security contract detects malformed encryption dictionary without silent support" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  pdf.trailerdict = pdf.trailerdict.add_entry(
    "/Encrypt",
    Dictionary([
      ("/Filter", security_contract_name("/Unsupported")),
      ("/V", Integer(99)),
    ]),
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(pdf))
  assert_true(@pdfread.PdfRead::new().what_encryption(pdf) is None)
  assert_eq(@pdfread.PdfRead::new().permissions(pdf).length(), 0)
}
