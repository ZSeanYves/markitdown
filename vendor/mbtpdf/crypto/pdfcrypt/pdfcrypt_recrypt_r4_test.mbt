///|
test "recrypt_pdf exercises ARC4 128 r4 path from saved_encryption" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  pdf.saved_encryption = Some(@pdf.SavedEncryption::{
    from_get_encryption_values: (
      @pdfcryptprimitives.Encryption::ARC4(128, 4),
      @pdfio.string_of_int_array(Array::make(32, 66)),
      @pdfio.string_of_int_array(Array::make(32, 65)),
      -4,
      "id",
      None,
      None,
    ),
    encrypt_metadata: true,
    perms: "",
  })
  let result = try? @pdfcrypt.PdfCrypt::new().recrypt_pdf(
    pdf,
    "pw",
    renumber=false,
  )
  assert_true(result is Err(_))
}
