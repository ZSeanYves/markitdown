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
fn gbk_simple_font_dict(
  basefont? : String = "/FangSong_GB2312",
) -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/TrueType"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string(basefont))),
    ("/FirstChar", Integer(0)),
    ("/LastChar", Integer(255)),
    ("/Widths", Array([Integer(500)])),
    ("/Encoding", Name(@pdf.PdfName::of_string("/WinAnsiEncoding"))),
  ])
}

///|
fn raw_gbk_basefont_name() -> String {
  @pdfio.string_of_int_array([47, 0xcb, 0xce, 0xcc, 0xe5])
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
fn simple_font_with_raw_tounicode_stream(
  data : String,
) -> (@pdf.PdfObject, @pdf.Pdf) {
  let pdf = @pdf.Pdf::empty()
  let bytes = @pdfio.bytes_of_string(data)
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  let tounicode_ref = pdf.addobj(Stream(Ref((dict, @pdf.Stream::Got(bytes)))))
  (
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
      ("/BaseFont", Name(@pdf.PdfName::of_string("/Helvetica"))),
      ("/FirstChar", Integer(0)),
      ("/LastChar", Integer(255)),
      ("/Widths", Array([Integer(500)])),
      ("/ToUnicode", Indirect(tounicode_ref)),
    ]),
    pdf,
  )
}

///|
fn gbk_simple_font_with_raw_tounicode_stream(
  data : String,
) -> (@pdf.PdfObject, @pdf.Pdf) {
  let pdf = @pdf.Pdf::empty()
  let bytes = @pdfio.bytes_of_string(data)
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  let tounicode_ref = pdf.addobj(Stream(Ref((dict, @pdf.Stream::Got(bytes)))))
  (
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
      ("/BaseFont", Name(@pdf.PdfName::of_string(raw_gbk_basefont_name()))),
      ("/FirstChar", Integer(0)),
      ("/LastChar", Integer(255)),
      ("/Widths", Array([Integer(500)])),
      ("/ToUnicode", Indirect(tounicode_ref)),
    ]),
    pdf,
  )
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
fn cid_font_with_raw_tounicode_stream(
  encoding_name : String,
  data : String,
) -> (@pdf.PdfObject, @pdf.Pdf) {
  let pdf = @pdf.Pdf::empty()
  let bytes = @pdfio.bytes_of_string(data)
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  let tounicode_ref = pdf.addobj(Stream(Ref((dict, @pdf.Stream::Got(bytes)))))
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
  (
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Type0"))),
      ("/BaseFont", Name(@pdf.PdfName::of_string("/CIDFontType0"))),
      ("/DescendantFonts", Array([descendant])),
      ("/Encoding", Name(@pdf.PdfName::of_string(encoding_name))),
      ("/ToUnicode", Indirect(tounicode_ref)),
    ]),
    pdf,
  )
}

///|
fn identity_h_shifted_text(text : String, shift : Int) -> String {
  let bytes = Array::new(capacity=text.length() * 2)
  for ch in text {
    let shifted = ch.to_int() - shift
    bytes.push((shifted >> 8) & 255)
    bytes.push(shifted & 255)
  }
  @pdfio.string_of_int_array(bytes)
}

///|
test "utf16be conversions" {
  debug_inspect(
    @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x41),
    content="[0, 65]",
  )
  debug_inspect(
    @pdftext.PdfTextUtil::new().utf16be_of_codepoint(0x1f600),
    content="[216, 61, 222, 0]",
  )
  let utf16 = @pdftext.PdfTextUtil::new().utf16be_of_codepoints([0x41, 0x1f600])
  let utf16_bytes = @pdfio.int_array_of_string(utf16)
  debug_inspect(utf16_bytes, content="[254, 255, 0, 65, 216, 61, 222, 0]")
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_utf16be(
    @pdfio.string_of_int_array([0x00, 0x41, 0xd8, 0x3d, 0xde, 0x00]),
  )
  debug_inspect(decoded, content="[65, 128888]")
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
  debug_inspect(
    @pdftext.PdfTextUtil::new().codepoints_of_pdfdocstring("A"),
    content="[65]",
  )
  debug_inspect(
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
  debug_inspect(
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
  debug_inspect(
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
  assert_true(table.get(sample.1) == Some(sample.0))
  let reversed = @pdftext.PdfTextUtil::new().reverse_table_of_encoding(encoding)
  assert_true(reversed.get(sample.0) == Some(sample.1))
  let custom = ctx.read_encoding(custom_encoding_font_dict())
  let custom_table = @pdftext.PdfTextUtil::new().table_of_encoding(custom)
  assert_true(custom_table.get(65) == Some("/A"))
  let extractor = ctx.text_extractor_of_font(standard_font_dict())
  let pairs = extractor.glyphnames_and_codepoints_of_text("A")
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, "/A")
  debug_inspect(pairs[0].1, content="[65]")
  debug_inspect(extractor.codepoints_of_text("AB"), content="[65, 66]")
  let charcode = ctx.charcode_extractor_of_font(standard_font_dict())
  assert_true(charcode(0x41) == Some(65))
}

///|
test "tounicode and cmap extraction" {
  let pdf = @pdf.Pdf::empty()
  let ctx = @pdftext.PdfText::new(pdf)
  let tounicode : Map[Int, String] = Map([])
  tounicode.set(33, @pdfio.string_of_int_array([0x00, 0x42]))
  let tounicode_ref = ctx.write_tounicode(tounicode)
  let extractor = ctx.text_extractor_of_font(
    simple_font_with_tounicode(tounicode_ref),
  )
  let pairs = extractor.glyphnames_and_codepoints_of_text("!")
  assert_eq(pairs.length(), 1)
  debug_inspect(pairs[0].1, content="[66]")
  let miss = extractor.glyphnames_and_codepoints_of_text("A")
  assert_eq(miss.length(), 1)
  debug_inspect(miss[0].1, content="[65]")
  let identity_extractor = ctx.text_extractor_of_font(
    cid_font_dict("/Identity-H"),
  )
  let identity_text = @pdfio.string_of_int_array([0x00, 0x41, 0x00, 0x42])
  let identity_pairs = identity_extractor.glyphnames_and_codepoints_of_text(
    identity_text,
  )
  assert_eq(identity_pairs.length(), 2)
  debug_inspect(identity_pairs[0].1, content="[65]")
  debug_inspect(identity_pairs[1].1, content="[66]")
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
  debug_inspect(shift_pairs[0].1, content="[12288]")
  let rescued_text = identity_h_shifted_text(
    "This is an Arial Unicode PDF from OpenOffice.", 31,
  )
  assert_eq(
    @pdftext.PdfTextUtil::new().utf8_of_codepoints(
      identity_extractor.codepoints_of_text(rescued_text),
    ),
    "This is an Arial Unicode PDF from OpenOffice.",
  )
}

///|
test "gbk helper decodes mixed ascii and chinese" {
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_gbk([
    0xc4, 0xbf, 0xc2, 0xbc, 0x20,
  ])
  match decoded {
    Some(codepoints) =>
      assert_eq(
        @pdftext.PdfTextUtil::new().utf8_of_codepoints(codepoints),
        "目录 ",
      )
    None => fail("expected valid gbk decode")
  }
}

///|
test "gbk helper rejects invalid trailing byte" {
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_gbk([0xc4, 0x20])
  assert_true(decoded is None)
}

///|
test "gbk helper decodes fullwidth punctuation and spaces" {
  let decoded = @pdftext.PdfTextUtil::new().codepoints_of_gbk([
    0xa3, 0xac, 0x20, 0xa3, 0xb1, 0x20, 0xa1, 0xa1,
  ])
  match decoded {
    Some(codepoints) =>
      assert_eq(
        @pdftext.PdfTextUtil::new().utf8_of_codepoints(codepoints),
        "， １ 　",
      )
    None => fail("expected valid gbk punctuation decode")
  }
}

///|
test "simple font gbk fallback decodes conservative cjk snippets" {
  let pdf = @pdf.Pdf::empty()
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(
    gbk_simple_font_dict(basefont=raw_gbk_basefont_name()),
  )
  let text = @pdfio.string_of_int_array([0xc4, 0xbf, 0x20, 0xc2, 0xbc, 0x20])
  assert_eq(
    @pdftext.PdfTextUtil::new().utf8_of_codepoints(
      extractor.codepoints_of_text(text),
    ),
    "目 录 ",
  )
}

///|
test "simple font gbk fallback rescues punctuation only chunks" {
  let pdf = @pdf.Pdf::empty()
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(
    gbk_simple_font_dict(basefont=raw_gbk_basefont_name()),
  )
  let punct = @pdfio.string_of_int_array([0xa3, 0xac, 0x20, 0xa3, 0xb1, 0x20])
  assert_eq(
    @pdftext.PdfTextUtil::new().utf8_of_codepoints(
      extractor.codepoints_of_text(punct),
    ),
    "， １ ",
  )
  let ideographic_space = @pdfio.string_of_int_array([0xa1, 0xa1])
  assert_eq(
    @pdftext.PdfTextUtil::new().utf8_of_codepoints(
      extractor.codepoints_of_text(ideographic_space),
    ),
    "　",
  )
}

///|
test "latin simple fonts do not trigger gbk fallback" {
  let pdf = @pdf.Pdf::empty()
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(
    gbk_simple_font_dict(basefont="/Helvetica"),
  )
  let pairs = extractor.glyphnames_and_codepoints_of_text(
    @pdfio.string_of_int_array([0xc4, 0xbf, 0x20]),
  )
  assert_eq(pairs.length(), 3)
  debug_inspect(pairs.map(pair => pair.1[0]), content="[196, 191, 32]")
}

///|
test "gbk fallback does not override tounicode" {
  let cmap = "begincodespacerange<00><ff>endcodespacerange\n" +
    "beginbfchar<21><0042>endbfchar\n"
  let (font, pdf) = gbk_simple_font_with_raw_tounicode_stream(cmap)
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(font)
  let pairs = extractor.glyphnames_and_codepoints_of_text("!")
  assert_eq(pairs.length(), 1)
  debug_inspect(pairs[0].1, content="[66]")
}

///|
test "tounicode greedy matching honors codespacerange lengths" {
  let cmap = "begincodespacerange<00><ff><0000><ffff>endcodespacerange\n" +
    "beginbfchar<0001><4E00><41><0041>endbfchar\n"
  let (font, pdf) = simple_font_with_raw_tounicode_stream(cmap)
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(font)
  let text = @pdfio.string_of_int_array([0x00, 0x01, 0x41])
  let pairs = extractor.glyphnames_and_codepoints_of_text(text)
  assert_eq(pairs.length(), 2)
  debug_inspect(pairs[0].1, content="[19968]")
  debug_inspect(pairs[1].1, content="[65]")
}

///|
test "tounicode missing source code falls back safely" {
  let cmap = "beginbfchar<21><0042>endbfchar"
  let (font, pdf) = simple_font_with_raw_tounicode_stream(cmap)
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(font)
  let miss = extractor.glyphnames_and_codepoints_of_text("A")
  assert_eq(miss.length(), 1)
  debug_inspect(miss[0].1, content="[65]")
}

///|
test "simple font fallback ignores overly wide tounicode codespacerange" {
  let cmap = "1 begincodespacerange\n<0000><ffff>\nendcodespacerange\n" +
    "2 beginbfchar\n<30><0030>\n<31><0031>\nendbfchar\n"
  let (font, pdf) = simple_font_with_raw_tounicode_stream(cmap)
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(font)
  let pairs = extractor.glyphnames_and_codepoints_of_text("10")
  assert_eq(pairs.length(), 2)
  debug_inspect(pairs[0].1, content="[49]")
  debug_inspect(pairs[1].1, content="[48]")
}

///|
test "invalid tounicode values fall back without splitting multibyte codes" {
  let cmap = "1 begincodespacerange\n<0000><ffff>\nendcodespacerange\n" +
    "1 beginbfchar\n<19d2><ffff>\nendbfchar\n"
  let (font, pdf) = cid_font_with_raw_tounicode_stream("/Identity-H", cmap)
  let extractor = @pdftext.PdfText::new(pdf).text_extractor_of_font(font)
  let text = @pdfio.string_of_int_array([0x19, 0xd2])
  let pairs = extractor.glyphnames_and_codepoints_of_text(text)
  assert_eq(pairs.length(), 1)
  debug_inspect(pairs[0].1, content="[6610]")
}
