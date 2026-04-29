///|
test "glyphlist tables include basic mappings" {
  let src = @pdfglyphlist.PdfGlyphList::new().glyphlist_src()
  assert_true(src.length() > 0)
  let hashes = @pdfglyphlist.PdfGlyphList::new().glyph_hashes()
  match hashes.get("/A") {
    Some(values) => {
      assert_eq(values.length(), 1)
      assert_eq(values[0], 65)
    }
    None => fail("expected /A in glyph_hashes")
  }
  let reverse = @pdfglyphlist.PdfGlyphList::new().reverse_glyph_hashes()
  match reverse.get([65]) {
    Some(name) => assert_eq(name, "/A")
    None => fail("expected reverse glyph for 65")
  }
  match @pdfglyphlist.name_to_pdf_hashes.get("/A") {
    Some(code) => assert_eq(code, 65)
    None => fail("expected /A in name_to_pdf_hashes")
  }
  match @pdfglyphlist.reverse_name_to_pdf_hashes.get(65) {
    Some(name) => assert_eq(name, "/A")
    None => fail("expected 65 in reverse_name_to_pdf_hashes")
  }
}
