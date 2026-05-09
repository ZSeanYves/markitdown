///|
test "html stable facade handles doctype comments nested elements and multiple top-level nodes" {
  let source = "<!doctype html>\n" +
    "<!-- lead -->\n" +
    "<div class=\"outer\"><h1>Hi</h1><img src='img.png' alt=test /></div>\n" +
    "<footer>tail</footer>\n"

  let tokens = @html.tokenize_html_document(source)
  assert_true(tokens.length() > 0)

  let doc = @html.parse_html_document(source)
  assert_true(doc.has_doctype)
  assert_eq(doc.nodes.length(), 4)

  let report = @html.inspect_html_document(doc)
  assert_eq(report.doctype_count, 1)
  assert_eq(report.comment_count, 1)
  assert_eq(report.element_count, 4)
  assert_eq(report.attribute_count, 3)
  assert_eq(report.heading_element_count, 1)
  assert_eq(report.image_element_count, 1)
  assert_eq(report.max_depth, 3)
  assert_eq(report.issue_count, 0)
}

///|
test "html parser preserves raw script style content and flags unsafe urls without rewriting" {
  let source = "<script>if (a < b) alert(1);</script>" +
    "<style>.x { color: red; }</style>" +
    "<a href=\"javascript:alert(1)\">bad</a>" +
    "<img src=img.png alt=test>"

  let doc = @html.parse_html_document(source)
  let report = @html.inspect_html_document(doc)
  let validation = @html.validate_html_document(doc)

  assert_eq(report.script_element_count, 1)
  assert_eq(report.style_element_count, 1)
  assert_eq(report.link_element_count, 1)
  assert_eq(report.image_element_count, 1)
  assert_eq(validation.issue_count, 3)

  let kinds = validation.issues.map(fn(issue) { issue.kind })
  assert_true(kinds[0] == @html.HtmlValidationIssueKind::ScriptElement)
  assert_true(kinds[1] == @html.HtmlValidationIssueKind::StyleElement)
  assert_true(kinds[2] == @html.HtmlValidationIssueKind::UnsafeUrl)

  match doc.nodes[0] {
    @html.HtmlNode::Element(script) =>
      match script.children[0] {
        @html.HtmlNode::Text(text) =>
          assert_true(text.text.contains("if (a < b) alert(1);"))
        _ => fail("expected raw script text child")
      }
    _ => fail("expected first node to be script element")
  }

  match doc.nodes[3] {
    @html.HtmlNode::Element(img) => {
      assert_eq(img.tag_name, "img")
      assert_eq(img.attributes[0].name, "src")
      assert_eq(img.attributes[0].value, "img.png")
      assert_true(
        img.attributes[0].quote_style == @html.HtmlAttributeQuoteStyle::Unquoted,
      )
      assert_eq(img.attributes[1].value, "test")
    }
    _ => fail("expected img element")
  }
}

///|
test "html parser tolerates duplicate attributes unclosed elements and unexpected closing tags with deterministic issue ordering" {
  let doc = @html.parse_html_document(
    "<div class=\"a\" class=\"b\"><p>ok</div></span>",
  )
  let validation = @html.validate_html_document(doc)
  let report = @html.inspect_html_document(doc)

  assert_eq(report.element_count, 2)
  assert_eq(validation.issue_count, 3)
  assert_true(
    validation.issues[0].kind ==
    @html.HtmlValidationIssueKind::DuplicateAttribute,
  )
  assert_true(
    validation.issues[1].kind == @html.HtmlValidationIssueKind::UnclosedElement,
  )
  assert_true(
    validation.issues[2].kind ==
    @html.HtmlValidationIssueKind::UnexpectedClosingTag,
  )
}

///|
test "html source spans and multiple top-level nodes are preserved in the raw model" {
  let doc = @html.parse_html_document(
    "<section>\n<h1>Title</h1>\n<p>Body</p>\n</section>\n<p>Tail</p>\n",
  )
  assert_eq(doc.nodes.length(), 2)

  match doc.nodes[0] {
    @html.HtmlNode::Element(section) => {
      assert_eq(section.tag_name, "section")
      assert_eq(section.span.line_start, 1)
      assert_eq(section.span.line_end, 4)
      assert_eq(section.children.length(), 2)
    }
    _ => fail("expected section element")
  }

  match doc.nodes[1] {
    @html.HtmlNode::Element(paragraph) => {
      assert_eq(paragraph.tag_name, "p")
      assert_eq(paragraph.span.line_start, 5)
      assert_eq(paragraph.span.line_end, 5)
    }
    _ => fail("expected trailing paragraph element")
  }
}

///|
test "html parser keeps empty documents explicit and classifies malformed hard errors" {
  let empty = @html.parse_html_document("")
  let empty_validation = @html.validate_html_document(empty)
  let empty_report = @html.inspect_html_document(empty)
  assert_eq(empty_validation.issue_count, 1)
  assert_true(
    empty_validation.issues[0].kind ==
    @html.HtmlValidationIssueKind::EmptyDocument,
  )
  assert_true(empty_report.is_empty)

  let bad_cases : Array[(String, @html.HtmlErrorKind)] = [
    ("<!-- broken", @html.HtmlErrorKind::UnterminatedComment),
    ("<div class=\"x></div>", @html.HtmlErrorKind::MalformedAttribute),
    ("<div", @html.HtmlErrorKind::UnterminatedTag),
  ]

  for i in 0..<bad_cases.length() {
    let (source, expected_kind) = bad_cases[i]
    assert_true((try? @html.parse_html_document(source)) is Err(_))
    let info = match expected_kind {
      @html.HtmlErrorKind::UnterminatedComment =>
        @html.classify_html_error(
          @html.HtmlError::ParseError("unterminated comment"),
        )
      @html.HtmlErrorKind::MalformedAttribute =>
        @html.classify_html_error(
          @html.HtmlError::ParseError("unterminated attribute value"),
        )
      @html.HtmlErrorKind::UnterminatedTag =>
        @html.classify_html_error(
          @html.HtmlError::ParseError("unterminated start tag"),
        )
      _ => @html.classify_html_error(@html.HtmlError::ParseError("unknown"))
    }
    assert_true(info.kind == expected_kind)
  }
}
