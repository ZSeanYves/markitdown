///|
test "lex quoted string with escaped quote" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("\"a\\\"b\"")
  if tokens.length() != 1 {
    fail("expected single token")
  }
  match tokens[0] {
    @pdfgenlex.Token::LexString(s) => assert_eq(s, "a\"b")
    _ => fail("expected LexString token")
  }
}

///|
test "string_of_tokens formats values" {
  let tokens = [
    @pdfgenlex.Token::LexInt(1),
    @pdfgenlex.Token::LexReal(1.5),
    @pdfgenlex.Token::LexName("abc"),
  ]
  let rendered = @pdfgenlex.PdfGenLex::new().string_of_tokens(tokens)
  assert_true(rendered.contains("Int 1"))
  assert_true(rendered.contains("Float 1.5"))
  assert_true(rendered.contains("Ident abc"))
}

///|
test "lex_string parses numbers and names" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("10 -5 3.14 -2.5e2 name")
  assert_eq(tokens.length(), 5)
  match tokens[0] {
    @pdfgenlex.Token::LexInt(10) => ()
    _ => fail("expected LexInt 10")
  }
  match tokens[1] {
    @pdfgenlex.Token::LexInt(-5) => ()
    _ => fail("expected LexInt -5")
  }
  match tokens[2] {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - 3.14).abs() < 0.000001)
    _ => fail("expected LexReal 3.14")
  }
  match tokens[3] {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - -250.0).abs() < 0.000001)
    _ => fail("expected LexReal -250.0")
  }
  match tokens[4] {
    @pdfgenlex.Token::LexName("name") => ()
    _ => fail("expected LexName name")
  }
}

///|
test "lex_string ignores whitespace-only input" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string(" \n\t ")
  assert_eq(tokens.length(), 0)
}

///|
test "string_of_token covers extra variants" {
  assert_eq(
    @pdfgenlex.PdfGenLex::new().string_of_token(
      @pdfgenlex.Token::LexString("hi"),
    ),
    "String hi",
  )
  assert_eq(
    @pdfgenlex.PdfGenLex::new().string_of_token(@pdfgenlex.Token::LexNull),
    "Nothing",
  )
  assert_eq(
    @pdfgenlex.PdfGenLex::new().string_of_token(@pdfgenlex.Token::LexLeftDict),
    "GenLexNone",
  )
}

///|
test "string_of_tokens handles empty list" {
  assert_eq(@pdfgenlex.PdfGenLex::new().string_of_tokens([]), "")
}

///|
test "lex_string tokenizes delimiter characters" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("()<>[]{}%/")
  let expected = ["(", ")", "<", ">", "[", "]", "{", "}", "%", "/"]
  assert_eq(tokens.length(), expected.length())
  for i in 0..<expected.length() {
    match tokens[i] {
      @pdfgenlex.Token::LexName(value) => assert_eq(value, expected[i])
      _ => fail("expected LexName token")
    }
  }
}

///|
test "lex_string handles malformed strings" {
  let cases = [("\"x", ""), ("\"a\\", ""), ("\"a\\n\"", "a\\n")]
  for pair in cases {
    let tokens = @pdfgenlex.PdfGenLex::new().lex_string(pair.0)
    if tokens.length() != 1 {
      fail("expected single token")
    }
    match tokens[0] {
      @pdfgenlex.Token::LexString(value) => assert_eq(value, pair.1)
      _ => fail("expected LexString token")
    }
  }
}

///|
test "lex_string treats invalid exponential as name" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("1e--2")
  if tokens.length() != 1 {
    fail("expected single token")
  }
  match tokens[0] {
    @pdfgenlex.Token::LexName("1e--2") => ()
    _ => fail("expected LexName token")
  }
}

///|
test "lex_string parses huge integer as real" {
  let big = "999999999999999999999999999999999999999999"
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string(big)
  if tokens.length() != 1 {
    fail("expected single token")
  }
  match tokens[0] {
    @pdfgenlex.Token::LexReal(_) => ()
    _ => fail("expected LexReal token")
  }
}

///|
test "lex_string handles double dash numbers" {
  let tokens = @pdfgenlex.PdfGenLex::new().lex_string("--5")
  if tokens.length() != 1 {
    fail("expected single token")
  }
  match tokens[0] {
    @pdfgenlex.Token::LexInt(-5) => ()
    _ => fail("expected LexInt -5")
  }
}
