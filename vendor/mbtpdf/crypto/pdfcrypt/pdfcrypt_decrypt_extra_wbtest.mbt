///|
fn repeat_char(ch : Char, count : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<count {
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
test "already_decrypted returns false for missing objnum" {
  let pdf = @pdf.Pdf::empty()
  assert_false(already_decrypted(pdf, 999))
}

///|
test "already_decrypted returns true for ParsedAlreadyDecrypted" {
  let pdf = @pdf.Pdf::empty()
  let objnum = pdf.addobj(@pdf.PdfObject::String("x"))
  let entry = @pdf.pdfobjmap_find(objnum, pdf.objects.objects)
  entry.0.val = @pdf.ObjectData::ParsedAlreadyDecrypted(
    @pdf.PdfObject::String("x"),
  )
  assert_true(already_decrypted(pdf, objnum))
}

///|
test "is_identity handles decodeparms shapes" {
  let pdf = @pdf.Pdf::empty()
  let base : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
  ])
  let dict_none_name = base.add_entry("/DecodeParms", Dictionary([]))
  assert_true(is_identity(false, pdf, dict_none_name))
  let dict_bad_name = base.add_entry(
    "/DecodeParms",
    Dictionary([("/Name", Name(@pdf.PdfName::of_string("/NotIdentity")))]),
  )
  assert_false(is_identity(false, pdf, dict_bad_name))
  let dict_array_first = base.add_entry("/DecodeParms", Array([Dictionary([])]))
  assert_true(is_identity(false, pdf, dict_array_first))
  let dict_array_other = base.add_entry("/DecodeParms", Array([Integer(1)]))
  assert_true(is_identity(false, pdf, dict_array_other))
  let dict_other = base.add_entry("/DecodeParms", Integer(1))
  assert_true(is_identity(false, pdf, dict_other))
}

///|
test "decrypt returns unchanged values when already_decrypted is set" {
  let pdf = @pdf.Pdf::empty()
  let objnum = pdf.addobj(@pdf.PdfObject::String("x"))
  let entry = @pdf.pdfobjmap_find(objnum, pdf.objects.objects)
  entry.0.val = @pdf.ObjectData::ParsedAlreadyDecrypted(
    @pdf.PdfObject::String("x"),
  )
  let ct = @pdfcryptprimitives.Encryption::AESV2
  match
    decrypt(
      ct,
      pdf,
      false,
      false,
      objnum,
      0,
      [1],
      40,
      2,
      None,
      @pdf.PdfObject::String("s"),
    ) {
    @pdf.PdfObject::String("s") => ()
    _ => fail("expected string passthrough")
  }
  match
    decrypt(
      ct,
      pdf,
      false,
      false,
      objnum,
      0,
      [1],
      40,
      2,
      None,
      @pdf.PdfObject::Array([@pdf.PdfObject::Integer(1)]),
    ) {
    @pdf.PdfObject::Array(_) => ()
    _ => fail("expected array passthrough")
  }
  match
    decrypt(
      ct,
      pdf,
      false,
      false,
      objnum,
      0,
      [1],
      40,
      2,
      None,
      @pdf.PdfObject::Dictionary([]),
    ) {
    @pdf.PdfObject::Dictionary(_) => ()
    _ => fail("expected dict passthrough")
  }
}

///|
test "decrypt raises when AESV3 key is missing" {
  let pdf = @pdf.Pdf::empty()
  let ct = @pdfcryptprimitives.Encryption::AESV3(false)
  let res : Result[@pdf.PdfObject, Error] = try? decrypt(
    ct,
    pdf,
    false,
    false,
    1,
    0,
    [1],
    256,
    5,
    None,
    @pdf.PdfObject::String("x"),
  )
  assert_true(res is Err(_))
  let stream_ref = Ref::new(
    (
      @pdf.PdfObject::Dictionary([]),
      @pdf.Stream::Got(@pdfio.bytes_of_string("x")),
    ),
  )
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  let res2 : Result[@pdf.PdfObject, Error] = try? decrypt_stream(
    v => v,
    ct,
    pdf,
    false,
    false,
    1,
    0,
    [1],
    256,
    5,
    None,
    stream_obj,
  )
  assert_true(res2 is Err(_))
}

///|
test "decrypt_stream handles non-stream and non-dictionary stream dict cases" {
  let pdf = @pdf.Pdf::empty()
  let ct = @pdfcryptprimitives.Encryption::AESV2
  let passthrough = decrypt_stream(
    v => v,
    ct,
    pdf,
    false,
    false,
    1,
    0,
    [1],
    40,
    2,
    None,
    @pdf.PdfObject::Integer(0),
  )
  match passthrough {
    @pdf.PdfObject::Integer(0) => ()
    _ => fail("expected passthrough")
  }
  let toget = @pdf.ToGet::new(@pdfio.Input::of_string("", source="toget"), 0, 0)
  let stream_ref = Ref::new(
    (@pdf.PdfObject::Integer(0), @pdf.Stream::ToGet(toget)),
  )
  let out = decrypt_stream(
    v => v,
    ct,
    pdf,
    false,
    false,
    1,
    0,
    [1],
    40,
    2,
    None,
    @pdf.PdfObject::Stream(stream_ref),
  )
  match out {
    Stream(_) => ()
    _ => fail("expected stream")
  }
}

///|
test "aesv3 helpers cover iso branch and length errors" {
  let pw = "pw"
  let u48 = repeat_char('U', 48)
  let o48 = repeat_char('O', 48)
  let oe = repeat_char('E', 32)
  let ue = repeat_char('e', 32)

  // Exercise shamix branches for small raw payloads.
  let mixed = shamix(pw, None, "x")
  assert_eq(mixed.length(), 32)

  // Exercise iso=true hashing branch for key derivation.
  let _ = authenticate_user_password_aesv3(true, pw, u48) catch {
    _ => fail("unexpected")
  }
  let _ = authenticate_owner_password_aesv3(true, pw, u48, o48) catch {
    _ => fail("unexpected")
  }
  let _ = file_encryption_key_aesv3(true, pw, o48, oe, u48) catch {
    _ => fail("unexpected")
  }
  let _ = file_encryption_key_aesv3_user(true, pw, u48, ue) catch {
    _ => fail("unexpected")
  }

  // Length error branches.
  let short_owner_res : Result[@pdfio.MutableBytes, Error] = try? file_encryption_key_aesv3(
    true, pw, "short", oe, u48,
  )
  assert_true(short_owner_res is Err(_))
  let short_user_res : Result[@pdfio.MutableBytes, Error] = try? file_encryption_key_aesv3_user(
    true, pw, "short", ue,
  )
  assert_true(short_user_res is Err(_))
  let short_auth_owner_res : Result[Bool, Error] = try? authenticate_owner_password_aesv3(
    true, pw, u48, "short",
  )
  assert_true(short_auth_owner_res is Err(_))
  let short_auth_user_res : Result[Bool, Error] = try? authenticate_user_password_aesv3(
    true, pw, "short",
  )
  assert_true(short_auth_user_res is Err(_))
}
