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
      StartBlock(Heading),
      "Compact title",
      source_ref=Some(compact_markup_ref(level="2")),
    ),
    rag_test_event(
      StartBlock(Paragraph),
      "[docs](https://example.test)",
      source_ref=Some(inline_ref),
    ),
    rag_test_event(
      StartBlock(Paragraph),
      "first\n# literal",
      source_ref=Some(compact_markup_ref()),
    ),
    rag_test_event(
      StartBlock(Code),
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
      StartBlock(Heading),
      "<root>",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      StartBlock(ListItem),
      "@page: 1",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      StartBlock(ListItem),
      "",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      StartBlock(ListItem),
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
    rag_test_event(TextLine, " first *value* "),
    rag_test_event(TextLine, "second"),
    rag_test_event(BlankLine, ""),
    rag_test_event(TextLine, "third"),
  ])
  assert_eq(lines, "first \\*value\\* second\n\nthird")

  let table = render_markdown_events([
    rag_test_event(Cell, "Name"),
    rag_test_event(Cell, "A | B"),
    rag_test_event(RowBreak, ""),
    rag_test_event(Cell, "alpha"),
    rag_test_event(RowBreak, ""),
    rag_test_event(Text, "tail *text*"),
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
    rag_test_event(StartBlock(Code), "fn main() {}", source_ref=Some(code_ref)),
    rag_test_event(StartBlock(Raw), "<aside>raw</aside>"),
    rag_test_event(Text, "plain _text_"),
    rag_test_event(EndDocument, "ignored"),
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
    rag_test_event(StartBlock(Paragraph), "", source_ref=Some(paragraph_ref)),
    rag_test_event(Text, "Read ", source_ref=Some(markdown_generic_ref())),
    rag_test_event(Text, "docs", source_ref=Some(link_ref)),
    rag_test_event(Text, "", source_ref=Some(break_ref)),
    rag_test_event(Text, "value", source_ref=Some(code_ref)),
    rag_test_event(EndBlock(Paragraph), ""),
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
    rag_test_event(StartBlock(Table), "", source_ref=Some(table_ref)),
    rag_test_event(Cell, "A", source_ref=Some(cell_ref)),
    rag_test_event(Cell, "B"),
    rag_test_event(RowBreak, ""),
    rag_test_event(StructureStart, "ignored"),
    rag_test_event(EndBlock(Table), ""),
    rag_test_event(
      StartBlock(Paragraph),
      "",
      source_ref=Some(markdown_generic_ref()),
    ),
    rag_test_event(Text, "plain", source_ref=Some(text_ref)),
    rag_test_event(Text, "diagram", source_ref=Some(image_ref)),
    rag_test_event(EndBlock(Paragraph), ""),
  ])
  assert_eq(blocks.length(), 2)
  assert_eq(blocks[0].children.length(), 1)
  assert_eq(blocks[0].children[0].children.length(), 2)
  assert_true(blocks[0].source_ref.unwrap().extra.get("keep") == Some("value"))
  assert_true(
    blocks[0].source_ref.unwrap().extra.get("ir_event_encoding") is None,
  )
  assert_true(blocks[1].rich_inlines.unwrap()[0].kind == Text)
  assert_true(blocks[1].rich_inlines.unwrap()[1].kind == Image)
  let rendered = render_markdown_events([
    rag_test_event(StartBlock(Code), "code without info"),
    rag_test_event(EndDocument, "ignored"),
  ])
  assert_true(rendered.contains("```\ncode without info\n```"))
  let out = StringBuilder::new()
  write_markdown_generic_event_to(out, rag_test_event(EndDocument, "ignored"))
  assert_eq(out.to_string(), "")
}

///|
fn render_events_through_sink(events : Array[@core.CoreEvent]) -> String {
  let chunks : Array[String] = []
  let result = render_markdown_input_to_sink(
    EventStream(events),
    make_render_context(false),
    fn(chunk) {
      chunks.push(chunk)
      Ok(())
    },
  ).unwrap()
  ignore(result)
  chunks.join("")
}

///|
test "incremental event renderer matches every event encoding" {
  let compact = [
    rag_test_event(
      StartBlock(Heading),
      "Compact title",
      source_ref=Some(compact_markup_ref(level="2")),
    ),
    rag_test_event(
      StartBlock(Paragraph),
      "first\n# literal",
      source_ref=Some(compact_markup_ref()),
    ),
    rag_test_event(
      StartBlock(Code),
      "literal code",
      source_ref=Some(compact_markup_ref()),
    ),
  ]
  assert_eq(
    render_events_through_sink(compact),
    render_markdown_events(compact),
  )

  let xml = [
    rag_test_event(
      StartBlock(Heading),
      "<root>",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      StartBlock(ListItem),
      "@page: 1",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 0)),
    ),
    rag_test_event(
      StartBlock(ListItem),
      "name: A",
      source_ref=Some(xml_outline_test_ref("xml_outline_v1", 1)),
    ),
  ]
  assert_eq(render_events_through_sink(xml), render_markdown_events(xml))

  let table = [
    rag_test_event(Cell, "Name"),
    rag_test_event(Cell, "A | B"),
    rag_test_event(RowBreak, ""),
    rag_test_event(Cell, "alpha"),
    rag_test_event(RowBreak, ""),
    rag_test_event(Text, "tail *text*"),
  ]
  assert_eq(render_events_through_sink(table), render_markdown_events(table))

  let generic = [
    rag_test_event(StartBlock(Code), "fn main() {}"),
    rag_test_event(StartBlock(Raw), "<aside>raw</aside>"),
    rag_test_event(Text, "plain _text_"),
  ]
  assert_eq(
    render_events_through_sink(generic),
    render_markdown_events(generic),
  )
}

///|
fn encoded_event_ref(
  encoding : String,
  format? : String = "",
) -> @core.SourceRef {
  let source_ref = {
    ..@core.empty_source_ref(),
    format: if format == "" {
      None
    } else {
      Some(format)
    },
  }
  source_ref.extra.set("ir_event_encoding", encoding)
  source_ref
}

///|
test "incremental renderer covers JSON XML subtitle line and generic routes" {
  let json_ref = encoded_event_ref("json_list_v1", format="json")
  let json = [
    rag_test_event(StartBlock(ListItem), "one", source_ref=Some(json_ref)),
    rag_test_event(StartBlock(ListItem), "two", source_ref=Some(json_ref)),
  ]
  assert_eq(render_events_through_sink(json), render_markdown_events(json))

  let xml_ref = encoded_event_ref("generic_block", format="xml")
  let xml = [
    rag_test_event(StartBlock(Heading), "root", source_ref=Some(xml_ref)),
    rag_test_event(StartBlock(List), "", source_ref=Some(xml_ref)),
    rag_test_event(StartBlock(ListItem), "first", source_ref=Some(xml_ref)),
    rag_test_event(StartBlock(List), "", source_ref=Some(xml_ref)),
    rag_test_event(StartBlock(ListItem), "nested", source_ref=Some(xml_ref)),
    rag_test_event(EndBlock(ListItem), "", source_ref=Some(xml_ref)),
    rag_test_event(EndBlock(List), "", source_ref=Some(xml_ref)),
    rag_test_event(EndBlock(ListItem), "", source_ref=Some(xml_ref)),
    rag_test_event(EndBlock(List), "", source_ref=Some(xml_ref)),
    rag_test_event(EndBlock(Heading), "", source_ref=Some(xml_ref)),
  ]
  assert_eq(render_events_through_sink(xml), render_markdown_events(xml))

  let subtitle_ref = { ..@core.empty_source_ref(), format: Some("srt") }
  let nested_subtitle_ref = { ..@core.empty_source_ref(), format: Some("srt") }
  nested_subtitle_ref.extra.set("ir_event_encoding", "generic_block")
  let subtitles = [
    rag_test_event(
      StartBlock(BlockQuote),
      "00:00:00,000 --> 00:00:01,000\nfirst",
      source_ref=Some(subtitle_ref),
    ),
    rag_test_event(
      StartBlock(BlockQuote),
      "",
      source_ref=Some(nested_subtitle_ref),
    ),
    rag_test_event(
      StartBlock(Heading),
      "second",
      source_ref=Some(nested_subtitle_ref),
    ),
    rag_test_event(
      StartBlock(Paragraph),
      "payload",
      source_ref=Some(nested_subtitle_ref),
    ),
    rag_test_event(
      EndBlock(BlockQuote),
      "",
      source_ref=Some(nested_subtitle_ref),
    ),
    rag_test_event(StartBlock(Raw), "broken", source_ref=Some(subtitle_ref)),
  ]
  assert_eq(
    render_events_through_sink(subtitles),
    render_markdown_events(subtitles),
  )

  let lines = [
    rag_test_event(TextLine, "alpha"),
    rag_test_event(BlankLine, ""),
    rag_test_event(StartBlock(Raw), "broken"),
    rag_test_event(EndDocument, "ignored"),
  ]
  assert_eq(render_events_through_sink(lines), "alpha\n\n```raw\nbroken\n```")

  let generic_ref = markdown_generic_ref()
  let generic_blocks = [
    rag_test_event(StartBlock(Paragraph), "", source_ref=Some(generic_ref)),
    rag_test_event(Text, "generic", source_ref=Some(generic_ref)),
    rag_test_event(EndBlock(Paragraph), "", source_ref=Some(generic_ref)),
  ]
  assert_eq(
    render_events_through_sink(generic_blocks),
    render_markdown_events(generic_blocks),
  )
}

///|
test "incremental renderer propagates block event and finish failures" {
  let document = @core.empty_document_ir()
  document.blocks.push(@core.make_block_without_source_ref(Paragraph, "body"))
  match
    render_markdown_input_to_sink(
      Document(document),
      make_render_context(false),
      fn(_chunk) { Err("document stopped") },
    ) {
    Err(message) => assert_eq(message, "document stopped")
    Ok(_) => fail("document sink failure should propagate")
  }
  match
    render_markdown_input_to_sink(
      BlockStream([@core.make_block_without_source_ref(Paragraph, "body")]),
      make_render_context(false),
      fn(_chunk) { Err("block stopped") },
    ) {
    Err(message) => assert_eq(message, "block stopped")
    Ok(_) => fail("block sink failure should propagate")
  }
  let line_sink = open_markdown_line_event_sink(fn(_chunk) {
    Err("line stopped")
  })
  assert_true(
    (line_sink.push)(rag_test_event(TextLine, "body")) == Err("line stopped"),
  )
  let subtitle_chunks : Array[String] = []
  let subtitle_sink = open_markdown_subtitle_event_sink(fn(chunk) {
    subtitle_chunks.push(chunk)
    Ok(())
  })
  (subtitle_sink.push)(rag_test_event(StartBlock(BlockQuote), "")).unwrap()
  (subtitle_sink.push)(rag_test_event(StartBlock(Heading), "heading")).unwrap()
  (subtitle_sink.push)(rag_test_event(StartBlock(Paragraph), "body")).unwrap()
  (subtitle_sink.finish)().unwrap()
  assert_true(subtitle_chunks.join("").contains("heading"))

  let json_ref = encoded_event_ref("json_list_v1", format="json")
  match
    render_markdown_input_to_sink(
      EventStream([
        rag_test_event(StartBlock(ListItem), "value", source_ref=Some(json_ref)),
      ]),
      make_render_context(false),
      fn(_chunk) { Err("json stopped") },
    ) {
    Err(message) => assert_eq(message, "json stopped")
    Ok(_) => fail("JSON sink failure should propagate")
  }

  let generic_ref = markdown_generic_ref()
  match
    render_markdown_input_to_sink(
      EventStream([
        rag_test_event(StartBlock(Paragraph), "", source_ref=Some(generic_ref)),
        rag_test_event(Text, "body", source_ref=Some(generic_ref)),
        rag_test_event(EndBlock(Paragraph), "", source_ref=Some(generic_ref)),
      ]),
      make_render_context(false),
      fn(_chunk) { Err("generic stopped") },
    ) {
    Err(message) => assert_eq(message, "generic stopped")
    Ok(_) => fail("generic block sink failure should propagate")
  }
}

///|
test "incremental XML outline handles repeated headings invalid depth and noise" {
  let root_ref = xml_outline_test_ref("xml_outline_v1", 0)
  let invalid_ref = xml_outline_test_ref("xml_outline_v1", 0)
  invalid_ref.extra.set("xml_outline_depth", "invalid")
  let events = [
    rag_test_event(StartBlock(Heading), "root", source_ref=Some(root_ref)),
    rag_test_event(StartBlock(Heading), "child", source_ref=Some(root_ref)),
    rag_test_event(Text, "ignored", source_ref=Some(root_ref)),
    rag_test_event(
      StartBlock(ListItem),
      "invalid depth",
      source_ref=Some(invalid_ref),
    ),
    rag_test_event(StartBlock(ListItem), "no ref"),
  ]
  assert_eq(render_events_through_sink(events), render_markdown_events(events))
}
