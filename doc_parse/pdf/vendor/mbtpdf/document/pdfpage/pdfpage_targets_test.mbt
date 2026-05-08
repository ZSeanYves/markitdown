///|
test "pagenumber_of_target handles non-page targets" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(
      @pdfdest.Destination::NullDestination,
    ),
    0,
  )
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(
      @pdfdest.Destination::NamedDestination(@pdf.PdfName::of_string("/Name")),
    ),
    0,
  )
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(
      @pdfdest.Destination::StringDestination("Name"),
    ),
    0,
  )
}

///|
test "pagenumber_of_target follows GoTo action and fastrefnums" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let refs = pdf.page_reference_numbers()
  let dest_array : @pdf.PdfObject = Array([
    Indirect(refs[0]),
    Name(@pdf.PdfName::of_string("/Fit")),
  ])
  let action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", dest_array),
  ])
  let table : Map[Int, Int] = Map::new()
  table.set(refs[0], 7)
  let dest = @pdfdest.Destination::Action(action)
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(dest, fastrefnums=table),
    7,
  )
}

///|
test "pagenumber_of_target handles action edge cases" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let action_missing : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
  ])
  let action_other : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/URI"))),
  ])
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(
      @pdfdest.Destination::Action(action_missing),
    ),
    0,
  )
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(
      @pdfdest.Destination::Action(action_other),
    ),
    0,
  )
}

///|
test "pagenumber_of_target follows GoTo action without fastrefnums" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let refs = pdf.page_reference_numbers()
  let dest_array : @pdf.PdfObject = Array([
    Indirect(refs[0]),
    Name(@pdf.PdfName::of_string("/Fit")),
  ])
  let action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", dest_array),
  ])
  let dest = @pdfdest.Destination::Action(action)
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(dest), 1)
}

///|
test "pagenumber_of_target handles target page variants" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let other = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::OtherDocPageNumber(2),
  )
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(other), 3)
  let refs = pdf.page_reference_numbers()
  let dest = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(refs[0]))
  let table : Map[Int, Int] = Map::new()
  table.set(refs[0] + 100, 9)
  assert_eq(
    @pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(dest, fastrefnums=table),
    0,
  )
  let missing = @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(9999))
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pagenumber_of_target(missing), 0)
}

///|
test "page_object_number and target_of_pagenumber handle out of range" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
    Some(_) => ()
    _ => fail("expected page object number")
  }
  match @pdfpage.PdfPageDoc::new(pdf).page_object_number(0) {
    None => ()
    _ => fail("expected None for page 0")
  }
  match @pdfpage.PdfPageDoc::new(pdf).page_object_number(2) {
    None => ()
    _ => fail("expected None for page 2")
  }
  match @pdfpage.PdfPageDoc::new(pdf).target_of_pagenumber(2) {
    @pdfdest.Destination::NullDestination => ()
    _ => fail("expected NullDestination")
  }
}
