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
      assert_eq(section.children.length(), 5)
      match section.children[0] {
        @html.HtmlNode::Text(text) => assert_eq(text.text, "\n")
        _ => fail("expected leading section whitespace text")
      }
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
    assert_true(
      (try @html.parse_html_document(source) |> Ok catch {
        e => Err(e)
      })
      is Err(_),
    )
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
  assert_eq(
    source[events[12].source_start:events[12].source_end].to_owned(),
    "if (a < b) ok()",
  )
  assert_true(@html.html_token_event_is_close_tag(events[13], "script"))

  assert_true(@html.html_token_event_is_open_tag(events[14], "div"))
  assert_true(@html.html_tokens_find_matching_close(events, 14) is None)
  assert_true(
    (try @html.tokenize_html_events("<div class=\"x>") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "html token event element ranges cover skip tags without unclosed ranges" {
  let source = "<html><head><script>HEAD</script><style>.x{}</style></head><body><noscript><p>No JS</p></noscript><p>Visible</p><script>BODY</script><script>UNCLOSED"
  let events = @html.tokenize_html_events(source)
  let ranges = @html.html_tokens_collect_element_ranges(events, [
    "script", "style", "head", "noscript",
  ])

  assert_eq(ranges.length(), 5)
  assert_true(
    source[ranges[0].source_start:ranges[0].source_end]
    .to_owned()
    .has_prefix("<head>"),
  )
  assert_true(
    source[ranges[0].source_start:ranges[0].source_end]
    .to_owned()
    .has_suffix("</head>"),
  )
  assert_eq(
    source[ranges[1].source_start:ranges[1].source_end].to_owned(),
    "<script>HEAD</script>",
  )
  assert_eq(
    source[ranges[2].source_start:ranges[2].source_end].to_owned(),
    "<style>.x{}</style>",
  )
  assert_eq(
    source[ranges[3].source_start:ranges[3].source_end].to_owned(),
    "<noscript><p>No JS</p></noscript>",
  )
  assert_eq(
    source[ranges[4].source_start:ranges[4].source_end].to_owned(),
    "<script>BODY</script>",
  )
  assert_true(!source[ranges[4].source_end:].to_owned().contains("</script>"))
  assert_true(
    (try @html.tokenize_html_events("<script data=\"broken>") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "html semantic block facts collect headings paragraphs lists tables and text previews" {
  let doc = @html.parse_html_document(
    "<article><h1 id='title'>Title</h1><p class='lead'>Body text</p>" +
    "<ul><li>One<ol><li>Nested</li></ol></li></ul>" +
    "<table><tr><th>H</th><td>D</td></tr></table></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.heading_count, 1)
  assert_eq(report.paragraph_count, 1)
  assert_eq(report.list_count, 2)
  assert_eq(report.list_item_count, 2)
  assert_eq(report.table_count, 1)
  assert_eq(report.table_row_count, 1)
  assert_eq(report.table_cell_count, 2)
  assert_eq(report.unknown_block_count, 1)
  assert_eq(report.warning_count, 0)

  assert_true(semantic.blocks[0].kind == @html.HtmlBlockKind::UnknownBlock)
  assert_eq(semantic.blocks[0].tag_name, "article")
  assert_eq(semantic.blocks[0].children.length(), 4)

  match semantic.blocks[1].kind {
    @html.HtmlBlockKind::Heading(level) => assert_eq(level, 1)
    _ => fail("expected second semantic block to be h1")
  }
  assert_eq(semantic.blocks[1].source_key, "html:block:h1:2")
  assert_eq(semantic.blocks[1].source_order, 2)
  assert_eq(semantic.blocks[1].tag_name, "h1")
  assert_eq(semantic.blocks[1].text_preview, "Title")
  assert_eq(semantic.blocks[1].attributes[0].name, "id")
  assert_eq(
    semantic.blocks[1].parent_source_key.unwrap_or(""),
    semantic.blocks[0].source_key,
  )
  assert_eq(semantic.blocks[2].text_preview, "Body text")

  match semantic.blocks[3].kind {
    @html.HtmlBlockKind::List(ordered) => assert_false(ordered)
    _ => fail("expected unordered list fact")
  }
  match semantic.blocks[5].kind {
    @html.HtmlBlockKind::List(ordered) => assert_true(ordered)
    _ => fail("expected nested ordered list fact")
  }
  assert_eq(semantic.blocks[3].children[0], semantic.blocks[4].source_key)
  assert_eq(
    semantic.blocks[4].parent_source_key.unwrap_or(""),
    semantic.blocks[3].source_key,
  )
  assert_eq(
    semantic.blocks[6].parent_source_key.unwrap_or(""),
    semantic.blocks[5].source_key,
  )

  match semantic.blocks[9].kind {
    @html.HtmlBlockKind::TableCell(is_header) => assert_true(is_header)
    _ => fail("expected header table cell")
  }
  match semantic.blocks[10].kind {
    @html.HtmlBlockKind::TableCell(is_header) => assert_false(is_header)
    _ => fail("expected data table cell")
  }
}

///|
test "html semantic block facts collect blockquote pre code figure caption and hr" {
  let doc = @html.parse_html_document(
    "<article><blockquote><p>Quoted</p></blockquote>" +
    "<pre><code>literal &amp; code</code></pre>" +
    "<figure><img src='img.png'><figcaption>Caption text</figcaption></figure>" +
    "<hr></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.blockquote_count, 1)
  assert_eq(report.paragraph_count, 1)
  assert_eq(report.pre_count, 1)
  assert_eq(report.code_block_count, 1)
  assert_eq(report.figure_count, 1)
  assert_eq(report.figcaption_count, 1)
  assert_eq(report.horizontal_rule_count, 1)
  assert_eq(report.unknown_block_count, 1)

  assert_true(semantic.blocks[0].kind == @html.HtmlBlockKind::UnknownBlock)
  assert_true(semantic.blocks[1].kind == @html.HtmlBlockKind::BlockQuote)
  assert_true(semantic.blocks[3].kind == @html.HtmlBlockKind::Pre)
  assert_true(semantic.blocks[4].kind == @html.HtmlBlockKind::CodeBlock)
  assert_true(semantic.blocks[5].kind == @html.HtmlBlockKind::Figure)
  assert_true(semantic.blocks[6].kind == @html.HtmlBlockKind::FigCaption)
  assert_true(semantic.blocks[7].kind == @html.HtmlBlockKind::HorizontalRule)
  assert_eq(semantic.blocks[4].text_preview, "literal & code")
  assert_eq(semantic.blocks[6].text_preview, "Caption text")
}

///|
test "html semantic block facts stay bounded for malformed deep-ish input and previews" {
  let mut source = ""
  for i in 0..<40 {
    source = source + "<div data-depth='" + i.to_string() + "'>"
  }
  source = source + "<p"
  for i in 0..<16 {
    source = source +
      " a" +
      i.to_string() +
      "='" +
      "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" +
      "'"
  }
  source = source + ">"
  for _ in 0..<220 {
    source = source + "x"
  }
  source = source + "</p>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.paragraph_count, 1)
  assert_true(report.max_depth >= 40)
  assert_true(semantic.blocks.length() >= 41)
  let paragraph = semantic.blocks[semantic.blocks.length() - 1]
  assert_eq(paragraph.attributes.length(), 12)
  assert_true(paragraph.text_preview.length() <= 160)
  assert_true(paragraph.warnings.length() >= 3)

  let warning_kinds = paragraph.warnings.map(fn(warning) { warning.kind })
  assert_true(
    warning_kinds.contains(
      @html.HtmlSemanticWarningKind::AttributeSummaryTruncated,
    ),
  )
  assert_true(
    warning_kinds.contains(
      @html.HtmlSemanticWarningKind::AttributeValuePreviewTruncated,
    ),
  )
  assert_true(
    warning_kinds.contains(@html.HtmlSemanticWarningKind::TextPreviewTruncated),
  )
}

///|
test "html semantic block facts classify unsupported blocks without product policy" {
  let doc = @html.parse_html_document(
    "<article><script>bad()</script><style>.x{}</style><template><p>x</p></template><svg><text>x</text></svg><form><input name='q'></form><video><source src='a.mp4'></video><canvas></canvas></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_true(report.unsupported_block_count >= 7)
  assert_true(report.warning_count >= report.unsupported_block_count)
  for block in semantic.blocks {
    if block.kind == @html.HtmlBlockKind::UnsupportedBlock {
      assert_eq(block.warnings.length(), 1)
      assert_true(
        block.warnings[0].kind ==
        @html.HtmlSemanticWarningKind::UnsupportedElement,
      )
    }
  }
}

///|
test "html semantic inline facts collect text emphasis strong code span and breaks" {
  let doc = @html.parse_html_document(
    "<article><p>Hello <em>em</em><strong>strong</strong><code>code</code><span data-x='1'>span</span><br>tail</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.paragraph_count, 1)
  assert_true(report.inline_count >= 9)
  assert_true(report.text_inline_count >= 5)
  assert_eq(report.emphasis_inline_count, 1)
  assert_eq(report.strong_inline_count, 1)
  assert_eq(report.code_inline_count, 1)
  assert_eq(report.span_inline_count, 1)
  assert_eq(report.break_inline_count, 1)
  assert_eq(report.link_count, 0)
  assert_eq(report.image_count, 0)

  let paragraph_key = semantic.blocks[1].source_key
  let mut saw_em = false
  let mut saw_strong = false
  let mut saw_code = false
  let mut saw_span = false
  let mut saw_break = false
  for fact in semantic.inlines {
    if fact.parent_block_source_key.unwrap_or("") == paragraph_key {
      match fact.kind {
        @html.HtmlInlineKind::Emphasis => {
          saw_em = true
          assert_eq(fact.text_preview, "em")
          assert_eq(fact.children.length(), 1)
        }
        @html.HtmlInlineKind::Strong => {
          saw_strong = true
          assert_eq(fact.text_preview, "strong")
        }
        @html.HtmlInlineKind::Code => {
          saw_code = true
          assert_eq(fact.text_preview, "code")
        }
        @html.HtmlInlineKind::Span => {
          saw_span = true
          assert_eq(fact.attributes[0].name, "data-x")
          assert_eq(fact.attributes[0].value_preview, "1")
        }
        @html.HtmlInlineKind::Break => saw_break = true
        _ => ()
      }
    }
  }

  assert_true(saw_em)
  assert_true(saw_strong)
  assert_true(saw_code)
  assert_true(saw_span)
  assert_true(saw_break)
}

///|
test "html semantic link facts classify common href schemes and preserve attrs" {
  let doc = @html.parse_html_document(
    "<article><p>" +
    "<a href='#toc'>toc</a>" +
    "<a href='https://example.com' title='External' target='_blank' rel='noopener'>external</a>" +
    "<a href='mailto:a@example.com'>mail</a>" +
    "<a href='tel:+123'>tel</a>" +
    "<a href='data:text/plain,hi'>data</a>" +
    "<a href='javascript:bad()'>bad</a>" +
    "<a>empty</a>" +
    "</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.link_inline_count, 7)
  assert_eq(report.link_count, 7)
  assert_eq(report.internal_link_count, 1)
  assert_eq(report.external_link_count, 1)
  assert_eq(report.mailto_link_count, 1)
  assert_eq(report.tel_link_count, 1)
  assert_eq(report.data_link_count, 1)
  assert_eq(report.unsafe_link_count, 1)
  assert_eq(report.empty_link_count, 1)
  assert_eq(report.warning_count, 3)

  let paragraph_key = semantic.blocks[1].source_key
  let mut saw_external = false
  let mut saw_data = false
  let mut saw_unsafe = false
  let mut saw_empty = false
  for link in semantic.links {
    assert_eq(link.parent_block_source_key.unwrap_or(""), paragraph_key)
    match link.kind {
      @html.HtmlLinkKind::External => {
        saw_external = true
        assert_eq(link.href, "https://example.com")
        assert_eq(link.title.unwrap_or(""), "External")
        assert_eq(link.target.unwrap_or(""), "_blank")
        assert_eq(link.rel.unwrap_or(""), "noopener")
        assert_eq(link.text_preview, "external")
      }
      @html.HtmlLinkKind::Data => {
        saw_data = true
        assert_true(
          link.warnings[0].kind == @html.HtmlSemanticWarningKind::UnsafeUrl,
        )
      }
      @html.HtmlLinkKind::Unsafe => {
        saw_unsafe = true
        assert_true(
          link.warnings[0].kind == @html.HtmlSemanticWarningKind::UnsafeUrl,
        )
      }
      @html.HtmlLinkKind::Empty => {
        saw_empty = true
        assert_eq(link.href, "")
        assert_true(
          link.warnings[0].kind == @html.HtmlSemanticWarningKind::EmptyUrl,
        )
      }
      _ => ()
    }
  }

  assert_true(saw_external)
  assert_true(saw_data)
  assert_true(saw_unsafe)
  assert_true(saw_empty)
}

///|
test "html semantic image facts classify local remote data empty and unsafe sources" {
  let doc = @html.parse_html_document(
    "<article><p>" +
    "<img src='local.png' alt='Local' title='T' width='10' height='20' loading='lazy' decoding='async'>" +
    "<img src='https://example.com/a.png'>" +
    "<img src='data:image/png;base64,abcdef'>" +
    "<img src=''>" +
    "<img alt='missing'>" +
    "<img src='javascript:bad()'>" +
    "</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.image_inline_count, 6)
  assert_eq(report.image_count, 6)
  assert_eq(report.local_image_count, 1)
  assert_eq(report.remote_image_count, 1)
  assert_eq(report.data_uri_image_count, 1)
  assert_eq(report.empty_image_count, 2)
  assert_eq(report.unsafe_image_count, 1)
  assert_eq(report.warning_count, 5)

  let mut saw_local = false
  let mut saw_remote = false
  let mut saw_data = false
  let mut empty_count = 0
  let mut saw_unsafe = false
  for image in semantic.images {
    match image.kind {
      @html.HtmlImageKind::Local => {
        saw_local = true
        assert_eq(image.src, "local.png")
        assert_eq(image.alt.unwrap_or(""), "Local")
        assert_eq(image.title.unwrap_or(""), "T")
        assert_eq(image.width.unwrap_or(""), "10")
        assert_eq(image.height.unwrap_or(""), "20")
        assert_eq(image.loading.unwrap_or(""), "lazy")
        assert_eq(image.decoding.unwrap_or(""), "async")
      }
      @html.HtmlImageKind::Remote => {
        saw_remote = true
        assert_true(
          image.warnings[0].kind == @html.HtmlSemanticWarningKind::RemoteImage,
        )
      }
      @html.HtmlImageKind::DataUri => {
        saw_data = true
        assert_true(
          image.warnings[0].kind == @html.HtmlSemanticWarningKind::DataUriImage,
        )
      }
      @html.HtmlImageKind::Empty => {
        empty_count += 1
        assert_true(
          image.warnings[0].kind ==
          @html.HtmlSemanticWarningKind::EmptyImageSource,
        )
      }
      @html.HtmlImageKind::Unsafe => {
        saw_unsafe = true
        assert_true(
          image.warnings[0].kind == @html.HtmlSemanticWarningKind::UnsafeUrl,
        )
      }
      _ => ()
    }
  }

  assert_true(saw_local)
  assert_true(saw_remote)
  assert_true(saw_data)
  assert_eq(empty_count, 2)
  assert_true(saw_unsafe)
}

///|
test "html semantic inline facts stay bounded for nested text attrs and data uri" {
  let mut source = "<article><p><a href='https://example.com/long' title='"
  for _ in 0..<140 {
    source = source + "t"
  }
  source = source + "'"
  for i in 0..<16 {
    source = source +
      " data-a" +
      i.to_string() +
      "='" +
      "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" +
      "'"
  }
  source = source + "><span>"
  for _ in 0..<220 {
    source = source + "x"
  }
  source = source + "</span></a><img src='data:image/png;base64,"
  for _ in 0..<160 {
    source = source + "a"
  }
  source = source + "'></p></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.link_count, 1)
  assert_eq(report.image_count, 1)
  assert_eq(report.data_uri_image_count, 1)
  assert_true(report.warning_count >= 5)

  let link_inline_key = semantic.links[0].inline_source_key
  let mut saw_link_inline = false
  for inline in semantic.inlines {
    if inline.source_key == link_inline_key {
      saw_link_inline = true
      assert_eq(inline.attributes.length(), 12)
      assert_true(inline.text_preview.length() <= 160)
      let warning_kinds = inline.warnings.map(fn(warning) { warning.kind })
      assert_true(
        warning_kinds.contains(
          @html.HtmlSemanticWarningKind::AttributeSummaryTruncated,
        ),
      )
      assert_true(
        warning_kinds.contains(
          @html.HtmlSemanticWarningKind::AttributeValuePreviewTruncated,
        ),
      )
      assert_true(
        warning_kinds.contains(
          @html.HtmlSemanticWarningKind::TextPreviewTruncated,
        ),
      )
    }
  }
  assert_true(saw_link_inline)
  assert_true(semantic.links[0].title.unwrap_or("").length() <= 80)
  assert_true(semantic.links[0].text_preview.length() <= 160)
  assert_true(semantic.images[0].src.length() <= 80)
  let image_warning_kinds = semantic.images[0].warnings.map(fn(warning) {
    warning.kind
  })
  assert_true(
    image_warning_kinds.contains(@html.HtmlSemanticWarningKind::DataUriImage),
  )
}

///|
test "html semantic external href keeps full safe url even when long" {
  let href = "https://epub-samples.googlecode.com/files/moby-dick-20120118.epub#epubcfi('/6/14!/4/2/2/2/2/1')"
  let doc = @html.parse_html_document(
    "<article><p><a href=\"" +
    href +
    "\">Link to Chapter 1 of Moby Dick</a></p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  assert_eq(semantic.links.length(), 1)
  assert_eq(semantic.links[0].href, href)
  assert_true(semantic.links[0].href.length() > 80)
}

///|
test "html semantic table facts collect simple rows header and data cells" {
  let doc = @html.parse_html_document(
    "<article><table id='t'><tr><th scope='col'>Name</th><td>Alice</td></tr><tr><th>Score</th><td>42</td></tr></table></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.table_fact_count, 1)
  assert_eq(report.table_fact_row_count, 2)
  assert_eq(report.table_fact_cell_count, 4)
  assert_eq(report.table_header_cell_count, 2)
  assert_eq(report.table_data_cell_count, 2)
  assert_eq(report.table_caption_count, 0)
  assert_eq(report.table_warning_count, 0)

  let table = semantic.tables[0]
  assert_eq(table.block_source_key, semantic.blocks[1].source_key)
  assert_eq(table.rows.length(), 2)
  assert_eq(table.cells.length(), 4)
  assert_eq(table.row_count, 2)
  assert_eq(table.cell_count, 4)
  assert_eq(table.max_column_count, 2)
  assert_false(table.has_ragged_rows)
  assert_false(table.has_span)
  assert_false(table.has_caption)
  assert_false(table.has_nested_table)
  assert_false(table.has_complex_cell)
  assert_true(table.safe_simple_table_candidate)
  assert_eq(table.text_preview, "NameAliceScore42")
  assert_eq(table.attributes[0].name, "id")

  assert_eq(semantic.table_rows[0].row_index, 0)
  assert_eq(semantic.table_rows[0].cell_count, 2)
  assert_eq(
    semantic.table_rows[0].block_source_key,
    semantic.blocks[2].source_key,
  )
  assert_eq(semantic.table_cells[0].row_index, 0)
  assert_eq(semantic.table_cells[0].cell_index, 0)
  assert_eq(
    semantic.table_cells[0].block_source_key,
    semantic.blocks[3].source_key,
  )
  assert_true(semantic.table_cells[0].kind == @html.HtmlTableCellKind::Header)
  assert_eq(semantic.table_cells[0].scope.unwrap_or(""), "col")
  assert_eq(semantic.table_cells[0].colspan_value, 1)
  assert_eq(semantic.table_cells[0].rowspan_value, 1)
  assert_eq(semantic.table_cells[0].inline_child_keys.length(), 1)
  assert_eq(semantic.table_cells[0].direct_child_block_keys.length(), 0)
  assert_true(semantic.table_cells[0].text_complete)
  assert_false(semantic.table_cells[0].has_complex_block)
  assert_false(semantic.table_cells[0].has_nested_table)
  assert_false(semantic.table_cells[0].has_image)
  assert_false(semantic.table_cells[0].has_list)
  assert_false(semantic.table_cells[0].has_blockquote)
  assert_false(semantic.table_cells[0].has_pre)
  assert_false(semantic.table_cells[0].has_figure)
  assert_false(semantic.table_cells[0].has_unsupported_warning)
  assert_true(semantic.table_cells[0].safe_simple_cell_candidate)
  assert_eq(semantic.table_cells[0].text_preview, "Name")
  assert_true(semantic.table_cells[1].kind == @html.HtmlTableCellKind::Data)
  assert_eq(semantic.table_cells[1].text_preview, "Alice")
  assert_true(semantic.table_cells[1].safe_simple_cell_candidate)
}

///|
test "html semantic table facts preserve caption sections spans headers and scope" {
  let doc = @html.parse_html_document(
    "<article><table>" +
    "<caption>Quarterly Results</caption>" +
    "<thead><tr><th id='h1' scope='col' colspan='2'>Head</th></tr></thead>" +
    "<tbody><tr><td headers='h1' rowspan='2'>A</td><td>B</td></tr></tbody>" +
    "<tfoot><tr><td>Total</td><td>99</td></tr></tfoot>" +
    "</table></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.table_fact_count, 1)
  assert_eq(report.table_section_count, 3)
  assert_eq(report.table_head_section_count, 1)
  assert_eq(report.table_body_section_count, 1)
  assert_eq(report.table_foot_section_count, 1)
  assert_eq(report.table_caption_count, 1)
  assert_eq(report.table_fact_row_count, 3)
  assert_eq(report.table_fact_cell_count, 5)

  let table = semantic.tables[0]
  assert_true(table.caption_source_key is Some(_))
  assert_eq(table.caption_text_preview.unwrap_or(""), "Quarterly Results")
  assert_eq(table.sections.length(), 3)
  assert_eq(table.rows.length(), 3)
  assert_eq(table.cells.length(), 5)
  assert_eq(table.max_column_count, 2)
  assert_true(table.has_caption)
  assert_true(table.has_span)
  assert_true(table.has_ragged_rows)
  assert_false(table.safe_simple_table_candidate)

  assert_true(
    semantic.table_sections[0].kind == @html.HtmlTableSectionKind::Head,
  )
  assert_true(
    semantic.table_sections[1].kind == @html.HtmlTableSectionKind::Body,
  )
  assert_true(
    semantic.table_sections[2].kind == @html.HtmlTableSectionKind::Foot,
  )
  assert_eq(semantic.table_sections[0].row_count, 1)
  assert_eq(semantic.table_cells[0].colspan.unwrap_or(""), "2")
  assert_eq(semantic.table_cells[0].colspan_value, 2)
  assert_eq(semantic.table_cells[0].rowspan_value, 1)
  assert_false(semantic.table_cells[0].safe_simple_cell_candidate)
  assert_eq(semantic.table_cells[0].scope.unwrap_or(""), "col")
  assert_eq(semantic.table_cells[1].rowspan.unwrap_or(""), "2")
  assert_eq(semantic.table_cells[1].colspan_value, 1)
  assert_eq(semantic.table_cells[1].rowspan_value, 2)
  assert_false(semantic.table_cells[1].safe_simple_cell_candidate)
  assert_eq(semantic.table_cells[1].headers.unwrap_or(""), "h1")
}

///|
test "html semantic table facts keep nested and malformed tables bounded" {
  let doc = @html.parse_html_document(
    "<article><table><tr><td>Outer <table><tr><td>Inner</td></tr></table></td></tr></table><table><tbody></tbody></table></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.table_fact_count, 3)
  let mut saw_nested_table_guard = false
  for table in semantic.tables {
    if table.has_nested_table {
      saw_nested_table_guard = true
      assert_eq(table.row_count, 1)
      assert_eq(table.cell_count, 1)
      assert_true(table.has_complex_cell)
      assert_false(table.safe_simple_table_candidate)
    }
  }
  assert_true(saw_nested_table_guard)

  let mut saw_nested_cell_guard = false
  for cell in semantic.table_cells {
    if cell.has_nested_table {
      saw_nested_cell_guard = true
      assert_true(cell.has_complex_block)
      assert_false(cell.safe_simple_cell_candidate)
    }
  }
  assert_true(saw_nested_cell_guard)

  assert_eq(semantic.tables[0].row_count, 1)
  assert_eq(semantic.tables[0].cell_count, 1)
  assert_eq(semantic.tables[1].row_count, 1)
  assert_eq(semantic.tables[1].cell_count, 1)
  assert_eq(semantic.tables[2].row_count, 0)
  assert_eq(semantic.tables[2].cell_count, 0)
  assert_false(semantic.tables[2].safe_simple_table_candidate)
  assert_true(report.table_warning_count >= 2)

  let table_warning_kinds = semantic.tables[2].warnings.map(fn(warning) {
    warning.kind
  })
  assert_true(
    table_warning_kinds.contains(
      @html.HtmlSemanticWarningKind::MalformedTableStructure,
    ),
  )
}

///|
test "html semantic table facts mark ragged and complex cells for m7e guards" {
  let doc = @html.parse_html_document(
    "<article><table><tr><th>A</th><th>B</th></tr><tr><td>Only one</td></tr></table>" +
    "<table><tr><th>Kind</th><th>Value</th></tr><tr><td><img src='x.png' alt='X'></td><td><ul><li>One</li></ul></td></tr><tr><td><blockquote>Q</blockquote></td><td><pre>code</pre></td></tr></table></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)

  assert_eq(semantic.tables.length(), 2)
  assert_true(semantic.tables[0].has_ragged_rows)
  assert_false(semantic.tables[0].safe_simple_table_candidate)

  let complex = semantic.tables[1]
  assert_false(complex.has_ragged_rows)
  assert_true(complex.has_complex_cell)
  assert_false(complex.safe_simple_table_candidate)

  let mut saw_image_cell = false
  let mut saw_list_cell = false
  let mut saw_blockquote_cell = false
  let mut saw_pre_cell = false
  for cell in semantic.table_cells {
    if cell.has_image {
      saw_image_cell = true
      assert_false(cell.safe_simple_cell_candidate)
    }
    if cell.has_list {
      saw_list_cell = true
      assert_true(cell.has_complex_block)
      assert_false(cell.safe_simple_cell_candidate)
    }
    if cell.has_blockquote {
      saw_blockquote_cell = true
      assert_true(cell.has_complex_block)
      assert_false(cell.safe_simple_cell_candidate)
    }
    if cell.has_pre {
      saw_pre_cell = true
      assert_true(cell.has_complex_block)
      assert_false(cell.safe_simple_cell_candidate)
    }
  }
  assert_true(saw_image_cell)
  assert_true(saw_list_cell)
  assert_true(saw_blockquote_cell)
  assert_true(saw_pre_cell)
}

///|
test "html semantic m95 table counters expose spans ragged nested image and block cells" {
  let doc = @html.parse_html_document(
    "<article>" +
    "<table><caption>Cap</caption><thead><tr><th colspan='2'>H</th></tr></thead><tbody><tr><td rowspan='2'>A</td><td><img src='x.png' alt='X'></td></tr><tr><td><blockquote>Q</blockquote></td></tr><tr><td>ragged</td></tr></tbody></table>" +
    "<table><tr><td><table><tr><td>Inner</td></tr></table></td></tr></table>" +
    "</article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.table_fact_count, 3)
  assert_true(report.table_span_cell_count >= 2)
  assert_true(report.table_ragged_row_count >= 1)
  assert_true(report.table_nested_cell_count >= 1)
  assert_true(report.table_complex_cell_count >= 3)
  assert_true(report.table_image_cell_count >= 1)
  assert_true(report.table_block_child_cell_count >= 1)

  let complex = semantic.tables[0]
  assert_eq(complex.caption_text_preview.unwrap_or(""), "Cap")
  assert_true(complex.span_cell_count >= 2)
  assert_true(complex.ragged_row_count >= 1)
  assert_true(complex.image_cell_count >= 1)
  assert_true(complex.block_child_cell_count >= 1)
  assert_false(complex.safe_simple_table_candidate)
}

///|
test "html semantic table facts stay bounded for large attrs and previews" {
  let mut source = "<article><table"
  for i in 0..<16 {
    source = source +
      " data-a" +
      i.to_string() +
      "='" +
      "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz" +
      "'"
  }
  source = source + ">"
  for i in 0..<520 {
    source = source + "<tr><td>"
    for _ in 0..<8 {
      source = source + "cell" + i.to_string()
    }
    source = source + "</td></tr>"
  }
  source = source + "</table></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.table_fact_count, 1)
  assert_eq(report.table_fact_row_count, 520)
  assert_eq(report.table_fact_cell_count, 520)
  assert_eq(report.max_table_row_count, 520)
  assert_eq(report.max_table_cell_count, 520)
  assert_true(report.table_warning_count >= 4)

  let table = semantic.tables[0]
  assert_eq(table.attributes.length(), 12)
  assert_true(table.text_preview.length() <= 160)
  let warning_kinds = table.warnings.map(fn(warning) { warning.kind })
  assert_true(
    warning_kinds.contains(
      @html.HtmlSemanticWarningKind::AttributeSummaryTruncated,
    ),
  )
  assert_true(
    warning_kinds.contains(
      @html.HtmlSemanticWarningKind::AttributeValuePreviewTruncated,
    ),
  )
  assert_true(
    warning_kinds.contains(@html.HtmlSemanticWarningKind::TextPreviewTruncated),
  )
  assert_true(
    warning_kinds.contains(
      @html.HtmlSemanticWarningKind::TableSizeLimitExceeded,
    ),
  )
}

///|
test "html semantic list facts preserve ordered attrs nested depth and malformed lists" {
  let doc = @html.parse_html_document(
    "<article><ol start='3' type='A' reversed><li>First<ul><li>Nested</li></ul></li><li>Second</li></ol><ul><span>loose</span></ul></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.list_fact_count, 3)
  assert_eq(report.ordered_list_fact_count, 1)
  assert_eq(report.unordered_list_fact_count, 2)
  assert_eq(report.list_item_fact_count, 3)
  assert_eq(report.max_list_depth, 2)

  let mut ordered = semantic.lists[0]
  let mut saw_ordered = false
  for list in semantic.lists {
    if list.kind == @html.HtmlListKind::Ordered {
      ordered = list
      saw_ordered = true
    }
  }
  assert_true(saw_ordered)
  assert_true(ordered.kind == @html.HtmlListKind::Ordered)
  assert_eq(ordered.start.unwrap_or(""), "3")
  assert_eq(ordered.type_attr.unwrap_or(""), "A")
  assert_true(ordered.reversed)
  assert_eq(ordered.item_count, 2)
  assert_true(ordered.parent_list_source_key is None)

  let mut first_item = semantic.list_items[0]
  for item in semantic.list_items {
    if item.list_depth == 1 && item.item_order == 0 {
      first_item = item
    }
  }
  assert_eq(first_item.item_order, 0)
  assert_eq(first_item.list_depth, 1)
  assert_eq(first_item.child_list_source_keys.length(), 1)
  let mut nested = semantic.lists[0]
  let mut saw_nested = false
  for list in semantic.lists {
    if list.kind == @html.HtmlListKind::Unordered && list.list_depth == 2 {
      nested = list
      saw_nested = true
    }
  }
  assert_true(saw_nested)
  assert_true(nested.kind == @html.HtmlListKind::Unordered)
  assert_eq(nested.list_depth, 2)
  assert_eq(nested.parent_item_source_key.unwrap_or(""), first_item.source_key)
  let mut saw_nested_item = false
  for item in semantic.list_items {
    if item.list_depth == 2 {
      saw_nested_item = true
    }
  }
  assert_true(saw_nested_item)
  let mut saw_malformed = false
  for list in semantic.lists {
    if list.item_count == 0 && list.text_preview == "loose" {
      saw_malformed = true
    }
  }
  assert_true(saw_malformed)
}

///|
test "html semantic blockquote facts preserve cite and quote depth" {
  let doc = @html.parse_html_document(
    "<article><blockquote cite='https://example.com/q'><p>Outer</p><blockquote><p>Inner</p></blockquote></blockquote></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.blockquote_fact_count, 2)
  assert_eq(report.max_quote_depth, 2)
  let mut outer_quote = semantic.blockquotes[0]
  let mut inner_quote = semantic.blockquotes[0]
  for quote in semantic.blockquotes {
    if quote.quote_depth == 1 {
      outer_quote = quote
    } else if quote.quote_depth == 2 {
      inner_quote = quote
    }
  }
  assert_eq(outer_quote.quote_depth, 1)
  assert_eq(outer_quote.cite.unwrap_or(""), "https://example.com/q")
  assert_eq(outer_quote.text_preview, "OuterInner")
  assert_true(outer_quote.child_block_source_keys.length() >= 2)
  assert_eq(inner_quote.quote_depth, 2)
  assert_eq(
    inner_quote.parent_quote_source_key.unwrap_or(""),
    outer_quote.source_key,
  )
}

///|
test "html semantic pre code facts preserve whitespace preview and language hints" {
  let doc = @html.parse_html_document(
    "<article><pre class='language-moonbit'>let x = 1\n  x + 1</pre><pre><code class='lang-js'>const y = 2;</code></pre><p>Use <code>inline()</code> now.</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.code_block_fact_count, 3)
  assert_eq(report.code_block_language_hint_count, 3)
  assert_eq(report.code_inline_count, 2)

  assert_eq(semantic.code_blocks[0].language_hint.unwrap_or(""), "moonbit")
  assert_eq(semantic.code_blocks[0].code_text, "let x = 1\n  x + 1")
  assert_true(semantic.code_blocks[0].code_text_complete)
  assert_true(semantic.code_blocks[0].whitespace_preview.contains("\n  x + 1"))
  let mut saw_pre_with_code = false
  let mut saw_js_code = false
  for code in semantic.code_blocks {
    if code.tag_name == "pre" && code.code_block_source_key is Some(_) {
      saw_pre_with_code = true
    }
    if code.language_hint.unwrap_or("") == "js" {
      saw_js_code = true
    }
  }
  assert_true(saw_pre_with_code)
  assert_true(saw_js_code)

  let mut saw_inline_code = false
  for inline in semantic.inlines {
    if inline.kind == @html.HtmlInlineKind::Code &&
      inline.text_preview == "inline()" {
      saw_inline_code = true
    }
  }
  assert_true(saw_inline_code)
}

///|
test "html semantic figure facts relate images captions links and bounded text" {
  let doc = @html.parse_html_document(
    "<article><figure class='hero'><a href='full.png'><img src='img.png' alt='Alt'></a><figcaption>Caption text</figcaption></figure><figure><img src='solo.png' alt='Solo'></figure><figure><img src='one.png'><img src='two.png'><table><tr><td>A</td></tr></table></figure></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.figure_fact_count, 3)
  assert_eq(report.figure_caption_count, 1)
  assert_eq(report.figure_image_count, 4)

  let figure = semantic.figures[0]
  assert_eq(figure.caption_text_preview.unwrap_or(""), "Caption text")
  assert_true(figure.caption_block_source_key is Some(_))
  assert_eq(figure.image_source_keys.length(), 1)
  assert_eq(figure.link_source_keys.length(), 1)
  assert_true(figure.inline_child_keys.length() > 0)
  assert_eq(figure.attributes[0].name, "class")
  assert_true(semantic.figures[1].caption_block_source_key is None)
  assert_eq(semantic.figures[1].image_source_keys.length(), 1)
  assert_eq(semantic.figures[2].image_source_keys.length(), 2)
  assert_true(semantic.figures[2].child_block_source_keys.length() > 0)
}

///|
test "html semantic figure caption and huge pre previews stay bounded" {
  let mut source = "<article><figure><figcaption>"
  for _ in 0..<220 {
    source = source + "c"
  }
  source = source + "</figcaption></figure><pre class='language-text'>"
  for _ in 0..<220 {
    source = source + "p"
  }
  source = source + "</pre></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)

  assert_eq(semantic.figures.length(), 1)
  assert_true(
    semantic.figures[0].caption_text_preview.unwrap_or("").length() <= 160,
  )
  assert_eq(semantic.code_blocks.length(), 1)
  assert_true(semantic.code_blocks[0].whitespace_preview.length() <= 160)
  assert_eq(semantic.code_blocks[0].language_hint.unwrap_or(""), "text")
  assert_true(semantic.code_blocks[0].code_text.length() > 160)
  assert_true(semantic.code_blocks[0].code_text_complete)
}

///|
test "html semantic unsupported facts classify element taxonomy with bounded previews" {
  let mut script_text = ""
  for _ in 0..<220 {
    script_text = script_text + "alert(1);"
  }
  let doc = @html.parse_html_document(
    "<article>" +
    "<script>" +
    script_text +
    "</script>" +
    "<style>.x{display:none}</style>" +
    "<iframe src='frame.html'></iframe>" +
    "<embed src='movie.swf'>" +
    "<object data='widget.bin'></object>" +
    "<svg><text>x</text></svg>" +
    "<math><mi>x</mi></math>" +
    "<template><p>tmpl</p></template>" +
    "<form><input name='q'><select><option>one</option></select><textarea>txt</textarea><button>go</button></form>" +
    "<video><source src='movie.mp4'></video>" +
    "<audio><source src='sound.mp3'></audio>" +
    "<canvas>fallback</canvas>" +
    "</article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.unsupported_script_count, 1)
  assert_eq(report.unsupported_style_count, 1)
  assert_eq(report.unsupported_iframe_count, 1)
  assert_eq(report.unsupported_embed_count, 1)
  assert_eq(report.unsupported_object_count, 1)
  assert_eq(report.unsupported_svg_count, 1)
  assert_eq(report.unsupported_math_count, 1)
  assert_eq(report.unsupported_template_count, 1)
  assert_eq(report.unsupported_form_count, 1)
  assert_eq(report.unsupported_input_count, 1)
  assert_eq(report.unsupported_select_count, 1)
  assert_eq(report.unsupported_textarea_count, 1)
  assert_eq(report.unsupported_button_count, 1)
  assert_eq(report.unsupported_video_count, 1)
  assert_eq(report.unsupported_audio_count, 1)
  assert_eq(report.unsupported_source_count, 2)
  assert_eq(report.unsupported_canvas_count, 1)
  assert_true(report.unsupported_fact_count >= 18)
  assert_true(report.unsupported_warning_count >= 18)
  assert_true(report.warning_warning_count >= 18)

  let mut saw_script = false
  for fact in semantic.unsupported {
    if fact.kind == @html.HtmlUnsupportedKind::Script {
      saw_script = true
      assert_eq(fact.tag_name, "script")
      assert_true(fact.text_preview.length() <= 160)
      assert_true(fact.related_source_key.unwrap_or("").contains("script"))
      assert_true(fact.severity == @html.HtmlWarningSeverity::Warning)
    }
  }
  assert_true(saw_script)
}

///|
test "html semantic unsupported facts classify link and image url warnings" {
  let doc = @html.parse_html_document(
    "<article><p>" +
    "<a href='javascript:bad()'>bad</a>" +
    "<a href='data:text/plain,hi'>data</a>" +
    "<a>empty</a>" +
    "<img src='https://example.com/a.png'>" +
    "<img src='data:image/png;base64,abcdef'>" +
    "<img src=''>" +
    "<img alt='missing'>" +
    "<img src='javascript:bad()'>" +
    "</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.link_count, 3)
  assert_eq(report.image_count, 5)
  assert_eq(report.warning_count, 8)
  assert_eq(report.warning_info_count, 4)
  assert_eq(report.warning_warning_count, 4)
  assert_eq(report.unsupported_fact_count, 8)
  assert_eq(report.unsupported_info_count, 4)
  assert_eq(report.unsupported_warning_count, 4)
  assert_eq(report.unsupported_unsafe_url_count, 3)
  assert_eq(report.unsupported_empty_url_count, 3)
  assert_eq(report.unsupported_remote_image_count, 1)
  assert_eq(report.unsupported_data_image_count, 1)

  let mut saw_remote_image = false
  let mut saw_data_image = false
  for fact in semantic.unsupported {
    match fact.kind {
      @html.HtmlUnsupportedKind::RemoteImage => {
        saw_remote_image = true
        assert_eq(fact.url.unwrap_or(""), "https://example.com/a.png")
        assert_true(fact.severity == @html.HtmlWarningSeverity::Info)
      }
      @html.HtmlUnsupportedKind::DataImage => {
        saw_data_image = true
        assert_true(fact.url.unwrap_or("").has_prefix("data:image/png"))
        assert_true(fact.severity == @html.HtmlWarningSeverity::Warning)
      }
      _ => ()
    }
  }
  assert_true(saw_remote_image)
  assert_true(saw_data_image)
}

///|
test "html semantic unsupported facts stay quiet for ordinary paragraph" {
  let doc = @html.parse_html_document(
    "<article><p>Hello <em>world</em> and <a href='#top'>toc</a>.</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.warning_count, 0)
  assert_eq(report.unsupported_fact_count, 0)
  assert_eq(semantic.unsupported.length(), 0)
}

///|
test "html semantic unsupported facts count huge text attrs deep nesting and huge tables" {
  let mut source = "<article><p title='"
  for _ in 0..<140 {
    source = source + "t"
  }
  source = source + "'>"
  for _ in 0..<220 {
    source = source + "x"
  }
  source = source + "</p>"
  for _ in 0..<270 {
    source = source + "<div>"
  }
  source = source + "deep"
  for _ in 0..<270 {
    source = source + "</div>"
  }
  source = source + "<table>"
  for _ in 0..<513 {
    source = source + "<tr><td>x</td></tr>"
  }
  source = source + "</table></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_true(report.warning_count > 0)
  assert_true(report.unsupported_huge_text_node_count > 0)
  assert_true(report.unsupported_huge_attribute_value_count > 0)
  assert_true(report.unsupported_deep_nesting_count > 0)
  assert_eq(report.unsupported_huge_table_count, 1)
  assert_true(report.max_depth <= 256)
}

///|
test "html semantic m95 note facts relate refs bodies duplicates and backrefs" {
  let doc = @html.parse_html_document(
    "<article><p>Text <a epub:type='noteref' href='#fn1'>1</a><a role='doc-noteref' href='#missing'>2</a></p>" +
    "<aside epub:type='footnote' id='fn1'>1. Body <a epub:type='backlink' href='#ref1'>back</a></aside>" +
    "<aside role='doc-footnote' id='fn1'>duplicate body</aside></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.note_ref_fact_count, 3)
  assert_eq(report.note_body_fact_count, 2)
  assert_true(report.note_fact_count >= 4)
  assert_eq(report.broken_note_ref_count, 0)
  assert_eq(report.duplicate_note_body_count, 1)
  assert_true(report.backref_note_count >= 1)

  let first_ref = semantic.note_refs[0]
  assert_eq(first_ref.target_id.unwrap_or(""), "fn1")
  assert_true(first_ref.kind == @html.HtmlNoteKind::Reference)
  assert_true(
    first_ref.relation_confidence == @html.HtmlNoteRelationConfidence::Medium,
  )
  assert_false(first_ref.is_broken)
  assert_false(first_ref.is_back_reference)

  let body = semantic.note_bodies[0]
  assert_true(body.kind == @html.HtmlNoteKind::Footnote)
  assert_eq(body.note_id.unwrap_or(""), "fn1")
  assert_true(body.body_text_preview.contains("Body"))
  assert_false(body.duplicate_target)
  assert_true(semantic.note_bodies[1].duplicate_target)

  let mut saw_high_relation = false
  let mut saw_missing_relation = false
  let mut saw_backref = false
  for note in semantic.notes {
    if note.note_id == Some("fn1") &&
      note.relation_confidence == @html.HtmlNoteRelationConfidence::High {
      saw_high_relation = true
      assert_true(note.ref_source_key is Some(_))
      assert_true(note.body_source_key is Some(_))
    }
    if note.note_id == Some("missing") &&
      note.relation_confidence == @html.HtmlNoteRelationConfidence::Broken {
      saw_missing_relation = true
      assert_true(note.body_source_key is None)
    }
    if note.kind == @html.HtmlNoteKind::BackReference {
      saw_backref = true
      assert_true(note.ref_source_key is Some(_))
    }
  }
  assert_true(saw_high_relation)
  assert_true(saw_missing_relation)
  assert_true(saw_backref)
}

///|
test "html semantic m95 note facts flag broken non-fragment targets" {
  let doc = @html.parse_html_document(
    "<article><p><a epub:type='noteref' href='notes.html#fn1'>external</a></p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.note_ref_fact_count, 1)
  assert_eq(report.broken_note_ref_count, 1)
  assert_true(semantic.note_refs[0].is_broken)
  assert_true(
    semantic.note_refs[0].relation_confidence ==
    @html.HtmlNoteRelationConfidence::Broken,
  )
}

///|
test "html semantic m95 scope facts expose body fragment malformed and metadata" {
  let full = @html.collect_html_semantic_document(
    @html.parse_html_document(
      "<html><head><title>Doc Title</title><meta charset='utf-8'><meta name='viewport' content='width=device-width'><meta name='description' content='Desc'></head><body><main><p>Body</p></main></body></html>",
    ),
  )
  let full_report = @html.inspect_html_semantic_document(full)
  assert_eq(full_report.scope_fact_count, 1)
  assert_eq(full_report.scope_main_count, 1)
  assert_eq(full_report.scope_body_count, 0)
  assert_eq(full_report.scope_missing_body_count, 0)
  assert_true(full.scope[0].scope_source == @html.HtmlDocumentScopeSource::Main)
  assert_eq(full.scope[0].title_text_preview.unwrap_or(""), "Doc Title")
  assert_eq(full.scope[0].meta_charset.unwrap_or(""), "utf-8")
  assert_eq(full.scope[0].meta_viewport.unwrap_or(""), "width=device-width")
  assert_eq(full.scope[0].meta_description.unwrap_or(""), "Desc")
  assert_true(full.scope[0].body_node_key is Some(_))
  assert_true(full.scope[0].selected_content_root_key is Some(_))

  let fragment = @html.collect_html_semantic_document(
    @html.parse_html_document("<article><p>Fragment</p></article>"),
  )
  let fragment_report = @html.inspect_html_semantic_document(fragment)
  assert_eq(fragment_report.scope_article_count, 1)
  assert_eq(fragment_report.scope_fragment_count, 0)
  assert_true(
    fragment.scope[0].scope_source == @html.HtmlDocumentScopeSource::Article,
  )

  let missing_body = @html.collect_html_semantic_document(
    @html.parse_html_document(
      "<html><head><title>No body</title></head><p>x</p></html>",
    ),
  )
  let missing_report = @html.inspect_html_semantic_document(missing_body)
  assert_eq(missing_report.scope_document_root_count, 1)
  assert_eq(missing_report.scope_missing_body_count, 1)
  assert_true(missing_body.scope[0].missing_body_warning)

  let malformed = @html.collect_html_semantic_document(
    @html.parse_html_document(
      "<html><body><p>one</p></body><body><p>two</p></body></html>",
    ),
  )
  let malformed_report = @html.inspect_html_semantic_document(malformed)
  assert_eq(malformed_report.scope_body_count, 1)
  assert_eq(malformed_report.scope_multiple_body_count, 1)
  assert_eq(malformed_report.scope_malformed_root_count, 1)
  assert_true(malformed.scope[0].multiple_body_warning)
}

///|
test "html semantic preserves separator whitespace inside inline containers" {
  let semantic = @html.collect_html_semantic_document(
    @html.parse_html_document(
      "<main><h1><code>&lt;main&gt;</code> HTML main element</h1></main>",
    ),
  )
  let heading = semantic.blocks[1]
  match heading.kind {
    @html.HtmlBlockKind::Heading(level) => assert_eq(level, 1)
    _ => fail("expected h1 semantic block")
  }
  assert_true(heading.text_preview.contains("HTML main element"))
  assert_false(heading.text_preview.contains("<main>HTML"))
  assert_false(heading.text_preview.contains("&lt;main&gt;HTML"))
  let mut saw_code = false
  for inline in semantic.inlines {
    if inline.kind == @html.HtmlInlineKind::Code &&
      (inline.text_preview == "&lt;main&gt;" || inline.text_preview == "<main>") {
      saw_code = true
    }
  }
  assert_true(saw_code)
}

///|
test "html semantic scope prefers main content root over body" {
  let semantic = @html.collect_html_semantic_document(
    @html.parse_html_document(
      "<html><body><main><p>Body</p></main></body></html>",
    ),
  )
  assert_true(
    semantic.scope[0].scope_source == @html.HtmlDocumentScopeSource::Main,
  )
  match semantic.scope[0].selected_content_root_key {
    Some(key) => {
      let mut saw_main = false
      for block in semantic.blocks {
        if block.source_key == key {
          saw_main = true
          assert_eq(block.tag_name, "main")
        }
      }
      assert_true(saw_main)
    }
    None => fail("expected main content root")
  }
}

///|
test "html semantic m95 noise candidate facts expose hints without product filtering" {
  let doc = @html.parse_html_document(
    "<article><nav class='menu'>Nav</nav><footer>Footer</footer><aside class='sidebar toc'>Side</aside><div hidden>Hidden</div><div style='display:none'>Style hidden</div><script>skip()</script><style>.x{}</style><template><p>T</p></template><p>Visible</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_true(report.noise_candidate_count >= 8)
  assert_true(report.noise_nav_like_count >= 1)
  assert_true(report.noise_footer_like_count >= 1)
  assert_true(report.noise_sidebar_like_count >= 1)
  assert_true(report.noise_hiddenish_count >= 2)
  assert_true(report.noise_script_style_template_count >= 3)
  assert_eq(
    semantic.scope[0].noise_candidate_source_keys.length(),
    report.noise_candidate_count,
  )

  let mut saw_nav = false
  let mut saw_hidden = false
  for noise in semantic.noise_candidates {
    if noise.reasons.contains(@html.HtmlNoiseCandidateReason::NavLike) {
      saw_nav = true
      assert_true(noise.confidence == @html.HtmlNoiseCandidateConfidence::High)
    }
    if noise.reasons.contains(@html.HtmlNoiseCandidateReason::Hiddenish) {
      saw_hidden = true
      assert_true(noise.text_preview.to_lower().contains("hidden"))
    }
  }
  assert_true(saw_nav)
  assert_true(saw_hidden)
}

///|
test "html semantic nav-like noise does not overmatch hyphenated content ids" {
  let doc = @html.parse_html_document(
    "<article>" +
    "<section id='toc-nav'><h2><code>toc nav</code></h2><p>Body A</p></section>" +
    "<section id='landmarks-nav'><h2><code>landmarks nav</code></h2><p>Body B</p></section>" +
    "<section id='page-list-nav'><h2><code>page-list nav</code></h2><p>110</p></section>" +
    "<section id='custom-nav'><h2>Custom <code>nav</code> elements</h2><p>Glossary</p></section>" +
    "</article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)

  for noise in semantic.noise_candidates {
    if noise.text_preview.contains("toc nav") ||
      noise.text_preview.contains("landmarks nav") ||
      noise.text_preview.contains("page-list nav") ||
      noise.text_preview.contains("Custom nav elements") {
      fail("hyphenated content ids must not become nav-like noise")
    }
  }
}

///|
test "html semantic m95 complex inline image link facts expose relations and attrs" {
  let doc = @html.parse_html_document(
    "<article><p> A&nbsp; <a href='https://example.com' title='T' target='_blank' rel='noopener'><span>nested</span><img src='local.png' srcset='local-2x.png 2x' alt='Alt' title='Title'></a> <a href='javascript:bad'>bad</a><img src='data:image/png;base64,abc' alt='Data'><picture><source srcset='wide.png'><img src='/abs.png' alt='Abs'></picture> tail</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.link_count, 2)
  assert_true(report.linked_image_count >= 1)
  assert_true(report.image_in_link_count >= 1)
  assert_eq(report.unsafe_link_count, 1)
  assert_true(report.srcset_image_count >= 1)
  assert_true(report.unsupported_source_count >= 1)
  assert_true(report.data_uri_image_count >= 1)
  assert_true(report.local_image_count >= 1)

  let linked = semantic.links[0]
  assert_true(linked.has_nested_inline)
  assert_true(linked.has_image)
  assert_eq(linked.image_source_keys.length(), 1)
  assert_eq(linked.inline_child_keys.length(), 2)
  assert_eq(linked.title.unwrap_or(""), "T")
  assert_eq(linked.target.unwrap_or(""), "_blank")
  assert_eq(linked.rel.unwrap_or(""), "noopener")

  let linked_image = semantic.images[0]
  assert_eq(
    linked_image.parent_link_source_key.unwrap_or(""),
    linked.source_key,
  )
  assert_eq(linked_image.srcset.unwrap_or(""), "local-2x.png 2x")
  assert_true(linked_image.alt_complete)
  assert_true(linked_image.title_complete)

  let mut saw_decoded_space = false
  let mut saw_surrounding_link = false
  for inline in semantic.inlines {
    if inline.kind == @html.HtmlInlineKind::Text &&
      inline.normalized_text_preview.contains("A") {
      saw_decoded_space = true
      assert_true(inline.has_leading_whitespace)
    }
    if inline.kind == @html.HtmlInlineKind::Link && inline.has_surrounding_text {
      saw_surrounding_link = true
    }
  }
  assert_true(saw_decoded_space)
  assert_true(saw_surrounding_link)
}

///|
test "html semantic pre code text is bounded for lowering" {
  let mut source = "<article><pre>"
  for _ in 0..<(128 * 1024 + 32) {
    source = source + "x"
  }
  source = source + "</pre></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)

  assert_eq(semantic.code_blocks.length(), 1)
  assert_eq(semantic.code_blocks[0].code_text.length(), 128 * 1024)
  assert_false(semantic.code_blocks[0].code_text_complete)
}

///|
test "html semantic paragraph facts summarize inline spacing and candidates" {
  let doc = @html.parse_html_document(
    "<article>" +
    "<p>hello   <a href='https://example.com'>world</a> !\n" +
    "<em>em</em><strong>strong</strong><code> x  y </code><br>" +
    "<img src='local.png' alt='Alt'></p>" +
    "<div>candidate text</div>" +
    "<p>   </p>" +
    "</article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.paragraph_fact_count, 3)
  assert_eq(report.paragraph_with_link_count, 1)
  assert_eq(report.paragraph_with_image_count, 1)
  assert_eq(report.paragraph_with_code_count, 1)
  assert_eq(report.paragraph_with_emphasis_count, 1)
  assert_eq(report.paragraph_with_strong_count, 1)
  assert_eq(report.paragraph_with_break_count, 1)
  assert_eq(report.paragraph_meaningful_text_count, 2)
  assert_eq(report.paragraph_candidate_count, 1)
  assert_eq(report.paragraph_repeated_whitespace_count, 2)
  assert_eq(report.paragraph_newline_count, 1)
  assert_true(report.leading_whitespace_inline_count > 0)
  assert_true(report.trailing_whitespace_inline_count > 0)
  assert_true(report.repeated_whitespace_inline_count > 0)
  assert_true(report.newline_inline_count > 0)
  assert_eq(report.whitespace_preserving_inline_count, 1)
  assert_true(report.inline_with_surrounding_text_count > 0)

  let first_paragraph = semantic.paragraphs[0]
  assert_true(first_paragraph.raw_text_preview.contains("hello"))
  assert_true(first_paragraph.raw_text_preview.contains("world"))
  assert_true(first_paragraph.normalized_text_preview.contains("hello world"))
  assert_true(first_paragraph.has_links)
  assert_true(first_paragraph.has_images)
  assert_true(first_paragraph.has_code)
  assert_true(first_paragraph.has_emphasis)
  assert_true(first_paragraph.has_strong)
  assert_true(first_paragraph.has_breaks)
  assert_true(first_paragraph.has_repeated_whitespace)
  assert_true(first_paragraph.has_newline)
  assert_false(first_paragraph.is_candidate)
  assert_true(first_paragraph.inline_child_keys.length() > 0)

  let mut saw_surrounded_link = false
  let mut saw_inline_code = false
  for inline in semantic.inlines {
    if inline.kind == @html.HtmlInlineKind::Link {
      saw_surrounded_link = inline.has_surrounding_text
      assert_eq(inline.text_preview, "world")
    }
    if inline.kind == @html.HtmlInlineKind::Code {
      saw_inline_code = true
      assert_eq(inline.raw_text_preview, " x  y ")
      assert_eq(inline.normalized_text_preview, "x y")
      assert_true(inline.contains_repeated_whitespace)
      assert_true(inline.preserves_whitespace)
    }
  }
  assert_true(saw_surrounded_link)
  assert_true(saw_inline_code)

  let candidate = semantic.paragraphs[1]
  assert_true(candidate.is_candidate)
  assert_eq(candidate.tag_name, "div")
  assert_eq(candidate.normalized_text_preview, "candidate text")

  let empty = semantic.paragraphs[2]
  assert_false(empty.has_meaningful_text)
  assert_false(empty.is_candidate)
}

///|
test "html semantic simple paragraph facts can drive m7a inline readiness" {
  let doc = @html.parse_html_document(
    "<article><p>alpha <span>span</span><em>em</em><strong>strong</strong><code> x  y </code><br>tail</p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.paragraph_fact_count, 1)
  assert_eq(report.paragraph_with_link_count, 0)
  assert_eq(report.paragraph_with_image_count, 0)
  assert_eq(report.paragraph_with_code_count, 1)
  assert_eq(report.paragraph_with_emphasis_count, 1)
  assert_eq(report.paragraph_with_strong_count, 1)
  assert_eq(report.paragraph_with_break_count, 1)
  assert_eq(report.span_inline_count, 1)
  assert_eq(report.whitespace_preserving_inline_count, 1)
  assert_true(report.repeated_whitespace_inline_count > 0)

  let paragraph = semantic.paragraphs[0]
  assert_eq(paragraph.tag_name, "p")
  assert_false(paragraph.is_candidate)
  assert_true(paragraph.has_meaningful_text)
  assert_false(paragraph.has_links)
  assert_false(paragraph.has_images)
  assert_true(paragraph.inline_child_keys.length() >= 6)

  let mut saw_span = false
  let mut saw_break = false
  let mut saw_code = false
  for key in paragraph.inline_child_keys {
    for inline in semantic.inlines {
      if inline.source_key == key {
        match inline.kind {
          @html.HtmlInlineKind::Span => saw_span = true
          @html.HtmlInlineKind::Break => saw_break = true
          @html.HtmlInlineKind::Code => {
            saw_code = true
            assert_eq(inline.raw_text_preview, " x  y ")
            assert_eq(inline.normalized_text_preview, "x y")
            assert_true(inline.preserves_whitespace)
          }
          _ => ()
        }
      }
    }
  }
  assert_true(saw_span)
  assert_true(saw_break)
  assert_true(saw_code)
}

///|
test "html semantic heading facts expose level and inline child keys for m7b" {
  let doc = @html.parse_html_document(
    "<article><h2>Head <span>span</span><em>em</em><code>x</code><br>tail</h2></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.heading_count, 1)
  assert_eq(report.span_inline_count, 1)
  assert_eq(report.emphasis_inline_count, 1)
  assert_eq(report.code_inline_count, 1)
  assert_eq(report.break_inline_count, 1)

  let heading = semantic.blocks[1]
  match heading.kind {
    @html.HtmlBlockKind::Heading(level) => assert_eq(level, 2)
    _ => fail("expected h2 semantic block")
  }
  assert_eq(heading.tag_name, "h2")
  assert_true(heading.text_preview.contains("Head"))
  assert_true(heading.text_preview.contains("tail"))

  let mut top_level_inline_count = 0
  for inline in semantic.inlines {
    if inline.parent_block_source_key == Some(heading.source_key) &&
      inline.parent_inline_source_key is None {
      top_level_inline_count += 1
    }
  }
  assert_true(top_level_inline_count >= 6)
}

///|
test "html semantic link paragraph facts classify safe and guarded links for m7b" {
  let doc = @html.parse_html_document(
    "<article><p><a href='#top'>internal</a><a href='https://example.com'>external</a><a href='mailto:a@example.com'>mail</a><a href='tel:+123'>tel</a></p>" +
    "<p><a href='javascript:bad'>bad</a><a href='data:text/plain,hi'>data</a><a>empty</a></p></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.paragraph_fact_count, 2)
  assert_eq(report.paragraph_with_link_count, 2)
  assert_eq(report.link_count, 7)
  assert_eq(report.internal_link_count, 1)
  assert_eq(report.external_link_count, 1)
  assert_eq(report.mailto_link_count, 1)
  assert_eq(report.tel_link_count, 1)
  assert_eq(report.unsafe_link_count, 1)
  assert_eq(report.data_link_count, 1)
  assert_eq(report.empty_link_count, 1)
  assert_eq(report.unsupported_unsafe_url_count, 2)
  assert_eq(report.unsupported_empty_url_count, 1)

  let safe = semantic.paragraphs[0]
  assert_true(safe.has_links)
  assert_false(safe.has_images)
  assert_true(safe.has_meaningful_text)

  let guarded = semantic.paragraphs[1]
  assert_true(guarded.has_links)
  assert_true(guarded.has_meaningful_text)
}

///|
test "html semantic list item facts expose safe and nested guard signals for m7c" {
  let doc = @html.parse_html_document(
    "<article><ul><li>Alpha <a href='https://example.com'>link</a></li><li>Nested<ul><li>Child</li></ul></li></ul><ol><li><code>x</code><br>tail</li></ol></article>",
  )
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_eq(report.list_fact_count, 3)
  assert_eq(report.unordered_list_fact_count, 2)
  assert_eq(report.ordered_list_fact_count, 1)
  assert_eq(report.list_item_fact_count, 4)
  assert_eq(report.max_list_depth, 2)

  let mut saw_safe_link_item = false
  let mut saw_nested_guard_item = false
  let mut saw_code_break_item = false
  for item in semantic.list_items {
    if item.list_depth == 1 && item.text_preview.contains("Alpha") {
      saw_safe_link_item = true
      assert_eq(item.item_order, 0)
      assert_eq(item.child_list_source_keys.length(), 0)
      assert_true(item.list_source_key is Some(_))
    }
    if item.list_depth == 1 && item.text_preview.contains("Nested") {
      saw_nested_guard_item = true
      assert_eq(item.child_list_source_keys.length(), 1)
    }
    if item.list_depth == 1 && item.text_preview.contains("xtail") {
      saw_code_break_item = true
      assert_eq(item.child_list_source_keys.length(), 0)
    }
  }
  assert_true(saw_safe_link_item)
  assert_true(saw_nested_guard_item)
  assert_true(saw_code_break_item)
}

///|
test "html semantic inspect report exposes profile-sized fact counters" {
  let mut source = "<article><h1>Profile Facts</h1>"
  for i in 0..<24 {
    source = source +
      "<p>Paragraph " +
      i.to_string() +
      " <a href='https://example.com/" +
      i.to_string() +
      "'>link</a>"
    if i % 8 == 0 {
      source = source + " <img src='local-" + i.to_string() + ".png' alt='img'>"
    }
    source = source + "</p>"
  }
  source = source +
    "<p>See <a epub:type='noteref' href='#n1'>1</a>.</p>" +
    "<table><tr><th>K</th><th>V</th></tr><tr><td>A</td><td>B</td></tr></table>" +
    "<aside epub:type='footnote' id='n1'>Parser note.</aside>" +
    "<script>skip()</script></article>"

  let doc = @html.parse_html_document(source)
  let semantic = @html.collect_html_semantic_document(doc)
  let report = @html.inspect_html_semantic_document(semantic)

  assert_true(report.block_count >= 28)
  assert_true(report.paragraph_fact_count >= 25)
  assert_true(report.inline_count >= 24)
  assert_eq(report.link_count, 25)
  assert_eq(report.image_count, 3)
  assert_eq(report.table_fact_count, 1)
  assert_eq(report.table_fact_cell_count, 4)
  assert_true(report.note_fact_count >= 1)
  assert_true(report.noise_candidate_count >= 1)
  assert_true(report.warning_count >= 1)
  assert_true(report.unsupported_fact_count >= 1)
}
