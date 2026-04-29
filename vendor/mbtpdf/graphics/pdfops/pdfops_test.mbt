///|
test "string_of_ops renders basic operators" {
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::Opw(2.0),
    @pdfops.Op::Opq,
    @pdfops.Op::OpQ,
  ])
  assert_true(rendered.contains("w"))
  assert_true(rendered.contains("q"))
  assert_true(rendered.contains("Q"))
}

///|
test "stream_of_ops builds a stream" {
  let stream = @pdfops.Op::stream_of_ops([@pdfops.Op::Opq, @pdfops.Op::OpQ])
  match (stream : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, contents) = r.val
      match
        (@pdf.Pdf::empty().lookup_direct("/Length", dict) : @pdf.PdfObject?) {
        Some(Integer(length)) => assert_true(length > 0)
        _ => fail("expected /Length")
      }
      match contents {
        @pdf.Stream::Got(bytes) => {
          let text = @pdfio.string_of_bytes(bytes)
          assert_true(text.contains("q"))
          assert_true(text.contains("Q"))
        }
        _ => fail("expected stream bytes")
      }
    }
    _ => fail("expected stream object")
  }
}

///|
test "components resolves color spaces" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    (
      "/ColorSpace",
      Dictionary([("/MyCS", Name(@pdf.PdfName::of_string("/DeviceGray")))]),
    ),
  ])
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Name(@pdf.PdfName::of_string("/DeviceRGB")),
    ),
    3,
  )
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Name(@pdf.PdfName::of_string("/MyCS")),
    ),
    1,
  )
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/Pattern")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
      ]),
    ),
    3,
  )
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/ICCBased")),
        Dictionary([("/N", Integer(4))]),
      ]),
    ),
    4,
  )
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/DeviceN")),
        Array([
          Name(@pdf.PdfName::of_string("/A")),
          Name(@pdf.PdfName::of_string("/B")),
        ]),
      ]),
    ),
    2,
  )
  assert_eq(
    @pdfops.Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/Separation")),
        Name(@pdf.PdfName::of_string("/Spot")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
        Dictionary([]),
      ]),
    ),
    1,
  )
  let pattern_err : Result[Int, Error] = try? @pdfops.Op::components(
    pdf,
    resources,
    Name(@pdf.PdfName::of_string("/Pattern")),
  )
  assert_true(pattern_err is Err(_))
}

///|
test "parse_single_stream reads basic ops" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_string("1 w q 0 0 m 10 0 l S Q")
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
  match ops[0] {
    Opw(value) => assert_eq(value, 1.0)
    _ => fail("expected Opw")
  }
  match ops[1] {
    Opq => ()
    _ => fail("expected Opq")
  }
  assert_true(ops.exists(fn(op) { op is OpS }))
}

///|
test "parse_operators roundtrips stream_of_ops" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let ops_in : Array[@pdfops.Op] = [Opq, Opw(2.0), OpQ]
  let stream = @pdfops.Op::stream_of_ops(ops_in)
  let ops = @pdfops.Op::parse_operators(pdf, resources, [stream])
  assert_true(ops.length() >= 3)
  match ops[0] {
    Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    Opw(value) => assert_eq(value, 2.0)
    _ => fail("expected Opw")
  }
  match ops[2] {
    OpQ => ()
    _ => fail("expected OpQ")
  }
}

///|
test "parse_stream concatenates multiple streams" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let ops = @pdfops.Op::parse_stream(pdf, resources, [
    @pdfio.bytes_of_string("q"),
    @pdfio.bytes_of_string("Q"),
  ])
  assert_true(ops.length() >= 2)
  match ops[0] {
    Opq => ()
    _ => fail("expected Opq")
  }
  match ops[1] {
    OpQ => ()
    _ => fail("expected OpQ")
  }
}

///|
test "parse_operators handles diverse ops" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let ops : Array[@pdfops.Op] = [
    Opw(2.0),
    OpJ(1),
    Opj(2),
    OpM(10.0),
    Opd([1.0, 2.0], 0.5),
    Opri("/RelativeColorimetric"),
    Opi(1),
    Opgs("/GS1"),
    Opq,
    OpQ,
    Opcm(@pdftransform.TransformMatrix::{
      a: 1.0,
      b: 0.0,
      c: 0.0,
      d: 1.0,
      e: 10.0,
      f: 20.0,
    }),
    Opm(10.0, 20.0),
    Opl(30.0, 40.0),
    Opc(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    Opv(1.0, 2.0, 3.0, 4.0),
    Opy(1.0, 2.0, 3.0, 4.0),
    Oph,
    Opre(0.1, 0.2, 0.3, 0.4),
    OpS,
    Ops,
    Opf,
    OpF,
    OpfStar,
    OpB,
    OpBStar,
    Opb,
    OpbStar,
    Opn,
    OpW,
    OpWStar,
    OpBT,
    OpET,
    OpTc(1.0),
    OpTw(2.0),
    OpTz(120.0),
    OpTL(14.0),
    OpTf("/F1", 12.0),
    OpTr(1),
    OpTs(3.0),
    OpTd(10.0, 20.0),
    OpTD(10.0, 20.0),
    OpTm(@pdftransform.TransformMatrix::{
      a: 1.0,
      b: 0.0,
      c: 0.0,
      d: 1.0,
      e: 0.0,
      f: 0.0,
    }),
    OpTStar,
    OpTj("Hello"),
    OpTJ(Array([String("A"), Integer(-120), String("B")])),
    OpSingleQuote("World"),
    OpDoubleQuote(1.0, 2.0, "Quote"),
    Opd0(0.0, 1.0),
    Opd1(0.0, 0.0, 1.0, 1.0, 2.0, 2.0),
    OpCS("/DeviceRGB"),
    Opcs("/DeviceCMYK"),
    OpSC([0.1, 0.2, 0.3]),
    Opsc([0.1, 0.2, 0.3]),
    OpSCN([0.2, 0.4, 0.6]),
    Opscn([0.2, 0.4, 0.6]),
    OpSCNName("/Pattern", [0.1]),
    OpscnName("/Pattern", [0.2]),
    OpG(0.5),
    Opg(0.6),
    OpRG(0.1, 0.2, 0.3),
    Oprg(0.4, 0.5, 0.6),
    OpK(0.1, 0.2, 0.3, 0.4),
    Opk(0.2, 0.3, 0.4, 0.5),
    Opsh("/Sh1"),
    OpDo("/X1"),
    OpMP("/Tag"),
    OpDP("/Tag", Dictionary([("/K", Integer(1))])),
    OpBMC("/Span"),
    OpBDC("/Span", Dictionary([("/Lang", String("en"))])),
    OpEMC,
    OpBX,
    OpEX,
  ]
  let rendered = @pdfops.Op::string_of_ops(ops)
  assert_true(rendered.contains("TJ"))
  let stream = @pdfops.Op::stream_of_ops(ops)
  let parsed = @pdfops.Op::parse_operators(pdf, resources, [stream])
  assert_true(parsed.exists(fn(op : @pdfops.Op) { op is OpTJ(_) }))
  assert_true(parsed.exists(fn(op : @pdfops.Op) { op is OpSCNName(_, _) }))
  assert_true(parsed.exists(fn(op : @pdfops.Op) { op is OpBDC(_, _) }))
  assert_true(parsed.exists(fn(op : @pdfops.Op) { op is OpDo(_) }))
}

///|
test "string_of_ops renders inline image" {
  let inline_dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
  ])
  let inline_data = @pdfio.bytes_of_list([128])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((inline_dict, None, inline_data)),
  ])
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("ID"))
  assert_true(rendered.contains("EI"))
}

///|
test "parse_single_stream returns OpUnknown for bad ops" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("1 2 ZZ")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}
