///|
fn build_minimal_pdf() -> @pdf.Pdf {
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
fn roundtrip(pdf : @pdf.Pdf) -> @pdf.Pdf raise {
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(None, false, pdf, output)
  let pdf_bytes = output.extract_bytes(buffer)
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="roundtrip")
  @pdfread.PdfRead::new().pdf_of_input(None, None, input)
}

///|
test "pdf roundtrip read/write/read" {
  let pdf1 = build_minimal_pdf()
  let pdf2 = roundtrip(pdf1)
  let pdf3 = roundtrip(pdf2)
  assert_eq(pdf2.objcard(), 4)
  assert_eq(pdf3.objcard(), 4)
  assert_eq(pdf2.root, 4)
  assert_eq(pdf3.root, 4)
}

///|
test "pdf roundtrip with xref stream" {
  let pdf1 = build_minimal_pdf()
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    None,
    false,
    pdf1,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let pdf_text = @pdfio.string_of_bytes(pdf_bytes)
  assert_true(pdf_text.contains("/Type /XRef"))
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="xref-stream")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
  assert_eq(parsed.objcard(), 4)
  assert_eq(parsed.root, 4)
}

///|
test "pdf roundtrip with generated object streams" {
  let pdf1 = build_minimal_pdf()
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    preserve_objstm=false,
    compress_objstm=true,
    None,
    false,
    pdf1,
    output,
  )
  let pdf_bytes = output.extract_bytes(buffer)
  let pdf_text = @pdfio.string_of_bytes(pdf_bytes)
  assert_true(pdf_text.contains("/ObjStm"))
  let input = @pdfio.Input::of_bytes(pdf_bytes, source="objstm")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
  assert_true(parsed.objects.object_stream_ids.length() > 0)
}

///|
test "pdf roundtrip with preserved object streams" {
  let pdf1 = build_minimal_pdf()
  let (output1, buffer1) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    generate_objstm=true,
    preserve_objstm=false,
    compress_objstm=true,
    None,
    false,
    pdf1,
    output1,
  )
  let bytes1 = output1.extract_bytes(buffer1)
  let input1 = @pdfio.Input::of_bytes(bytes1, source="objstm-preserve")
  let parsed = @pdfread.PdfRead::new().pdf_of_input(None, None, input1)
  let (output2, buffer2) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    false,
    parsed,
    output2,
  )
  let bytes2 = output2.extract_bytes(buffer2)
  let pdf_text = @pdfio.string_of_bytes(bytes2)
  assert_true(pdf_text.contains("/ObjStm"))
}
