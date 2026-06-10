///|
test "replacement contract: parse_operators_with_source keeps stream attribution" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let direct_stream = @pdfops.Op::stream_of_ops([
    @pdfops.Op::Opq,
    @pdfops.Op::Opw(2.0),
  ])
  let indirect_stream = @pdfops.Op::stream_of_ops([
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTj("Hi"),
    @pdfops.Op::OpET,
  ])
  let indirect_ref = pdf.addobj(indirect_stream)
  let located = @pdfops.Op::parse_operators_with_source(pdf, resources, [
    direct_stream,
    @pdf.PdfObject::Indirect(indirect_ref),
  ])
  assert_eq(located.length(), 5)
  match located[0].op {
    Opq => ()
    _ => fail("expected first op from direct stream")
  }
  assert_eq(located[0].source_stream_index, 0)
  assert_eq(located[0].source_op_index, 0)
  assert_true(located[0].source_object_ref is None)
  match located[1].op {
    Opw(value) => assert_eq(value, 2.0)
    _ => fail("expected second op from direct stream")
  }
  assert_eq(located[1].source_stream_index, 0)
  assert_eq(located[1].source_op_index, 1)
  assert_true(located[1].source_object_ref is None)
  match located[3].op {
    OpTj(text) => assert_eq(text, "Hi")
    _ => fail("expected text-show op from indirect stream")
  }
  assert_eq(located[3].source_stream_index, 1)
  assert_eq(located[3].source_op_index, 1)
  assert_true(located[3].source_object_ref == Some(indirect_ref))
}
