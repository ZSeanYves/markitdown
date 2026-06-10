///|
fn contract_gbk_font_dict(
  basefont? : String = @pdfio.string_of_int_array([47, 0xcb, 0xce, 0xcc, 0xe5]),
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
fn contract_gbk_font_with_tounicode(
  data : String,
) -> (@pdf.PdfObject, @pdf.Pdf) {
  let pdf = @pdf.Pdf::empty()
  let bytes = @pdfio.bytes_of_string(data)
  let tounicode_ref = pdf.addobj(
    Stream(
      Ref(
        (
          Dictionary([("/Length", Integer(@pdfio.bytes_size(bytes)))]),
          @pdf.Stream::Got(bytes),
        ),
      ),
    ),
  )
  (
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/TrueType"))),
      (
        "/BaseFont",
        Name(
          @pdf.PdfName::of_string(
            @pdfio.string_of_int_array([47, 0xcb, 0xce, 0xcc, 0xe5]),
          ),
        ),
      ),
      ("/FirstChar", Integer(0)),
      ("/LastChar", Integer(255)),
      ("/Widths", Array([Integer(500)])),
      ("/ToUnicode", Indirect(tounicode_ref)),
    ]),
    pdf,
  )
}

///|
test "replacement contract: GBK fallback decodes CJK and punctuation" {
  let pdf = @pdf.Pdf::empty()
  let extractor = PdfText::new(pdf).text_extractor_of_font(
    contract_gbk_font_dict(),
  )
  assert_eq(
    PdfTextUtil::new().utf8_of_codepoints(
      extractor.codepoints_of_text(
        @pdfio.string_of_int_array([0xc4, 0xbf, 0xc2, 0xbc]),
      ),
    ),
    "目录",
  )
  assert_eq(
    PdfTextUtil::new().utf8_of_codepoints(
      extractor.codepoints_of_text(
        @pdfio.string_of_int_array([0xa3, 0xac, 0xa1, 0xa1]),
      ),
    ),
    "，　",
  )
}

///|
test "replacement contract: ToUnicode wins over GBK fallback" {
  let cmap = "begincodespacerange<00><ff>endcodespacerange\n" +
    "beginbfchar<21><0042>endbfchar\n"
  let (font, pdf) = contract_gbk_font_with_tounicode(cmap)
  let extractor = PdfText::new(pdf).text_extractor_of_font(font)
  let pairs = extractor.glyphnames_and_codepoints_of_text("!")
  assert_eq(pairs.length(), 1)
  debug_inspect(pairs[0].1, content="[66]")
}
