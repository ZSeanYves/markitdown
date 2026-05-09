///|
test "getuntil functions error on EOF when delimiter required" {
  let input = @pdfio.Input::of_string("abc")
  let res_chars : Result[Array[Char], Error] = try? @pdfsyntax.PdfSyntax::new().getuntil(
    false,
    c => c == 'z',
    input,
  )
  assert_true(res_chars is Err(_))
  let input2 = @pdfio.Input::of_string("q")
  let res_ignore : Result[Unit, Error] = try? @pdfsyntax.PdfSyntax::new().ignoreuntil(
    false,
    c => c == 'z',
    input2,
  )
  assert_true(res_ignore is Err(_))
}

///|
test "getuntil_white_or_delimiter stops at delimiter" {
  let input = @pdfio.Input::of_string("abc/def")
  let out = @pdfsyntax.PdfSyntax::new().getuntil_white_or_delimiter_string(
    input,
  )
  assert_eq(out, "abc")
}

///|
test "lex_string handles escapes and octal" {
  let input = @pdfio.Input::of_string("(A\\053B\\(C\\)\\\\)")
  let token = @pdfsyntax.PdfSyntax::new().lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      assert_true(s.contains("A+B"))
      assert_true(s.contains("(C)"))
      assert_true(s.contains("\\"))
    }
    _ => fail("expected LexString")
  }
}

///|
test "lex_string handles line continuation and octal digits" {
  let input = @pdfio.Input::of_string("(A\\\nB\\141)")
  let token = @pdfsyntax.PdfSyntax::new().lex_string(input)
  match token {
    @pdfgenlex.Token::LexString(s) => assert_eq(s, "ABa")
    _ => fail("expected LexString")
  }
}

///|
test "lex_hexstring handles odd and invalid digits" {
  let odd = @pdfsyntax.PdfSyntax::new().lex_hexstring(
    @pdfio.Input::of_string("<4>"),
  )
  match odd {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes[0].to_int(), 64)
    }
    _ => fail("expected LexString")
  }
  let bad : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_hexstring(
    @pdfio.Input::of_string("<GG>"),
  )
  assert_true(bad is Err(_))
}

///|
test "lex_comment consumes until newline" {
  let token = @pdfsyntax.PdfSyntax::new().lex_comment(
    @pdfio.Input::of_string("%hi\n"),
  )
  match token {
    @pdfgenlex.Token::LexComment(_) => ()
    _ => fail("expected comment token")
  }
}

///|
test "lex_stream_data handles well-formed and malformed streams" {
  let ok_input = @pdfio.Input::of_string("\nABCendstream")
  let ok = @pdfsyntax.PdfSyntax::new().lex_stream_data(ok_input, 3, true)
  match ok {
    @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes)) =>
      assert_eq(@pdfio.string_of_bytes(bytes), "ABC")
    _ => fail("expected LexStream Got")
  }
  let malformed_input = @pdfio.Input::of_string("\nABCXYZendstreamXXXXXXXXXXX")
  let malformed = @pdfsyntax.PdfSyntax::new().lex_stream_data(
    malformed_input, 3, true,
  )
  match malformed {
    @pdfgenlex.Token::LexStream(_) => ()
    _ => fail("expected LexStream for malformed data")
  }
}

///|
test "lex_stream_data returns ToGet when read_data is false" {
  let input = @pdfio.Input::of_string("\nABCendstream")
  let token = @pdfsyntax.PdfSyntax::new().lex_stream_data(input, 3, false)
  match token {
    @pdfgenlex.Token::LexStream(@pdf.Stream::ToGet(_)) => ()
    _ => fail("expected LexStream ToGet")
  }
}
