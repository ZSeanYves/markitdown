///|
test "@pdfsyntax.PdfSyntax::new().lex_keyword rewinds endobj suffix" {
  let input = @pdfio.Input::of_string("endobj123 0 obj")
  let token = @pdfsyntax.PdfSyntax::new().lex_keyword(input)
  match token {
    @pdfgenlex.Token::LexEndObj => ()
    _ => fail("expected LexEndObj")
  }
  match @pdfsyntax.PdfSyntax::new().lex_number(input) {
    @pdfgenlex.Token::LexInt(123) => ()
    _ => fail("expected 123")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_next returns LexNone for unknown uppercase" {
  let input = @pdfio.Input::of_string("T")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfsyntax.PdfSyntax::new().lex_next(
    dict_level,
    array_level,
    false,
    input,
    previous,
    true,
    _ => [],
  )
  match token {
    @pdfgenlex.Token::LexNone => ()
    _ => fail("expected LexNone")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_next recovers from lex errors" {
  let input = @pdfio.Input::of_string("(")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfe.with_logger(_ => (), fn() {
    @pdfsyntax.PdfSyntax::new().lex_next(
      dict_level,
      array_level,
      false,
      input,
      previous,
      true,
      _ => [],
    )
  })
  match token {
    @pdfgenlex.Token::StopLexing => ()
    _ => fail("expected StopLexing")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring rejects invalid hex" {
  let input = @pdfio.Input::of_string("<G>")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_hexstring(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_hexstring failure")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring pads odd nibble" {
  let input = @pdfio.Input::of_string("<F>")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 1)
      assert_eq(bytes[0].to_int(), 0xF0)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring ignores whitespace" {
  let input = @pdfio.Input::of_string("<0F 0A>")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 2)
      assert_eq(bytes[0].to_int(), 0x0F)
      assert_eq(bytes[1].to_int(), 0x0A)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_dictionary minus_one stops after closing dict" {
  let input = @pdfio.Input::of_string("/Type /Example >> trailer")
  let tokens = @pdfsyntax.PdfSyntax::new().lex_dictionary(true, input)
  if tokens.length() == 0 {
    fail("expected tokens")
  }
  let last = tokens[tokens.length() - 1]
  match last {
    @pdfgenlex.Token::LexRightDict => ()
    _ => fail("expected closing dict")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_name rejects invalid hex" {
  let input = @pdfio.Input::of_string("/#GZ")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_name failure")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_name rejects truncated hex" {
  let input = @pdfio.Input::of_string("/#1")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_name failure")
  }
}
