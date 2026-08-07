///|
test "html stable facade handles doctype comments nested elements and multiple top-level nodes" {
  let source = "<!doctype html>\n" +
    "<!-- lead -->\n" +
    "<div class=\"outer\"><h1>Hi</h1><img src='img.png' alt=test /></div>\n" +
    "<footer>tail</footer>\n"

  let tokens = @html.tokenize_html_document(source)
  assert_true(tokens.length() > 0)

  let doc = @html.parse_html_document(source)
  let issues = @html.collect_html_validation_issues(doc)
  let validation = @html.validate_html_document(doc)
  let report = @html.inspect_html_document(doc)
  let info = @html.classify_html_error(ParseError("expected name"))

  assert_true(doc.has_doctype)
  assert_eq(doc.nodes.length(), 4)
  assert_eq(issues.length(), 0)
  assert_eq(validation.issue_count, 0)
  assert_eq(report.doctype_count, 1)
  assert_eq(report.comment_count, 1)
  assert_eq(report.heading_element_count, 1)
  assert_eq(report.image_element_count, 1)
  assert_eq(report.issue_count, 0)
  assert_true(info.kind == InvalidName)
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
  assert_true(kinds[0] == ScriptElement)
  assert_true(kinds[1] == StyleElement)
  assert_true(kinds[2] == UnsafeUrl)

  match doc.nodes[0] {
    Element(script) =>
      match script.children[0] {
        Text(text) => assert_true(text.text.contains("if (a < b) alert(1);"))
        _ => fail("expected raw script text child")
      }
    _ => fail("expected first node to be script element")
  }

  match doc.nodes[1] {
    Element(style) =>
      match style.children[0] {
        Text(text) => assert_true(text.text.contains(".x { color: red; }"))
        _ => fail("expected raw style text child")
      }
    _ => fail("expected second node to be style element")
  }
}

///|
test "html parser keeps empty documents explicit and classifies malformed hard errors" {
  let empty = @html.parse_html_document("")
  let empty_validation = @html.validate_html_document(empty)
  let empty_report = @html.inspect_html_document(empty)
  assert_eq(empty_validation.issue_count, 1)
  assert_true(empty_validation.issues[0].kind == EmptyDocument)
  assert_true(empty_report.is_empty)

  let bad_cases : Array[(String, @html.HtmlErrorKind)] = [
    ("<!-- broken", UnterminatedComment),
    ("<div class=\"x></div>", MalformedAttribute),
    ("<div", UnterminatedTag),
  ]

  for i in 0..<bad_cases.length() {
    let (source, expected_kind) = bad_cases[i]
    assert_true(
      (try @html.parse_html_document(source) |> Ok catch {
        e => Err(e)
      })
      is Err(_),
    )
    let info = match expected_kind {
      UnterminatedComment =>
        @html.classify_html_error(ParseError("unterminated comment"))
      MalformedAttribute =>
        @html.classify_html_error(ParseError("unterminated attribute value"))
      UnterminatedTag =>
        @html.classify_html_error(ParseError("unterminated start tag"))
      _ => @html.classify_html_error(ParseError("unknown"))
    }
    assert_true(info.kind == expected_kind)
  }
}

///|
test "html tokenizer covers multiline tolerant and malformed boundaries" {
  let source = "<!DOCTYPE\n html>\n" +
    "<!-- first\nsecond -->\n" +
    "<DIV\r class='one\ntwo' disabled data-x=value>text</DIV>" +
    "<script>line1\nline2</SCRIPT>" +
    "</ \n div><"
  let tokens = @html.tokenize_html_document(source)
  let events = @html.tokenize_html_events(source)
  assert_true(tokens.length() >= 8)
  assert_true(events.length() >= 8)
  assert_true(events.any(event => event.span.line_end > event.span.line_start))

  let malformed = [
    "<!-- broken\ncomment", "<!DOCTYPE\nhtml", "<div", "<a href=", "<a href=>", "<a href='unterminated",
    "<img / broken>", "<div data-x=/>",
  ]
  for value in malformed {
    assert_true(
      (try @html.tokenize_html_document(value) |> Ok catch {
        _ => Err(())
      })
      is Err(_),
    )
  }
}
