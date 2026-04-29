///|
fn standard_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    ("/Encoding", Dictionary([])),
  ])
}

///|
fn win_ansi_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    ("/Encoding", Name(@pdf.PdfName::of_string("/WinAnsiEncoding"))),
  ])
}

///|
fn custom_encoding_font_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(@pdf.PdfName::of_string("/WinAnsiEncoding"))),
        (
          "/Differences",
          Array([Integer(65), Name(@pdf.PdfName::of_string("/A"))]),
        ),
      ]),
    ),
  ])
}

///|
fn simple_font_with_tounicode(tounicode_ref : Int) -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
    ("/FirstChar", Integer(33)),
    ("/LastChar", Integer(33)),
    ("/Widths", Array([Integer(500)])),
    ("/ToUnicode", Indirect(tounicode_ref)),
  ])
}

///|
fn cid_font_dict(encoding_name : String) -> @pdf.PdfObject {
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
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type0"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
    ("/DescendantFonts", Array([descendant])),
    ("/Encoding", Name(@pdf.PdfName::of_string(encoding_name))),
  ])
}

///|
test "utf16be conversions" {
  inspect(
    @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x41),
    content="[0, 65]",
  )
  inspect(
    @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x1f600),
    content="[216, 61, 222, 0]",
  )
  let utf16 = @pdftext.PdfTextUtil::new().utf16be_of_codepoints([0x41, 0x1f600])
  let utf16_bytes = @pdfio.int_array_of_string(utf16)
  inspect(utf16_bytes, content="[254, 255, 0, 65, 216, 61, 222, 0]")
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_utf16be(
    @pdfio.string_of_int_array([0x00, 0x41, 0xd8, 0x3d, 0xde, 0x00]),
  )
  inspect(decoded, content="[65, 128888]")
  let invalid_len : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().codepoints_of_utf16be(
    @pdfio.string_of_int_array([0x00]),
  )
  assert_true(invalid_len is Err(_))
  let invalid_cp : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().utf16be_of_codepoint(
    0x110000,
  )
  assert_true(invalid_cp is Err(_))
}

///|
test "pdfdocstring conversions" {
  assert_true(!@pdftext.PdfTextUtil::new().is_unicode("A"))
  let unicode = @pdftext.PdfTextUtil::new().utf16be_of_codepoints([0x41])
  assert_true(@pdftext.PdfTextUtil::new().is_unicode(unicode))
  inspect(
    @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring("A"),
    content="[65]",
  )
  inspect(
    @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring(unicode),
    content="[65]",
  )
  assert_eq(@pdftext.PdfTextUtil::new().utf8_of_pdfdocstring("AB"), "AB")
  let simplified = @pdftext.PdfTextUtil::new().simplify_utf16be(unicode)
  assert_eq(simplified, "A")
  let pdfdoc_ascii = @pdftext.PdfTextUtil::new().pdfdocstring_of_codepoints([
    0x41, 0x42,
  ])
  assert_eq(pdfdoc_ascii, "AB")
  let pdfdoc_cjk = @pdftext.PdfTextUtil::new().pdfdocstring_of_codepoints([
    0x4e2d,
  ])
  assert_true(@pdftext.PdfTextUtil::new().is_unicode(pdfdoc_cjk))
  inspect(
    @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring(pdfdoc_cjk),
    content="[20013]",
  )
  let bad : Result[Int, Error] = try? @pdftext.PdfTextUtil::new().codepoint_of_pdfdocencoding_character(
    300,
  )
  assert_true(bad is Err(_))
}

///|
test "utf8 conversion helpers" {
  let cps = [0x41, 0x20ac, 0x1f600]
  let utf8 = @pdftext.PdfTextUtil::new().utf8_of_codepoints(cps)
  inspect(
    @pdftext.PdfTextUtil::new().codepoints_of_utf8(utf8),
    content="[65, 8364, 128512]",
  )
  let bytes = @pdfio.int_array_of_bytes(
    @pdfio.bytes_of_caml_bytes(@utf8.encode(utf8)),
  )
  let expected = @pdftext.PdfTextUtil::new()
    .get_utf8_chars(0x41)
    .add(@pdftext.PdfTextUtil::new().get_utf8_chars(0x20ac))
    .add(@pdftext.PdfTextUtil::new().get_utf8_chars(0x1f600))
  assert_eq(bytes.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(bytes[i], expected[i])
  }
  let invalid_utf8 : Result[Array[Int], Error] = try? @pdftext.PdfTextUtil::new().get_utf8_chars(
    0x110000,
  )
  assert_true(invalid_utf8 is Err(_))
}

///|
test "encoding tables and extractors" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let encoding = ctx.read_encoding(win_ansi_font_dict())
  let table = @pdftext.PdfTextUtil::new().table_of_encoding(encoding)
  let sample = @pdfglyphlist.name_to_win[0]
  assert_eq(table.get(sample.1), Some(sample.0))
  let reversed = @pdftext.PdfTextUtil::new().reverse_table_of_encoding(encoding)
  assert_eq(reversed.get(sample.0), Some(sample.1))
  let custom = ctx.read_encoding(custom_encoding_font_dict())
  let custom_table = @pdftext.PdfTextUtil::new().table_of_encoding(custom)
  assert_eq(custom_table.get(65), Some("/A"))
  let extractor = ctx.text_extractor_of_font(standard_font_dict())
  let pairs = extractor.glyphnames_and_codepoints_of_text("A")
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, "/A")
  inspect(pairs[0].1, content="[65]")
  inspect(extractor.codepoints_of_text("AB"), content="[65, 66]")
  let charcode = ctx.charcode_extractor_of_font(standard_font_dict())
  assert_eq(charcode(0x41), Some(65))
}

///|
test "tounicode and cmap extraction" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let tounicode : Map[Int, String] = Map::new()
  tounicode.set(33, @pdfio.string_of_int_array([0x00, 0x42]))
  let tounicode_ref = ctx.write_tounicode(tounicode)
  let extractor = ctx.text_extractor_of_font(
    simple_font_with_tounicode(tounicode_ref),
  )
  let pairs = extractor.glyphnames_and_codepoints_of_text("!")
  assert_eq(pairs.length(), 1)
  inspect(pairs[0].1, content="[66]")
  let miss = extractor.glyphnames_and_codepoints_of_text("A")
  assert_eq(miss.length(), 1)
  inspect(miss[0].1, content="[65]")
  let identity_extractor = ctx.text_extractor_of_font(
    cid_font_dict("/Identity-H"),
  )
  let identity_text = @pdfio.string_of_int_array([0x00, 0x41, 0x00, 0x42])
  let identity_pairs = identity_extractor.glyphnames_and_codepoints_of_text(
    identity_text,
  )
  assert_eq(identity_pairs.length(), 2)
  inspect(identity_pairs[0].1, content="[65]")
  inspect(identity_pairs[1].1, content="[66]")
  let odd_res : Result[Array[(String, Array[Int])], Error] = try? identity_extractor.glyphnames_and_codepoints_of_text(
    @pdfio.string_of_int_array([0x00]),
  )
  assert_true(odd_res is Err(_))
  let shift_extractor = ctx.text_extractor_of_font(
    cid_font_dict("/90ms-RKSJ-H"),
  )
  let shift_text = @pdfio.string_of_int_array([0x81, 0x40])
  let shift_pairs = shift_extractor.glyphnames_and_codepoints_of_text(
    shift_text,
  )
  assert_eq(shift_pairs.length(), 1)
  inspect(shift_pairs[0].1, content="[12288]")
}
