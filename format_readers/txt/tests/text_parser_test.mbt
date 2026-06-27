///|
test "text parser handles bom and newline styles" {
  let doc = @txt.parse_text_document("\u{FEFF}a\r\nb\r\n")
  assert_true(doc.newline_style == @txt.TextNewlineStyle::CRLF)
  assert_eq(doc.lines.length(), 2)
  assert_eq(doc.paragraphs.length(), 1)
  assert_eq(doc.paragraphs[0].text, "a b")
}

///|
test "text parser handles lf cr and unicode" {
  let lf = @txt.parse_text_document("你\n好\n\nworld")
  assert_true(lf.newline_style == @txt.TextNewlineStyle::LF)
  assert_eq(lf.paragraphs.length(), 2)

  let cr = @txt.parse_text_document("a\rb\r\rc")
  assert_true(cr.newline_style == @txt.TextNewlineStyle::CR)
  assert_eq(cr.paragraphs.length(), 2)
}

///|
test "text inspect exposes counts and low-signal marker" {
  let doc = @txt.parse_text_document("hi")
  let report = @txt.inspect_text_document(doc)
  assert_eq(report.line_count, 1)
  assert_eq(report.paragraph_count, 1)
  assert_eq(report.is_low_signal, true)
}

///|
test "text parser reports mixed newline and empty text deterministically" {
  let mixed = @txt.parse_text_document("a\r\nb\nc\r")
  assert_true(mixed.newline_style == @txt.TextNewlineStyle::Mixed)

  let empty = @txt.parse_text_document("")
  let empty_report = @txt.inspect_text_document(empty)
  assert_eq(empty_report.char_count, 0)
  assert_eq(empty_report.line_count, 0)
  assert_eq(empty_report.paragraph_count, 0)
  assert_true(empty_report.is_empty)
}

///|
test "text open bytes fails closed on invalid utf8" {
  let ok = @txt.open_text_document(
    Bytes::from_array([228, 189, 160, 229, 165, 189]),
  )
  let ok_report = @txt.inspect_text_document(ok)
  assert_true(ok_report.byte_count == Some(6))

  let bad_result = try
    @txt.open_text_document(Bytes::from_array([195, 40])) |> Ok
  catch {
    e => Err(e)
  }
  assert_true(bad_result is Err(_))

  let info = @txt.classify_text_error(
    @txt.TextError::Utf8DecodeFailed("invalid utf8"),
  )
  assert_true(info.kind == @txt.TextErrorKind::Utf8DecodeFailed)
}
