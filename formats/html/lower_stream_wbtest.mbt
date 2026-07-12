///|
test "HTML child text block stream lowers rich nested content and assets" {
  let html =
    #|<!doctype html>
    #|<html><head><title>Ignored title</title><style>.x{color:red}</style></head>
    #|<body>
    #|<h2>Contract <em>heading</em></h2>
    #|<p>Alpha <a href="https://example.test/path">linked <strong>text</strong></a><br>next line.</p>
    #|<ol start="3"><li>First <code>item</code></li><li>Second<ul><li>Nested</li></ul></li></ol>
    #|<blockquote><p>Quoted paragraph</p></blockquote>
    #|<table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>alpha</td><td><a href="/local">one</a></td></tr><tr><td colspan="2"><img src="assets/cell.png" alt="cell"></td></tr></tbody></table>
    #|<p><img src="assets/local.png" alt="Local"> <img src="https://example.test/remote.png" alt="Remote"></p>
    #|<pre><code class="language-moonbit">fn main {}</code></pre>
    #|<hr><script>ignored()</script>
    #|</body></html>
  let source = @input.with_bytes_payload(
    @input.input_from_text_with_format(
      html,
      "complex.html",
      Some(@input.DetectedFormat::Html),
    ),
    @utf8.encode(html),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Html),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let result = html_parse_with_token_events(
    source,
    context,
    html,
    @dhtml.tokenize_html_events(html),
  )
  let blocks = result.block_stream.unwrap()
  assert_true(blocks.length() >= 7)
  assert_true(blocks.any(block => block.kind == @core.BlockKind::Heading))
  assert_true(blocks.any(block => block.kind == @core.BlockKind::List))
  assert_true(blocks.any(block => block.kind == @core.BlockKind::BlockQuote))
  assert_true(blocks.any(block => block.kind == @core.BlockKind::Table))
  assert_true(blocks.any(block => block.kind == @core.BlockKind::Code))
  assert_true(
    blocks.any(block => block.attrs.get("raw_kind") == Some("thematic_break")),
  )
  assert_true(result.assets.length() >= 2)
  assert_true(
    result.diagnostics.metrics.get("html_block_stream_token_path") ==
    Some("true"),
  )
  assert_true(
    result.diagnostics.metrics.get("scope_plan_labels") ==
    Some("child_text_fast"),
  )
}

///|
test "HTML stream switches semantic path for disclosure and figure markup" {
  let html =
    #|<main><figure><img src="figure.png" alt="plot"><figcaption>Figure one</figcaption></figure>
    #|<details open><summary>More</summary><p>Hidden body</p></details></main>
  let source = @input.input_from_text_with_format(
    html,
    "semantic.html",
    Some(@input.DetectedFormat::Html),
  )
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Html),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let result = (html_parser().parse)(source, context).unwrap()
  assert_true(result.block_stream.unwrap().length() >= 2)
  assert_true(
    result.diagnostics.metrics.get("scope_plan_labels") !=
    Some("child_text_fast"),
  )
}

///|
test "HTML huge byte sources reuse prepared token events" {
  let html = "<main>" +
    "<p>plain <a href=\"/x\">link</a></p>".repeat(140_000) +
    "</main>"
  let source = @input.input_from_bytes_with_format(
    @utf8.encode(html),
    "huge.html",
    Some(@input.DetectedFormat::Html),
  )
  let prepared = @dhtml.prepare_html_document_from_source(source).unwrap()
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Html),
    Some(@parser.ParserMode::BlockStreaming),
    None,
    None,
    None,
    None,
    false,
  )
  let result = html_parse_with_prepared_document(
    prepared.prepared_source,
    context,
    prepared,
  )
  assert_true(result.block_stream.unwrap().length() > 120_000)
  assert_true(
    result.diagnostics.metrics.get("scope_plan_labels") ==
    Some("child_text_fast"),
  )
}

///|
test "HTML DOM route lowers semantic notes tables figures noise and unsupported content" {
  let html = [
    "<!doctype html><html><head><title>Fixture</title><script>alert(1)</script><style>.x{}</style></head>",
    "<body><header>Repeated header</header><main><article><section>", "<h1 id='top'>Title <em>em</em> <strong>strong</strong> <code>code</code></h1>",
    "<p>Text <a href='#note-1'>internal</a> <a href='https://example.test'>external</a>",
    "<a href='mailto:a@example.test'>mail</a> <a href='javascript:alert(1)'>unsafe</a><br>",
    "<img src='local.png' srcset='a.png 1x, b.png 2x' alt='local'>", "<img src='https://example.test/remote.png'><img src='data:image/png;base64,AA=='></p>",
    "<ul><li>one<ol><li>nested</li></ol></li><li><blockquote><p>quote</p></blockquote></li></ul>",
    "<pre><code class='language-moonbit'>fn main() {}</code></pre>", "<figure><img src='figure.png'><figcaption>Figure caption</figcaption></figure>",
    "<details open><summary>More</summary><p>Disclosure body</p></details>", "<table><caption>Table caption</caption><thead><tr><th rowspan='2'>H</th><th>V</th></tr></thead>",
    "<tbody><tr><td colspan='2'><p>complex</p><table><tr><td>nested</td></tr></table></td></tr>",
    "<tr><td>ragged</td></tr></tbody></table>", "<p>Reference<a href='#fn1' role='doc-noteref'>1</a></p>",
    "<ol><li id='fn1' role='doc-endnote'>Note body <a href='#top' role='doc-backlink'>back</a></li></ol>",
    "<aside class='sidebar advertisement'>noise</aside><nav>navigation</nav>", "<iframe src='https://example.test'></iframe><form><input><button>go</button></form>",
    "<svg><path></path></svg><math><mi>x</mi></math><template>hidden</template>",
    "</section></article></main><footer>Repeated footer</footer></body></html>",
  ].join("")
  let source = @input.input_from_text_with_format(
    html,
    "semantic-dom.html",
    Some(@input.DetectedFormat::Html),
  )
  match html_document_to_ir(source, html) {
    Ok((document, diagnostics)) => {
      assert_true(document.blocks.length() > 0)
      assert_true(document.assets.length() > 0)
      assert_true(diagnostics.warnings.length() > 0)
      assert_true(diagnostics.metrics.get("block_count") is Some(_))
    }
    Err(error) => fail(error)
  }
  let result = (html_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Html),
  ).unwrap()
  assert_true(result.document is Some(_))
  assert_true(
    result.diagnostics.metrics.get("effective_mode") == Some("dom_ast_model"),
  )
  assert_true(result.diagnostics.pass_trace.contains("parse:html_parser"))
}

///|
test "HTML source helper paths trim inlines render lists and classify local images" {
  assert_true(
    html_split_once_double_space("left   right") == Some(("left", "right")),
  )
  assert_true(html_split_once_double_space("single") is None)
  assert_true(html_split_once_double_space("  right") is None)
  let source_ref = @core.empty_source_ref()
  let split = html_split_text_only_inline_segment([
    @core.make_inline_text("left  right", source_ref~),
  ]).unwrap()
  assert_eq(split.0[0].text, "left")
  assert_eq(split.1[0].text, "right")
  assert_true(
    html_split_text_only_inline_segment([
      @core.make_inline_link("link", "https://example.test", source_ref~),
    ])
    is None,
  )
  assert_true(html_split_text_only_inline_segment([]) is None)
  let trimmed = html_trim_core_inlines_edges([
    @core.make_inline_text(" \n ", source_ref~),
    @core.make_inline_text("  alpha ", source_ref~),
    @core.make_inline_text(" beta\t", source_ref~),
  ])
  assert_eq(trimmed.length(), 1)
  assert_eq(trimmed[0].text, "alpha  beta")
  assert_eq(html_trim_leading_spaces(" \n\talpha"), "alpha")
  assert_eq(html_trim_trailing_spaces("alpha \r\n"), "alpha")
  assert_true(html_ascii_space_like('\t'))
  assert_true(!html_ascii_space_like('x'))
  let list = @core.make_block(@core.BlockKind::List, "")
  list.attrs.set("ordered", "true")
  let first = @core.make_block(@core.BlockKind::ListItem, "First")
  first.children.push(@core.make_block(@core.BlockKind::Paragraph, "detail"))
  let nested = @core.make_block(@core.BlockKind::List, "")
  nested.children.push(@core.make_block(@core.BlockKind::ListItem, "Nested"))
  first.children.push(nested)
  list.children.push(first)
  list.children.push(@core.make_block(@core.BlockKind::ListItem, "Second"))
  let rendered = render_list_plain(list, 0)
  assert_true(rendered.contains("1. First"))
  assert_true(rendered.contains("detail"))
  assert_true(rendered.contains("- Nested"))
  assert_true(html_quote_lines_from_blocks([list]).length() > 0)
  assert_true(render_quote_lines_from_text("a\nb") == ["a", "b"])
  assert_true(html_safe_local_image_src("images/pic.png"))
  for
    unsafe_src in [
      "", "http://x/a.png", "https://x/a.png", "data:image/png,x", "//x/a.png", "/absolute.png",
      "../escape.png",
    ] {
    assert_true(!html_safe_local_image_src(unsafe_src))
  }
  assert_eq(html_strip_query_and_hash("image.png?x=1#y"), "image.png")
  assert_eq(html_strip_query_and_hash("image.png"), "image.png")
  let extensions = [
    ("a.png", "png"),
    ("a.JPG", "jpg"),
    ("a.jpeg", "jpeg"),
    ("a.gif", "gif"),
    ("a.bmp", "bmp"),
    ("a.webp", "webp"),
    ("a.tif", "tiff"),
    ("a.tiff", "tiff"),
    ("a.unknown", "img"),
  ]
  assert_true(extensions.all(item => html_image_ext_from_src(item.0) == item.1))
  assert_eq(html_two_digit(3), "03")
  assert_eq(html_two_digit(12), "12")
}
