///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "input utils handle EOF and rewind paths" {
  let syn = @pdfsyntax.PdfSyntax::new()
  let empty = @pdfio.Input::of_string("", source="empty")
  assert_eq(syn.getuntil(true, _ => true, empty).length(), 0)
  let input_chars = @pdfio.Input::of_string("ab ", source="getuntil")
  let chars = syn.getuntil(true, c => c == ' ', input_chars)
  assert_eq(chars.map(c => c.to_string()).join(""), "ab")
  match (input_chars.input_byte)() {
    b if b == ' '.to_int() => ()
    _ => fail("expected getuntil rewind")
  }
  let input = @pdfio.Input::of_string("abc", source="rewind")
  let out = syn.getuntil_string(true, c => c == 'a', input)
  assert_eq(out, "")
  // Rewind should have put 'a' back.
  match (input.input_byte)() {
    b if b == 'a'.to_int() => ()
    _ => fail("expected rewind")
  }
  assert_is_err(
    try? syn.getuntil_string(
      false,
      _ => false,
      @pdfio.Input::of_string("abc", source="eof-string"),
    ),
  )
  let eof_fail = @pdfio.Input::of_string("", source="eof")
  assert_is_err(try? syn.ignoreuntil(false, _ => true, eof_fail))
  let line = syn.input_line(@pdfio.Input::of_string("", source="line"))
  assert_eq(line, "")
  assert_is_err(
    try? syn.backline(@pdfio.Input::of_string("", source="backline")),
  )
}

///|
test "lexer covers name, number, string, and chunk error paths" {
  let syn = @pdfsyntax.PdfSyntax::new()

  // Bad name hex escape.
  assert_is_err(
    try? syn.lex_name(@pdfio.Input::of_string("/Name#GG", source="name")),
  )

  // Number parsing fallbacks.
  match syn.lex_number(@pdfio.Input::of_string("1e-3", source="real")) {
    @pdfgenlex.Token::LexReal(_) => ()
    other => fail("expected LexReal, got \{syn.string_of_lexeme(other)}")
  }
  match syn.lex_number(@pdfio.Input::of_string("nan", source="nan")) {
    @pdfgenlex.Token::LexReal(_) => ()
    other => fail("expected LexReal, got \{syn.string_of_lexeme(other)}")
  }
  match syn.lex_number(@pdfio.Input::of_string("1.2.3", source="bad")) {
    @pdfgenlex.Token::LexNone => ()
    other => fail("expected LexNone, got \{syn.string_of_lexeme(other)}")
  }
  match syn.lex_number(@pdfio.Input::of_string("12a", source="fallback")) {
    @pdfgenlex.Token::LexNone => ()
    other => fail("expected LexNone, got \{syn.string_of_lexeme(other)}")
  }

  // lex_string expects '('.
  assert_is_err(
    try? syn.lex_string(@pdfio.Input::of_string("abc", source="string")),
  )

  // lex_string escape unexpected EOF.
  assert_is_err(
    try? syn.lex_string(@pdfio.Input::of_string("(\\", source="eof-string")),
  )

  // lex_string CR escape path with rewind.
  let token = syn.lex_string(@pdfio.Input::of_string("(\\\rX)", source="cr"))
  match token {
    @pdfgenlex.Token::LexString(_) => ()
    _ => fail("expected string token")
  }

  // lex_string octal parse error is tolerated.
  let token2 = syn.lex_string(
    @pdfio.Input::of_string("(\\888)", source="octal"),
  )
  match token2 {
    @pdfgenlex.Token::LexString(_) => ()
    _ => fail("expected string token")
  }

  // read_chunk failure rewinds and raises.
  assert_is_err(
    try? syn.read_chunk(5, @pdfio.Input::of_string("abc", source="chunk")),
  )
}

///|
test "lex_stream_data handles malformed and rewind cases" {
  let syn = @pdfsyntax.PdfSyntax::new()
  // CR not followed by LF triggers a rewind.
  match
    syn.lex_stream_data(
      @pdfio.Input::of_string("\rX0123456789\nendstream", source="cr-stream"),
      999,
      false,
    ) {
    @pdfgenlex.Token::LexStream(_) => ()
    other => fail("expected LexStream, got \{syn.string_of_lexeme(other)}")
  }
  // Non-newline char triggers rewind branch too.
  match
    syn.lex_stream_data(
      @pdfio.Input::of_string(" X0123456789\nendstream", source="rewind-stream"),
      999,
      false,
    ) {
    @pdfgenlex.Token::LexStream(_) => ()
    other => fail("expected LexStream, got \{syn.string_of_lexeme(other)}")
  }
}

///|
test "lex_keyword covers R and unknown keywords" {
  let syn = @pdfsyntax.PdfSyntax::new()
  match syn.lex_keyword(@pdfio.Input::of_string("R", source="kw-r")) {
    @pdfgenlex.Token::LexR => ()
    other => fail("expected LexR, got \{syn.string_of_lexeme(other)}")
  }
  match syn.lex_keyword(@pdfio.Input::of_string("nonsense", source="kw-none")) {
    @pdfgenlex.Token::LexNone => ()
    other => fail("expected LexNone, got \{syn.string_of_lexeme(other)}")
  }
}

///|
test "lex_stream errors when previous lexemes are not a dictionary" {
  let syn = @pdfsyntax.PdfSyntax::new()
  let res : Result[@pdfgenlex.Token, Error] = try? syn.lex_stream(
    @pdfio.Input::of_string("stream\nabc", source="stream-bad"),
    [@pdfgenlex.Token::LexInt(1)],
    _k => [],
    false,
  )
  assert_is_err(res)
}

///|
test "lex_stream falls back to malformed stream scan on missing /Length" {
  let syn = @pdfsyntax.PdfSyntax::new()
  let dict_lexemes = syn.lex_dictionary(
    false,
    @pdfio.Input::of_string("<< /Type /X >>", source="stream-dict"),
  )
  match
    syn.lex_stream(
      @pdfio.Input::of_string("stream\nABCDEF", source="stream-no-end"),
      dict_lexemes,
      _k => [],
      false,
    ) {
    @pdfgenlex.Token::LexStream(_) => ()
    other => fail("expected LexStream, got \{syn.string_of_lexeme(other)}")
  }
}

///|
test "lex_next stops on short 's' sequences" {
  let syn = @pdfsyntax.PdfSyntax::new()
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let prev : Array[@pdfgenlex.Token] = []
  let t1 = syn.lex_next(
    dict_level,
    array_level,
    true,
    @pdfio.Input::of_string("st", source="lex-next-st"),
    prev,
    false,
    _ => [],
  )
  assert_true(t1 is @pdfgenlex.Token::StopLexing)
  let t2 = syn.lex_next(
    dict_level,
    array_level,
    true,
    @pdfio.Input::of_string("sta", source="lex-next-sta"),
    prev,
    false,
    _ => [],
  )
  assert_true(t2 is @pdfgenlex.Token::StopLexing)
}
