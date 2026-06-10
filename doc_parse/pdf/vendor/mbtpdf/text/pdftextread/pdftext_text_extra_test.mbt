///|
fn font_with_encoding_name(
  encoding_name : String,
  subtype? : String = "/Type1",
) -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string(subtype))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
    ("/Encoding", Name(@pdf.PdfName::of_string(encoding_name))),
  ])
}

///|
fn truetype_font_with_encoding_dict() -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/TrueType"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
    (
      "/Encoding",
      Dictionary([
        ("/BaseEncoding", Name(@pdf.PdfName::of_string("/MacRomanEncoding"))),
      ]),
    ),
  ])
}

///|
fn font_with_difference(name : String) -> @pdf.PdfObject {
  Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
    (
      "/Encoding",
      Dictionary([
        (
          "/Differences",
          Array([Integer(70), Name(@pdf.PdfName::of_string(name))]),
        ),
      ]),
    ),
  ])
}

///|
test "encoding tables include mac variants and filled standards" {
  let pdf = @pdf.Pdf::empty()
  let ctx = PdfText::new(pdf)
  let macroman_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = PdfTextUtil::new().table_of_encoding(macroman_encoding)
  assert_true(macroman.get(65) == Some("/A"))
  let macexpert_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = PdfTextUtil::new().table_of_encoding(macexpert_encoding)
  assert_true(macexpert.get(97) == Some("/Asmall"))
  let filled_encoding = ctx.read_encoding(truetype_font_with_encoding_dict())
  let filled = PdfTextUtil::new().table_of_encoding(filled_encoding)
  assert_true(filled.get(65) == Some("/A"))
}

///|
test "reverse tables handle implicit and mac encodings" {
  let pdf = @pdf.Pdf::empty()
  let ctx = PdfText::new(pdf)
  let font_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/CustomFont"))),
  ])
  let implicit_encoding = ctx.read_encoding(font_dict)
  let implicit = PdfTextUtil::new().reverse_table_of_encoding(implicit_encoding)
  assert_true(implicit.get("/A") == None)
  let macroman_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacRomanEncoding"),
  )
  let macroman = PdfTextUtil::new().reverse_table_of_encoding(macroman_encoding)
  assert_true(macroman.get("/A") == Some(65))
  let macexpert_encoding = ctx.read_encoding(
    font_with_encoding_name("/MacExpertEncoding"),
  )
  let macexpert = PdfTextUtil::new().reverse_table_of_encoding(
    macexpert_encoding,
  )
  assert_true(macexpert.get("/Asmall") == Some(97))
  let filled_encoding = ctx.read_encoding(truetype_font_with_encoding_dict())
  let filled = PdfTextUtil::new().reverse_table_of_encoding(filled_encoding)
  assert_true(filled.get("/A") == Some(65))
}

///|
test "reverse table handles custom differences" {
  let pdf = @pdf.Pdf::empty()
  let encoding = PdfText::new(pdf).read_encoding(
    font_with_difference("/NotAGlyph"),
  )
  let reversed = PdfTextUtil::new().reverse_table_of_encoding(encoding)
  assert_true(reversed.get("/NotAGlyph") == Some(70))
}

///|
test "text extractor handles missing glyph hashes" {
  let hashes = @pdfglyphlist.PdfGlyphList::new().glyph_hashes()
  assert_true(hashes.get("/NotAGlyph") is None)
  let pdf = @pdf.Pdf::empty()
  let extractor = PdfText::new(pdf).text_extractor_of_font(
    font_with_difference("/NotAGlyph"),
  )
  let pairs = extractor.glyphnames_and_codepoints_of_text("F")
  assert_eq(pairs.length(), 1)
  assert_true(pairs[0].0.contains("NotAGlyph"))
  debug_inspect(pairs[0].1, content="[70]")
  let names = extractor.glyphnames_of_text("F")
  assert_eq(names.length(), 1)
}

///|
test "charcode extractor uses tounicode bytes map" {
  let cmap = "begincodespacerange<21><21>endcodespacerange\n" +
    "beginbfchar<21><0042>endbfchar\n"
  let (font, pdf) = simple_font_with_raw_tounicode_stream(cmap)
  let ctx = PdfText::new(pdf)
  let charcode = ctx.charcode_extractor_of_font(font)
  assert_true(charcode(66) == Some(33))
}

///|
test "codepoints_of_utf16be rejects invalid surrogate pairs" {
  let missing_low = @pdfio.string_of_int_array([0xd8, 0x00])
  let missing_result : Result[Array[Int], Error] = try
    PdfTextUtil::new().codepoints_of_utf16be(missing_low) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(missing_result is Err(_))
  let bad_low = @pdfio.string_of_int_array([0xd8, 0x00, 0x00, 0x41])
  let bad_low_result : Result[Array[Int], Error] = try
    PdfTextUtil::new().codepoints_of_utf16be(bad_low) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_low_result is Err(_))
  let low_only = @pdfio.string_of_int_array([0xdc, 0x00, 0x00, 0x41])
  let low_only_result : Result[Array[Int], Error] = try
    PdfTextUtil::new().codepoints_of_utf16be(low_only) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(low_only_result is Err(_))
}

///|
test "codepoints_of_utf8 handles two byte sequences" {
  let utf8 = PdfTextUtil::new().utf8_of_codepoints([0x00e9])
  debug_inspect(PdfTextUtil::new().codepoints_of_utf8(utf8), content="[233]")
}

///|
test "simplify_utf16be keeps non-unicode text" {
  assert_eq(PdfTextUtil::new().simplify_utf16be("plain"), "plain")
}

///|
test "pdfdocstring_of_codepoints falls back for missing glyphs" {
  let pdfdoc = PdfTextUtil::new().pdfdocstring_of_codepoints([0x1f600])
  assert_true(PdfTextUtil::new().is_unicode(pdfdoc))
}

///|
test "pdfdocencoding rejects missing glyph mappings" {
  let mut missing : Int? = None
  let mut i = 0
  while i < 256 {
    if @pdfglyphlist.reverse_name_to_pdf_hashes.get(i) is None {
      missing = Some(i)
      break
    }
    i = i + 1
  }
  match missing {
    Some(code) => {
      let res : Result[Int, Error] = try
        PdfTextUtil::new().codepoint_of_pdfdocencoding_character(code) |> Ok
      catch {
        e => Err(e)
      }
      assert_true(res is Err(_))
    }
    None => {
      let code = 0
      let previous = @pdfglyphlist.reverse_name_to_pdf_hashes.get(code)
      @pdfglyphlist.reverse_name_to_pdf_hashes.set(code, "/NotARealGlyph")
      defer (match previous {
        Some(name) => @pdfglyphlist.reverse_name_to_pdf_hashes.set(code, name)
        None => @pdfglyphlist.reverse_name_to_pdf_hashes.remove(code)
      })
      let res : Result[Int, Error] = try
        PdfTextUtil::new().codepoint_of_pdfdocencoding_character(code) |> Ok
      catch {
        e => Err(e)
      }
      assert_true(res is Err(_))
    }
  }
}
