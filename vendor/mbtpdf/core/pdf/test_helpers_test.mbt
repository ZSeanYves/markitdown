///|
fn[T] assert_is_err(result : Result[T, Error]) -> Unit raise {
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn make_stream(
  dict : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
) -> @pdf.PdfObject {
  @pdf.PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(data))))
}

///|
fn assert_integer(obj : @pdf.PdfObject, expected : Int) -> Unit raise {
  match obj {
    @pdf.PdfObject::Integer(value) => assert_eq(value, expected)
    _ => fail("expected integer")
  }
}

///|
fn assert_some_integer(obj : @pdf.PdfObject?, expected : Int) -> Unit raise {
  match obj {
    Some(@pdf.PdfObject::Integer(value)) => assert_eq(value, expected)
    Some(_) => fail("expected integer")
    None => fail("expected some")
  }
}

///|
fn make_basic_pdf() -> @pdf.Pdf {
  let base = @pdf.Pdf::empty()
  let pages = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name(PdfName::of_string("/Pages"))),
    ("/Kids", @pdf.PdfObject::Array([@pdf.PdfObject::Indirect(2)])),
  ])
  let page = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name(PdfName::of_string("/Page"))),
  ])
  let catalog = @pdf.PdfObject::Dictionary([
    ("/Type", @pdf.PdfObject::Name(PdfName::of_string("/Catalog"))),
    ("/Pages", @pdf.PdfObject::Indirect(1)),
  ])
  base.addobj_given_num((1, pages))
  base.addobj_given_num((2, page))
  base.addobj_given_num((3, catalog))
  @pdf.Pdf::{
    major: base.major,
    minor: base.minor,
    root: 3,
    objects: base.objects,
    trailerdict: @pdf.PdfObject::Dictionary([
      ("/Root", @pdf.PdfObject::Indirect(3)),
    ]),
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
}
