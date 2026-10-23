///|
fn units_xml_reader(bytes : Bytes) -> @input.InputSource {
  @input.input_from_reader_with_format(
    @input.make_async_input_reader(
      async fn(offset, length) {
        @async.pause()
        let start = offset.to_int()
        let end = (start + length.min(1)).min(bytes.length())
        Ok(bytes.exact_view(start~, end~).to_owned())
      },
      size=bytes.length().to_int64(),
    ),
    "units.xml",
    Some(Xml),
  )
}

///|
fn units_xml_fallback_range(
  parsed : @parser.ParseResult,
  text : String,
) -> Unit raise {
  let reference = parsed.document.unwrap().blocks[0].source_ref.unwrap()
  assert_eq(reference.byte_start, Some(0))
  assert_eq(reference.byte_end, Some(@utf8.encode(text).length()))
  assert_eq(reference.extra.get("byte_basis"), Some("normalized_decoded_utf8"))
}

///|
test "XML both malformed fallback shapes count the actual UTF8 view not UTF16 units" {
  let text = "<r>é😀\r\n<broken"
  let source = @input.input_from_text(text)
  units_xml_fallback_range(
    malformed_xml_parse_result(
      source,
      text,
      @core.empty_diagnostics(),
      @dxml.XmlError::ParseError("fixture"),
    ),
    text,
  )
  units_xml_fallback_range(
    malformed_xml_text_parse_result(
      source,
      text,
      @core.empty_diagnostics(),
      "fixture policy",
    ),
    text,
  )
  assert_true(@utf8.encode(text).length() != text.length())
}

///|
async test "XML Text Bytes single byte Reader BOM and Latin1 keep local decoded ranges distinct from raw extent" {
  let text = "\u{FEFF}<r>é😀\r\n<broken"
  let normalized = "<r>é😀\r\n<broken"
  let bytes = @utf8.encode(text)
  for
    source in [
      @input.input_from_text_with_format(text, "units.xml", Some(Xml)),
      @input.input_from_bytes_with_format(bytes, "units.xml", Some(Xml)),
      units_xml_reader(bytes),
    ] {
    let parsed = (xml_parser().parse)(source, @parser.new_parse_context(Xml)).unwrap()
    units_xml_fallback_range(parsed, normalized)
    assert_true(@utf8.encode(normalized).length() < bytes.length())
  }
  let prefix = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><r>"
  let latin1 = @utf8.encode(prefix) + b"\xE9\r\n<broken"
  let decoded = prefix + "é\r\n<broken"
  for
    source in [
      @input.input_from_bytes_with_format(latin1, "latin1.xml", Some(Xml)),
      units_xml_reader(latin1),
    ] {
    let parsed = (xml_parser().parse)(source, @parser.new_parse_context(Xml)).unwrap()
    units_xml_fallback_range(parsed, decoded)
    assert_true(@utf8.encode(decoded).length() > latin1.length())
  }
  let utf16 = b"\xFF\xFE<\x00r\x00>\x00\xE9\x00"
  assert_true(
    (xml_parser().parse)(
      @input.input_from_bytes_with_format(utf16, "utf16.xml", Some(Xml)),
      @parser.new_parse_context(Xml),
    )
    is Err(_),
  )
  assert_true(
    (xml_parser().parse)(
      units_xml_reader(utf16),
      @parser.new_parse_context(Xml),
    )
    is Err(_),
  )
}
