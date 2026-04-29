///|
fn ops_sample_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn ops_page_with_ops(ops : Array[@pdfops.Op]) -> @pdfpage.Page raise {
  {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: ops_sample_rect(),
    resources: Dictionary([]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
}

///|
test "prepend_operators fast path inserts ops" {
  let pdf = @pdf.Pdf::empty()
  let base_ops : Array[@pdfops.Op] = [Opq, OpQ]
  let page = ops_page_with_ops(base_ops)
  let updated = page.prepend_operators(pdf, [Opw(2.0)], fast=true)
  let ops = @pdfops.Op::parse_operators(pdf, updated.resources, updated.content)
  match (ops[0] : @pdfops.Op) {
    Opw(2.0) => ()
    _ => fail("expected prepended op")
  }
}

///|
test "postpend_operators fast path wraps ops" {
  let pdf = @pdf.Pdf::empty()
  let base_ops : Array[@pdfops.Op] = [OpBT, OpET]
  let page = ops_page_with_ops(base_ops)
  let updated = page.postpend_operators(pdf, [Opw(3.0)], fast=true)
  let ops = @pdfops.Op::parse_operators(pdf, updated.resources, updated.content)
  let len = ops.length()
  match ((ops[len - 3], ops[len - 2], ops[len - 1]) : (@pdfops.Op, _, _)) {
    (Opq, Opw(3.0), OpQ) => ()
    _ => fail("expected wrapped ops at end")
  }
}

///|
test "postpend_operators handles empty content" {
  let pdf = @pdf.Pdf::empty()
  let page = @pdfpage.Page::custom(ops_sample_rect())
  let updated = page.postpend_operators(pdf, [Opw(1.0)])
  let ops = @pdfops.Op::parse_operators(pdf, updated.resources, updated.content)
  match (ops : Array[@pdfops.Op]) {
    [Opw(1.0)] => ()
    _ => fail("expected single op")
  }
}

///|
test "protect adds missing Q operators" {
  let fixed = @pdfe.with_logger(_ => (), fn() {
    @pdfpage.Page::protect_ops([Opq, Opq])
  })
  assert_eq(fixed.length(), 2)
  match (fixed : Array[@pdfops.Op]) {
    [OpQ, OpQ] => ()
    _ => fail("expected OpQ fixes")
  }
}
