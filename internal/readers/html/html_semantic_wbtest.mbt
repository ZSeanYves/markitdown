///|
test "HTML semantic collector covers rich document facts and warnings" {
  let html = [
    "<!doctype html><html><head><title>Fixture</title><script>alert(1)</script><style>.x{}</style></head>",
    "<body><header>Repeated header</header><main><article><section>", "<h1 id='top'>Title <em>em</em> <strong>strong</strong> <code>code</code></h1>",
    "<p>Text <a href='#note-1'>internal</a> <a href='https://example.test'>external</a>",
    "<a href='mailto:a@example.test'>mail</a> <a href='tel:+1'>tel</a>", "<a href='javascript:alert(1)'>unsafe</a> <a href=''>empty</a><br>",
    "<a href='https://example.test/image'><img src='local.png' srcset='a.png 1x, b.png 2x' alt='local'></a>",
    "<img src='https://example.test/remote.png'><img src='data:image/png;base64,AA=='><img src=''></p>",
    "<ul><li>one<ol><li>nested</li></ol></li><li><blockquote><p>quote</p></blockquote></li></ul>",
    "<pre><code class='language-moonbit'>fn main() {}</code></pre>", "<figure><img src='figure.png'><figcaption>Figure caption</figcaption></figure>",
    "<p> repeated   whitespace\nnext <span>span</span><custom-inline>unknown inline</custom-inline></p><hr>",
    "<picture><source srcset='wide.png 2x'><img src='javascript:unsafe' srcset='small.png 1x'></picture>",
    "<table><caption>Table caption</caption><thead><tr><th rowspan='2'>H</th><th>V</th></tr></thead>",
    "<tbody><tr><td colspan='2'><p>complex</p><table><tr><td>nested</td></tr></table></td></tr>",
    "<tr><td>ragged</td></tr></tbody><tfoot><tr><td>foot</td><td>end</td></tr></tfoot></table>",
    "<p>Reference<a href='#fn1' role='doc-noteref'>1</a></p>", "<ol><li id='fn1' role='doc-endnote'>Note body <a href='#top' role='doc-backlink'>back</a></li></ol>",
    "<aside class='sidebar advertisement'>noise</aside><nav>navigation</nav>", "<iframe src='https://example.test'></iframe><embed><object></object><form><input><select><option>x</option></select><textarea>x</textarea><button>go</button></form>",
    "<video><source src='movie.mp4'></video><audio src='sound.mp3'></audio><canvas>x</canvas>",
    "<svg><path></path></svg><math><mi>x</mi></math><template>hidden</template>",
    "</section></article></main><footer>Repeated footer</footer></body></html>",
  ].join("")
  let semantic = collect_html_semantic_document(parse_html_document(html))
  let report = inspect_html_semantic_document(semantic)
  assert_true(report.heading_count >= 1)
  assert_true(report.paragraph_count >= 3)
  assert_true(report.list_count >= 2)
  assert_true(report.list_item_count >= 3)
  assert_true(report.table_count >= 2)
  assert_true(report.table_cell_count >= 5)
  assert_true(report.blockquote_count >= 1)
  assert_true(report.code_block_count >= 1)
  assert_true(report.figure_count >= 1)
  assert_true(report.horizontal_rule_count >= 1)
  assert_true(report.link_count >= 7)
  assert_true(report.image_count >= 5)
  assert_true(report.unsafe_link_count >= 1)
  assert_true(report.remote_image_count >= 1)
  assert_true(report.data_uri_image_count >= 1)
  assert_true(report.unsafe_image_count >= 1)
  assert_true(report.table_foot_section_count >= 1)
  assert_true(report.repeated_whitespace_inline_count >= 1)
  assert_true(report.newline_inline_count >= 1)
  assert_true(report.unsupported_fact_count >= 5)
  assert_true(report.warning_count >= 5)
  assert_true(report.max_depth >= 5)
  assert_true(semantic.notes.length() >= 1)
  assert_true(semantic.noise_candidates.length() >= 1)
}

///|
test "HTML semantic scope inspection covers fragments and malformed roots" {
  for
    html in [
      "<section><p>fragment</p></section>", "<html><body><p>one</p></body><body><p>two</p></body></html>",
      "<html><head><title>missing body</title></head><main><p>x</p></main></html>",
    ] {
    let report = inspect_html_semantic_document(
      collect_html_semantic_document(parse_html_document(html)),
    )
    assert_true(report.scope_fact_count >= 1)
  }
}

///|
test "HTML semantic scope and table recovery cover empty fallback structures" {
  let article = inspect_html_semantic_document(
    collect_html_semantic_document(
      parse_html_document("<article><p>article only</p></article>"),
    ),
  )
  assert_true(article.scope_fact_count == 1)

  let document_root = collect_html_semantic_document(
    parse_html_document("<html><head><title>root only</title></head></html>"),
  )
  assert_true(document_root.scope.length() == 1)
  assert_true(document_root.scope[0].scope_source == DocumentRoot)
  assert_true(document_root.scope[0].missing_body_warning)

  let empty = collect_html_semantic_document(parse_html_document(""))
  assert_true(empty.scope.length() == 1)
  assert_true(empty.scope[0].scope_source == Heuristic)

  let malformed_tables = collect_html_semantic_document(
    parse_html_document(
      "<main><table></table><table><thead></thead></table></main>",
    ),
  )
  let warning_kinds = malformed_tables.warnings.map(warning => warning.kind)
  assert_true(warning_kinds.contains(MalformedTableStructure))
}

///|
test "HTML semantic guards bound depth previews attributes and large tables" {
  let deep = Array::make(260, "<span>").join("") +
    Array::make(320, "x").join("") +
    Array::make(260, "</span>").join("")
  let attrs : Array[String] = []
  for index in 0..<20 {
    attrs.push(
      "data-a" + index.to_string() + "='" + Array::make(100, "v").join("") + "'",
    )
  }
  let rows : Array[String] = []
  for row in 0..<520 {
    let cells : Array[String] = []
    for col in 0..<8 {
      cells.push("<td>" + row.to_string() + ":" + col.to_string() + "</td>")
    }
    rows.push("<tr>" + cells.join("") + "</tr>")
  }
  let html = "<main><p " +
    attrs.join(" ") +
    ">" +
    deep +
    "</p><table>" +
    rows.join("") +
    "</table></main>"
  let semantic = collect_html_semantic_document(parse_html_document(html))
  let kinds = semantic.warnings.map(warning => warning.kind)
  assert_true(kinds.contains(DepthLimitExceeded))
  assert_true(kinds.contains(TextPreviewTruncated))
  assert_true(kinds.contains(AttributeSummaryTruncated))
  assert_true(kinds.contains(TableSizeLimitExceeded))
}

///|
test "HTML preparation retains only a scan summary above the block-stream limit" {
  let body = "<p>bounded 😀</p>".repeat(20_000)
  let prepared = prepare_html_document_from_source(
    @input.input_from_text_with_format(
      "<main>" + body + "</main>",
      "large.html",
      Some(Html),
    ),
  ).unwrap()
  assert_true(prepared.document is None)
  assert_true(prepared.inspect is None)
  assert_true(prepared.events is None)
  assert_true(prepared.event_summary is Some(_))
  assert_true(prepared.event_summary.unwrap().node_count > 20_000)
}

///|
test "HTML semantic helper classifiers cover boundary values" {
  assert_eq(parse_html_semantic_positive_int_attr(None), 1)
  assert_eq(parse_html_semantic_positive_int_attr(Some("0")), 1)
  assert_eq(parse_html_semantic_positive_int_attr(Some("3")), 3)
  assert_eq(parse_html_semantic_positive_int_attr(Some("invalid")), 1)
  assert_true(html_semantic_inline_kind("em") == Some(Emphasis))
  assert_true(html_semantic_inline_kind("strong") == Some(Strong))
  assert_true(html_semantic_inline_kind("unknown") is None)
  assert_true(html_semantic_table_section_kind("thead") == Some(Head))
  assert_true(html_semantic_table_section_kind("tfoot") == Some(Foot))
  assert_true(html_semantic_table_section_kind("div") is None)
  assert_true(html_semantic_table_cell_kind("th") == Some(Header))
  assert_true(html_semantic_table_cell_kind("td") == Some(Data))
  assert_true(html_semantic_table_cell_kind("div") is None)
  assert_true(classify_html_semantic_link_kind("#local") == Internal)
  assert_true(classify_html_semantic_link_kind("mailto:a@b") == Mailto)
  assert_true(classify_html_semantic_link_kind("tel:1") == Tel)
  assert_true(classify_html_semantic_link_kind("data:text/plain,x") == Data)
  assert_true(classify_html_semantic_link_kind("javascript:x") == Unsafe)
  assert_true(classify_html_semantic_link_kind("") == Empty)
  assert_true(classify_html_semantic_image_kind("image.png") == Local)
  assert_true(classify_html_semantic_image_kind("https://x/y.png") == Remote)
  assert_true(classify_html_semantic_image_kind("data:image/png,x") == DataUri)
  assert_true(classify_html_semantic_image_kind("") == Empty)
  assert_true(
    html_semantic_language_hint_from_class("foo language-rust bar") ==
    Some("rust"),
  )
  assert_true(html_semantic_language_hint_from_class("none") is None)
  assert_true(html_semantic_fragment_id_from_href("#note") == Some("note"))
  assert_true(html_semantic_fragment_id_from_href("https://x") is None)
  assert_eq(
    bounded_html_semantic_url(Array::make(5000, "x").join("")).length(),
    80,
  )
}

///|
test "HTML semantic policy tables cover all block unsupported and URL branches" {
  for
    tag in [
      "h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "ol", "li", "table", "tr", "th",
      "td", "blockquote", "pre", "code", "figure", "figcaption", "hr", "body", "main",
      "article", "section", "div", "details", "summary", "header", "footer", "nav",
      "aside", "thead", "tbody", "tfoot", "script", "style",
    ] {
    assert_true(html_semantic_block_kind(tag) is Some(_))
  }
  assert_true(html_semantic_block_kind("span") is None)
  for
    tag in [
      "script", "noscript", "style", "iframe", "embed", "object", "svg", "math",
      "template", "form", "input", "select", "textarea", "button", "video", "audio",
      "source", "canvas",
    ] {
    assert_true(html_semantic_unsupported_kind_for_tag(tag) is Some(_))
    assert_true(is_html_semantic_unsupported_tag(tag))
  }
  assert_true(html_semantic_unsupported_kind_for_tag("main") is None)
  for
    kind in [
      HtmlLinkKind::Internal,
      External,
      Mailto,
      Tel,
      Unknown,
      Data,
      Unsafe,
      Empty,
    ] {
    ignore(html_semantic_unsupported_kind_for_link(kind))
  }
  for kind in [HtmlImageKind::Local, Remote, DataUri, Unsafe, Empty, Unknown] {
    ignore(html_semantic_unsupported_kind_for_image(kind))
  }
  for
    kind in [
      HtmlUnsupportedKind::RemoteImage,
      DataImage,
      UnsafeUrl,
      EmptyUrl,
      UnknownUnsupported,
    ] {
    ignore(html_semantic_unsupported_url_severity(kind))
    assert_true(html_semantic_unsupported_url_message(kind, "image") != "")
  }
  assert_eq(clamp_html_semantic_depth(-1), -1)
  assert_eq(clamp_html_semantic_depth(0), 0)
  assert_eq(clamp_html_semantic_depth(1), 1)
  assert_true(clamp_html_semantic_depth(999) < 999)
  assert_true(html_semantic_has_leading_whitespace(" x"))
  assert_true(html_semantic_has_trailing_whitespace("x "))
  assert_true(html_semantic_contains_newline("x\ny"))
  assert_true(html_semantic_contains_repeated_whitespace("x  y"))
  assert_eq(normalize_html_semantic_preview("  a\n  b  "), "a b")
  assert_true(html_semantic_first_source_key(None, Some("b")) == Some("b"))
  assert_true(html_semantic_first_source_key(Some("a"), Some("b")) == Some("a"))
  assert_eq(html_semantic_source_key("p", 2), "html:block:p:2")
  assert_eq(html_semantic_list_source_key(3), "html:list:3")
  assert_eq(html_semantic_list_item_source_key(4), "html:list-item:4")
  assert_eq(html_semantic_blockquote_source_key(5), "html:blockquote:5")
}
