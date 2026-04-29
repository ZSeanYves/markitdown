///|
fn first_stream(pdf : @pdf.Pdf) -> (Int, Int, @pdf.PdfObject) raise {
  let mut found : (Int, Int, @pdf.PdfObject)? = None
  pdf.objiter_gen((objnum, gen, obj) => match (obj : @pdf.PdfObject) {
    Stream(_) => if found is None { found = Some((objnum, gen, obj)) }
    _ => ()
  })
  match found {
    Some(value) => value
    None => fail("expected stream object")
  }
}

///|
fn pdf_with_stream() -> @pdf.Pdf raise {
  let data = @pdfio.bytes_of_string("q Q")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let mediabox : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdfpage.Page = {
    content: [stream],
    mediabox,
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
      page,
    ],
  )
  @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
}

///|
test "decrypt_single_stream passes through unencrypted stream" {
  let pdf = pdf_with_stream()
  let (objnum, gen, stream) = first_stream(pdf)
  let decrypted = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    None,
    None,
    pdf,
    objnum,
    gen,
    stream,
  )
  match (decrypted : @pdf.PdfObject) {
    Stream(_) => ()
    _ => fail("expected stream object")
  }
}

///|
test "decrypt_single_stream restores AES256 stream bytes" {
  let pdf = pdf_with_stream()
  let (_orig_objnum, _orig_gen, orig_stream) = first_stream(pdf)
  orig_stream.getstream()
  let orig_bytes = match (orig_stream : @pdf.PdfObject) {
    Stream(r) =>
      match r.val.1 {
        @pdf.Stream::Got(bytes) => bytes
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream object")
  }
  let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
    true,
    "user",
    "owner",
    [],
    pdf,
  )
  let (objnum, gen, stream) = first_stream(enc)
  let decrypted = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    Some("user"),
    None,
    enc,
    objnum,
    gen,
    stream,
  )
  decrypted.getstream()
  match (decrypted : @pdf.PdfObject) {
    Stream(r) =>
      match r.val.1 {
        @pdf.Stream::Got(bytes) => {
          assert_eq(@pdfio.bytes_size(bytes), @pdfio.bytes_size(orig_bytes))
          assert_eq(
            @pdfio.int_array_of_bytes(bytes),
            @pdfio.int_array_of_bytes(orig_bytes),
          )
        }
        _ => fail("expected decrypted bytes")
      }
    _ => fail("expected stream object")
  }
}
