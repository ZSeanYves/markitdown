///|
fn build_minimal_pdf_for_encrypt() -> @pdf.Pdf {
  let pdf : @pdf.Pdf = {
    major: 2,
    minor: 0,
    root: 4,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: @pdf.pdfobjmap_empty(),
      object_stream_ids: Map::new(),
    },
    trailerdict: Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let content = "BT /F0 12 Tf (Hello) Tj ET\n"
  let stream_bytes = @pdfio.bytes_of_string(content)
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(stream_bytes))),
  ])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(stream_bytes))),
  )
  let font_dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Times-Roman"))),
  ])
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F0", font_dict)])),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", Indirect(1)),
    ("/Resources", resources),
    ("/MediaBox", Array([Integer(0), Integer(0), Integer(300), Integer(300)])),
    ("/Contents", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(3)])),
    ("/Count", Integer(1)),
  ])
  let catalog : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Catalog"))),
    ("/Pages", Indirect(1)),
  ])
  pdf.addobj_given_num((1, pages))
  pdf.addobj_given_num((2, stream_obj))
  pdf.addobj_given_num((3, page))
  pdf.addobj_given_num((4, catalog))
  pdf
}

///|
fn find_subslice(
  haystack : @pdfio.MutableBytes,
  needle : @pdfio.MutableBytes,
  start? : Int = 0,
) -> Int? {
  if needle.length() == 0 {
    return Some(start)
  }
  let mut i = start
  let last = haystack.length() - needle.length()
  while i <= last {
    let mut j = 0
    while j < needle.length() && haystack[i + j] == needle[j] {
      j = j + 1
    }
    if j == needle.length() {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
test "pdf_to_output encrypts and reads with user password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(Some(enc), false, pdf, output)
  let pdf_bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="encrypt-roundtrip")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input)
  assert_eq(parsed.objcard(), 5)
  assert_eq(parsed.root, 4)
}

///|
test "pdf_to_output recrypt uses saved encryption" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::PDF40bit,
    "owner",
    "user",
    permissions,
  )
  let (output1, buffer1) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(Some(enc), false, pdf, output1)
  let bytes1 = output1.extract_bytes(buffer1)
  let input1 = @pdfio.Input::of_bytes(bytes1, source="encrypt-recrypt")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input1)
  let (decrypted_opt, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", parsed)
  let decrypted = match decrypted_opt {
    Some(value) => value
    None => fail("expected decryptable PDF")
  }
  let (output2, buffer2) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    recrypt="user",
    None,
    false,
    decrypted,
    output2,
  )
  let bytes2 = output2.extract_bytes(buffer2)
  let input2 = @pdfio.Input::of_bytes(bytes2, source="recrypt-roundtrip")
  let parsed2 = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input2)
  let (roundtrip_opt, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf(
    "user", parsed2,
  )
  match roundtrip_opt {
    Some(_) => ()
    None => fail("expected recryptable PDF")
  }
  assert_eq(parsed2.objcard(), 6)
  assert_eq(parsed2.root, 4)
}

///|
test "pdf_to_output encrypts object streams and reads with user password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="encrypt-objstm")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input)
  assert_eq(parsed.root, 4)
}

///|
test "pdfread lazy decrypts object streams for encrypted PDFs" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="encrypt-objstm-lazy")
  let parsed = @pdfread.PdfRead::new().pdf_of_input_lazy(
    Some("user"),
    None,
    input,
  )
  let objstm_entries = parsed.objects.object_stream_ids.to_array()
  if objstm_entries.length() == 0 {
    fail("expected object stream entries")
  }
  let objnum = objstm_entries[0].0
  let obj = parsed.lookup_obj(objnum)
  match (obj : @pdf.PdfObject) {
    Null => fail("expected parsed object from objstm")
    _ => ()
  }
}

///|
test "pdfread returns pdf for encrypted objstm without password" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::PDF128bit,
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="encrypt-objstm-nopw")
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(None, None, input)
  })
  match res {
    Ok(parsed) =>
      if @pdfread.PdfRead::new().what_encryption(parsed) is None {
        fail("expected encryption info")
      }
    Err(_) => fail("expected read to succeed without password")
  }
}

///|
test "pdfread skips malformed object stream" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::AES128bit(true),
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    compress_objstm=false,
    Some(enc),
    false,
    pdf,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let objstm_marker = @pdfio.bytes_of_string("/ObjStm")
  let n_marker = @pdfio.bytes_of_string("/N ")
  let objstm_pos = match find_subslice(pdf_bytes, objstm_marker) {
    Some(pos) => pos
    None => fail("expected /ObjStm")
  }
  let n_pos = match find_subslice(pdf_bytes, n_marker, start=objstm_pos) {
    Some(pos) => pos
    None => fail("expected /N entry")
  }
  let n_value_index = n_pos + n_marker.length()
  pdf_bytes[n_value_index] = '/'.to_int().to_byte()
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="malformed-objstm")
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_silenced_logs(fn() {
    @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(
      Some("user"),
      None,
      input,
    )
  })
  match res {
    Ok(_) => ()
    Err(_) => fail("expected read to succeed despite malformed objstm")
  }
}

///|
test "pdf_to_output encrypts with AES256" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::AES256bit(true),
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(Some(enc), false, pdf, output)
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="aes256-encrypt")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input)
  let (decrypted_opt, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", parsed)
  assert_true(decrypted_opt is Some(_))
}

///|
test "pdf_to_output encrypts with AES256 ISO" {
  let pdf = build_minimal_pdf_for_encrypt()
  let permissions : Array[@pdfcrypt.Permission] = []
  let enc = @pdfwrite.Encryption::new(
    @pdfwrite.EncryptionMethod::AES256bitISO(true),
    "owner",
    "user",
    permissions,
  )
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(Some(enc), false, pdf, output)
  let bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(bytes, source="aes256iso-encrypt")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(Some("user"), None, input)
  let (decrypted_opt, _) = @pdfcrypt.PdfCrypt::new().decrypt_pdf("user", parsed)
  assert_true(decrypted_opt is Some(_))
}
