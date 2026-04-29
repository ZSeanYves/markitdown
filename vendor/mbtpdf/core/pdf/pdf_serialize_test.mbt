///|
test "PdfName compare, bytes, and show" {
  let a = PdfName::of_string("/A")
  let b = PdfName::of_string("/B")
  assert_eq(a.to_bytes().length(), 2)
  let names = [b, a]
  names.sort()
  assert_true(names[0].equal_string_bytes("/A"))
  assert_eq(a.to_string(), "/A")
}

///|
test "pdfobjmap_find fails on missing key" {
  let res : Result[(Ref[ObjectData], Int), Error] = try? pdfobjmap_find(
    1,
    pdfobjmap_empty(),
  )
  match res {
    Err(_) => ()
    _ => fail("expected Not_found")
  }
}

///|
test "lookup_immediate_all works on stream dictionaries" {
  let dict = PdfObject::Dictionary([
    ("/A", PdfObject::Integer(1)),
    ("/A", PdfObject::Integer(2)),
  ])
  let stream_ref = Ref::new((dict, Stream::Got(@pdfio.bytes_of_string("x"))))
  let stream_obj = PdfObject::Stream(stream_ref)
  let values = stream_obj.lookup_immediate_all("/A")
  assert_eq(values.length(), 2)
  assert_eq(stream_obj.lookup_immediate_all("/Missing").length(), 0)
  assert_eq(PdfObject::Integer(1).lookup_immediate_all("/A").length(), 0)
  let stream_ref_bad = Ref::new(
    (PdfObject::Integer(0), Stream::Got(@pdfio.mkbytes(0))),
  )
  let stream_bad = PdfObject::Stream(stream_ref_bad)
  assert_eq(stream_bad.lookup_immediate_all("/A").length(), 0)
}

///|
test "PdfObject::to_string escapes strings and normalizes names" {
  let messages : Array[String] = []
  let rendered = @pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
    let obj = PdfObject::Dictionary([
      ("Type", PdfObject::Name(PdfName::of_string("NoSlash"))),
      ("/Needs Escape", PdfObject::String("a(b)\\c\n")),
    ])
    obj.to_string()
  })
  assert_true(rendered.contains("/Type"))
  assert_true(rendered.contains("/NoSlash"))
  assert_true(rendered.contains("#20"))
  assert_true(rendered.contains("\\("))
  assert_true(rendered.contains("\\)"))
  assert_true(rendered.contains("\\\\"))
  assert_true(rendered.contains("\\n"))
  assert_true(messages.length() > 0)
}

///|
test "to_string_including_data warns when stream cannot be got" {
  let input = @pdfio.Input::of_string("abc", source="crypt")
  let crypt = ToGetCrypt::ToDecrypt(DeferredEncryption::{
    crypt_type: @pdfcryptprimitives.Encryption::AESV2,
    file_encryption_key: None,
    obj: 1,
    gen: 0,
    key: [1],
    keylength: 40,
    r: 5,
  })
  let toget = ToGet::new(input, 0, 3, crypt~)
  let stream_ref = Ref::new(
    (
      PdfObject::Dictionary([("/Length", PdfObject::Integer(3))]),
      Stream::ToGet(toget),
    ),
  )
  let stream_obj = PdfObject::Stream(stream_ref)
  let messages : Array[String] = []
  let rendered = @pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
    stream_obj.to_string_including_data()
  })
  assert_true(rendered.contains("stream"))
  assert_true(
    messages[:].contains("WARNING: toget in string_of_pdfobj_including_data\n"),
  )
}

///|
test "real formatting expands scientific notation when present" {
  let candidates : Array[String] = [
    "1e-30", "1e-50", "1e-80", "1e30", "1e50", "1e80", "-1e-50", "-1e50",
  ]
  let mut exercised = false
  for s in candidates {
    let parsed : Result[Double, Error] = try? @strconv.parse_double(s)
    let v = match parsed {
      Ok(v) => v
      Err(_) => continue
    }
    let raw = v.to_string()
    if raw.contains("e") || raw.contains("E") {
      let rendered = PdfObject::Real(v).to_string()
      assert_false(rendered.contains("e") || rendered.contains("E"))
      exercised = true
      break
    }
  }
  assert_true(exercised)
}
