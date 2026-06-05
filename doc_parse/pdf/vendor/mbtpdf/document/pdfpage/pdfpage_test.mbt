///|
test "pagenumber_of_target on page object" {
  let pdf = PdfPageDoc::minimum_valid()
  let refs = pdf.page_reference_numbers()
  let dest = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(refs[0]))
  assert_eq(PdfPageDoc::new(pdf).pagenumber_of_target(dest), 1)
}

///|
test "ppstub returns identity matrix" {
  let (value, n, matrix) = ppstub((x, y) => x + y, 2, 3)
  assert_eq(value, 5)
  assert_eq(n, 2)
  assert_eq(
    matrix.to_string(),
    @pdftransform.TransformMatrix::identity().to_string(),
  )
}

///|
test "pages_of_pagetree_quick detects cycle" {
  let pdf0 = @pdf.Pdf::empty()
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(1)])),
  ])
  pdf0.addobj_given_num((1, pages))
  let pdf = PdfPageDoc::new(pdf0).add_root(1, [])
  let res : Result[Int, Error] = try? PdfPageDoc::new(pdf).pages_of_pagetree_quick()
  match res {
    Err(_) => ()
    _ => fail("expected cycle detection")
  }
}
