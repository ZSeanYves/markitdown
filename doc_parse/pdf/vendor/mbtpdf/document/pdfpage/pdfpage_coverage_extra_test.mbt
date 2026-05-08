///|
fn coverage_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn make_pdf_with_pages(count : Int) -> @pdf.Pdf raise {
  let rect = coverage_rect()
  let pages : Array[@pdfpage.Page] = []
  for _ in 0..<count {
    pages.push(@pdfpage.Page::custom(rect))
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
}

///|
test "rotation conversions cover remaining variants" {
  assert_eq(@pdfpage.Rotation::Rotate180.to_int(), 180)
  assert_eq(@pdfpage.Rotation::Rotate270.to_int(), 270)
  match (@pdfpage.Rotation::from_int(270) : @pdfpage.Rotation) {
    Rotate270 => ()
    _ => fail("expected Rotate270")
  }
  match (@pdfpage.Rotation::from_int(-90) : @pdfpage.Rotation) {
    Rotate270 => ()
    _ => fail("expected Rotate270 for -90")
  }
}

///|
test "pages_of_pagetree returns empty when /Pages resolves to Null" {
  let pdf0 = @pdf.Pdf::empty()
  let null_pages = pdf0.addobj(Null)
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(null_pages, [])
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  assert_eq(pages.length(), 0)
}

///|
test "pages_of_pagetree treats stream /Contents as singleton array" {
  let pdf0 = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("q Q")
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream_num = pdf0.addobj(
    Stream(Ref::new((stream_dict, @pdf.Stream::Got(data)))),
  )
  let page_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
      ("/MediaBox", coverage_rect()),
      ("/Rotate", Integer(180)),
      ("/Contents", Indirect(stream_num)),
      ("/Resources", Dictionary([])),
    ]),
  )
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([Indirect(page_num)])),
      ("/Count", Integer(1)),
    ]),
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, [])
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].content.length(), 1)
  match (pages[0].rotate : @pdfpage.Rotation) {
    Rotate180 => ()
    _ => fail("expected Rotate180")
  }
}

///|
test "pdf_of_pages builds branched page tree for large selections" {
  let pdf = make_pdf_with_pages(30)
  let range : Array[Int] = []
  for i in 1..<=30 {
    range.push(i)
  }
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(range)
  let root = subset.catalog_of_pdf()
  let pages = match subset.lookup_direct("/Pages", root) {
    Some(obj) => obj
    None => fail("expected /Pages")
  }
  let count = match (subset.lookup_direct("/Count", pages) : @pdf.PdfObject?) {
    Some(Integer(n)) => n
    _ => fail("expected /Count")
  }
  assert_eq(count, 30)
}

///|
test "pdf_of_pages drops page labels when retain_numbering is false" {
  let pdf = make_pdf_with_pages(3)
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
    retain_numbering=false,
  )
  let read_back = @pdfpagelabels.PageLabel::read_all(subset)
  assert_eq(read_back.length(), 0)
}
