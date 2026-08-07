///|
test "XML parser lowers rich document and streaming structure routes" {
  let xml = "<?xml version=\"1.0\"?><catalog><item id=\"1\"><name>Alpha</name><value>10</value></item><item id=\"2\"><name>Beta</name><value>20</value></item></catalog>"
  let source = @input.input_from_text_with_format(xml, "catalog.xml", Some(Xml))
  let document = (xml_parser().parse)(source, @parser.new_parse_context(Xml)).unwrap()
  assert_true(document.document.unwrap().blocks.length() > 0)
  assert_true(document.diagnostics.metrics.get("element_count") != Some("0"))
  assert_true(document.diagnostics.metrics.get("attribute_count") == Some("2"))
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Xml),
    Some(StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (xml_parser().parse)(source, context).unwrap()
  assert_true(streamed.event_stream.unwrap().length() > 0)
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("streaming_event"),
  )
  assert_true(streamed.diagnostics.metrics.get("comment_count") == Some("0"))
  assert_true(streamed.diagnostics.metrics.get("cdata_count") == Some("0"))
}

///|
test "XML empty and malformed inputs return controlled document fallbacks" {
  let empty = (xml_parser().parse)(
    @input.input_from_text_with_format(" \n ", "empty.xml", Some(Xml)),
    @parser.new_parse_context(Xml),
  ).unwrap()
  assert_eq(empty.document.unwrap().blocks.length(), 0)
  assert_true(empty.diagnostics.metrics.get("element_count") == Some("0"))
  let malformed = (xml_parser().parse)(
    @input.input_from_text_with_format(
      "<root><unclosed></root>",
      "broken.xml",
      Some(Xml),
    ),
    @parser.new_parse_context(Xml),
  ).unwrap()
  assert_true(malformed.document.unwrap().blocks.length() == 1)
  assert_true(
    malformed.diagnostics.degraded_features.contains("xml_fail_closed"),
  )
  assert_true(
    malformed.diagnostics.metrics.get("syntax_error_count") == Some("1"),
  )
  let invalid_utf8 = @input.input_from_bytes_with_format(
    Bytes::from_array([0xC3, 0x28].map(Int::to_byte)),
    "invalid.xml",
    Some(Xml),
  )
  assert_true(
    (xml_parser().parse)(invalid_utf8, @parser.new_parse_context(Xml)) is Err(_),
  )
}

///|
test "XML streaming policy rejects unsafe or ambiguous structural inputs" {
  let cases = [
    "<!DOCTYPE root [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><root>&x;</root>",
    "<root xmlns=\"urn:default\"><child/></root>", "<root attr=\"line one\nline two\"><child/></root>",
    "<root>```markdown\ntext\n```</root>",
  ]
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Xml),
    Some(StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  for index in 0..<cases.length() {
    let result = (xml_parser().parse)(
      @input.input_from_text_with_format(
        cases[index],
        "policy-" + index.to_string() + ".xml",
        Some(Xml),
      ),
      context,
    ).unwrap()
    assert_true(result.document is Some(_))
    assert_true(
      result.diagnostics.degraded_features.contains("xml_fail_closed"),
    )
    assert_true(result.diagnostics.metrics.get("event_count") == Some("0"))
  }
  assert_true(xml_parser_capability().supports_streaming)
  assert_true(xml_parser_capability().supports_document_ir)
}

///|
test "XML compact outline events preserve hierarchy text and xpath" {
  let source = @input.input_from_text_with_format(
    "<root page=\"1\"><record><name>A</name><value id=\"v\">10</value></record></root>",
    "compact.xml",
    Some(Xml),
  )
  let tokens = @dxml.parse_xml_structure_tokens(
    "<root page=\"1\"><record><name>A</name><value id=\"v\">10</value></record></root>",
  )
  let events = xml_compact_outline_events_from_tokens(tokens, source)
  assert_true(events.length() >= 6)
  assert_true(events[0].kind == StartBlock(Heading))
  assert_eq(events[0].text, "<root>")
  assert_true(events.any(event => event.text == "name: A"))
  let value_attrs = events.filter(event => event.text == "@id: v")
  assert_eq(value_attrs.length(), 1)
  let value_attr = value_attrs[0].source_ref.unwrap()
  assert_true(value_attr.xpath == Some("/root/record[0]/value[0]/@id"))
  assert_true(value_attr.extra.get("xml_outline_depth") == Some("2"))
  assert_true(
    value_attr.extra.get("ir_event_encoding") == Some("xml_outline_v1"),
  )
}
