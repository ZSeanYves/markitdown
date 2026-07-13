///|
fn markdown_test_cell(text : String) -> @core.CoreBlock {
  @core.make_block(@core.BlockKind::TableCell, text)
}

///|
test "markdown large repeated leaves reuse exact rendered templates" {
  assert_true(
    !markdown_needs_blank_line_between(None, @core.BlockKind::Paragraph),
  )
  let blocks : Array[@core.CoreBlock] = Array::new(capacity=1025)
  for i in 0..<1025 {
    let text = if i % 2 == 0 {
      "Repeated paragraph with *literal* punctuation."
    } else {
      "Second repeated paragraph with # literal prefix."
    }
    blocks.push(
      @core.make_block(@core.BlockKind::Paragraph, text)
      |> @core.block_with_attr("literal", "true"),
    )
  }
  let rendered = render_markdown_blocks(blocks)
  assert_true(
    rendered.has_prefix("Repeated paragraph with \\*literal\\* punctuation."),
  )
  assert_true(
    rendered.contains("\n\nSecond repeated paragraph with \\# literal prefix."),
  )
  assert_eq(rendered.split("\n\n").count(), 1025)
}

///|
test "markdown event renderer writes subtitle records without rebuilding blocks" {
  let source_ref = @core.empty_source_ref()
  source_ref.extra.set("ir_event_encoding", "generic_block")
  source_ref.extra.set("ir_event_family", "subtitle")
  source_ref.extra.set("ir_block_attr_literal", "true")
  let events : Array[@core.CoreEvent] = [
    {
      kind: @core.EventKind::StartBlock(@core.BlockKind::BlockQuote),
      text: "",
      source_ref: Some(source_ref),
    },
    {
      kind: @core.EventKind::StartBlock(@core.BlockKind::Heading),
      text: "00:00:00,000 --> 00:00:02,000",
      source_ref: Some(source_ref),
    },
    {
      kind: @core.EventKind::EndBlock(@core.BlockKind::Heading),
      text: "",
      source_ref: Some(source_ref),
    },
    {
      kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      text: "Hello world.\n# literal",
      source_ref: Some(source_ref),
    },
    {
      kind: @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
      text: "",
      source_ref: Some(source_ref),
    },
    {
      kind: @core.EventKind::EndBlock(@core.BlockKind::BlockQuote),
      text: "",
      source_ref: Some(source_ref),
    },
  ]
  inspect(
    render_markdown_events(events),
    content="> ###### 00:00:00,000 --> 00:00:02,000\n> \n> Hello world.\n> \\# literal",
  )
}

///|
test "markdown block renderer formats nested ordered lists" {
  let nested = @core.make_block(@core.BlockKind::ListItem, "nested *item*")
  let child_list = @core.make_block(@core.BlockKind::List, "")
    |> @core.block_with_children([nested])
  let first = @core.make_block(@core.BlockKind::ListItem, "first")
    |> @core.block_with_attr("stable_ordered_marker", "true")
    |> @core.block_with_attr("ordered_indent_step", "4")
    |> @core.block_with_children([child_list])
  let second = @core.make_block(@core.BlockKind::ListItem, "second")
  let list = @core.make_block(@core.BlockKind::List, "")
    |> @core.block_with_attr("ordered", "true")
    |> @core.block_with_children([first, second])
  let rendered = render_markdown_blocks([list])
  assert_true(rendered.has_prefix("1. first"))
  assert_true(rendered.contains("  - nested \\*item\\*"))
  assert_true(rendered.has_suffix("2. second"))
}

///|
test "markdown block renderer emits HTML tables for spans" {
  let spanning = markdown_test_cell("A < B & C")
    |> @core.block_with_attr("rowspan", "2")
    |> @core.block_with_attr("colspan", "\"2\"")
  let header = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_children([spanning, markdown_test_cell("Header")])
  let body = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_children([
      markdown_test_cell("Body"),
      markdown_test_cell("Value"),
    ])
  let table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_attr("render_html_table", "true")
    |> @core.block_with_attr("header_rows", "1")
    |> @core.block_with_children([header, body])
  let rendered = render_markdown_block(table)
  assert_true(rendered.contains("<table>"))
  assert_true(rendered.contains("rowspan=\"2\""))
  assert_true(rendered.contains("colspan=\"&quot;2&quot;\""))
  assert_true(rendered.contains("A &lt; B &amp; C"))
  assert_true(rendered.contains("<td>Body</td>"))
}

///|
test "markdown block renderer expands sparse rows and synthetic headers" {
  let left = markdown_test_cell("left\nline")
    |> @core.block_with_attr("column_index", "1")
  let right = markdown_test_cell("right\tvalue")
    |> @core.block_with_attr("column_index", "3")
  let row = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_attr("sparse_cell_columns", "true")
    |> @core.block_with_attr("declared_column_count", "3")
    |> @core.block_with_children([left, right])
  let table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_attr("header_rows", "0")
    |> @core.block_with_children([row])
  let rendered = render_markdown_block(table)
  assert_true(rendered.contains("| Column 1 | Column 2 | Column 3 |"))
  assert_true(rendered.contains("left<br>line"))
  assert_true(rendered.contains("right"))
}

///|
test "markdown block renderer handles rich inline annotations and footnotes" {
  let note = @core.make_inline_text("[^n]")
    |> @core.inline_with_attr("annotation_role", "note_ref")
    |> @core.inline_with_attr("annotation_marker", "[^note]")
  let comment = @core.make_inline_text("[^c]")
    |> @core.inline_with_attr("annotation_role", "note_ref")
    |> @core.inline_with_attr("annotation_kind", "comment")
    |> @core.inline_with_attr("annotation_marker", "[^comment]")
  let literal = @core.make_inline_text("*literal*")
    |> @core.inline_with_attr("render_literal", "true")
  let paragraph = @core.make_block(@core.BlockKind::Paragraph, "")
    |> @core.block_with_attr("note_definition_id", "note")
    |> @core.block_with_rich_inlines(
      Some([
        @core.make_inline_link("Docs", "https://example.test"),
        note,
        @core.make_inline_text(" "),
        comment,
        @core.make_inline_line_break(),
        @core.make_inline_code("a`b"),
        literal,
      ]),
    )
  let rendered = render_markdown_block(paragraph)
  assert_true(rendered.has_prefix("[^note]: [Docs](https://example.test)"))
  assert_true(rendered.contains("[^note]  [^comment]"))
  assert_true(rendered.contains("<br>`` a`b ``*literal*"))
}

///|
test "markdown block renderer handles quotes frontmatter and images" {
  let quote = @core.make_block(
      @core.BlockKind::BlockQuote,
      "quoted\ncontinuation",
    )
    |> @core.block_with_attr("literal", "true")
    |> @core.block_with_attr("semantic_family", "rst")
  let frontmatter = @core.make_block(@core.BlockKind::Raw, "title: Fixture")
    |> @core.block_with_attr("raw_kind", "markdown_frontmatter")
    |> @core.block_with_attr("frontmatter_marker", "+++")
  let image = @core.make_block(@core.BlockKind::Image, "")
    |> @core.block_with_attr("path", "asset.png")
    |> @core.block_with_attr("alt", "A *diagram*")
    |> @core.block_with_attr("title", "Title")
    |> @core.block_with_attr("caption", "Caption")
  let rendered = render_markdown_blocks([quote, frontmatter, image])
  assert_true(rendered.contains("> quoted\ncontinuation"))
  assert_true(rendered.contains("+++\ntitle: Fixture\n+++"))
  assert_true(rendered.contains("![A \\*diagram\\*](asset.png)"))
  assert_true(rendered.contains("*Title*\nCaption"))
}

///|
test "markdown block renderer covers empty and text-row table fallbacks" {
  let empty = @core.make_block(@core.BlockKind::Table, "fallback")
  assert_true(render_markdown_block(empty).contains("```text"))
  let zero_row = @core.make_block(@core.BlockKind::TableRow, "")
  let zero_table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_children([zero_row])
  assert_true(render_markdown_block(zero_table).contains("```text"))
  let header = @core.make_block(@core.BlockKind::TableRow, "A|B")
  let wide = @core.make_block(@core.BlockKind::TableRow, "1|2|3")
  let table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_attr("header_rows", "invalid")
    |> @core.block_with_attr("table_column_count", "invalid")
    |> @core.block_with_children([header, wide])
  let rendered = render_markdown_block(table)
  assert_true(rendered.contains("| A | B |"))
  assert_true(rendered.contains("| 1 | 2 | 3 |"))
  assert_eq(
    table_render_width_from_children(
      @core.block_with_attr(empty, "table_column_count", "3"),
      [],
    ),
    3,
  )
}

///|
test "markdown block renderer covers sparse child cells and safe whitespace" {
  let first = markdown_test_cell("left")
    |> @core.block_with_attr("column_index", "1")
  let rich = markdown_test_cell("")
    |> @core.block_with_attr("column_index", "3")
    |> @core.block_with_rich_inlines(Some([@core.make_inline_text("right")]))
  let invalid = markdown_test_cell("ignored")
    |> @core.block_with_attr("column_index", "0")
  let row = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_attr("sparse_cell_columns", "true")
    |> @core.block_with_children([first, rich, invalid])
  assert_eq(sparse_table_row_width(row), 3)
  assert_true(sparse_table_row_cells(row) == ["left", "", "right"])
  let empty_sparse = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_attr("sparse_cell_columns", "true")
  assert_eq(sparse_table_row_cells(empty_sparse).length(), 0)
  assert_eq(safe_markdown_table_cell("a\n   b  "), "a<br>b")
  assert_eq(safe_markdown_table_cell("a  "), "a")
}

///|
test "markdown block renderer covers quote children and rich quote" {
  let list = @core.make_block(@core.BlockKind::List, "")
    |> @core.block_with_children([
      @core.make_block(@core.BlockKind::ListItem, "one"),
      @core.make_block(@core.BlockKind::ListItem, "two"),
    ])
  let paragraph = @core.make_block(@core.BlockKind::Paragraph, "body")
  let quote = @core.make_block(@core.BlockKind::BlockQuote, "")
    |> @core.block_with_children([list, paragraph])
  let rendered = render_markdown_block(quote)
  assert_true(rendered.contains("> - one"))
  assert_true(rendered.contains("> body"))
  let rich_quote = @core.make_block(@core.BlockKind::BlockQuote, "")
    |> @core.block_with_rich_inlines(
      Some([@core.make_inline_text("rich *quote*")]),
    )
  assert_eq(render_markdown_block(rich_quote), "> rich \\*quote\\*")
  assert_eq(render_markdown_blockquote_children([]), "")
  assert_true(
    text_markup_semantic_blockquote_markdown(paragraph, ["body"]) is None,
  )
}

///|
test "markdown block renderer covers literal direct and generic variants" {
  let empty_paragraph = @core.make_block(@core.BlockKind::Paragraph, "")
  assert_true(!write_markdown_block_to(StringBuilder::new(), empty_paragraph))
  let literal = @core.make_block(@core.BlockKind::Paragraph, "# one\n> two")
    |> @core.block_with_attr("literal", "true")
  assert_eq(render_markdown_block(literal), "\\# one\n\\> two")
  let raw_literal = @core.block_with_attr(
    literal, "markdown_literal_raw", "true",
  )
  assert_eq(render_markdown_block(raw_literal), "# one\n> two")
  let note = @core.make_block(@core.BlockKind::Paragraph, "note body")
    |> @core.block_with_attr("note_definition_id", "n")
  assert_eq(render_markdown_block(note), "[^n]: note body")
  let heading = @core.make_block(@core.BlockKind::Heading, "*heading*")
  assert_eq(render_markdown_block(heading), "# \\*heading\\*")
  let empty_frontmatter = @core.make_block(@core.BlockKind::Raw, "")
    |> @core.block_with_attr("raw_kind", "markdown_frontmatter")
  assert_eq(render_markdown_block(empty_frontmatter), "---\n---")
  let generic = @core.make_block(@core.BlockKind::Section, "section")
  assert_eq(render_markdown_block(generic), "section")
  let generic_children = @core.block_with_children(generic, [note])
  assert_eq(render_markdown_block(generic_children), "[^n]: note body")
}

///|
test "markdown block renderer covers list child blocks and inline fallbacks" {
  let item = @core.make_block(@core.BlockKind::ListItem, "item")
    |> @core.block_with_attr("ordered", "true")
    |> @core.block_with_attr("ordered_indent_step", "0")
    |> @core.block_with_children([
      @core.make_block(@core.BlockKind::ListItem, "child"),
      @core.make_block(@core.BlockKind::Paragraph, "detail\nnext"),
    ])
  let rendered = render_markdown_block(item)
  assert_true(rendered.contains("1. item"))
  assert_true(rendered.contains("  - child"))
  assert_true(rendered.contains("  detail next"))
  let empty_list = @core.make_block(@core.BlockKind::List, "single")
  assert_eq(render_markdown_block(empty_list), "- single")
  let empty_link = @core.make_inline_link("label", "")
  assert_eq(render_markdown_inline_with_format(empty_link, None), "label")
  assert_true(
    annotation_note_marker_inline(@core.make_inline_code("x")) == false,
  )
  assert_true(
    annotation_comment_marker_inline(@core.make_inline_code("x")) == false,
  )
  assert_eq(
    render_markdown_inline_with_format(
      @core.make_inline_image("alt", "path"),
      None,
    ),
    "![alt](path)",
  )
}

///|
test "markdown block renderer covers direct code image and HTML escaping" {
  let code = @core.make_block(@core.BlockKind::Code, "a```b")
    |> @core.block_with_attr("info", "txt")
  assert_true(render_markdown_block(code).has_prefix("````txt"))
  let image = @core.make_block(@core.BlockKind::Image, "")
    |> @core.block_with_attr("literal", "true")
    |> @core.block_with_attr("caption", "literal *caption*")
  assert_true(render_markdown_block(image).contains("literal *caption*"))
  assert_eq(markdown_escape_html_text("a > b"), "a &gt; b")
  assert_eq(markdown_escape_html_attr("&<>\""), "&amp;&lt;&gt;&quot;")
  let cell = markdown_test_cell("")
    |> @core.block_with_rich_inlines(Some([@core.make_inline_text("rich")]))
  assert_eq(markdown_table_cell_text(cell), "rich")
}
