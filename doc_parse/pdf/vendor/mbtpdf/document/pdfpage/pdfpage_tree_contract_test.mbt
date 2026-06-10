///|
fn tree_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
fn tree_contract_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @pdf.PdfObject {
  Array([Real(x0), Real(y0), Real(x1), Real(y1)])
}

///|
fn tree_contract_close(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < 0.000001)
}

///|
fn tree_contract_assert_rect(
  pdf : @pdf.Pdf,
  rect : @pdf.PdfObject,
  expected : (Double, Double, Double, Double),
) -> Unit raise {
  let (x0, y0, x1, y1) = pdf.parse_rectangle(rect)
  tree_contract_close(x0, expected.0)
  tree_contract_close(y0, expected.1)
  tree_contract_close(x1, expected.2)
  tree_contract_close(y1, expected.3)
}

///|
fn tree_contract_assert_marker(
  page : @pdfpage.Page,
  marker : Int,
) -> Unit raise {
  match page.rest.lookup_immediate("/Marker") {
    Some(Integer(value)) => assert_eq(value, marker)
    _ => fail("expected page marker")
  }
}

///|
fn tree_contract_assert_xobject_ref(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  key : String,
  expected : Int,
) -> Unit raise {
  let xobjects = match pdf.lookup_direct("/XObject", resources) {
    Some(Dictionary(_) as obj) => obj
    _ => fail("expected /XObject resources")
  }
  match xobjects.lookup_immediate(key) {
    Some(Indirect(objnum)) => assert_eq(objnum, expected)
    _ => fail("expected xobject resource reference")
  }
}

///|
fn tree_contract_form(pdf : @pdf.Pdf) -> Int {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Type", tree_contract_name("/XObject")),
    ("/Subtype", tree_contract_name("/Form")),
    ("/BBox", tree_contract_rect(0.0, 0.0, 10.0, 10.0)),
  ])
  pdf.addobj(Stream(Ref((dict, @pdf.Stream::Got(@pdfio.mkbytes(0))))))
}

///|
test "page tree contract preserves nested order and inherited facts" {
  let pdf0 = @pdf.Pdf::empty()
  let root_form_num = tree_contract_form(pdf0)
  let branch_form_num = tree_contract_form(pdf0)
  let root_resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/FmRoot", Indirect(root_form_num))])),
  ])
  let branch_resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/FmBranch", Indirect(branch_form_num))])),
  ])
  let root_media = tree_contract_rect(0.0, 0.0, 300.0, 300.0)
  let root_crop = tree_contract_rect(5.0, 5.0, 295.0, 295.0)
  let branch_media = tree_contract_rect(0.0, 0.0, 200.0, 100.0)
  let branch_crop = tree_contract_rect(10.0, 15.0, 190.0, 90.0)
  let page3_media = tree_contract_rect(0.0, 0.0, 120.0, 80.0)
  let page1_num = pdf0.addobj(
    Dictionary([("/Type", tree_contract_name("/Page")), ("/Marker", Integer(1))]),
  )
  let page2_num = pdf0.addobj(
    Dictionary([("/Type", tree_contract_name("/Page")), ("/Marker", Integer(2))]),
  )
  let page3_num = pdf0.addobj(
    Dictionary([
      ("/Type", tree_contract_name("/Page")),
      ("/MediaBox", page3_media),
      ("/Rotate", Integer(270)),
      ("/Marker", Integer(3)),
    ]),
  )
  let branch_num = pdf0.addobj(
    Dictionary([
      ("/Type", tree_contract_name("/Pages")),
      ("/Kids", Array([Indirect(page2_num)])),
      ("/Count", Integer(1)),
      ("/MediaBox", branch_media),
      ("/CropBox", branch_crop),
      ("/Rotate", Integer(90)),
      ("/Resources", branch_resources),
    ]),
  )
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", tree_contract_name("/Pages")),
      (
        "/Kids",
        Array([Indirect(page1_num), Indirect(branch_num), Indirect(page3_num)]),
      ),
      ("/Count", Integer(3)),
      ("/MediaBox", root_media),
      ("/CropBox", root_crop),
      ("/Rotate", Integer(180)),
      ("/Resources", root_resources),
    ]),
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, [])
  let doc = @pdfpage.PdfPageDoc::new(pdf)
  let pages = doc.pages_of_pagetree()
  assert_eq(pages.length(), 3)
  assert_eq(doc.endpage(), 3)
  assert_eq(doc.endpage_fast(), 3)
  tree_contract_assert_marker(pages[0], 1)
  tree_contract_assert_marker(pages[1], 2)
  tree_contract_assert_marker(pages[2], 3)
  tree_contract_assert_rect(pdf, pages[0].mediabox, (0.0, 0.0, 300.0, 300.0))
  tree_contract_assert_rect(pdf, pages[1].mediabox, (0.0, 0.0, 200.0, 100.0))
  tree_contract_assert_rect(pdf, pages[2].mediabox, (0.0, 0.0, 120.0, 80.0))
  match pages[0].cropbox {
    Some(rect) => tree_contract_assert_rect(pdf, rect, (5.0, 5.0, 295.0, 295.0))
    None => fail("expected root cropbox")
  }
  match pages[1].cropbox {
    Some(rect) =>
      tree_contract_assert_rect(pdf, rect, (10.0, 15.0, 190.0, 90.0))
    None => fail("expected branch cropbox")
  }
  match (pages[0].rotate : @pdfpage.Rotation) {
    Rotate180 => ()
    _ => fail("expected root rotation")
  }
  match (pages[1].rotate : @pdfpage.Rotation) {
    Rotate90 => ()
    _ => fail("expected branch rotation")
  }
  match (pages[2].rotate : @pdfpage.Rotation) {
    Rotate270 => ()
    _ => fail("expected page rotation")
  }
  tree_contract_assert_xobject_ref(
    pdf,
    pages[0].resources,
    "/FmRoot",
    root_form_num,
  )
  tree_contract_assert_xobject_ref(
    pdf,
    pages[1].resources,
    "/FmBranch",
    branch_form_num,
  )
}

///|
test "page tree contract fails closed on missing page child" {
  let pdf0 = @pdf.Pdf::empty()
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", tree_contract_name("/Pages")),
      ("/Kids", Array([Indirect(999999)])),
      ("/Count", Integer(1)),
    ]),
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, [])
  let result : Result[Array[@pdfpage.Page], Error] = try
    @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree() |> Ok
  catch {
    err => Err(err)
  }
  assert_true(result is Err(_))
}
