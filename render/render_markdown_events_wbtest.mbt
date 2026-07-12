///|
fn markdown_generic_ref() -> @core.SourceRef {
  let source_ref = @core.empty_source_ref()
  source_ref.extra.set("ir_event_encoding", "generic_block")
  source_ref
}

///|
fn xml_outline_test_ref(encoding : String, depth : Int) -> @core.SourceRef {
  let source_ref = { ..@core.empty_source_ref(), format: Some("xml") }
  source_ref.extra.set("ir_event_encoding", encoding)
  source_ref.extra.set("xml_outline_depth", depth.to_string())
  source_ref
}

///|
fn compact_markup_ref(
  kind? : String = "leaf",
  level? : String = "1",
) -> @core.SourceRef {
  let source_ref = @core.empty_source_ref()
  source_ref.extra.set("ir_event_encoding", "text_markup_compact_v1")
  if kind == "leaf" {
    source_ref.extra.set("ir_text_markup_compact_leaf", "true")
  }
  source_ref.extra.set("ir_block_attr_level", level)
  source_ref.extra.set("ir_block_attr_info", "text")
  source_ref
}

///|
test "markdown event renderer covers compact text-markup leaf protocol" {
  let inline_ref = compact_markup_ref()
  inline_ref.extra.set("ir_text_markup_rendered_inline", "true")
  let events = [
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Heading),
      "Compact title",
      source_ref=Some(compact_markup_ref(level="2")),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      "[docs](https://example.test)",
      source_ref=Some(inline_ref),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      "first\n# literal",
      source_ref=Some(compact_markup_ref()),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Code),
      "literal code",
      source_ref=Some(compact_markup_ref()),
    ),
  ]
  let rendered = render_markdown_events(events)
  assert_true(rendered.has_prefix("## Compact title"))
  assert_true(rendered.contains("[docs](https://example.test)"))
  assert_true(rendered.contains("first\n\\# literal"))
  assert_true(rendered.contains("```text\nliteral code\n```"))
}

///|
test "markdown event renderer preserves XML generic and compact outlines" {
  let compact = render_markdown_events([
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Heading),
      "<root>",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      "@page: 1",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      "",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      "name: A",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 1)),
    ),
  ])
  assert_eq(compact, "# <root>\n\n- @page: 1\n- \n  - name: A")
}

///|
test "markdown event renderer handles empty line and mixed table streams" {
  assert_eq(render_markdown_events([]), "")
  let lines = render_markdown_events([
    rag_test_event(@core.EventKind::TextLine, " first *value* "),
    rag_test_event(@core.EventKind::TextLine, "second"),
    rag_test_event(@core.EventKind::BlankLine, ""),
    rag_test_event(@core.EventKind::TextLine, "third"),
  ])
  assert_eq(lines, "first \\*value\\* second\n\nthird")

  let table = render_markdown_events([
    rag_test_event(@core.EventKind::Cell, "Name"),
    rag_test_event(@core.EventKind::Cell, "A | B"),
    rag_test_event(@core.EventKind::RowBreak, ""),
    rag_test_event(@core.EventKind::Cell, "alpha"),
    rag_test_event(@core.EventKind::RowBreak, ""),
    rag_test_event(@core.EventKind::Text, "tail *text*"),
  ])
  assert_true(table.contains("| Name | A \\| B |"))
  assert_true(table.contains("| --- | --- |"))
  assert_true(table.contains("| alpha |  |"))
  assert_true(table.has_suffix("tail \\*text\\*"))
}

///|
test "markdown event renderer handles visible generic code and raw events" {
  let code_ref = @core.empty_source_ref()
  code_ref.extra.set("ir_block_attr_info", "moonbit")
  let output = render_markdown_events([
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Code),
      "fn main() {}",
      source_ref=Some(code_ref),
    ),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Raw),
      "<aside>raw</aside>",
    ),
    rag_test_event(@core.EventKind::Text, "plain _text_"),
    rag_test_event(@core.EventKind::EndDocument, "ignored"),
  ])
  assert_true(output.contains("```moonbit\nfn main() {}\n```"))
  assert_true(output.contains("<aside>raw</aside>"))
  assert_true(output.contains("plain \\_text\\_"))
  assert_true(!output.contains("ignored"))
}

///|
test "markdown event renderer reconstructs generic rich blocks" {
  let paragraph_ref = markdown_generic_ref()
  paragraph_ref.extra.set("ir_block_attr_role", "lead")
  let link_ref = markdown_generic_ref()
  link_ref.extra.set("ir_inline_kind", "link")
  link_ref.extra.set("ir_inline_href", "https://example.test")
  let break_ref = markdown_generic_ref()
  break_ref.extra.set("ir_inline_kind", "line_break")
  let code_ref = markdown_generic_ref()
  code_ref.extra.set("ir_inline_kind", "code")
  let output = render_markdown_events([
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      "",
      source_ref=Some(paragraph_ref),
    ),
    rag_test_event(
      @core.EventKind::Text,
      "Read ",
      source_ref=Some(markdown_generic_ref()),
    ),
    rag_test_event(@core.EventKind::Text, "docs", source_ref=Some(link_ref)),
    rag_test_event(@core.EventKind::Text, "", source_ref=Some(break_ref)),
    rag_test_event(@core.EventKind::Text, "value", source_ref=Some(code_ref)),
    rag_test_event(@core.EventKind::EndBlock(@core.BlockKind::Paragraph), ""),
  ])
  assert_true(output.contains("[docs](https://example.test)"))
  assert_true(output.contains("`value`"))
}

///|
test "markdown event renderer reconstructs generic tables and image inlines" {
  let table_ref = markdown_generic_ref()
  table_ref.extra.set("keep", "value")
  let cell_ref = markdown_generic_ref()
  cell_ref.extra.set("cell", "one")
  let image_ref = markdown_generic_ref()
  image_ref.extra.set("ir_inline_kind", "image")
  image_ref.extra.set("ir_inline_href", "image.png")
  let text_ref = markdown_generic_ref()
  text_ref.extra.set("ir_inline_kind", "text")
  let blocks = generic_blocks_from_events([
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Table),
      "",
      source_ref=Some(table_ref),
    ),
    rag_test_event(@core.EventKind::Cell, "A", source_ref=Some(cell_ref)),
    rag_test_event(@core.EventKind::Cell, "B"),
    rag_test_event(@core.EventKind::RowBreak, ""),
    rag_test_event(@core.EventKind::StructureStart, "ignored"),
    rag_test_event(@core.EventKind::EndBlock(@core.BlockKind::Table), ""),
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      "",
      source_ref=Some(markdown_generic_ref()),
    ),
    rag_test_event(@core.EventKind::Text, "plain", source_ref=Some(text_ref)),
    rag_test_event(@core.EventKind::Text, "diagram", source_ref=Some(image_ref)),
    rag_test_event(@core.EventKind::EndBlock(@core.BlockKind::Paragraph), ""),
  ])
  assert_eq(blocks.length(), 2)
  assert_eq(blocks[0].children.length(), 1)
  assert_eq(blocks[0].children[0].children.length(), 2)
  assert_true(blocks[0].source_ref.unwrap().extra.get("keep") == Some("value"))
  assert_true(
    blocks[0].source_ref.unwrap().extra.get("ir_event_encoding") is None,
  )
  assert_true(blocks[1].rich_inlines.unwrap()[0].kind == @core.InlineKind::Text)
  assert_true(
    blocks[1].rich_inlines.unwrap()[1].kind == @core.InlineKind::Image,
  )
  let rendered = render_markdown_events([
    rag_test_event(
      @core.EventKind::StartBlock(@core.BlockKind::Code),
      "code without info",
    ),
    rag_test_event(@core.EventKind::EndDocument, "ignored"),
  ])
  assert_true(rendered.contains("```\ncode without info\n```"))
  let out = StringBuilder::new()
  write_markdown_generic_event_to(
    out,
    rag_test_event(@core.EventKind::EndDocument, "ignored"),
  )
  assert_eq(out.to_string(), "")
}
