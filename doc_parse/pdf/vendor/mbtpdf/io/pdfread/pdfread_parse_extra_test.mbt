///|
test "parse errors on non-name dictionary key" {
  let tokens = [
    @pdfgenlex.Token::LexLeftDict,
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexInt(2),
    @pdfgenlex.Token::LexRightDict,
  ]
  let res : Result[(Int, @pdf.PdfObject), Error] = try
    @pdfsyntax.PdfSyntax::new().parse(tokens) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "parse errors on invalid array element" {
  let tokens = [@pdfgenlex.Token::LexLeftSquare, @pdfgenlex.Token::LexRightDict]
  let res : Result[(Int, @pdf.PdfObject), Error] = try
    @pdfsyntax.PdfSyntax::new().parse(tokens) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}

///|
test "parse returns null for empty object" {
  let tokens = [
    @pdfgenlex.Token::LexInt(10),
    @pdfgenlex.Token::LexInt(0),
    @pdfgenlex.Token::LexObj,
    @pdfgenlex.Token::LexEndObj,
  ]
  let (objnum, obj) = @pdfsyntax.PdfSyntax::new().parse(tokens)
  assert_eq(objnum, 10)
  match (obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null object")
  }
}

///|
test "parse skips unmatched stream pattern" {
  let tokens = [
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexInt(0),
    @pdfgenlex.Token::LexObj,
    @pdfgenlex.Token::LexBool(false),
    @pdfgenlex.Token::LexInt(2),
    @pdfgenlex.Token::LexInt(3),
    @pdfgenlex.Token::LexInt(4),
  ]
  let (objnum, obj) = @pdfsyntax.PdfSyntax::new().parse(tokens)
  assert_eq(objnum, 1)
  match (obj : @pdf.PdfObject) {
    Boolean(false) => ()
    _ => fail("expected boolean object")
  }
}

///|
test "parse returns null when failure_is_ok" {
  let tokens = [@pdfgenlex.Token::LexObj, @pdfgenlex.Token::LexEndObj]
  let (objnum, obj) = @pdfsyntax.PdfSyntax::new().parse(
    tokens,
    failure_is_ok=true,
  )
  assert_eq(objnum, 0)
  match (obj : @pdf.PdfObject) {
    Null => ()
    _ => fail("expected null fallback object")
  }
}

///|
test "lex_object_at parses consecutive object-stream-like dictionaries independently" {
  let data = "<</AP<</N 75 0 R>>/TU(One)/Type/Annot/V(A)>><</AP<</N 74 0 R>>/TU(Two)/Type/Annot/V(B)>>"
  let bytes = @pdfio.bytes_of_string(data)
  let first_input = @pdfio.Input::of_bytes(bytes[:44].to_owned())
  let first_tokens = @pdfsyntax.PdfSyntax::new().lex_object_at(
    true,
    first_input,
    true,
    _ => [],
  )
  let (_, first_obj) = @pdfsyntax.PdfSyntax::new().parse(first_tokens)
  match @pdf.Pdf::empty().lookup_direct("/V", first_obj) {
    Some(@pdf.PdfObject::String("A")) => ()
    _ => fail("expected first object /V")
  }

  let second_input = @pdfio.Input::of_bytes(bytes[44:].to_owned())
  let second_tokens = @pdfsyntax.PdfSyntax::new().lex_object_at(
    true,
    second_input,
    true,
    _ => [],
  )
  let (_, second_obj) = @pdfsyntax.PdfSyntax::new().parse(second_tokens)
  match @pdf.Pdf::empty().lookup_direct("/V", second_obj) {
    Some(@pdf.PdfObject::String("B")) => ()
    _ => fail("expected second object /V")
  }
}
