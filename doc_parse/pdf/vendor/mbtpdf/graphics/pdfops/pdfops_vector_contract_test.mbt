///|
test "vector contract keeps path and graphics-state source attribution" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let direct_stream = @pdfops.Op::stream_of_ops([
    @pdfops.Op::Opq,
    @pdfops.Op::Opcm(@pdftransform.TransformMatrix::{
      a: 1.0,
      b: 0.0,
      c: 0.0,
      d: 1.0,
      e: 12.0,
      f: 24.0,
    }),
    @pdfops.Op::Opre(10.0, 20.0, 30.0, 40.0),
    @pdfops.Op::OpS,
  ])
  let indirect_stream = @pdfops.Op::stream_of_ops([
    @pdfops.Op::Opm(0.0, 0.0),
    @pdfops.Op::Opl(50.0, 50.0),
    @pdfops.Op::Opf,
    @pdfops.Op::OpQ,
  ])
  let indirect_ref = pdf.addobj(indirect_stream)
  let located = @pdfops.Op::parse_operators_with_source(pdf, resources, [
    direct_stream,
    Indirect(indirect_ref),
  ])
  assert_eq(located.length(), 8)
  match located[1].op {
    Opcm(matrix) => {
      assert_eq(matrix.e, 12.0)
      assert_eq(matrix.f, 24.0)
    }
    _ => fail("expected CTM operator")
  }
  match located[2].op {
    Opre(x, y, w, h) => {
      assert_eq(x, 10.0)
      assert_eq(y, 20.0)
      assert_eq(w, 30.0)
      assert_eq(h, 40.0)
    }
    _ => fail("expected rectangle operator")
  }
  match located[3].op {
    OpS => ()
    _ => fail("expected stroke operator")
  }
  match located[6].op {
    Opf => ()
    _ => fail("expected fill operator")
  }
  assert_eq(located[2].source_stream_index, 0)
  assert_eq(located[2].source_op_index, 2)
  assert_true(located[2].source_object_ref is None)
  assert_eq(located[6].source_stream_index, 1)
  assert_eq(located[6].source_op_index, 2)
  assert_true(located[6].source_object_ref == Some(indirect_ref))
}
