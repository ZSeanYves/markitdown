///|
test "what_encryption returns None for unencrypted" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  assert_true(@pdfread.PdfRead::new().what_encryption(pdf) is None)
  assert_eq(@pdfread.PdfRead::new().permissions(pdf).length(), 0)
}

///|
test "what_encryption detects ARC4 and AES methods" {
  let base = @pdfpage.PdfPageDoc::minimum_valid()
  let arc4 = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
    "user",
    "owner",
    [],
    base.deep_copy(),
  )
  match @pdfread.PdfRead::new().what_encryption(arc4) {
    Some(@pdfcrypt.EncryptionMethod::PDF40bit) => ()
    _ => fail("expected PDF40bit encryption")
  }
  let aes128 = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
    true,
    "user",
    "owner",
    [],
    base.deep_copy(),
  )
  match @pdfread.PdfRead::new().what_encryption(aes128) {
    Some(@pdfcrypt.EncryptionMethod::AES128bit(_)) => ()
    _ => fail("expected AES128bit encryption")
  }
}

///|
test "what_encryption detects AES256 variants" {
  let base = @pdfpage.PdfPageDoc::minimum_valid()
  let aes256 = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    base.deep_copy(),
  )
  match @pdfread.PdfRead::new().what_encryption(aes256) {
    Some(@pdfcrypt.EncryptionMethod::AES256bit(_)) => ()
    _ => fail("expected AES256bit encryption")
  }
  let aes256iso = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256ISO(
    true,
    "user",
    "owner",
    [],
    base.deep_copy(),
  )
  match @pdfread.PdfRead::new().what_encryption(aes256iso) {
    Some(@pdfcrypt.EncryptionMethod::AES256bitISO(_)) => ()
    _ => fail("expected AES256bitISO encryption")
  }
  assert_eq(@pdfread.PdfRead::new().permissions(aes256iso).length(), 0)
}
