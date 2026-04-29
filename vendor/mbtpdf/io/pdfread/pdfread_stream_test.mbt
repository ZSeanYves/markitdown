///|
test "lex_stream_data reads stream bytes" {
  let input = @pdfio.Input::of_string("stream\nABCendstream")
  match @pdfsyntax.PdfSyntax::new().lex_stream_data(input, 3, true) {
    @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes)) =>
      assert_eq(@pdfio.string_of_bytes(bytes), "ABC")
    _ => fail("expected stream bytes")
  }
}

///|
test "lex_stream_data returns ToGet for unread stream" {
  let input = @pdfio.Input::of_string("stream\nXYZendstream")
  match @pdfsyntax.PdfSyntax::new().lex_stream_data(input, 3, false) {
    @pdfgenlex.Token::LexStream(@pdf.Stream::ToGet(toget)) =>
      assert_eq(@pdf.ToGet::length(toget), 3)
    _ => fail("expected ToGet stream")
  }
}

///|
test "lex_stream_data falls back for malformed length" {
  let input = @pdfio.Input::of_string("stream\nendstreamXXXX")
  match @pdfsyntax.PdfSyntax::new().lex_stream_data(input, 2, true) {
    @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes)) =>
      assert_eq(@pdfio.string_of_bytes(bytes), "")
    _ => fail("expected stream bytes")
  }
}

///|
test "lex_stream_data fallback ignores read_data flag" {
  let input = @pdfio.Input::of_string("stream\nendstreamXXXX")
  match @pdfsyntax.PdfSyntax::new().lex_stream_data(input, 2, false) {
    @pdfgenlex.Token::LexStream(@pdf.Stream::Got(bytes)) =>
      assert_eq(@pdfio.string_of_bytes(bytes), "")
    _ => fail("expected stream bytes")
  }
}

///|
test "lex_dictionary parses nested dictionary" {
  let input = @pdfio.Input::of_string("<< /A 1 /B << /C 2 >> >>")
  let tokens = @pdfsyntax.PdfSyntax::new().lex_dictionary(false, input)
  let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(tokens)
  match (@pdf.Pdf::empty().lookup_direct("/B", parsed) : @pdf.PdfObject?) {
    Some(Dictionary(_)) => ()
    _ => fail("expected nested dictionary")
  }
}

///|
test "lex_dictionary minus_one accepts preconsumed marker" {
  let input = @pdfio.Input::of_string("<< /A 1 >>")
  input.nudge()
  input.nudge()
  let tokens = @pdfsyntax.PdfSyntax::new().lex_dictionary(true, input)
  let full = Array::new(capacity=tokens.length() + 1)
  full.push(@pdfgenlex.Token::LexLeftDict)
  for t in tokens {
    full.push(t)
  }
  let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(full)
  match (@pdf.Pdf::empty().lookup_direct("/A", parsed) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected /A entry")
  }
}

///|
test "lex_dictionary errors on unexpected token" {
  let res : Result[Array[@pdfgenlex.Token], Error] = try? @pdfe.with_logger(
    _ => (),
    fn() {
      @pdfsyntax.PdfSyntax::new().lex_dictionary(
        false,
        @pdfio.Input::of_string("<< @ >>"),
      )
    },
  )
  assert_true(res is Err(_))
}

///|
test "lex_dictionary stops on stream without dict" {
  let tokens = @pdfe.with_logger(_ => (), fn() {
    @pdfsyntax.PdfSyntax::new().lex_dictionary(
      false,
      @pdfio.Input::of_string("stream\nendstreamXXXX"),
    )
  })
  assert_true(tokens.exists(t => t is @pdfgenlex.Token::StopLexing))
}
