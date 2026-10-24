///|
test "TXT shared cleanup normalizes line endings spaces ligatures and zero-width chars" {
  assert_true(!text_text_needs_shared_cleanup("plain\ntext"))
  let dirty = "a\r\nb\rc\t" +
    "\u{00A0}\u{2007}\u{2008}\u{2009}\u{200A}\u{202F}\u{205F}\u{3000}" +
    "\u{00AD}\u{200B}\u{FEFF}" +
    "ﬀﬁﬂﬃﬄﬅﬆ"
  assert_true(text_text_needs_shared_cleanup(dirty))
  assert_eq(normalize_text_line_endings("a\r\nb\rc\n"), "a\nb\nc\n")
  let normalized = normalize_text_source(dirty)
  assert_true(normalized.has_prefix("a\nb\nc "))
  assert_true(!normalized.contains("\r"))
  assert_true(!normalized.contains("\u{00AD}"))
  assert_true(!normalized.contains("\u{200B}"))
  assert_true(normalized.has_suffix("fffiflffifflstst"))
  assert_eq(normalize_text_source("plain"), "plain")
}

///|
async test "TXT prepare preserves valid source and rejects invalid UTF8" {
  let valid = @input.input_from_text_with_format(
    "one\r\ntwo",
    "valid.txt",
    Some(Txt),
  )
  match prepare_text_document_from_source(valid) {
    Ok(prepared) => {
      assert_true(prepared.document is Some(_))
      assert_true(prepared.inspect.unwrap().line_count == 2)
      assert_true(prepared.parse_error is None)
    }
    Err(error) => fail(error)
  }
  let invalid = @input.input_from_bytes_with_format(
    Bytes::from_array([0xC3, 0x28].map(Int32::to_byte)),
    "invalid.txt",
    Some(Txt),
  )
  match prepare_text_document_from_source(invalid) {
    Ok(_) =>
      fail("invalid encoding must not become a successful prepared placeholder")
    Err(error) => assert_eq(error, "utf8 decode failed")
  }
}

///|
async test "TXT prepare rejects malformed UTF16 BOM payloads instead of successful placeholders" {
  for bytes in [b"\xff\xfe\x00\xd8", b"\xff\xfeA", b"\xfe\xff\xdc\x00"] {
    let source = @input.input_from_bytes_with_format(
      bytes,
      "invalid-utf16.txt",
      Some(Txt),
    )
    assert_true(prepare_text_document_from_source(source) is Err(_))
    assert_true(
      (txt_parser().parse)(source, @parser.new_parse_context(Txt)) is Err(_),
    )
  }
}
