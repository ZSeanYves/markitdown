///|
test "string_of_ops handles comments and inline filters" {
  let old = write_comments.val
  write_comments.val = true
  let dict_filter_array : @pdf.PdfObject = Dictionary([
    ("/Filter", Array([Name(@pdf.PdfName::of_string("/ASCII85Decode"))])),
  ])
  let dict_filter_name : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
  ])
  let bytes = @pdfio.bytes_of_list([0x61, 0x62])
  let rendered = Op::string_of_ops([
    Op::OpComment("note"),
    Op::InlineImage((dict_filter_array, None, bytes)),
    Op::InlineImage((dict_filter_name, None, bytes)),
    Op::Opq,
  ])
  write_comments.val = old
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("EI"))
  assert_true(rendered.contains("q"))
}

///|
test "string_of_op delegates to string_of_ops" {
  let rendered = Op::OpQ.to_string()
  assert_true(rendered.contains("Q"))
}

///|
test "parse_single_stream ignores comments and yields unknown" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("%c\ntrue false ZZ q Q")
    let ops = Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : Op) { op is OpUnknown(_) }))
    assert_true(ops.exists(fn(op : Op) { op is Opq }))
    assert_true(ops.exists(fn(op : Op) { op is OpQ }))
  })
}

///|
test "components handles extra branches and errors" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    assert_eq(
      Op::components(pdf, resources, Name(@pdf.PdfName::of_string("/CalCMYK"))),
      4,
    )
    assert_eq(
      Op::components(
        pdf,
        resources,
        Array([Name(@pdf.PdfName::of_string("/Lab")), Dictionary([])]),
      ),
      3,
    )
    assert_eq(
      Op::components(
        pdf,
        resources,
        Array([
          Name(@pdf.PdfName::of_string("/Indexed")),
          Name(@pdf.PdfName::of_string("/DeviceRGB")),
          Integer(0),
          String(""),
        ]),
      ),
      1,
    )
    let missing_dict : Result[Int, Error] = try? Op::components(
      pdf,
      resources,
      Name(@pdf.PdfName::of_string("/MyCS")),
    )
    assert_true(missing_dict is Err(_))
    let resources_empty : @pdf.PdfObject = Dictionary([
      ("/ColorSpace", Dictionary([])),
    ])
    let missing_entry : Result[Int, Error] = try? Op::components(
      pdf,
      resources_empty,
      Name(@pdf.PdfName::of_string("/MyCS")),
    )
    assert_true(missing_entry is Err(_))
    let bad_icc : Result[Int, Error] = try? Op::components(
      pdf,
      resources,
      Array([Name(@pdf.PdfName::of_string("/ICCBased")), Dictionary([])]),
    )
    assert_true(bad_icc is Err(_))
    let bad_device_n : Result[Int, Error] = try? Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/DeviceN")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
      ]),
    )
    assert_true(bad_device_n is Err(_))
    let bad_other : Result[Int, Error] = try? Op::components(
      pdf,
      resources,
      Integer(1),
    )
    assert_true(bad_other is Err(_))
    ()
  })
}

///|
test "components handles /I alias" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  assert_eq(
    Op::components(
      pdf,
      resources,
      Array([
        Name(@pdf.PdfName::of_string("/I")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
      ]),
    ),
    1,
  )
}

///|
test "components errors on array without name leader" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Int, Error] = try? Op::components(
      pdf,
      resources,
      Array([Integer(1), Name(@pdf.PdfName::of_string("/DeviceRGB"))]),
    )
    assert_true(res is Err(_))
    ()
  })
}

///|
test "string_of_ops covers operator variants" {
  let ops : Array[Op] = [
    Opw(1.5),
    OpJ(1),
    Opj(2),
    OpM(3.0),
    Opd([1.0, 2.0], 0.5),
    Opri("/RelColorimetric"),
    Opi(10),
    Opgs("/GS1"),
    Opq,
    OpQ,
    Opcm(@pdftransform.TransformMatrix::identity()),
    Opm(0.0, 1.0),
    Opl(1.0, 2.0),
    Opc(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    Opv(1.0, 2.0, 3.0, 4.0),
    Opy(1.0, 2.0, 3.0, 4.0),
    Oph,
    Opre(0.0, 0.0, 10.0, 10.0),
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
    OpTz(100.0),
    OpTL(12.0),
    OpTf("/F1", 10.0),
    OpTr(1),
    OpTs(0.5),
    OpTd(10.0, 20.0),
    OpTD(5.0, 6.0),
    OpTm(@pdftransform.TransformMatrix::identity()),
    OpTStar,
    OpTj("Hi"),
    OpTJ(Array([String("A"), Real(-10.0), String("B")])),
    OpSingleQuote("A"),
    OpDoubleQuote(0.1, 0.2, "B"),
    Opd0(0.0, 0.0),
    Opd1(1.0, 2.0, 3.0, 4.0, 5.0, 6.0),
    OpCS("/DeviceRGB"),
    Opcs("/DeviceCMYK"),
    OpSC([1.0, 0.0, 0.0]),
    Opsc([0.1, 0.2, 0.3]),
    OpSCN([0.1, 0.2]),
    Opscn([0.3, 0.4]),
    OpSCNName("/Pattern", [0.1, 0.2]),
    OpscnName("/Pattern", [0.3]),
    OpG(0.0),
    Opg(0.5),
    OpRG(1.0, 0.0, 0.0),
    Oprg(0.0, 1.0, 0.0),
    OpK(0.0, 0.0, 0.0, 1.0),
    Opk(0.0, 0.0, 0.0, 0.0),
    Opsh("/Sh1"),
    OpDo("/X1"),
    OpMP("/Tag"),
    OpDP("/Tag", Dictionary([])),
    OpBMC("/Span"),
    OpBDC("/Span", Dictionary([])),
    OpEMC,
    OpBX,
    OpEX,
    OpUnknown("ZZ"),
    OpComment("note"),
  ]
  let rendered = Op::string_of_ops(ops)
  assert_true(rendered.contains("q"))
  assert_true(rendered.contains("cm"))
  assert_true(rendered.contains("TJ"))
  assert_true(rendered.contains("BDC"))
}
