///|
fn dest_contract_close(a : Double, b : Double) -> Unit raise {
  assert_true((a - b).abs() < 0.000001)
}

///|
fn dest_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
fn dest_contract_rect() -> @pdf.PdfObject {
  Array([Integer(0), Integer(0), Integer(100), Integer(100)])
}

///|
fn dest_contract_pdf_with_page() -> @pdf.Pdf raise {
  let pdf = @pdf.Pdf::empty()
  let pages_root_num = pdf.addobj(
    Dictionary([
      ("/Type", dest_contract_name("/Pages")),
      ("/Kids", Array([])),
      ("/Count", Integer(1)),
    ]),
  )
  let page_num = pdf.addobj(
    Dictionary([
      ("/Type", dest_contract_name("/Page")),
      ("/Parent", Indirect(pages_root_num)),
      ("/MediaBox", dest_contract_rect()),
    ]),
  )
  pdf.addobj_given_num(
    (
      pages_root_num,
      Dictionary([
        ("/Type", dest_contract_name("/Pages")),
        ("/Kids", Array([Indirect(page_num)])),
        ("/Count", Integer(1)),
      ]),
    ),
  )
  let catalog_num = pdf.addobj(
    Dictionary([
      ("/Type", dest_contract_name("/Catalog")),
      ("/Pages", Indirect(pages_root_num)),
    ]),
  )
  let trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(catalog_num))
  {
    major: pdf.major,
    minor: pdf.minor,
    root: catalog_num,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
test "destination contract reads explicit array variants" {
  let pdf = @pdf.Pdf::empty()
  let xyz : @pdf.PdfObject = Array([
    Indirect(11),
    dest_contract_name("/XYZ"),
    Real(12.0),
    Null,
    Real(1.5),
  ])
  match Destination::read(pdf, xyz, shallow=true) {
    Destination::XYZ(TargetPage::PageObject(11), Some(left), None, Some(zoom)) => {
      dest_contract_close(left, 12.0)
      dest_contract_close(zoom, 1.5)
    }
    _ => fail("expected XYZ destination")
  }
  let fit : @pdf.PdfObject = Array([Indirect(12), dest_contract_name("/Fit")])
  match Destination::read(pdf, fit, shallow=true) {
    Destination::Fit(TargetPage::PageObject(12)) => ()
    _ => fail("expected Fit destination")
  }
  let fith : @pdf.PdfObject = Array([
    Indirect(13),
    dest_contract_name("/FitH"),
    Real(44.0),
  ])
  match Destination::read(pdf, fith, shallow=true) {
    Destination::FitH(TargetPage::PageObject(13), Some(top)) =>
      dest_contract_close(top, 44.0)
    _ => fail("expected FitH destination")
  }
  let fitv : @pdf.PdfObject = Array([
    Indirect(14),
    dest_contract_name("/FitV"),
    Real(55.0),
  ])
  match Destination::read(pdf, fitv, shallow=true) {
    Destination::FitV(TargetPage::PageObject(14), Some(left)) =>
      dest_contract_close(left, 55.0)
    _ => fail("expected FitV destination")
  }
}

///|
test "destination contract resolves named string and action destinations" {
  let pdf = dest_contract_pdf_with_page()
  let page_ref = pdf.page_reference_numbers()[0]
  let named_dest : @pdf.PdfObject = Array([
    Indirect(page_ref),
    dest_contract_name("/Fit"),
  ])
  let string_dest : @pdf.PdfObject = Array([
    Indirect(page_ref),
    dest_contract_name("/FitV"),
    Real(42.0),
  ])
  let root = pdf.lookup_obj(pdf.root)
  let updated_root = root
    .add_entry("/Dests", Dictionary([("/Chapter1", named_dest)]))
    .add_entry(
      "/Names",
      Dictionary([
        (
          "/Dests",
          Dictionary([("/Names", Array([String("Anchor"), string_dest]))]),
        ),
      ]),
    )
  pdf.addobj_given_num((pdf.root, updated_root))
  match Destination::read(pdf, Name(@pdf.PdfName::of_string("/Chapter1"))) {
    Destination::Fit(TargetPage::PageObject(n)) => assert_eq(n, page_ref)
    _ => fail("expected named Fit destination")
  }
  match Destination::read(pdf, String("Anchor")) {
    Destination::FitV(TargetPage::PageObject(n), Some(left)) => {
      assert_eq(n, page_ref)
      dest_contract_close(left, 42.0)
    }
    _ => fail("expected string FitV destination")
  }
  let action : @pdf.PdfObject = Dictionary([
    ("/S", dest_contract_name("/GoTo")),
    ("/D", Array([Indirect(page_ref), dest_contract_name("/FitH"), Real(24.0)])),
  ])
  match Destination::read(pdf, action, shallow=true) {
    Destination::FitH(TargetPage::PageObject(n), Some(top)) => {
      assert_eq(n, page_ref)
      dest_contract_close(top, 24.0)
    }
    _ => fail("expected action /D FitH destination")
  }
}
