///|
test "parse errors on non-name dictionary key" {
  let tokens = [
    @pdfgenlex.Token::LexLeftDict,
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexInt(2),
    @pdfgenlex.Token::LexRightDict,
  ]
  let res : Result[(Int, @pdf.PdfObject), Error] = try? @pdfsyntax.PdfSyntax::new().parse(
    tokens,
  )
  assert_true(res is Err(_))
}

///|
test "parse errors on invalid array element" {
  let tokens = [@pdfgenlex.Token::LexLeftSquare, @pdfgenlex.Token::LexRightDict]
  let res : Result[(Int, @pdf.PdfObject), Error] = try? @pdfsyntax.PdfSyntax::new().parse(
    tokens,
  )
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
