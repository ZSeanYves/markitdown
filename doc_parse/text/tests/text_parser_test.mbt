///|
test "text parser handles bom and newline styles" {
  let doc = @text.parse_text_document("\u{FEFF}a\r\nb\r\n")
  assert_true(doc.newline_style == @text.TextNewlineStyle::CRLF)
  assert_eq(doc.lines.length(), 2)
  assert_eq(doc.paragraphs.length(), 1)
  assert_eq(doc.paragraphs[0].text, "a b")
}

///|
test "text parser handles lf cr and unicode" {
  let lf = @text.parse_text_document("你\n好\n\nworld")
  assert_true(lf.newline_style == @text.TextNewlineStyle::LF)
  assert_eq(lf.paragraphs.length(), 2)

  let cr = @text.parse_text_document("a\rb\r\rc")
  assert_true(cr.newline_style == @text.TextNewlineStyle::CR)
  assert_eq(cr.paragraphs.length(), 2)
}

///|
test "text inspect exposes counts and low-signal marker" {
  let doc = @text.parse_text_document("hi")
  let report = @text.inspect_text_document(doc)
  assert_eq(report.line_count, 1)
  assert_eq(report.paragraph_count, 1)
  assert_eq(report.is_low_signal, true)
}

///|
test "text open bytes fails closed on invalid utf8" {
  let ok = @text.open_text_document(
    Bytes::from_array([228, 189, 160, 229, 165, 189]),
  )
  let ok_report = @text.inspect_text_document(ok)
  assert_true(ok_report.byte_count == Some(6))

  let bad_result = try? @text.open_text_document(Bytes::from_array([195, 40]))
  assert_true(bad_result is Err(_))

  let info = @text.classify_text_error(
    @text.TextError::Utf8DecodeFailed("invalid utf8"),
  )
  assert_true(info.kind == @text.TextErrorKind::Utf8DecodeFailed)
}
