///|
fn event_builder_event(
  kind : EventKind,
  text : String,
  source_ref? : SourceRef? = None,
) -> CoreEvent {
  { kind, text, source_ref }
}

///|
fn event_builder_ref(line : Int, cell_range? : String? = None) -> SourceRef {
  {
    ..empty_source_ref(),
    file_id: Some("fixture"),
    format: Some("csv"),
    line_start: Some(line),
    line_end: Some(line),
    byte_start: Some(line * 10),
    byte_end: Some(line * 10 + 5),
    cell_range,
  }
}

///|
test "event document builder materializes code paragraphs and tables" {
  let code_ref = event_builder_ref(1)
  code_ref.extra.set("ir_block_attr_info", "moonbit")
  let document = build_document_from_events([
    event_builder_event(
      StartBlock(Code),
      "fn main {}",
      source_ref=Some(code_ref),
    ),
    event_builder_event(
      TextLine,
      " first ",
      source_ref=Some(event_builder_ref(2)),
    ),
    event_builder_event(
      TextLine,
      "second",
      source_ref=Some(event_builder_ref(3)),
    ),
    event_builder_event(BlankLine, ""),
    event_builder_event(
      Cell,
      "Name",
      source_ref=Some(event_builder_ref(4, cell_range=Some("A1"))),
    ),
    event_builder_event(
      Cell,
      "Value",
      source_ref=Some(event_builder_ref(4, cell_range=Some("B1"))),
    ),
    event_builder_event(
      RowBreak,
      "",
      source_ref=Some(event_builder_ref(4, cell_range=Some("A1:B1"))),
    ),
    event_builder_event(
      Cell,
      "alpha",
      source_ref=Some(event_builder_ref(5, cell_range=Some("A2"))),
    ),
    event_builder_event(
      RowBreak,
      "",
      source_ref=Some(event_builder_ref(5, cell_range=Some("A2:B2"))),
    ),
  ])
  assert_eq(document.blocks.length(), 3)
  assert_true(document.blocks[0].kind == Code)
  assert_true(document.blocks[0].attrs.get("info") == Some("moonbit"))
  assert_eq(document.blocks[1].text, "first second")
  assert_true(document.blocks[2].kind == Table)
  assert_eq(document.blocks[2].children.length(), 2)
  assert_true(document.blocks[2].attrs.get("table_column_count") == Some("2"))
  assert_true(
    document.blocks[2].source_ref.unwrap().cell_range == Some("A1:B2"),
  )
  assert_true(document.diagnostics.metrics.get("table_count") == Some("1"))
}

///|
fn generic_builder_ref(inline_kind? : String? = None) -> SourceRef {
  let source_ref = { ..empty_source_ref(), page: Some(2) }
  source_ref.extra.set("ir_event_encoding", "generic_block")
  source_ref.extra.set("keep", "yes")
  match inline_kind {
    Some(kind) => source_ref.extra.set("ir_inline_kind", kind)
    None => ()
  }
  source_ref
}

///|
test "event document builder reconstructs generic blocks and rich inlines" {
  let paragraph_ref = generic_builder_ref()
  paragraph_ref.extra.set("ir_block_attr_role", "lead")
  let link_ref = generic_builder_ref(inline_kind=Some("link"))
  link_ref.extra.set("ir_inline_href", "https://example.test")
  link_ref.extra.set("ir_inline_title", "Example")
  link_ref.extra.set("ir_inline_attr_rel", "external")
  let image_ref = generic_builder_ref(inline_kind=Some("image"))
  image_ref.extra.set("ir_inline_href", "image.png")
  let table_ref = generic_builder_ref()
  let document = build_document_from_events([
    event_builder_event(
      StartBlock(Paragraph),
      "",
      source_ref=Some(paragraph_ref),
    ),
    event_builder_event(
      Text,
      "Read ",
      source_ref=Some(generic_builder_ref(inline_kind=Some("text"))),
    ),
    event_builder_event(Text, "docs", source_ref=Some(link_ref)),
    event_builder_event(
      Text,
      "",
      source_ref=Some(generic_builder_ref(inline_kind=Some("line_break"))),
    ),
    event_builder_event(
      Text,
      "code",
      source_ref=Some(generic_builder_ref(inline_kind=Some("code"))),
    ),
    event_builder_event(Text, "diagram", source_ref=Some(image_ref)),
    event_builder_event(EndBlock(Paragraph), ""),
    event_builder_event(StartBlock(Table), "", source_ref=Some(table_ref)),
    event_builder_event(Cell, "A"),
    event_builder_event(Cell, "B"),
    event_builder_event(RowBreak, ""),
    event_builder_event(EndBlock(Table), ""),
  ])
  assert_eq(document.blocks.length(), 2)
  let paragraph = document.blocks[0]
  assert_true(paragraph.attrs.get("role") == Some("lead"))
  assert_true(paragraph.source_ref.unwrap().extra.get("keep") == Some("yes"))
  assert_true(
    paragraph.source_ref.unwrap().extra.get("ir_event_encoding") is None,
  )
  assert_eq(paragraph.rich_inlines.unwrap().length(), 5)
  assert_true(paragraph.rich_inlines.unwrap()[1].kind == Link)
  assert_true(
    paragraph.rich_inlines.unwrap()[1].attrs.get("rel") == Some("external"),
  )
  let table = document.blocks[1]
  assert_eq(table.children.length(), 1)
  assert_eq(table.children[0].children.length(), 2)
  assert_eq(table.children[0].children[1].text, "B")
}

///|
test "event document builder covers missing refs info and ignored events" {
  let document = build_document_from_events([
    event_builder_event(StartBlock(Code), "no info"),
    event_builder_event(
      StartBlock(Code),
      "ref no info",
      source_ref=Some(empty_source_ref()),
    ),
    event_builder_event(EndDocument, "ignored"),
    event_builder_event(RowBreak, ""),
  ])
  assert_eq(document.blocks.length(), 2)
  assert_true(document.blocks[0].attrs.get("info") is None)
  assert_true(document.blocks[1].attrs.get("info") is None)
  let row = simple_event_table_row(
    ["A", "B"],
    [event_builder_ref(1)],
    event_builder_ref(2),
  )
  assert_eq(row.children.length(), 2)
  assert_true(row.children[1].source_ref.unwrap().line_start == Some(2))
  assert_eq(
    paragraph_blocks_from_line_events([event_builder_event(BlankLine, "")]).length(),
    0,
  )
  let with_signals = document_with_signals(empty_document_ir(), [
    make_signal(RenderHint, 50),
  ])
  assert_eq(with_signals.signals.length(), 1)
}
