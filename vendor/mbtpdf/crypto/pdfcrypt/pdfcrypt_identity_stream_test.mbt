///|
fn set_encrypt_metadata_false(pdf : @pdf.Pdf) -> Unit raise {
  match (pdf.trailerdict : @pdf.PdfObject) {
    Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == "/Encrypt") {
        None => fail("expected /Encrypt in trailer")
        Some(i) =>
          match (entries[i].1 : @pdf.PdfObject) {
            Indirect(objnum) => {
              let encrypt_dict = pdf.lookup_obj(objnum)
              let updated = encrypt_dict.add_entry(
                "/EncryptMetadata",
                @pdf.PdfObject::Boolean(false),
              )
              pdf.addobj_given_num((objnum, updated))
            }
            encrypt_dict => {
              let updated = encrypt_dict.add_entry(
                "/EncryptMetadata",
                @pdf.PdfObject::Boolean(false),
              )
              pdf.trailerdict = pdf.trailerdict.replace_entry(
                "/Encrypt", updated,
              )
            }
          }
      }
    _ => fail("expected trailer dictionary")
  }
}

///|
test "decrypt_pdf treats /Crypt with non-Identity name as decryptable" {
  let base = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
    "user",
    "owner",
    [],
    base,
  )
  set_encrypt_metadata_false(enc)
  let crypt_stream_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(3)),
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
    (
      "/DecodeParms",
      Array([
        Dictionary([("/Name", Name(@pdf.PdfName::of_string("/NotIdentity")))]),
      ]),
    ),
  ])
  let stream_bytes = @pdfio.bytes_of_string("abc")
  ignore(
    enc.addobj(
      Stream(Ref::new((crypt_stream_dict, @pdf.Stream::Got(stream_bytes)))),
    ),
  )
  let (dec, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", enc.deep_copy())
  assert_true(dec is Some(_))
}
