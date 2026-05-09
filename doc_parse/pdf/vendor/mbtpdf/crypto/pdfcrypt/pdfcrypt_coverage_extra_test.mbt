///|
fn encrypt_objnum(pdf : @pdf.Pdf) -> Int raise {
  match (pdf.trailerdict.lookup_immediate("/Encrypt") : @pdf.PdfObject?) {
    Some(Indirect(i)) => i
    _ => raise Failure::Failure("expected /Encrypt indirect")
  }
}

///|
test "decrypt_single_stream decrypts ARC4 stream with owner password" {
  let base = pdf_with_stream()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
    "user",
    "owner",
    [],
    base,
  )
  let (objnum, gen, stream) = first_stream(enc)
  let out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    None,
    Some("owner"),
    enc,
    objnum,
    gen,
    stream,
  )
  match (out : @pdf.PdfObject) {
    Stream(r) => {
      @pdf.PdfObject::Stream(r).getstream()
      ()
    }
    _ => fail("expected decrypted stream")
  }
}

///|
test "decrypt_single_stream AESV3 errors when no password supplied" {
  let base = pdf_with_stream()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    base,
  )
  let (objnum, gen, stream) = first_stream(enc)
  let res : Result[@pdf.PdfObject, Error] = try? @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    None,
    None,
    enc,
    objnum,
    gen,
    stream,
  )
  assert_true(res is Err(_))
}

///|
test "decrypt_single_stream AESV3 succeeds with owner password" {
  let base = pdf_with_stream()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    base,
  )
  let (objnum, gen, stream) = first_stream(enc)
  let out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    None,
    Some("owner"),
    enc,
    objnum,
    gen,
    stream,
  )
  match (out : @pdf.PdfObject) {
    Stream(r) => {
      @pdf.PdfObject::Stream(r).getstream()
      ()
    }
    _ => fail("expected decrypted stream")
  }
}

///|
test "decrypt_pdf AESV3 errors when /OE missing" {
  let base = pdf_with_stream()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    base,
  )
  let enc_num = encrypt_objnum(enc)
  let enc_dict = enc.lookup_obj(enc_num).remove_entry("/OE")
  enc.addobj_given_num((enc_num, enc_dict))
  let res : Result[(@pdf.Pdf?, Array[Permission]), Error] = try? @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user", enc,
  )
  assert_true(res is Err(_))
}

///|
test "decrypt_pdf AESV3 errors when /Perms and /P mismatch" {
  let base = pdf_with_stream()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    base,
  )
  let enc_num = encrypt_objnum(enc)
  let enc_dict = enc.lookup_obj(enc_num).replace_entry("/P", Integer(123456))
  enc.addobj_given_num((enc_num, enc_dict))
  let res : Result[(@pdf.Pdf?, Array[Permission]), Error] = try? @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user", enc,
  )
  assert_true(res is Err(_))
}

///|
test "recrypt_pdf errors on unencrypted pdf" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let res : Result[@pdf.Pdf, Error] = try? @pdfcrypt.PdfCrypt::new().recrypt_pdf(
    pdf,
    "pw",
    renumber=false,
  )
  assert_true(res is Err(_))
}
