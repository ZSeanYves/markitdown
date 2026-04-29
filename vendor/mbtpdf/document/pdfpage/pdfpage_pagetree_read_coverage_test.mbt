///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
fn dict_entries_has_int(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
  value : Int,
) -> Bool {
  entries[:].any(fn(entry) {
    match entry {
      (k, Integer(i)) => k == key && i == value
      _ => false
    }
  })
}

///|
fn dict_entries_has_key(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
) -> Bool {
  entries[:].any(fn(entry) {
    match entry {
      (k, _) => k == key
    }
  })
}

///|
fn sample_rect() -> @pdf.PdfObject {
  Array([Integer(0), Integer(0), Integer(100), Integer(100)])
}

///|
fn empty_stream(pdf : @pdf.Pdf) -> Int {
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(0))])
  pdf.addobj(Stream(Ref::new((dict, @pdf.Stream::Got(@pdfio.mkbytes(0))))))
}

///|
test "pages_of_pagetree reads inherited resources and contents shapes" {
  let pdf0 = @pdf.Pdf::empty()
  let stream_num = empty_stream(pdf0)

  // /Contents -> indirect array -> [stream, int] (int should be ignored with a log).
  let contents_array_num = pdf0.addobj(
    Array([Indirect(stream_num), Integer(0)]),
  )

  // /Contents -> indirect non-array -> should be treated as a singleton array.
  let bad_contents_num = pdf0.addobj(Integer(0))
  let resources_parent : @pdf.PdfObject = Dictionary([("/Font", Dictionary([]))])
  let page1_dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/MediaBox", sample_rect()),
    ("/Contents", Indirect(contents_array_num)),
    ("/Extra", Integer(1)),
  ])
  let page2_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
      ("/Contents", Indirect(bad_contents_num)),
      ("/Extra2", Integer(2)),
    ]),
  )

  // Intermediate page tree node with no /Type: exercises the typ=None branch.
  let intermediate_num = pdf0.addobj(
    Dictionary([
      ("/Kids", Array([page1_dict, Indirect(page2_num)])),
      ("/Resources", resources_parent),
      ("/Rotate", Integer(90)),
    ]),
  )
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([Indirect(intermediate_num)])),
      ("/Count", Integer(2)),
    ]),
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, [])
  let messages : Array[String] = []
  let pages = @pdfe.with_logger(fn(msg) { messages.push(msg) }, fn() {
    @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  })
  assert_eq(pages.length(), 2)
  assert_eq(pages[0].content.length(), 1)
  assert_eq(pages[1].content.length(), 0)
  match (pages[0].rotate : @pdfpage.Rotation) {
    Rotate90 => ()
    _ => fail("expected inherited /Rotate 90")
  }
  // Second page inherits the most recently seen mediabox.
  assert_eq(pages[0].mediabox.to_string(), pages[1].mediabox.to_string())

  // Rest dict should keep custom keys but drop page-standard ones.
  match (pages[0].rest : @pdf.PdfObject) {
    Dictionary(entries) => {
      assert_true(dict_entries_has_int(entries, "/Extra", 1))
      assert_true(!dict_entries_has_key(entries, "/Type"))
    }
    _ => fail("expected rest dictionary")
  }
  assert_true(messages[:].contains("Page /Contents not a stream: ignoring.\n"))
  assert_true(
    messages[:].contains(
      "Warning: missing mediabox. Using most recently seen.\n",
    ),
  )
}

///|
test "pages_of_pagetree errors on malformed and missing kids" {
  let base = @pdf.Pdf::empty()
  let bad_kids_num = base.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Integer(1)),
    ]),
  )
  let pdf_bad_kids = @pdfpage.PdfPageDoc::new(base).add_root(bad_kids_num, [])
  assert_is_err(try? @pdfpage.PdfPageDoc::new(pdf_bad_kids).pages_of_pagetree())
  let base2 = @pdf.Pdf::empty()
  let missing_kid_num = base2.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([Indirect(999999)])),
    ]),
  )
  let pdf_missing_kid = @pdfpage.PdfPageDoc::new(base2).add_root(
    missing_kid_num,
    [],
  )
  assert_is_err(
    try? @pdfpage.PdfPageDoc::new(pdf_missing_kid).pages_of_pagetree(),
  )
  let base3 = @pdf.Pdf::empty()
  let malformed_kid_num = base3.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([Integer(0)])),
    ]),
  )
  let pdf_malformed_kid = @pdfpage.PdfPageDoc::new(base3).add_root(
    malformed_kid_num,
    [],
  )
  assert_is_err(
    try? @pdfpage.PdfPageDoc::new(pdf_malformed_kid).pages_of_pagetree(),
  )
}

///|
test "add_pagetree errors on empty page list and bad rest" {
  let pdf = @pdf.Pdf::empty()
  let res : Result[(@pdf.Pdf, Int), Error] = try? @pdfpage.PdfPageDoc::new(pdf).add_pagetree([],
  )
  match res {
    Ok((_, root_num)) => assert_true(root_num > 0)
    Err(_) => fail("expected ok for empty page list")
  }
  let bad_page : @pdfpage.Page = {
    content: [],
    mediabox: sample_rect(),
    resources: Dictionary([]),
    rotate: Rotate0,
    rest: Integer(0),
  }
  let res2 : Result[(@pdf.Pdf, Int), Error] = try? @pdfpage.PdfPageDoc::new(
    @pdf.Pdf::empty(),
  ).add_pagetree([bad_page])
  assert_is_err(res2)
}

///|
test "add_root errors when trailer is not a dictionary" {
  let pdf0 = @pdf.Pdf::empty()
  pdf0.trailerdict = Integer(0)
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([])),
      ("/Count", Integer(0)),
    ]),
  )
  assert_is_err(
    try? @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, []),
  )
}

///|
test "add_pagetree writes rotate and builds nested trees" {
  let pages : Array[@pdfpage.Page] = []
  for i in 0..<40 {
    let base = @pdfpage.Page::custom(sample_rect())
    let page : @pdfpage.Page = if i == 0 {
      {
        content: base.content,
        mediabox: base.mediabox,
        resources: base.resources,
        rotate: Rotate90,
        rest: base.rest,
      }
    } else {
      base
    }
    pages.push(page)
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let first = pdf.lookup_obj(refs[0])
  match (pdf.lookup_direct("/Rotate", first) : @pdf.PdfObject?) {
    Some(Integer(90)) => ()
    _ => fail("expected /Rotate 90 on first page")
  }
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(), 40)
}
