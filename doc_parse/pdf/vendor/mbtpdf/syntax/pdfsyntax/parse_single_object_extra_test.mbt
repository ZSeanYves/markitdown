///|
test "parse_single_object preserves widget dictionary boundary keys" {
  let syntax = @pdfsyntax.PdfSyntax::new()
  let source = "<</AP<</N 75 0 R>>/DA(/MyriadPro-Regular 10.00 Tf 0 g)/F 4/FT/Tx/MK<<>>/P 48 0 R/Parent 17 0 R/Q 0/Rect[147.171 751.323 591.465 771.165]/StructParent 0/Subtype/Widget/T(\u{00FE}\u{00FF}\u{0000}T\u{0000}e\u{0000}k\u{0000}s\u{0000}t\u{0000}v\u{0000}e\u{0000}l\u{0000}d\u{0000}1\u{0000}[\u{0000}0\u{0000}])/TU(Single line, unlimited length)/Type/Annot/V(Lorem ipsum dolor sit amet, consectetur adipiscing elit.)>>"
  let obj = syntax.parse_single_object(source)
  let dict = match obj {
    @pdf.PdfObject::Dictionary(entries) => @pdf.PdfObject::Dictionary(entries)
    _ => fail("expected parsed dictionary")
  }

  if dict.lookup_immediate("/AP") is None {
    fail("expected /AP entry to survive parse_single_object")
  }
  match dict.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) => fail("expected /V string, got " + other.to_string())
    None => fail("expected /V entry to survive parse_single_object")
  }

  let input = @pdfio.Input::of_bytes(@pdfio.bytes_of_string(source))
  let bytes_tokens = syntax.lex_object_at(true, input, true, _ => [])
  let (_, bytes_obj) = syntax.parse(bytes_tokens)
  let bytes_dict = match bytes_obj {
    @pdf.PdfObject::Dictionary(entries) => @pdf.PdfObject::Dictionary(entries)
    _ => fail("expected parsed byte-input dictionary")
  }
  if bytes_dict.lookup_immediate("/AP") is None {
    fail("expected /AP entry to survive byte-input parse")
  }
  match bytes_dict.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) =>
      fail("expected byte-input /V string, got " + other.to_string())
    None => fail("expected /V entry to survive byte-input parse")
  }
}
