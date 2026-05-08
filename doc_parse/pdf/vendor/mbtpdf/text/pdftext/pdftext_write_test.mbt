///|
fn type3_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type3"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/TestFont"))),
    ("/FontBBox", Array([Real(0.0), Real(0.0), Real(1.0), Real(1.0)])),
    (
      "/FontMatrix",
      Array([
        Real(0.001),
        Real(0.0),
        Real(0.0),
        Real(0.001),
        Real(0.0),
        Real(0.0),
      ]),
    ),
    ("/CharProcs", Dictionary([("/A", Null)])),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(0)])),
    ("/FontDescriptor", Dictionary([])),
  ])
}

///|
test "write_encoding handles builtins and custom diffs" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let standard_encoding = ctx.read_encoding(standard_font_dict())
  let standard = ctx.write_encoding(standard_encoding)
  match (pdf.lookup_obj(standard) : @pdf.PdfObject) {
    Name(n) if n.equal_string_bytes("/StandardEncoding") => ()
    _ => fail("expected StandardEncoding name")
  }
  let custom_encoding = ctx.read_encoding(custom_encoding_font_dict())
  let custom = ctx.write_encoding(custom_encoding)
  match (pdf.lookup_obj(custom) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      match (pdf.lookup_direct("/Differences", dict) : @pdf.PdfObject?) {
        Some(Array(values)) => assert_true(values.length() >= 2)
        _ => fail("expected /Differences")
      }
    _ => fail("expected encoding dictionary")
  }
  let implicit_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type0"))),
  ])
  let implicit = ctx.read_encoding(implicit_dict)
  let implicit_result : Result[Int, Error] = try? ctx.write_encoding(implicit)
  assert_true(implicit_result is Err(_))
}

///|
test "hex and tounicode_map encode bytes" {
  assert_eq(@pdftext.PdfTextUtil::new().hex("A"), "41")
  let bytes = @pdftext.PdfTextUtil::new().tounicode_map(33, ["A", "B"])
  let text = @pdfio.string_of_bytes(bytes)
  assert_true(text.contains("begincmap"))
  assert_true(text.contains("<21><21><41>"))
  assert_true(text.contains("<22><22><42>"))
}

///|
test "write_font handles standard and type3 fonts" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let standard_font = ctx.read_font(win_ansi_font_dict())
  let standard = ctx.write_font(standard_font)
  match (pdf.lookup_obj(standard) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      match (pdf.lookup_direct("/BaseFont", dict) : @pdf.PdfObject?) {
        Some(Name(n)) if n.equal_string_bytes("/Helvetica") => ()
        _ => fail("expected /BaseFont /Helvetica")
      }
    _ => fail("expected font dictionary")
  }
  let type3_font = ctx.read_font(type3_font_dict())
  let type3_num = ctx.write_font(type3_font)
  match (pdf.lookup_obj(type3_num) : @pdf.PdfObject) {
    Dictionary(_) as dict =>
      match (pdf.lookup_direct("/Subtype", dict) : @pdf.PdfObject?) {
        Some(Name(n)) if n.equal_string_bytes("/Type3") => ()
        _ => fail("expected /Subtype /Type3")
      }
    _ => fail("expected Type3 font dictionary")
  }
}
