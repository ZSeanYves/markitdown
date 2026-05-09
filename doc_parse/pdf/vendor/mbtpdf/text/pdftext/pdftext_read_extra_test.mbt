///|
fn type3_bbox() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(10.0), Real(10.0)])
}

///|
fn type3_matrix_ok() -> @pdf.PdfObject {
  Array([Real(1.0), Real(0.0), Real(0.0), Real(1.0), Real(0.0), Real(0.0)])
}

///|
fn type3_charprocs_ok() -> @pdf.PdfObject {
  Dictionary([("/A", Null)])
}

///|
fn type3_font_base(
  matrix : @pdf.PdfObject,
  charprocs : @pdf.PdfObject,
) -> @pdf.PdfObject {
  Dictionary([
    ("/FontBBox", type3_bbox()),
    ("/FontMatrix", matrix),
    ("/CharProcs", charprocs),
  ])
}

///|
test "read_type3_data validates matrix and charprocs" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let bad_len_matrix : @pdf.PdfObject = Array([
    Real(1.0),
    Real(0.0),
    Real(0.0),
    Real(1.0),
    Real(0.0),
  ])
  let bad_len_font = type3_font_base(bad_len_matrix, type3_charprocs_ok())
  let bad_len_result : Result[@pdffont.Type3Glyphs, Error] = try? ctx.read_type3_data(
    bad_len_font,
  )
  assert_true(bad_len_result is Err(_))
  let bad_type_font = type3_font_base(
    Name(@pdf.PdfName::of_string("/Bad")),
    type3_charprocs_ok(),
  )
  let bad_type_result : Result[@pdffont.Type3Glyphs, Error] = try? ctx.read_type3_data(
    bad_type_font,
  )
  assert_true(bad_type_result is Err(_))
  let bad_charprocs_font = type3_font_base(
    type3_matrix_ok(),
    Name(@pdf.PdfName::of_string("/Bad")),
  )
  let bad_charprocs_result : Result[@pdffont.Type3Glyphs, Error] = try? ctx.read_type3_data(
    bad_charprocs_font,
  )
  assert_true(bad_charprocs_result is Err(_))
  let with_resources = type3_font_base(type3_matrix_ok(), type3_charprocs_ok()).add_entry(
    "/Resources",
    Dictionary([("/ProcSet", Array([]))]),
  )
  let good = ctx.read_type3_data(with_resources)
  match (good.type3_resources : @pdf.PdfObject) {
    Dictionary(_) => ()
    _ => fail("expected type3 resources")
  }
}

///|
test "simple_fonttype_of_string and read_basefont defaults" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([])
  assert_true(ctx.simple_fonttype_of_string(font, "/Unknown") is None)
  assert_eq(ctx.read_basefont(font), "")
}

///|
test "parse_charset handles invalid escapes" {
  let valid = @pdftext.PdfTextUtil::new().parse_charset("/A/B/")
  assert_eq(valid.length(), 2)
  assert_eq(valid[0], "/A")
  assert_eq(valid[1], "/B")
  let invalid = @pdftext.PdfTextUtil::new().parse_charset("/A#4")
  assert_eq(invalid.length(), 0)
}

///|
test "read_fontdescriptor reads font file references" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let null_obj : @pdf.PdfObject = Null
  let obj1 = pdf.addobj(null_obj)
  let obj2 = pdf.addobj(null_obj)
  let obj3 = pdf.addobj(null_obj)
  let font1 : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([("/FontFile", Indirect(obj1))])),
  ])
  match ctx.read_fontdescriptor(font1) {
    Some(desc) =>
      match (desc.fontfile : @pdffont.FontFile?) {
        Some(FontFile(num)) => assert_eq(num, obj1)
        _ => fail("expected FontFile")
      }
    None => fail("expected descriptor")
  }
  let font2 : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([("/FontFile2", Indirect(obj2))])),
  ])
  match ctx.read_fontdescriptor(font2) {
    Some(desc) =>
      match (desc.fontfile : @pdffont.FontFile?) {
        Some(FontFile2(num)) => assert_eq(num, obj2)
        _ => fail("expected FontFile2")
      }
    None => fail("expected descriptor")
  }
  let font3 : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([("/FontFile3", Indirect(obj3))])),
  ])
  match ctx.read_fontdescriptor(font3) {
    Some(desc) =>
      match (desc.fontfile : @pdffont.FontFile?) {
        Some(FontFile3(num)) => assert_eq(num, obj3)
        _ => fail("expected FontFile3")
      }
    None => fail("expected descriptor")
  }
}

///|
test "read_metrics validates required keys" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let descriptor : @pdf.PdfObject = Dictionary([])
  let missing_first : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(10)])),
  ])
  let missing_first_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    missing_first,
  )
  assert_true(missing_first_result is Err(_))
  let bad_first : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(999)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(10)])),
  ])
  let bad_first_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    bad_first,
  )
  assert_true(bad_first_result is Err(_))
  let missing_last : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/Widths", Array([Integer(10)])),
  ])
  let missing_last_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    missing_last,
  )
  assert_true(missing_last_result is Err(_))
  let bad_last : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(999)),
    ("/Widths", Array([Integer(10)])),
  ])
  let bad_last_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    bad_last,
  )
  assert_true(bad_last_result is Err(_))
  let missing_widths : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
  ])
  let missing_widths_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    missing_widths,
  )
  assert_true(missing_widths_result is Err(_))
  let bad_widths : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(1)),
    ("/Widths", Array([Integer(10)])),
  ])
  let bad_widths_result : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(
    bad_widths,
  )
  assert_true(bad_widths_result is Err(_))
}

///|
test "read_metrics accepts real widths" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let descriptor : @pdf.PdfObject = Dictionary([("/MissingWidth", Real(12.5))])
  let font : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Real(250.5)])),
  ])
  match ctx.read_metrics(font) {
    Some(metrics) => {
      assert_eq(metrics.length(), 256)
      assert_eq(metrics[0], 250.5)
      assert_eq(metrics[1], 12.5)
    }
    None => fail("expected metrics")
  }
}

///|
test "read_metrics accepts integer MissingWidth" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let descriptor : @pdf.PdfObject = Dictionary([("/MissingWidth", Integer(12))])
  let font : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", descriptor),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Integer(250)])),
  ])
  match ctx.read_metrics(font) {
    Some(metrics) => {
      assert_eq(metrics.length(), 256)
      assert_eq(metrics[0], 250.0)
      assert_eq(metrics[1], 12.0)
    }
    None => fail("expected metrics")
  }
}

///|
test "read_encoding errors on bad or missing font subtype" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([("/Encoding", Dictionary([]))])
  let res : Result[@pdffont.Encoding, Error] = try? ctx.read_encoding(font)
  assert_true(res is Err(_))
}

///|
test "cid helpers error on malformed inputs" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let sysinfo : Result[@pdffont.CIDSystemInfo, Error] = try? ctx.read_cid_system_info(
    Dictionary([]),
  )
  assert_true(sysinfo is Err(_))
  let util = @pdftext.PdfTextUtil::new()
  let bad1 : Result[Array[(Int, Double)], Error] = try? util.read_cid_widths([
    Integer(0),
    Integer(10),
  ])
  assert_true(bad1 is Err(_))
  let bad2 : Result[Array[(Int, Double)], Error] = try? util.read_cid_widths([
    Integer(0),
    Integer(1),
    Name(@pdf.PdfName::of_string("/Bad")),
  ])
  assert_true(bad2 is Err(_))
  let bad3 : Result[Array[(Int, Double)], Error] = try? util.read_cid_widths([
    Integer(0),
    Name(@pdf.PdfName::of_string("/Bad")),
  ])
  assert_true(bad3 is Err(_))
  let bad4 : Result[Array[(Int, Double)], Error] = try? util.read_cid_widths([
    Name(@pdf.PdfName::of_string("/Bad")),
  ])
  assert_true(bad4 is Err(_))
}

///|
test "read_descendant errors when FontDescriptor missing" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let dict : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", String("R")),
        ("/Ordering", String("O")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Foo"))),
  ])
  let res : Result[@pdffont.CompositeCIDFont, Error] = try? ctx.read_descendant(
    dict,
  )
  assert_true(res is Err(_))
}

///|
test "pairs_of_differences rejects malformed inputs" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let not_array : Result[@pdffont.Differences, Error] = try? ctx.pairs_of_differences(
    Name(@pdf.PdfName::of_string("/Bad")),
  )
  assert_true(not_array is Err(_))
  let bad_array_obj : @pdf.PdfObject = Array([
    Name(@pdf.PdfName::of_string("/A")),
  ])
  let bad_array : Result[@pdffont.Differences, Error] = try? ctx.pairs_of_differences(
    bad_array_obj,
  )
  assert_true(bad_array is Err(_))
}

///|
test "is_standard14font rejects non-name basefont" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Integer(1)),
  ])
  assert_true(!ctx.is_standard14font(font))
}

///|
test "read_metrics rejects non-number width entries" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([])),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(0)),
    ("/Widths", Array([Name(@pdf.PdfName::of_string("/Bad"))])),
  ])
  let res : Result[@pdffont.FontMetrics?, Error] = try? ctx.read_metrics(font)
  assert_true(res is Err(_))
}

///|
test "is_embedded detects FontFile3" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([("/FontFile3", Null)])),
  ])
  assert_true(ctx.is_embedded(font))
}

///|
test "is_symbolic errors when flags missing" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([("/FontDescriptor", Dictionary([]))])
  let res : Result[Bool, Error] = try? ctx.is_symbolic(font)
  assert_true(res is Err(_))
}

///|
test "read_encoding handles TrueType differences and bad subtype" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let enc : @pdf.PdfObject = Dictionary([
    ("/BaseEncoding", Name(@pdf.PdfName::of_string("/WinAnsiEncoding"))),
    (
      "/Differences",
      Array([
        Integer(65),
        Name(@pdf.PdfName::of_string("/A")),
        Name(@pdf.PdfName::of_string("/B")),
      ]),
    ),
  ])
  let font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/TrueType"))),
    ("/Encoding", enc),
  ])
  let encoding = ctx.read_encoding(font)
  match (encoding : @pdffont.Encoding) {
    FillUndefinedWithStandard(CustomEncoding(_, _)) => ()
    _ => fail("expected FillUndefinedWithStandard(CustomEncoding)")
  }
  let bad : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type0"))),
    ("/Encoding", enc),
  ])
  let bad_res : Result[@pdffont.Encoding, Error] = try? ctx.read_encoding(bad)
  assert_true(bad_res is Err(_))
}

///|
test "read_simple_font and standard14font error branches" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let missing_subtype : @pdf.PdfObject = Dictionary([])
  let res_simple : Result[@pdffont.Font, Error] = try? ctx.read_simple_font(
    missing_subtype,
  )
  assert_true(res_simple is Err(_))
  let bad_base : @pdf.PdfObject = Dictionary([("/BaseFont", Integer(1))])
  let res_standard : Result[@pdffont.Font, Error] = try? ctx.read_standard14font(
    bad_base,
  )
  assert_true(res_standard is Err(_))
}

///|
test "read_cid_system_info and widths reject malformed input" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let bad_info : @pdf.PdfObject = Dictionary([("/Registry", String("Adobe"))])
  let info_res : Result[@pdffont.CIDSystemInfo, Error] = try? ctx.read_cid_system_info(
    bad_info,
  )
  assert_true(info_res is Err(_))
  let missing_tail_arr : Array[@pdf.PdfObject] = [Integer(1)]
  let missing_tail : Result[Array[(Int, Double)], Error] = try? @pdftext.PdfTextUtil::new().read_cid_widths(
    missing_tail_arr,
  )
  assert_true(missing_tail is Err(_))
  let bad_width_arr : Array[@pdf.PdfObject] = [
    Integer(1),
    Array([Name(@pdf.PdfName::of_string("/Bad"))]),
  ]
  let bad_width : Result[Array[(Int, Double)], Error] = try? @pdftext.PdfTextUtil::new().read_cid_widths(
    bad_width_arr,
  )
  assert_true(bad_width is Err(_))
  let bad_range_arr : Array[@pdf.PdfObject] = [
    Integer(5),
    Integer(3),
    Integer(100),
  ]
  let bad_range : Result[Array[(Int, Double)], Error] = try? @pdftext.PdfTextUtil::new().read_cid_widths(
    bad_range_arr,
  )
  assert_true(bad_range is Err(_))
  let bad_head_arr : Array[@pdf.PdfObject] = [
    Name(@pdf.PdfName::of_string("/Bad")),
  ]
  let bad_head : Result[Array[(Int, Double)], Error] = try? @pdftext.PdfTextUtil::new().read_cid_widths(
    bad_head_arr,
  )
  assert_true(bad_head is Err(_))
}

///|
test "read_descendant and cidkeyed_font error paths" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let desc : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFont"))),
    ("/FontDescriptor", Dictionary([])),
  ])
  let desc_res : Result[@pdffont.CompositeCIDFont, Error] = try? ctx.read_descendant(
    desc,
  )
  assert_true(desc_res is Err(_))
  let bad_font : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
    ("/DescendantFonts", Array([desc])),
  ])
  let bad_cid : Result[@pdffont.Font, Error] = try? ctx.read_cidkeyed_font(
    bad_font,
  )
  assert_true(bad_cid is Err(_))
}

///|
test "find_tounicode returns none for simple fonts without descriptor" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fontdict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", Array([Integer(500)])),
  ])
  let font = ctx.read_simple_font(fontdict)
  assert_true(@pdftext.PdfTextUtil::new().find_tounicode(font) is None)
  assert_true(@pdftext.PdfTextUtil::new().find_tounicode_bytes(font) is None)
}

///|
test "is_embedded and is_symbolic read flags and missing fontfiles" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/FontDescriptor", Dictionary([("/Flags", Integer(8))])),
  ])
  assert_true(ctx.is_embedded(font) == false)
  assert_true(ctx.is_symbolic(font))
}

///|
test "read_encoding base encoding branches and implicit fallback" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let mac_expert : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(@pdf.PdfName::of_string("/MacExpertEncoding"))),
      ]),
    ),
  ])
  match (ctx.read_encoding(mac_expert) : @pdffont.Encoding) {
    MacExpertEncoding => ()
    _ => fail("expected MacExpertEncoding")
  }
  let implicit : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/FontDescriptor", Dictionary([("/Flags", Integer(8))])),
    ("/Encoding", Dictionary([])),
  ])
  match (ctx.read_encoding(implicit) : @pdffont.Encoding) {
    ImplicitInFontFile => ()
    _ => fail("expected implicit encoding")
  }
  let bad_base : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(@pdf.PdfName::of_string("/BadEncoding"))),
      ]),
    ),
  ])
  let bad_base_res : Result[@pdffont.Encoding, Error] = try? ctx.read_encoding(
    bad_base,
  )
  assert_true(bad_base_res is Err(_))
  let non_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/Encoding", Integer(1)),
  ])
  match (ctx.read_encoding(non_dict) : @pdffont.Encoding) {
    ImplicitInFontFile => ()
    _ => fail("expected implicit encoding")
  }
}

///|
test "read_simple_font rejects non-simple subtype" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type0"))),
  ])
  let res : Result[@pdffont.Font, Error] = try? ctx.read_simple_font(font)
  assert_true(res is Err(_))
}

///|
test "read_standard14font rejects unknown basefont" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let font : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/NotStandard"))),
  ])
  let res : Result[@pdffont.Font, Error] = try? ctx.read_standard14font(font)
  assert_true(res is Err(_))
}

///|
test "read_cid_system_info rejects missing supplement" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let info : @pdf.PdfObject = Dictionary([
    ("/Registry", String("Adobe")),
    ("/Ordering", String("Identity")),
  ])
  let res : Result[@pdffont.CIDSystemInfo, Error] = try? ctx.read_cid_system_info(
    info,
  )
  assert_true(res is Err(_))
}

///|
test "read_cid_widths handles real values and ranges" {
  let widths_arr : Array[@pdf.PdfObject] = [Integer(1), Array([Real(10.5)])]
  let widths = @pdftext.PdfTextUtil::new().read_cid_widths(widths_arr)
  assert_eq(widths.length(), 1)
  assert_eq(widths[0].0, 1)
  assert_eq(widths[0].1, 10.5)
  let ranged_arr : Array[@pdf.PdfObject] = [Integer(2), Integer(3), Real(7.25)]
  let ranged = @pdftext.PdfTextUtil::new().read_cid_widths(ranged_arr)
  assert_eq(ranged.length(), 2)
  assert_eq(ranged[0].0, 2)
  assert_eq(ranged[1].0, 3)
}

///|
test "read_descendant and cidkeyed_font missing basefont" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let desc : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", String("Adobe")),
        ("/Ordering", String("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/FontDescriptor", Dictionary([])),
  ])
  let res_desc : Result[@pdffont.CompositeCIDFont, Error] = try? ctx.read_descendant(
    desc,
  )
  assert_true(res_desc is Err(_))
  let cid_font : @pdf.PdfObject = Dictionary([
    ("/DescendantFonts", Array([desc])),
    ("/Encoding", Name(@pdf.PdfName::of_string("/Identity-H"))),
  ])
  let res_cid : Result[@pdffont.Font, Error] = try? ctx.read_cidkeyed_font(
    cid_font,
  )
  assert_true(res_cid is Err(_))
}

///|
test "read_cidkeyed_font rejects bad descendants and encoding streams" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let descendant : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", String("Adobe")),
        ("/Ordering", String("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFont"))),
    ("/FontDescriptor", Dictionary([])),
  ])
  let bad_desc : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
    ("/DescendantFonts", Array([descendant, descendant])),
    ("/Encoding", Name(@pdf.PdfName::of_string("/Identity-H"))),
  ])
  let res_desc : Result[@pdffont.Font, Error] = try? ctx.read_cidkeyed_font(
    bad_desc,
  )
  assert_true(res_desc is Err(_))
  let stream_dict : @pdf.PdfObject = Dictionary([])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(@pdfio.bytes_of_string("cmap")))),
  )
  let bad_encoding : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
    ("/DescendantFonts", Array([descendant])),
    ("/Encoding", stream),
  ])
  let res_stream : Result[@pdffont.Font, Error] = try? ctx.read_cidkeyed_font(
    bad_encoding,
  )
  assert_true(res_stream is Err(_))
}

///|
test "find_tounicode uses descriptor fields when present" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let fontdict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    ("/FirstChar", Integer(65)),
    ("/LastChar", Integer(65)),
    ("/Widths", Array([Integer(500)])),
    ("/FontDescriptor", Dictionary([])),
  ])
  let font = ctx.read_simple_font(fontdict)
  assert_true(@pdftext.PdfTextUtil::new().find_tounicode(font) is None)
  let descendant : @pdf.PdfObject = Dictionary([
    (
      "/CIDSystemInfo",
      Dictionary([
        ("/Registry", String("Adobe")),
        ("/Ordering", String("Identity")),
        ("/Supplement", Integer(0)),
      ]),
    ),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFont"))),
    ("/FontDescriptor", Dictionary([])),
  ])
  let cid_font : @pdf.PdfObject = Dictionary([
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
    ("/DescendantFonts", Array([descendant])),
    ("/Encoding", Name(@pdf.PdfName::of_string("/Identity-H"))),
  ])
  let cid = ctx.read_cidkeyed_font(cid_font)
  assert_true(@pdftext.PdfTextUtil::new().find_tounicode(cid) is None)
  assert_true(@pdftext.PdfTextUtil::new().find_tounicode_bytes(cid) is None)
}
