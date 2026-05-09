///|
test "xml tokenizer and parser handle nested elements attributes comments cdata and pi" {
  let tokens = @xml.tokenize_xml_document(
    "<?xml version=\"1.0\"?>\n" +
    "<?style test?>\n" +
    "<root a=\"1\" b='2'>hi<!--x--><![CDATA[<safe>]]><child/></root>\n",
  )
  assert_eq(tokens.length(), 11)

  let doc = @xml.parse_xml_document(
    "<?xml version=\"1.0\"?>\n" +
    "<?style test?>\n" +
    "<root a=\"1\" b='2'>hi<!--x--><![CDATA[<safe>]]><child/></root>\n",
  )
  assert_true(doc.root is Some(_))
  assert_eq(doc.nodes.length(), 2)

  let root = match doc.root {
    Some(root) => root
    None => fail("expected root element")
  }
  assert_eq(root.name, "root")
  assert_eq(root.attributes.length(), 2)
  assert_eq(root.children.length(), 4)

  let report = @xml.inspect_xml_document(doc)
  assert_eq(report.element_count, 2)
  assert_eq(report.attribute_count, 2)
  assert_eq(report.text_node_count, 1)
  assert_eq(report.comment_count, 1)
  assert_eq(report.cdata_count, 1)
  assert_eq(report.processing_instruction_count, 1)
  assert_eq(report.max_depth, 2)
}

///|
test "xml predefined entities decode and unknown entities fail closed" {
  let doc = @xml.parse_xml_document("<root>&lt;&amp;&gt;&quot;&apos;</root>")
  let root = match doc.root {
    Some(root) => root
    None => fail("expected root element")
  }
  match root.children[0] {
    @xml.XmlNode::Text(text) => assert_eq(text.text, "<&>\"'")
    _ => fail("expected text node")
  }

  let err = try? @xml.parse_xml_document("<root>&copy;</root>")
  assert_true(err is Err(_))
  match err {
    Err(_) => ()
    _ => ()
  }
  let info = @xml.classify_xml_error(
    @xml.XmlError::ParseError("unsupported entity: &copy;"),
  )
  assert_true(info.kind == @xml.XmlErrorKind::UnsupportedEntity)
}

///|
test "xml doctype is preserved as unsupported signal and never fetched" {
  let doc = @xml.parse_xml_document(
    "<!DOCTYPE note SYSTEM \"http://example.com/test.dtd\">\n<note>hi</note>\n",
  )
  assert_true(doc.has_doctype)
  assert_true(doc.has_unsupported_doctype)

  let validation = @xml.validate_xml_document(doc)
  assert_eq(validation.issue_count, 1)
  assert_eq(validation.warning_count, 1)
  assert_eq(validation.error_count, 0)
  assert_true(
    validation.issues[0].kind == @xml.XmlValidationIssueKind::UnsupportedDoctype,
  )
  assert_eq(
    validation.issues[0].message,
    "doctype is preserved as unsupported syntax and never fetched or expanded",
  )
}

///|
test "xml parser rejects malformed syntax and classifies" {
  let bad_cases : Array[(String, @xml.XmlErrorKind)] = [
    ("<root><child></root>", @xml.XmlErrorKind::MismatchedTag),
    ("<root><child>", @xml.XmlErrorKind::UnclosedTag),
    ("<root a=1></root>", @xml.XmlErrorKind::InvalidToken),
    ("<root a=\"1\" a=\"2\"></root>", @xml.XmlErrorKind::DuplicateAttribute),
    ("<!DOCTYPE note [ <!ENTITY a \"x\"> \n", @xml.XmlErrorKind::UnexpectedEOF),
    ("", @xml.XmlErrorKind::EmptyDocument),
  ]

  for i in 0..<bad_cases.length() {
    let (source, expected_kind) = bad_cases[i]
    assert_true((try? @xml.parse_xml_document(source)) is Err(_))
    let info = match expected_kind {
      @xml.XmlErrorKind::MismatchedTag =>
        @xml.classify_xml_error(
          @xml.XmlError::ParseError(
            "mismatched closing tag: expected </child> but found </root>",
          ),
        )
      @xml.XmlErrorKind::UnclosedTag =>
        @xml.classify_xml_error(
          @xml.XmlError::ParseError("unclosed tag: child"),
        )
      @xml.XmlErrorKind::InvalidToken =>
        @xml.classify_xml_error(
          @xml.XmlError::ParseError("unquoted attribute value"),
        )
      @xml.XmlErrorKind::DuplicateAttribute =>
        @xml.classify_xml_error(
          @xml.XmlError::ParseError("duplicate attribute: a"),
        )
      @xml.XmlErrorKind::UnexpectedEOF =>
        @xml.classify_xml_error(
          @xml.XmlError::ParseError("unterminated doctype"),
        )
      @xml.XmlErrorKind::EmptyDocument =>
        @xml.classify_xml_error(@xml.XmlError::ParseError("empty document"))
      _ => @xml.classify_xml_error(@xml.XmlError::ParseError("unknown"))
    }
    assert_true(info.kind == expected_kind)
  }
}

///|
test "xml namespace raw names and source spans are preserved without namespace semantics" {
  let doc = @xml.parse_xml_document(
    "<xhtml:body xmlns:xhtml=\"urn:test\"><xhtml:p id=\"a\">ok</xhtml:p></xhtml:body>",
  )
  let root = match doc.root {
    Some(root) => root
    None => fail("expected root element")
  }
  assert_eq(root.name, "xhtml:body")
  assert_eq(root.attributes[0].name, "xmlns:xhtml")
  assert_eq(root.span.line_start, 1)
  assert_eq(root.span.line_end, 1)

  match root.children[0] {
    @xml.XmlNode::Element(child) => {
      assert_eq(child.name, "xhtml:p")
      assert_eq(child.attributes[0].name, "id")
      assert_eq(child.attributes[0].span.line_start, 1)
      assert_eq(child.attributes[0].span.line_end, 1)
    }
    _ => fail("expected child element")
  }
}

///|
test "xml stable facade and inspect surface smoke" {
  let tokens = @xml.tokenize_xml_document("<root><a/>text</root>")
  assert_true(tokens.length() > 0)

  let doc = @xml.parse_xml_document("<root><a/>text</root>")
  let inspect = @xml.inspect_xml_document(doc)
  let validation = @xml.validate_xml_document(doc)

  assert_eq(inspect.element_count, 2)
  assert_eq(inspect.text_node_count, 1)
  assert_eq(validation.issue_count, 0)
}

///|
test "xml multiple root elements and empty document stay fail-closed" {
  assert_true((try? @xml.parse_xml_document("<a/><b/>")) is Err(_))
  assert_true((try? @xml.parse_xml_document("")) is Err(_))

  let multiple = @xml.classify_xml_error(
    @xml.XmlError::ParseError("multiple root elements"),
  )
  assert_true(multiple.kind == @xml.XmlErrorKind::MultipleRootElements)

  let empty = @xml.classify_xml_error(
    @xml.XmlError::ParseError("empty document"),
  )
  assert_true(empty.kind == @xml.XmlErrorKind::EmptyDocument)
}

///|
test "xml parser handles single quotes self closing tags and mixed top-level syntax" {
  let doc = @xml.parse_xml_document(
    "<?pi x?>\n<!-- lead -->\n<root><leaf name='v'/><t>ok</t></root>\n",
  )
  assert_eq(doc.nodes.length(), 3)
  let root = match doc.root {
    Some(root) => root
    None => fail("expected root element")
  }
  assert_eq(root.children.length(), 2)

  let report = @xml.inspect_xml_document(doc)
  assert_eq(report.element_count, 3)
  assert_eq(report.processing_instruction_count, 1)
  assert_eq(report.comment_count, 1)
  assert_eq(report.text_node_count, 1)
}
