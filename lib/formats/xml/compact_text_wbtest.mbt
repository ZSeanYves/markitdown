///|
fn compact_text_events(text : String) -> Array[@core.CoreEvent] raise {
  xml_compact_outline_events_from_tokens(
    @dxml.parse_xml_structure_tokens(text),
    @input.input_from_text_with_format(text, "text.xml", Some(Xml)),
  )
}

///|
fn compact_dom_labels(blocks : Array[@core.CoreBlock]) -> Array[String] {
  let labels : Array[String] = []
  for block in blocks {
    match block.kind {
      Heading | ListItem => labels.push(block.text)
      _ => ()
    }
    labels.append(compact_dom_labels(block.children)[:])
  }
  labels
}

///|
fn compact_assert_dom_labels(
  text : String,
  events : Array[@core.CoreEvent],
) -> Unit raise {
  let document = lower_xml_document(
    @dxml.parse_xml_document(text),
    @input.input_from_text_with_format(text, "text.xml", Some(Xml)),
  )
  assert_eq(
    events.map(event => event.text),
    compact_dom_labels(document.blocks),
  )
}

///|
test "XML compact producer retains attributed leaf text once after attributes" {
  let text = "<root><value id=\"v\">10 &amp;lt; 😀</value></root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), [
    "<root>", "<value>", "@id: v", "10 &lt; 😀",
  ])
  compact_assert_dom_labels(text, events)
  let value = events[3].source_ref.unwrap()
  assert_eq(value.xpath, Some("/root/value[0]"))
  assert_eq(value.extra.get("xml_outline_depth"), Some("1"))
}

///|
test "XML compact producer keeps mixed text CDATA and child rows in source order" {
  let text = "<root>before<child code=\"x\">inside</child>after<![CDATA[tail &amp; raw]]>last</root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), [
    "<root>", "before", "<child>", "@code: x", "inside", "after", "tail &amp; raw",
    "last",
  ])
  compact_assert_dom_labels(text, events)
  assert_eq(events[1].source_ref.unwrap().xpath, Some("/root"))
  assert_eq(events[4].source_ref.unwrap().xpath, Some("/root/child[0]"))
  assert_eq(events[5].source_ref.unwrap().xpath, Some("/root"))
  assert_eq(events[6].source_ref.unwrap().xpath, Some("/root"))
}

///|
test "XML compact producer flushes pending parent text before its first child" {
  let text = "<root><parent>first<child>inner</child>last</parent></root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), [
    "<root>", "<parent>", "first", "child: inner", "last",
  ])
  compact_assert_dom_labels(text, events)
  assert_eq(
    events[2].source_ref.unwrap().extra.get("xml_outline_depth"),
    Some("1"),
  )
  assert_eq(
    events[4].source_ref.unwrap().extra.get("xml_outline_depth"),
    Some("1"),
  )
}

///|
test "XML compact producer text provenance stays line based across CRLF and non BMP" {
  let text = "<root>\r\n<value id=\"😀\">Ω &amp;lt;</value>\r\n<![CDATA[𝄞 &amp;]]>\r\n</root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), [
    "<root>", "<value>", "@id: 😀", "Ω &lt;", "𝄞 &amp;",
  ])
  compact_assert_dom_labels(text, events)
  let value = events[3].source_ref.unwrap()
  assert_eq(value.file_id, Some("text.xml"))
  assert_eq(value.xpath, Some("/root/value[0]"))
  assert_eq(value.line_start, Some(2))
  assert_eq(value.line_end, Some(2))
  let cdata = events[4].source_ref.unwrap()
  assert_eq(cdata.xpath, Some("/root"))
  assert_eq(cdata.line_start, Some(3))
  assert_eq(cdata.line_end, Some(3))
}

///|
test "XML compact producer matches DOM structural label for an empty root child" {
  let text = "<root><v>A&amp;lt;<![CDATA[ B &amp;]]> C</v><empty/></root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), [
    "<root>", "v: A&lt; B &amp; C", "<empty>",
  ])
  compact_assert_dom_labels(text, events)
}

///|
test "XML compact producer simple leaf coalescing is a preservation control" {
  let text = "<root><v>A&amp;lt;<![CDATA[ B &amp;]]> C</v></root>"
  let events = compact_text_events(text)
  assert_eq(events.map(event => event.text), ["<root>", "v: A&lt; B &amp; C"])
  compact_assert_dom_labels(text, events)
}

///|
async test "XML parser large compact route retains attributed text through its public parser" {
  let out = StringBuilder()
  for ch in "<root><!--" {
    out.write_char(ch)
  }
  for _ in 0..<1_048_576 {
    out.write_char('x')
  }
  for ch in "--><value id=\"v\">10 &amp;lt; 😀</value></root>" {
    out.write_char(ch)
  }
  let source = @input.input_from_text_with_format(
    out.to_string(),
    "large.xml",
    Some(Xml),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Xml),
    Some(StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  let result = (xml_parser().parse)(source, context).unwrap()
  assert_eq(result.diagnostics.metrics.get("xml_compact_outline"), Some("true"))
  assert_eq(result.event_stream.unwrap().map(event => event.text), [
    "<root>", "<value>", "@id: v", "10 &lt; 😀",
  ])
}
