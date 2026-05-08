///|
test "lex_name decodes hex escapes" {
  let input = @pdfio.Input::of_string("/A#20B")
  let token = @pdfsyntax.PdfSyntax::new().lex_name(input)
  match token {
    @pdfgenlex.Token::LexName(name) => assert_eq(name, "/A B")
    _ => fail("expected LexName")
  }
}

///|
test "lex_number parses int and real" {
  let int_input = @pdfio.Input::of_string("123 ")
  match @pdfsyntax.PdfSyntax::new().lex_number(int_input) {
    @pdfgenlex.Token::LexInt(123) => ()
    _ => fail("expected LexInt 123")
  }
  let real_input = @pdfio.Input::of_string("-3.5")
  match @pdfsyntax.PdfSyntax::new().lex_number(real_input) {
    @pdfgenlex.Token::LexReal(v) => assert_true((v - -3.5).abs() < 0.000001)
    _ => fail("expected LexReal -3.5")
  }
}

///|
test "lex_string handles escapes and nesting" {
  let input = @pdfio.Input::of_string("(a\\n(b))")
  let token = @pdfsyntax.PdfSyntax::new().lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "a\n(b)")
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring reads hex bytes" {
  let input = @pdfio.Input::of_string("<48656c6c6f>")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "Hello")
    _ => fail("expected LexString")
  }
}

///|
test "lex_name errors on truncated hex escape" {
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    @pdfio.Input::of_string("/A#1"),
  )
  assert_true(res is Err(_))
}

///|
test "lex_name errors on invalid hex escape" {
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    @pdfio.Input::of_string("/A#GG"),
  )
  assert_true(res is Err(_))
}

///|
test "lex_number drops extra leading dash" {
  let input = @pdfio.Input::of_string("--2")
  match @pdfsyntax.PdfSyntax::new().lex_number(input) {
    @pdfgenlex.Token::LexInt(-2) => ()
    _ => fail("expected LexInt -2")
  }
}

///|
test "lex_string handles octal escape with rewind" {
  let input = @pdfio.Input::of_string("(\\12X)")
  let token = @pdfsyntax.PdfSyntax::new().lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "\nX")
    _ => fail("expected LexString")
  }
}

///|
test "lex_string handles short octal escape" {
  let input = @pdfio.Input::of_string("(\\1Z)")
  let token = @pdfsyntax.PdfSyntax::new().lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(value) => {
      match value.get_char(0) {
        Some(ch) => assert_eq(ch.to_int(), 1)
        _ => fail("expected first char")
      }
      match value.get_char(1) {
        Some('Z') => ()
        _ => fail("expected trailing Z")
      }
    }
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring handles odd nibble at EOF" {
  let input = @pdfio.Input::of_string("<4")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(value) => assert_eq(value, "@")
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring errors on invalid hex digit" {
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_hexstring(
    @pdfio.Input::of_string("<GG>"),
  )
  assert_true(res is Err(_))
}
