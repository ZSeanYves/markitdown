///|
fn replace_encrypt_entry(
  pdf : @pdf.Pdf,
  updated : @pdf.PdfObject,
) -> Unit raise {
  match pdf.trailerdict.lookup_immediate("/Encrypt") {
    Some(Indirect(n)) => pdf.addobj_given_num((n, updated))
    _ => fail("expected /Encrypt indirect reference")
  }
}

///|
fn update_perms(pdf : @pdf.Pdf, perms : String) -> Unit raise {
  match pdf.trailerdict.lookup_immediate("/Encrypt") {
    Some(Indirect(n)) => {
      let dict = pdf.lookup_obj(n)
      let updated = dict.add_entry("/Perms", String(perms))
      replace_encrypt_entry(pdf, updated)
    }
    _ => fail("expected /Encrypt indirect reference")
  }
}

///|
test "decrypt_single_stream skips metadata when EncryptMetadata is false" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
    false,
    "user",
    "owner",
    [],
    pdf,
  )
  let dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Metadata"))),
    ("/Length", Integer(4)),
  ])
  let data = @pdfio.bytes_of_string("meta")
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    1,
    0,
    stream,
  )
  match (out : @pdf.PdfObject) {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 4)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_single_stream skips identity crypt filters" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
    (
      "/DecodeParms",
      Dictionary([("/Name", Name(@pdf.PdfName::of_string("/Identity")))]),
    ),
    ("/Length", Integer(3)),
  ])
  let data = @pdfio.bytes_of_string("abc")
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    2,
    0,
    stream,
  )
  match (out : @pdf.PdfObject) {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 3)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
  let dict_array : @pdf.PdfObject = Dictionary([
    ("/Filter", Array([Name(@pdf.PdfName::of_string("/Crypt"))])),
    (
      "/DecodeParms",
      Array([
        Dictionary([("/Name", Name(@pdf.PdfName::of_string("/Identity")))]),
      ]),
    ),
    ("/Length", Integer(3)),
  ])
  let stream_array : @pdf.PdfObject = Stream(
    Ref::new((dict_array, @pdf.Stream::Got(@pdfio.bytes_of_string("abc")))),
  )
  let out_array = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    3,
    0,
    stream_array,
  )
  match (out_array : @pdf.PdfObject) {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => assert_eq(@pdfio.bytes_size(bytes), 3)
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_single_stream handles AES256 streams" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(4))])
  let got_stream : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string("data")))),
  )
  let got_out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    4,
    0,
    got_stream,
  )
  match (got_out : @pdf.PdfObject) {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(_)) => ()
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
  let input = @pdfio.Input::of_string("data", source="stream")
  let toget = @pdf.ToGet::new(input, 0, 4)
  let toget_stream : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::ToGet(toget))),
  )
  let toget_out = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    5,
    0,
    toget_stream,
  )
  match (toget_out : @pdf.PdfObject) {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::ToGet(_)) => ()
        _ => fail("expected ToGet stream")
      }
    _ => fail("expected stream")
  }
}

///|
test "decrypt_pdf fails with short perms" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  update_perms(enc, "short")
  let result = try? @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", enc)
  assert_true(result is Err(_))
}

///|
test "decrypt_pdf fails with corrupted perms marker" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  let bad_perms = @pdfio.string_of_int_array(Array::make(16, 0))
  update_perms(enc, bad_perms)
  let result = try? @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", enc)
  assert_true(result is Err(_))
}
