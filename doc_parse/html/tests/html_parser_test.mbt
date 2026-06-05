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

  let issues = @html.collect_html_validation_issues(doc)
  let validation = @html.validate_html_document(doc)
  let report = @html.inspect_html_document(doc)
  let info = @html.classify_html_error(
    @html.HtmlError::ParseError("expected name"),
  )

  assert_eq(issues.length(), 0)
  assert_eq(validation.issue_count, 0)
  assert_eq(report.doctype_count, 1)
  assert_eq(report.comment_count, 1)
  assert_eq(report.element_count, 4)
  assert_eq(report.attribute_count, 3)
  assert_eq(report.heading_element_count, 1)
  assert_eq(report.image_element_count, 1)
  assert_eq(report.max_depth, 3)
  assert_eq(report.issue_count, 0)
  assert_true(info.kind == @html.HtmlErrorKind::InvalidName)
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

  match doc.nodes[1] {
    @html.HtmlNode::Element(style) =>
      match style.children[0] {
        @html.HtmlNode::Text(text) =>
          assert_true(text.text.contains(".x { color: red; }"))
        _ => fail("expected raw style text child")
      }
    _ => fail("expected second node to be style element")
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

///|
test "html entities decode conservatively while unknown named entities stay literal" {
  let doc = @html.parse_html_document(
    "<p>A &amp; B &nbsp; &#169; &#x1F600; &copy;</p>",
  )

  match doc.nodes[0] {
    @html.HtmlNode::Element(paragraph) =>
      match paragraph.children[0] {
        @html.HtmlNode::Text(text) => {
          assert_true(text.text.contains("A & B"))
          assert_true(text.text.contains(" © "))
          assert_true(text.text.contains("😀"))
          assert_true(text.text.contains("&copy;"))
        }
        _ => fail("expected paragraph text child")
      }
    _ => fail("expected paragraph element")
  }
}

///|
test "html void and self-closing elements stay self-closing without unclosed warnings" {
  let doc = @html.parse_html_document(
    "<div><br><img src='img.png'/><input disabled><hr /></div>",
  )
  let validation = @html.validate_html_document(doc)
  let report = @html.inspect_html_document(doc)

  assert_eq(validation.issue_count, 0)
  assert_eq(report.image_element_count, 1)
  assert_eq(report.element_count, 5)

  match doc.nodes[0] {
    @html.HtmlNode::Element(div) => {
      assert_eq(div.children.length(), 4)
      for child in div.children {
        match child {
          @html.HtmlNode::Element(element) => assert_true(element.self_closing)
          _ => fail("expected only self-closing element children")
        }
      }
    }
    _ => fail("expected outer div element")
  }
}

///|
test "html unsafe url issues are deterministic and preserve raw attribute values" {
  let doc = @html.parse_html_document(
    "<a href='javascript:bad'>x</a>" +
    "<img src='data:text/plain,hi'>" +
    "<form action='vbscript:msgbox(1)'></form>",
  )
  let validation = @html.validate_html_document(doc)

  assert_eq(validation.issue_count, 3)
  assert_true(
    validation.issues[0].kind == @html.HtmlValidationIssueKind::UnsafeUrl,
  )
  assert_true(
    validation.issues[1].kind == @html.HtmlValidationIssueKind::UnsafeUrl,
  )
  assert_true(
    validation.issues[2].kind == @html.HtmlValidationIssueKind::UnsafeUrl,
  )
  assert_eq(validation.issues[0].message, "unsafe url uses javascript: scheme")
  assert_eq(validation.issues[1].message, "unsafe url uses data: scheme")
  assert_eq(validation.issues[2].message, "unsafe url uses vbscript: scheme")

  match doc.nodes[1] {
    @html.HtmlNode::Element(img) =>
      assert_eq(img.attributes[0].value, "data:text/plain,hi")
    _ => fail("expected img element")
  }
}

///|
test "html inspect inventory and validation ordering stay deterministic" {
  let doc = @html.parse_html_document(
    "<div><h2>Title</h2><a href='/safe'>x</a><img src='img.png'>" +
    "<table><tr><td>x</td></tr></table><ul><li>one</li></ul>" +
    "<pre><code>c</code></pre><script>bad()</script><style>.x{}</style></div>",
  )
  let report = @html.inspect_html_document(doc)
  let validation = @html.validate_html_document(doc)

  assert_eq(report.heading_element_count, 1)
  assert_eq(report.link_element_count, 1)
  assert_eq(report.image_element_count, 1)
  assert_eq(report.table_element_count, 1)
  assert_eq(report.list_element_count, 1)
  assert_eq(report.pre_element_count, 1)
  assert_eq(report.code_element_count, 1)
  assert_eq(report.script_element_count, 1)
  assert_eq(report.style_element_count, 1)

  assert_eq(validation.issue_count, 2)
  assert_true(
    validation.issues[0].kind == @html.HtmlValidationIssueKind::ScriptElement,
  )
  assert_true(
    validation.issues[1].kind == @html.HtmlValidationIssueKind::StyleElement,
  )
}

///|
test "html validation issue bundle stays stable for script style unsafe duplicate and malformed close mix" {
  let doc = @html.parse_html_document(
    "<html><body><script>bad()</script><style>.x{}</style><a href='javascript:bad'>x</a><div class='a' class='b'><p>ok</div></span></body></html>",
  )
  let validation = @html.validate_html_document(doc)

  assert_eq(validation.issue_count, 6)
  let kinds = validation.issues.map(fn(issue) { issue.kind })
  assert_true(kinds[0] == @html.HtmlValidationIssueKind::ScriptElement)
  assert_true(kinds[1] == @html.HtmlValidationIssueKind::StyleElement)
  assert_true(kinds[2] == @html.HtmlValidationIssueKind::UnsafeUrl)
  assert_true(kinds[3] == @html.HtmlValidationIssueKind::DuplicateAttribute)
  assert_true(kinds[4] == @html.HtmlValidationIssueKind::UnclosedElement)
  assert_true(kinds[5] == @html.HtmlValidationIssueKind::UnexpectedClosingTag)
}

///|
test "html shared primitive helpers expose source facts without product policy" {
  let tag = "<A data-href='https://wrong.example/' HREF=\"https://example.com/a?x=1&amp;y=2\" title='A&nbsp;&#169;' disabled>"

  assert_eq(@html.html_tag_name(tag).unwrap_or(""), "a")
  assert_eq(@html.html_tag_name("</SECTION>").unwrap_or(""), "section")
  assert_true(@html.html_tag_name("<!-- hidden -->") is None)

  assert_eq(
    @html.html_raw_attr_value(tag, "href").unwrap_or(""),
    "https://example.com/a?x=1&amp;y=2",
  )
  assert_eq(
    @html.html_attr_value(tag, "href").unwrap_or(""),
    "https://example.com/a?x=1&y=2",
  )
  assert_eq(@html.html_attr_value(tag, "title").unwrap_or(""), "A ©")
  assert_true(@html.html_raw_attr_value(tag, "disabled") is None)
  assert_true(@html.html_raw_attr_value(tag, "src") is None)

  assert_eq(
    @html.decode_html_entities("A &amp; B &nbsp; &#169; &#x1F600; &copy;"),
    "A & B   © 😀 &copy;",
  )
}

///|
test "html token events expose matching spans attrs and malformed boundaries" {
  let source = "<main id='root'><section data-x=\"1&amp;2\"><p>A</p><section><p>B</p></section></section><script>if (a < b) ok()</script><div>"
  let events = @html.tokenize_html_events(source)

  assert_true(@html.html_token_event_is_open_tag(events[0], "main"))
  assert_true(@html.html_token_event_is_open_tag(events[1], "section"))
  assert_eq(
    @html.html_token_event_attr_value(events[1], "data-x").unwrap_or(""),
    "1&2",
  )

  assert_eq(@html.html_tokens_find_matching_close(events, 1).unwrap_or(-1), 10)
  assert_eq(@html.html_tokens_find_matching_close(events, 5).unwrap_or(-1), 9)
  assert_true(@html.html_token_event_is_close_tag(events[10], "section"))

  assert_true(@html.html_token_event_is_open_tag(events[11], "script"))
  assert_eq(source[events[12].source_start:events[12].source_end].to_owned(), "if (a < b) ok()")
  assert_true(@html.html_token_event_is_close_tag(events[13], "script"))

  assert_true(@html.html_token_event_is_open_tag(events[14], "div"))
  assert_true(@html.html_tokens_find_matching_close(events, 14) is None)
  assert_true((try? @html.tokenize_html_events("<div class=\"x>")) is Err(_))
}

///|
test "html token event element ranges cover skip tags without unclosed ranges" {
  let source = "<html><head><script>HEAD</script><style>.x{}</style></head><body><noscript><p>No JS</p></noscript><p>Visible</p><script>BODY</script><script>UNCLOSED"
  let events = @html.tokenize_html_events(source)
  let ranges = @html.html_tokens_collect_element_ranges(
    events,
    ["script", "style", "head", "noscript"],
  )

  assert_eq(ranges.length(), 5)
  assert_true(source[ranges[0].source_start:ranges[0].source_end].to_owned().has_prefix("<head>"))
  assert_true(source[ranges[0].source_start:ranges[0].source_end].to_owned().has_suffix("</head>"))
  assert_eq(source[ranges[1].source_start:ranges[1].source_end].to_owned(), "<script>HEAD</script>")
  assert_eq(source[ranges[2].source_start:ranges[2].source_end].to_owned(), "<style>.x{}</style>")
  assert_eq(
    source[ranges[3].source_start:ranges[3].source_end].to_owned(),
    "<noscript><p>No JS</p></noscript>",
  )
  assert_eq(source[ranges[4].source_start:ranges[4].source_end].to_owned(), "<script>BODY</script>")
  assert_true(!source[ranges[4].source_end:].to_owned().contains("</script>"))
  assert_true((try? @html.tokenize_html_events("<script data=\"broken>")) is Err(_))
}
