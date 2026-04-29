///|
test "process_xobjects updates form xobject stream" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Form"))),
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(data))),
  )
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/X1", Indirect(xobj_num))])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let bbox : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(20.0),
  ])
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    let dict_updated : @pdf.PdfObject = Dictionary([
      ("/BBox", bbox),
      ("/Filter", Name(@pdf.PdfName::of_string("/ASCIIHexDecode"))),
    ])
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    [Stream(Ref::new((dict_updated, @pdf.Stream::Got(updated_data))))]
  }
  page.process_xobjects(pdf, update)
  let updated = pdf.lookup_obj(xobj_num)
  match (pdf.lookup_direct("/Subtype", updated) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/Form") => ()
    _ => fail("expected /Form subtype")
  }
  match (pdf.lookup_direct("/BBox", updated) : @pdf.PdfObject?) {
    Some(Array(_)) => ()
    _ => fail("expected bbox")
  }
  match pdf.lookup_direct("/Filter", updated) {
    None => ()
    _ => fail("expected filter removal")
  }
  let updated_bytes = updated.bigarray_of_stream()
  assert_eq(@pdfio.int_array_of_bytes(updated_bytes), [0x41, 0x42])
}

///|
test "combine_pdf_resources merges known and keeps unknown" {
  let pdf = @pdf.Pdf::empty()
  let a : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
    ("/Foo", Integer(1)),
  ])
  let b : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F2", Null)])),
    ("/Bar", Name(@pdf.PdfName::of_string("/Baz"))),
  ])
  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(a, b)
  match (pdf.lookup_direct("/Font", combined) : @pdf.PdfObject?) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 2)
    _ => fail("expected merged fonts")
  }
  match (pdf.lookup_direct("/Foo", combined) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /Foo")
  }
  match (pdf.lookup_direct("/Bar", combined) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/Baz") => ()
    _ => fail("expected /Bar")
  }
}

///|
test "process_xobjects errors when xobject subtype missing" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(data))),
  )
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/X1", Indirect(xobj_num))])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    []
  }
  let res : Result[Unit, Error] = try? page.process_xobjects(pdf, update)
  assert_true(res is Err(_))
}

///|
test "process_xobjects accepts updated stream with non-dict metadata" {
  let pdf = @pdf.Pdf::empty()
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Form"))),
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
  ])
  let data = @pdfio.bytes_of_list([0x01, 0x02])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(data))),
  )
  let xobj_num = pdf.addobj(stream)
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/X1", Indirect(xobj_num))])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    let updated_data = @pdfio.bytes_of_list([0x41, 0x42])
    let dict_updated : @pdf.PdfObject = Integer(0)
    [Stream(Ref::new((dict_updated, @pdf.Stream::Got(updated_data))))]
  }
  page.process_xobjects(pdf, update)
  let updated = pdf.lookup_obj(xobj_num)
  match pdf.lookup_direct("/Filter", updated) {
    None => ()
    _ => fail("expected filter removal")
  }
  let updated_bytes = updated.bigarray_of_stream()
  assert_eq(@pdfio.int_array_of_bytes(updated_bytes), [0x41, 0x42])
}

///|
test "process_xobjects errors on non-indirect xobject references" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/X1", Integer(0))])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let update = fn(
    _ : @pdf.Pdf,
    _ : @pdf.PdfObject,
    _ : Array[@pdf.PdfObject],
  ) -> Array[@pdf.PdfObject] {
    []
  }
  let res : Result[Unit, Error] = try? page.process_xobjects(pdf, update)
  assert_true(res is Err(_))
}
