///|
fn analysis_span(span : HtmlSourceSpan) -> Json {
  [
    Json(span.line_start),
    Json(span.line_end),
    Json(span.byte_start),
    Json(span.byte_end),
  ]
}

///|
fn analysis_attribute(attr : HtmlAttribute) -> Json {
  let quote = match attr.quote_style {
    DoubleQuoted => "double"
    SingleQuoted => "single"
    Unquoted => "none"
  }
  [Json(attr.name), Json(attr.value), Json(quote), analysis_span(attr.span)]
}

///|
fn analysis_node(node : HtmlNode) -> Json {
  match node {
    Element(element) =>
      [
        Json("element"),
        Json(element.tag_name),
        Json::array(element.attributes.map(analysis_attribute)),
        Json(element.self_closing),
        analysis_span(element.span),
        Json::array(element.children.map(analysis_node)),
      ]
    Text(text) => [Json("text"), Json(text.text), analysis_span(text.span)]
    Comment(comment) =>
      [Json("comment"), Json(comment.text), analysis_span(comment.span)]
    Doctype(doctype) =>
      [Json("doctype"), Json(doctype.text), analysis_span(doctype.span)]
  }
}

///|
fn analysis_document(doc : HtmlDocument) -> Json {
  let issues = doc.issues.map(issue => {
    let kind = match issue.kind {
      DuplicateAttribute => "duplicate"
      UnclosedElement => "unclosed"
      UnexpectedClosingTag => "closing"
      MalformedTag => "tag"
      UnsafeUrl => "url"
      ScriptElement => "script"
      StyleElement => "style"
      EmptyDocument => "empty"
    }
    let severity = match issue.severity {
      Warning => "warning"
      Error => "error"
    }
    Json::array([
      Json(kind),
      Json(severity),
      issue.line_start.map(i => Json(i)).unwrap_or(Json::null()),
      issue.line_end.map(i => Json(i)).unwrap_or(Json::null()),
      issue.tag_name.map(s => Json(s)).unwrap_or(Json::null()),
      Json(issue.message),
    ])
  })
  [
    Json::array(doc.nodes.map(analysis_node)),
    Json(doc.source_length),
    Json(doc.has_doctype),
    Json::array(issues),
  ]
}

///|
fn analysis_event(event : HtmlTokenEvent) -> Json {
  let kind = match event.kind {
    StartTag => "start"
    EndTag => "end"
    Text => "text"
    Comment => "comment"
    Doctype => "doctype"
  }
  [
    Json(kind),
    Json(event.tag_name),
    Json::array(event.attributes.map(analysis_attribute)),
    Json(event.self_closing),
    Json(event.source_start),
    Json(event.source_end),
    analysis_span(event.span),
  ]
}

///|
test "HTML shared analysis preserves complete DOM and event contracts" {
  for
    text in [
      "", "<p>body &amp; &#x1F600;</p>", "\u{FEFF}<!doctype html>\r\n<!-- 😀 -->\r<main><p a='&amp;' a=x>😀\r\n<span>tail</span></main>",
      "<script>if (a < b) x = '&amp;';</SCRIPT><style>.x{content:'<';}</style>",
      "<a href='javascript:bad'>unsafe</a><img src=x alt='quoted > value'>tail",
      "</stray><p>one<p>two<br/>three<", "<table><tr><td>甲</td><td>😀</table><pre>  x\n y</pre>",
    ] {
    let analysis = analyze_html_source(text)
    assert_eq(
      analysis_document(analysis.document),
      analysis_document(parse_html_document(text)),
    )
    assert_eq(
      Json::array(analysis.events.map(analysis_event)),
      Json::array(tokenize_html_events(text).map(analysis_event)),
    )
  }
}

///|
async test "HTML shared preparation preserves exact scanner failures" {
  for
    text in [
      "<!-- broken", "<div", "<a href='unterminated", "<script>body</script", "<!DOCTYPE html",
    ] {
    let scan_error = try {
      ignore(tokenize_html_events(text))
      ""
    } catch {
      error => error.to_string()
    }
    assert_true(scan_error != "")
    let prepared = prepare_html_document_from_source(
      @input.input_from_text_with_format(text, "bad.html", Some(Html)),
    ).unwrap()
    assert_true(prepared.document is None && prepared.events is None)
    assert_eq(prepared.parse_error, Some(scan_error + "; " + scan_error))
  }
}

///|
async test "HTML prepared event attributes do not alias DOM attribute arrays" {
  let prepared = prepare_html_document_from_source(
    @input.input_from_text_with_format(
      "<p data-x='one'>text</p>",
      "ownership.html",
      Some(Html),
    ),
  ).unwrap()
  let attrs = match prepared.document.unwrap().nodes[0] {
    Element(element) => element.attributes
    _ => fail("element required")
  }
  assert_eq(attrs.length(), 1)
  prepared.events.unwrap()[0].attributes.clear()
  assert_eq(attrs.length(), 1)
  assert_eq(attrs[0].value, "one")
}
