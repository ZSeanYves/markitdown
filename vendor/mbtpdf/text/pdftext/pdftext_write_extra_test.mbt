///|
test "write_encoding covers mac and custom encodings" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let macroman_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = ctx.write_encoding(macroman_encoding)
  match (pdf.lookup_obj(macroman) : @pdf.PdfObject) {
    Name(n) if n.equal_string_bytes("/MacRomanEncoding") => ()
    _ => fail("expected /MacRomanEncoding")
  }
  let macexpert_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = ctx.write_encoding(macexpert_encoding)
  match (pdf.lookup_obj(macexpert) : @pdf.PdfObject) {
    Name(n) if n.equal_string_bytes("/MacExpertEncoding") => ()
    _ => fail("expected /MacExpertEncoding")
  }
  let filled_encoding = ctx.read_encoding(truetype_font_with_encoding_dict())
  let filled = ctx.write_encoding(filled_encoding)
  match (pdf.lookup_obj(filled) : @pdf.PdfObject) {
    Name(n) if n.equal_string_bytes("/MacRomanEncoding") => ()
    _ => fail("expected filled encoding to reuse inner")
  }
  let custom_encoding = ctx.read_encoding(embedded_font_with_custom_encoding())
  let custom = ctx.write_encoding(custom_encoding)
  match (pdf.lookup_obj(custom) : @pdf.PdfObject) {
    Dictionary(_) as dict => {
      assert_true(pdf.lookup_direct("/BaseEncoding", dict) is None)
      match (pdf.lookup_direct("/Differences", dict) : @pdf.PdfObject?) {
        Some(Array(values)) => assert_true(values.length() > 0)
        _ => fail("expected differences array")
      }
    }
    _ => fail("expected custom encoding dictionary")
  }
  let font_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
  ])
  let implicit_encoding = ctx.read_encoding(font_dict)
  let implicit_result : Result[Int, Error] = try? ctx.write_encoding(
    implicit_encoding,
  )
  assert_true(implicit_result is Err(_))
}

///|
test "write_font errors on unsupported fonts" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let simple_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
  ])
  let simple_font = ctx.read_font(simple_dict)
  let simple_result : Result[Int, Error] = try? ctx.write_font(simple_font)
  assert_true(simple_result is Err(_))
  let cid_font = ctx.read_font(cid_font_dict("/Identity-H"))
  let cid_result : Result[Int, Error] = try? ctx.write_font(cid_font)
  assert_true(cid_result is Err(_))
}

///|
fn add_font_descriptor(pdf : @pdf.Pdf, fontfile_obj : Int?) -> Int {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Type", Name(@pdf.PdfName::of_string("/FontDescriptor"))),
    ("/Ascent", Integer(700)),
    ("/Descent", Integer(-200)),
    ("/AvgWidth", Integer(500)),
    ("/MaxWidth", Integer(1000)),
  ]
  match fontfile_obj {
    Some(objnum) => entries.push(("/FontFile2", Indirect(objnum)))
    None => ()
  }
  pdf.addobj(Dictionary(entries))
}

///|
fn add_fontfile_stream(pdf : @pdf.Pdf) -> Int {
  let data = @pdfio.bytes_of_string("ttf")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  pdf.addobj(Stream(Ref::new((dict, @pdf.Stream::Got(data)))))
}

///|
fn add_tounicode_stream(pdf : @pdf.Pdf) -> Int {
  let bytes = @pdftext.PdfTextUtil::new().tounicode_map(33, ["A"])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  pdf.addobj(Stream(Ref::new((dict, @pdf.Stream::Got(bytes)))))
}

///|
fn truetype_font_dict(
  font_descriptor : Int?,
  encoding_name : String,
  tounicode_obj : Int?,
) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Subtype", Name(@pdf.PdfName::of_string("/TrueType"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/DummyTTF"))),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(1)),
    ("/Widths", Array([Integer(500), Integer(600)])),
    ("/Encoding", Name(@pdf.PdfName::of_string(encoding_name))),
  ]
  match font_descriptor {
    Some(objnum) => entries.push(("/FontDescriptor", Indirect(objnum)))
    None => ()
  }
  match tounicode_obj {
    Some(objnum) => entries.push(("/ToUnicode", Indirect(objnum)))
    None => ()
  }
  Dictionary(entries)
}

///|
fn type3_font_dict_extra(font_descriptor : Int?) -> @pdf.PdfObject {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type3"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/DummyType3"))),
    ("/FontBBox", Array([Real(0.0), Real(0.0), Real(0.0), Real(0.0)])),
    (
      "/FontMatrix",
      Array([Real(1.0), Real(0.0), Real(0.0), Real(1.0), Real(0.0), Real(0.0)]),
    ),
    ("/CharProcs", Dictionary([("/A", Null)])),
    ("/Resources", Dictionary([])),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(0)])),
  ]
  match font_descriptor {
    Some(objnum) => entries.push(("/FontDescriptor", Indirect(objnum)))
    None => ()
  }
  Dictionary(entries)
}

///|
test "write_font writes type3 font with encoding" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fd = add_font_descriptor(pdf, None)
  let font_dict = type3_font_dict_extra(Some(fd))
  let font = ctx.read_font(font_dict)
  let objnum = ctx.write_font(font)
  match (pdf.lookup_obj(objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      match (pdf.lookup_direct("/Subtype", dict) : @pdf.PdfObject?) {
        Some(Name(n)) if n.equal_string_bytes("/Type3") => ()
        _ => fail("expected Type3 subtype")
      }
    _ => fail("expected Type3 font dictionary")
  }
}

///|
test "write_font writes truetype with tounicode" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fontfile = add_fontfile_stream(pdf)
  let fd = add_font_descriptor(pdf, Some(fontfile))
  let tounicode = add_tounicode_stream(pdf)
  let font_dict = truetype_font_dict(
    Some(fd),
    "/WinAnsiEncoding",
    Some(tounicode),
  )
  let font = ctx.read_font(font_dict)
  let objnum = ctx.write_font(objnum=50, font)
  assert_eq(objnum, 50)
  match (pdf.lookup_obj(objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      assert_true(pdf.lookup_direct("/ToUnicode", dict) is Some(_))
    _ => fail("expected truetype dictionary")
  }
}

///|
test "write_font writes truetype with encoding entry" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fontfile = add_fontfile_stream(pdf)
  let fd = add_font_descriptor(pdf, Some(fontfile))
  let font_dict = truetype_font_dict(Some(fd), "/MacRomanEncoding", None)
  let font = ctx.read_font(font_dict)
  let objnum = ctx.write_font(font)
  match (pdf.lookup_obj(objnum) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      assert_true(pdf.lookup_direct("/Encoding", dict) is Some(_))
    _ => fail("expected truetype dictionary")
  }
}

///|
test "write_font errors when truetype descriptor missing" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font_dict = truetype_font_dict(None, "/WinAnsiEncoding", None)
  let font = ctx.read_font(font_dict)
  let result : Result[Int, Error] = try? ctx.write_font(font)
  assert_true(result is Err(_))
}

///|
test "write_font errors when truetype fontfile missing" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fd = add_font_descriptor(pdf, None)
  let font_dict = truetype_font_dict(Some(fd), "/WinAnsiEncoding", None)
  let font = ctx.read_font(font_dict)
  let result : Result[Int, Error] = try? ctx.write_font(font)
  assert_true(result is Err(_))
}
