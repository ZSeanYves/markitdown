///|
fn pdf_of_pages_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn pdf_of_pages_make_pdf(count : Int) -> @pdf.Pdf raise {
  let rect = pdf_of_pages_rect()
  let pages = Array::new(capacity=count)
  for _ in 0..<count {
    pages.push(@pdfpage.Page::custom(rect))
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
}

///|
fn pdf_of_pages_with_bookmarks(count : Int) -> @pdf.Pdf raise {
  let pdf = pdf_of_pages_make_pdf(count)
  let refs = pdf.page_reference_numbers()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Root",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[0]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Child",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[1]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "Other",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[2]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
}

///|
test "pdf_of_pages rejects empty range" {
  let pdf = pdf_of_pages_make_pdf(1)
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages([],
  )
  match res {
    Err(_) => ()
    _ => fail("expected error for empty range")
  }
}

///|
test "pdf_of_pages errors on invalid page index" {
  let pdf = pdf_of_pages_make_pdf(2)
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages([
      3,
    ],
  )
  match res {
    Err(_) => ()
    _ => fail("expected invalid page error")
  }
}

///|
test "pdf_of_pages builds pagetree for many pages" {
  let pdf = pdf_of_pages_make_pdf(12)
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages([
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ])
  let root = subset.catalog_of_pdf()
  let pages = match subset.lookup_direct("/Pages", root) {
    Some(obj) => obj
    None => fail("expected /Pages")
  }
  match (subset.lookup_direct("/Type", pages) : @pdf.PdfObject?) {
    Some(Name(name)) if name.equal_string_bytes("/Pages") => ()
    _ => fail("expected /Type /Pages")
  }
  let count = match (subset.lookup_direct("/Count", pages) : @pdf.PdfObject?) {
    Some(Integer(n)) => n
    _ => fail("expected /Count")
  }
  assert_eq(count, 11)
}

///|
test "pdf_of_pages keeps bookmark prefix chain" {
  let pdf = pdf_of_pages_with_bookmarks(3)
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages([2])
  let marks = @pdfmarks.PdfMarks::new(subset).read_bookmarks()
  assert_eq(marks.length(), 2)
  assert_eq(marks[0].text, "Root")
  assert_eq(marks[1].text, "Child")
}

///|
test "pdf_of_pages retains page labels when requested" {
  let pdf = pdf_of_pages_make_pdf(3)
  let labels = [
    @pdfpagelabels.PageLabel::{
      labelstyle: @pdfpagelabels.LabelStyle::DecimalArabic,
      labelprefix: Some("A"),
      startpage: 1,
      startvalue: 1,
    },
  ]
  @pdfpagelabels.PageLabel::write_all(labels, pdf)
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(
    [1, 2],
    retain_numbering=true,
  )
  let read_back = @pdfpagelabels.PageLabel::read_all(subset)
  assert_true(read_back.length() > 0)
}

///|
test "pdf_of_pages trims structure tree" {
  let pdf = pdf_of_pages_make_pdf(2)
  let struct_tree : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/StructTreeRoot"))),
  ])
  let struct_num = pdf.addobj(struct_tree)
  let root = pdf.catalog_of_pdf()
  let updated_root = root.add_entry("/StructTreeRoot", Indirect(struct_num))
  pdf.addobj_given_num((pdf.root, updated_root))
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(
    [1],
    process_struct_tree=true,
  )
  let root2 = subset.catalog_of_pdf()
  match subset.lookup_direct("/StructTreeRoot", root2) {
    Some(_) => ()
    None => fail("expected StructTreeRoot to remain")
  }
}

///|
test "pdf_of_pages fails without root" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[@pdf.Pdf, Error] = try? @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages([
      1,
    ],
  )
  match res {
    Err(_) => ()
    _ => fail("expected missing /Root error")
  }
}

///|
test "endpage_fast handles missing count" {
  let pdf0 = @pdf.Pdf::empty()
  let rect = pdf_of_pages_rect()
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/MediaBox", rect),
  ])
  let page_num = pdf0.addobj(page)
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(page_num)])),
  ])
  let pages_num = pdf0.addobj(pages)
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_num, [])
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).endpage_fast(), 0)
}
