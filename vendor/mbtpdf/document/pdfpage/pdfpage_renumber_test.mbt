///|
fn renumber_resources() -> @pdf.PdfObject {
  Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
    ("/ExtGState", Dictionary([("/GS1", Null)])),
    (
      "/ColorSpace",
      Dictionary([("/CS1", Name(@pdf.PdfName::of_string("/DeviceRGB")))]),
    ),
    ("/Pattern", Dictionary([("/P1", Null)])),
    ("/Shading", Dictionary([("/Sh1", Null)])),
    ("/XObject", Dictionary([("/X1", Null)])),
    ("/Properties", Dictionary([("/Prop1", Null)])),
  ])
}

///|
fn renumber_page(rect : @pdf.PdfObject) -> @pdfpage.Page raise {
  let ops : Array[@pdfops.Op] = [
    OpTf("/F1", 12.0),
    Opgs("/GS1"),
    OpCS("/CS1"),
    Opcs("/CS1"),
    OpCS("/CSMissing"),
    Opcs("/CSMissing"),
    OpSCNName("/P1", [0.1]),
    OpscnName("/P1", [0.2]),
    Opsh("/Sh1"),
    OpDo("/X1"),
    OpDP("/Span", Name(@pdf.PdfName::of_string("/Prop1"))),
    OpBDC("/Span", Name(@pdf.PdfName::of_string("/Prop1"))),
    OpBDC("/Span", Name(@pdf.PdfName::of_string("/PropMissing"))),
  ]
  {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: rect,
    resources: renumber_resources(),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
}

///|
test "renumber_pages returns empty on no pages" {
  let pdf = @pdf.Pdf::empty()
  let updated = @pdfpage.PdfPageDoc::new(pdf).renumber_pages([])
  assert_eq(updated.length(), 0)
}

///|
test "renumber_pages renames resource operators consistently" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let updated = @pdfe.with_logger(_ => (), fn() {
    @pdfpage.PdfPageDoc::new(pdf).renumber_pages([renumber_page(rect)])
  })
  let renamed = updated[0]
  let ops = @pdfops.Op::parse_operators(pdf, renamed.resources, renamed.content)
  assert_eq(ops.length(), 13)
  match (ops[0] : @pdfops.Op) {
    OpTf(name, _) => assert_true(name != "/F1")
    _ => fail("expected OpTf")
  }
  match (ops[1] : @pdfops.Op) {
    Opgs(name) => assert_true(name != "/GS1")
    _ => fail("expected Opgs")
  }
  match (ops[2] : @pdfops.Op) {
    OpCS(name) => assert_true(name != "/CS1")
    _ => fail("expected OpCS")
  }
  match (ops[3] : @pdfops.Op) {
    Opcs(name) => assert_true(name != "/CS1")
    _ => fail("expected Opcs")
  }
  match (ops[4] : @pdfops.Op) {
    OpCS(name) => assert_eq(name, "/CSMissing")
    _ => fail("expected OpCS missing")
  }
  match (ops[5] : @pdfops.Op) {
    Opcs(name) => assert_eq(name, "/CSMissing")
    _ => fail("expected Opcs missing")
  }
  match (ops[6] : @pdfops.Op) {
    OpSCNName(name, _) => assert_true(name != "/P1")
    _ => fail("expected OpSCNName")
  }
  match (ops[7] : @pdfops.Op) {
    OpscnName(name, _) => assert_true(name != "/P1")
    _ => fail("expected OpscnName")
  }
  match (ops[8] : @pdfops.Op) {
    Opsh(name) => assert_true(name != "/Sh1")
    _ => fail("expected Opsh")
  }
  match (ops[9] : @pdfops.Op) {
    OpDo(name) => assert_true(name != "/X1")
    _ => fail("expected OpDo")
  }
  match (ops[10] : @pdfops.Op) {
    OpDP(_, Name(name)) => assert_true(!name.equal_string_bytes("/Prop1"))
    _ => fail("expected OpDP")
  }
  match (ops[11] : @pdfops.Op) {
    OpBDC(_, Name(name)) => assert_true(!name.equal_string_bytes("/Prop1"))
    _ => fail("expected OpBDC renamed")
  }
  match (ops[12] : @pdfops.Op) {
    OpBDC(_, Name(name)) => assert_true(name.equal_string_bytes("/PropMissing"))
    _ => fail("expected OpBDC missing")
  }
}

///|
test "renumber_pages rewrites inline image colorspace names" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let resources : @pdf.PdfObject = Dictionary([
    (
      "/ColorSpace",
      Dictionary([("/CS1", Name(@pdf.PdfName::of_string("/DeviceRGB")))]),
    ),
  ])
  let img1_dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/CS1"))),
  ])
  let img2_dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    (
      "/CS",
      Array([
        Name(@pdf.PdfName::of_string("/Indexed")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
        Integer(0),
        String(@pdfio.string_of_bytes(@pdfio.bytes_of_list([255, 0, 0]))),
      ]),
    ),
  ])
  let img3_dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceRGB"))),
  ])
  let ops : Array[@pdfops.Op] = [
    InlineImage((img1_dict, None, @pdfio.bytes_of_string("RGB"))),
    InlineImage((img2_dict, None, @pdfio.bytes_of_list([0]))),
    InlineImage((img3_dict, None, @pdfio.bytes_of_string("RGB"))),
  ]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: rect,
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let updated = @pdfpage.PdfPageDoc::new(pdf).renumber_pages([page])
  let renamed = updated[0]
  let ops_out = @pdfops.Op::parse_operators(
    pdf,
    renamed.resources,
    renamed.content,
  )
  let mut saw_renamed = false
  let mut saw_passthrough = false
  let mut saw_device = false
  for op in ops_out {
    match (op : @pdfops.Op) {
      InlineImage((inline_dict, _, _)) =>
        match pdf.lookup_direct("/CS", inline_dict) {
          Some(Name(name)) =>
            if name.equal_string_bytes("/DeviceRGB") {
              saw_device = true
            } else {
              assert_true(!name.equal_string_bytes("/CS1"))
              saw_renamed = true
            }
          Some(Array(_)) => saw_passthrough = true
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(saw_renamed)
  assert_true(saw_passthrough)
  assert_true(saw_device)
}
