///|
test "banlist_of_p returns all permissions for zero" {
  let perms = @pdfcrypt.PdfCrypt::new().banlist_of_p(0)
  assert_eq(perms.length(), 8)
}

///|
test "encrypt/decrypt 40bit roundtrip" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
    "user",
    "owner",
    [],
    pdf,
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", enc)
  match dec {
    Some(_) => ()
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let owner = @pdfcrypt.PdfCrypt::new().decrypt_pdf_owner("owner", enc)
  match owner {
    Some(_) => ()
    _ => fail("expected owner decrypt")
  }
}

///|
test "encrypt/decrypt 128bit roundtrip" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_128bit(
    "user",
    "owner",
    [],
    pdf,
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user",
    enc.deep_copy(),
  )
  match dec {
    Some(pdf_dec) =>
      assert_eq(
        @pdfpage.PdfPageDoc::new(pdf_dec).pages_of_pagetree().length(),
        1,
      )
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("wrong", enc.deep_copy())
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.PdfCrypt::new().get_encryption_values(
    enc,
  )
  match crypt_type {
    @pdfcryptprimitives.Encryption::ARC4(128, 3) => ()
    _ => fail("expected ARC4 128 r3")
  }
}

///|
test "encrypt/decrypt AES V2 roundtrip" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  assert_true(@pdfcrypt.PdfCrypt::new().is_encrypted(enc))
  let (dec, perms) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user",
    enc.deep_copy(),
  )
  match dec {
    Some(pdf_dec) =>
      assert_eq(
        @pdfpage.PdfPageDoc::new(pdf_dec).pages_of_pagetree().length(),
        1,
      )
    _ => fail("expected decrypted pdf")
  }
  assert_eq(perms.length(), 0)
  let (bad, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("wrong", enc.deep_copy())
  match bad {
    None => ()
    _ => fail("expected wrong password to fail")
  }
  let (crypt_type, _, _, _, _, _, _) = @pdfcrypt.PdfCrypt::new().get_encryption_values(
    enc,
  )
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV2 => ()
    _ => fail("expected AESV2")
  }
}

///|
test "decrypt_pdf returns original when unencrypted" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (dec, perms) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", pdf)
  match dec {
    Some(_) => ()
    _ => fail("expected unencrypted pdf to pass through")
  }
  assert_eq(perms.length(), 0)
  let missing : Result[
    (
      @pdfcryptprimitives.Encryption,
      String,
      String,
      Int,
      String,
      String?,
      String?,
    ),
    Error,
  ] = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  assert_true(missing is Err(_))
}

///|
test "recrypt_pdf requires correct password" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  let reenc_user : Result[@pdf.Pdf, Error] = try? @pdfcrypt.PdfCrypt::new().recrypt_pdf(
    enc.deep_copy(),
    "user",
    renumber=false,
  )
  match reenc_user {
    Ok(pdf_reenc) =>
      match
        @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", pdf_reenc.deep_copy()) {
        (Some(_), _) => ()
        _ => fail("expected user decrypt after recrypt")
      }
    Err(_) => fail("expected user recrypt to succeed")
  }
  let reenc_owner : Result[@pdf.Pdf, Error] = try? @pdfcrypt.PdfCrypt::new().recrypt_pdf(
    enc.deep_copy(),
    "owner",
    renumber=false,
  )
  match reenc_owner {
    Ok(pdf_reenc) =>
      match
        @pdfcrypt.PdfCrypt::new().decrypt_pdf_owner(
          "owner",
          pdf_reenc.deep_copy(),
        ) {
        Some(_) => ()
        None => fail("expected owner decrypt after recrypt")
      }
    Err(_) => fail("expected owner recrypt to succeed")
  }
  let bad : Result[@pdf.Pdf, Error] = try? @pdfcrypt.PdfCrypt::new().recrypt_pdf(
    enc.deep_copy(),
    "wrong",
    renumber=false,
  )
  assert_true(bad is Err(_))
}
