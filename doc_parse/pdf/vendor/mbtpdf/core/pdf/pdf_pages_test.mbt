///|
test "page_reference_numbers variants" {
  let base1 = Pdf::empty()
  let pages_kid_non_indirect = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Pages"))),
    ("/Kids", PdfObject::Array([PdfObject::Integer(1)])),
  ])
  let catalog1 = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Catalog"))),
    ("/Pages", PdfObject::Indirect(1)),
  ])
  base1.addobj_given_num((1, pages_kid_non_indirect))
  base1.addobj_given_num((2, catalog1))
  let pdf1 = Pdf::{
    major: base1.major,
    minor: base1.minor,
    root: 2,
    objects: base1.objects,
    trailerdict: PdfObject::Dictionary([("/Root", PdfObject::Indirect(2))]),
    was_linearized: base1.was_linearized,
    saved_encryption: base1.saved_encryption,
  }
  assert_eq(pdf1.page_reference_numbers().length(), 0)
  let base2 = Pdf::empty()
  let pages_kid_not_array = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Pages"))),
    ("/Kids", PdfObject::Integer(9)),
  ])
  let catalog2 = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Catalog"))),
    ("/Pages", PdfObject::Indirect(1)),
  ])
  base2.addobj_given_num((1, pages_kid_not_array))
  base2.addobj_given_num((2, catalog2))
  let pdf2 = Pdf::{
    major: base2.major,
    minor: base2.minor,
    root: 2,
    objects: base2.objects,
    trailerdict: PdfObject::Dictionary([("/Root", PdfObject::Indirect(2))]),
    was_linearized: base2.was_linearized,
    saved_encryption: base2.saved_encryption,
  }
  assert_eq(pdf2.page_reference_numbers(), [-1])
  let base3 = Pdf::empty()
  let root_only = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Catalog"))),
  ])
  base3.addobj_given_num((1, root_only))
  let pdf3 = Pdf::{
    major: base3.major,
    minor: base3.minor,
    root: 1,
    objects: base3.objects,
    trailerdict: PdfObject::Dictionary([("/Root", PdfObject::Indirect(1))]),
    was_linearized: base3.was_linearized,
    saved_encryption: base3.saved_encryption,
  }
  assert_is_err(try? pdf3.page_reference_numbers())
}

///|
test "remove_unreferenced nullifies page refs" {
  let pdf = make_basic_pdf()
  let extra_page = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Page"))),
  ])
  pdf.addobj_given_num((4, extra_page))
  let stream = make_stream(
    PdfObject::Dictionary([("/Ref", PdfObject::Indirect(4))]),
    @pdfio.bytes_of_string("x"),
  )
  pdf.addobj_given_num((5, stream))
  pdf.addobj_given_num((6, PdfObject::Integer(7)))
  let catalog = pdf.lookup_obj(3)
  let catalog_with_stream = catalog.add_entry("/Stream", PdfObject::Indirect(5))
  let catalog_with_number = catalog_with_stream.add_entry(
    "/Number",
    PdfObject::Indirect(6),
  )
  pdf.addobj_given_num((3, catalog_with_number))
  pdf.remove_unreferenced()
  assert_true(!pdf.objnumbers().contains(4))
  match pdf.lookup_obj(5) {
    PdfObject::Stream(r) =>
      match r.val {
        (dict_obj, _) =>
          match dict_obj.lookup_immediate("/Ref") {
            Some(PdfObject::Null) => ()
            _ => fail("expected nullified ref")
          }
      }
    _ => fail("expected stream")
  }
}
