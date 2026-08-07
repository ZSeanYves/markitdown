///|
fn rag_test_event(
  kind : @core.EventKind,
  text : String,
  source_ref? : @core.SourceRef? = None,
) -> @core.CoreEvent {
  { kind, text, source_ref }
}

///|
fn rag_test_line_ref(line : Int) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("fixture.txt"),
    Some("txt"),
    Some(line),
    Some(line),
  )
}

///|
test "RAG input chunking handles empty and paragraph event streams" {
  let options = @rag.default_rag_options()
  let metadata : @core.DocumentMetadata = Map([])
  let diagnostics = @core.empty_diagnostics()
  assert_eq(
    chunks_from_events([], metadata, diagnostics, [], None, None, options).length(),
    0,
  )
  let first_ref = rag_test_line_ref(1)
  let chunks = chunks_from_events(
    [
      rag_test_event(TextLine, " Alpha ", source_ref=Some(first_ref)),
      rag_test_event(TextLine, "Beta", source_ref=Some(first_ref)),
      rag_test_event(BlankLine, ""),
      rag_test_event(TextLine, "Gamma", source_ref=Some(rag_test_line_ref(3))),
    ],
    metadata,
    diagnostics,
    [],
    None,
    None,
    options,
  )
  assert_eq(chunks.length(), 1)
  assert_true(chunks[0].kind == Text)
  assert_eq(chunks[0].text, "Alpha Beta\n\nGamma")
  assert_eq(chunks[0].source_refs.length(), 2)
}

///|
test "RAG input chunking emits subtitle and generic code chunks" {
  let options = @rag.default_rag_options()
  let metadata : @core.DocumentMetadata = Map([])
  let subtitle_diagnostics = @core.empty_diagnostics()
  subtitle_diagnostics.metrics.set(
    "event_semantics", "subtitle_record_event_stream",
  )
  let subtitle = chunks_from_events(
    [
      rag_test_event(StartBlock(Heading), "00:00:01.000 --> 00:00:02.000"),
      rag_test_event(StartBlock(Paragraph), "Hello"),
    ],
    metadata,
    subtitle_diagnostics,
    [],
    None,
    None,
    options,
  )
  assert_eq(subtitle.length(), 1)
  assert_true(subtitle[0].kind == Text)
  assert_true(subtitle[0].text.contains("Hello"))

  let generic = rag_text_chunks_from_generic_events(
    [
      rag_test_event(StartBlock(Code), "let x = 1"),
      rag_test_event(Text, "println(x)"),
    ],
    metadata,
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(generic.length(), 1)
  assert_true(generic[0].kind == Code)
  assert_eq(generic[0].text, "let x = 1\nprintln(x)")
}

///|
test "RAG table chunking normalizes ragged rows and record batches" {
  let options = @rag.default_rag_options()
  let metadata : @core.DocumentMetadata = Map([])
  let events = [
    rag_test_event(Cell, "Name", source_ref=Some(rag_test_line_ref(1))),
    rag_test_event(Cell, "Role", source_ref=Some(rag_test_line_ref(1))),
    rag_test_event(RowBreak, ""),
    rag_test_event(Cell, "Alice", source_ref=Some(rag_test_line_ref(2))),
    rag_test_event(RowBreak, ""),
  ]
  let chunks = rag_table_chunks_from_events(
    events,
    metadata,
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(chunks.length(), 1)
  assert_true(chunks[0].kind == Table)
  assert_true(chunks[0].text.contains("| Name | Role |"))
  assert_true(chunks[0].text.contains("| Alice |  |"))

  let long = "x".repeat(610)
  let batched = batched_table_chunks_from_events(
    [
      rag_test_event(Cell, "Header"),
      rag_test_event(RowBreak, ""),
      rag_test_event(Cell, long),
      rag_test_event(RowBreak, ""),
      rag_test_event(Cell, "tail"),
      rag_test_event(RowBreak, ""),
    ],
    metadata,
    @core.empty_diagnostics(),
    options,
  )
  assert_true(batched.length() >= 2)
  assert_true(
    batched[0].metadata.get("record_batch_profile") == Some(Bool(true)),
  )
}

///|
test "RAG block batching preserves explicit render window boundaries" {
  let first = @core.block_with_attr(
    @core.make_block(Paragraph, "Alpha"),
    "render_window_group",
    "a",
  )
  let second = @core.block_with_attr(
    @core.make_block(Paragraph, "Beta"),
    "render_window_group",
    "b",
  )
  let batches = block_batches([first, second])
  assert_eq(batches.length(), 2)
  let chunks = chunks_from_blocks(
    [first, second],
    Map([]),
    @core.empty_diagnostics(),
    [],
    None,
    None,
    @rag.default_rag_options(),
    record_batching=true,
  )
  assert_true(chunks.length() >= 2)
  assert_true(chunks[0].id != chunks[1].id)
}

///|
test "RAG structural paths and source ref dedup remain deterministic" {
  assert_eq(
    preferred_structural_heading_path("/catalog/items/0/name", '/').join("/"),
    "catalog/items/0",
  )
  assert_eq(
    split_structural_path("/{root}/items/[0]/name", '/').join("/"),
    "root/items/name",
  )
  let refs : Array[@core.SourceRef] = []
  let source_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some("fixture.json"),
    Some("json"),
    Some("/catalog/items/0/name"),
  )
  append_unique_source_ref(refs, Some(source_ref), true)
  append_unique_source_ref(refs, Some(source_ref), true)
  append_unique_source_ref(refs, Some(rag_test_line_ref(2)), false)
  assert_eq(refs.length(), 1)
  let chunk = make_event_rag_chunk(
    Text,
    0,
    "Widget",
    refs,
    [],
    Map([("format", String("json"))]),
    @core.empty_diagnostics(),
  )
  assert_eq(chunk.heading_path.join("/"), "catalog/items/0")
  assert_true(chunk.id.has_prefix("text-0-"))
}

///|
test "RAG generic event batching emits independent code and raw records" {
  let chunks = chunks_from_events(
    [
      rag_test_event(StartBlock(Code), "first"),
      rag_test_event(EndBlock(Code), ""),
      rag_test_event(StartBlock(Raw), "second"),
      rag_test_event(EndBlock(Raw), ""),
    ],
    Map([]),
    @core.empty_diagnostics(),
    [],
    None,
    None,
    @rag.default_rag_options(),
    record_batching=true,
  )
  assert_eq(chunks.length(), 2)
  assert_true(chunks[0].kind == Code)
  assert_true(chunks[1].kind == Raw)
  assert_true(chunks[0].id.has_prefix("code-0-"))
  assert_true(chunks[1].id.has_prefix("raw-1-"))
}

///|
test "RAG subtitle chunking handles empty and raw records" {
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("event_semantics", "subtitle_record_event_stream")
  let empty = chunks_from_events(
    [rag_test_event(EndDocument, "")],
    Map([]),
    diagnostics,
    [],
    None,
    None,
    @rag.default_rag_options(),
  )
  assert_eq(empty.length(), 0)
  let raw = chunks_from_events(
    [rag_test_event(StartBlock(Raw), "malformed cue")],
    Map([]),
    diagnostics,
    [],
    None,
    None,
    @rag.default_rag_options(),
  )
  assert_eq(raw.length(), 1)
  assert_true(raw[0].kind == Raw)
}

///|
test "RAG event metadata and structural formats remain deterministic" {
  let diagnostics = @core.empty_diagnostics()
    |> @core.diagnostics_with_input(None, Some("json"))
  let source_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some("fixture.json"),
    Some("json"),
    Some("/items/0/name"),
  )
  let metadata = event_stream_metadata(
    Map([]),
    [rag_test_event(Text, "value", source_ref=Some(source_ref))],
    diagnostics,
  )
  assert_true(metadata.get("format") == Some(String("json")))
  assert_true(metadata.get("source_name") == Some(String("fixture.json")))
  assert_true(
    event_source_ref_heading_path(source_ref, "json") == Some(["items", "0"]),
  )
  let yaml_ref = {
    ..source_ref,
    json_pointer: None,
    yaml_path: Some("/root/list/0"),
  }
  assert_true(
    event_source_ref_heading_path(yaml_ref, "yaml") == Some(["root", "list"]),
  )
  let xml_ref = {
    ..source_ref,
    json_pointer: None,
    xpath: Some("/root/item/name"),
  }
  assert_true(
    event_source_ref_heading_path(xml_ref, "xml") == Some(["root", "item"]),
  )
  assert_true(event_source_ref_heading_path(source_ref, "txt") is None)
  assert_eq(rag_chunk_id_with_ordinal("text-7-abcdef", 2), "text-2-abcdef")
  assert_eq(rag_chunk_id_with_ordinal("invalid", 2), "invalid")
}

///|
test "RAG record batching splits large text at stable event boundaries" {
  let long = Array::make(610, "x").join("")
  let events = [
    rag_test_event(TextLine, long, source_ref=Some(rag_test_line_ref(1))),
    rag_test_event(BlankLine, ""),
    rag_test_event(TextLine, "tail", source_ref=Some(rag_test_line_ref(2))),
  ]
  let batches = text_event_batches(events)
  assert_eq(batches.length(), 2)
  let chunks = chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    [],
    None,
    None,
    @rag.default_rag_options(),
    record_batching=true,
  )
  assert_eq(chunks.length(), 2)
  assert_true(chunks[0].text.contains(long))
  assert_eq(chunks[1].text, "tail")
  assert_true(chunks[1].id.has_prefix("text-1-"))
  assert_eq(text_event_batches([]).length(), 1)
}

///|
test "RAG generic and table helpers cover empty and trailing records" {
  let options = @rag.default_rag_options()
  assert_eq(
    rag_text_chunks_from_generic_events(
      [rag_test_event(EndDocument, "")],
      Map([]),
      @core.empty_diagnostics(),
      options,
    ).length(),
    0,
  )
  let raw = rag_text_chunks_from_generic_events(
    [rag_test_event(StartBlock(Raw), "raw"), rag_test_event(EndDocument, "")],
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  assert_true(raw[0].kind == Raw)
  assert_eq(
    batched_chunks_from_blocks(
      [],
      Map([]),
      @core.empty_diagnostics(),
      [],
      None,
      None,
      options,
    ).length(),
    0,
  )
  assert_eq(
    batched_table_chunks_from_events(
      [],
      Map([]),
      @core.empty_diagnostics(),
      options,
    ).length(),
    0,
  )
  let single_table = batched_table_chunks_from_events(
    [rag_test_event(Cell, "A"), rag_test_event(Cell, "B")],
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(single_table.length(), 1)
  assert_true(
    single_table[0].metadata.get("record_batch_profile") == Some(Bool(true)),
  )
  assert_eq(generic_event_batches([rag_test_event(Text, "tail")]).length(), 1)
  assert_eq(generic_event_batches([]).length(), 1)
  assert_eq(row_batches([]).length(), 1)
  assert_eq(block_batches([]).length(), 1)
  assert_eq(rag_chunk_id_with_ordinal("text-tail", 2), "text-tail")
}

///|
test "RAG generic assembly derives nested structural heading paths" {
  let child_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some("fixture"),
    Some("json"),
    Some("/root/items/0/name"),
  )
  let child = @core.make_block(Paragraph, "child", source_ref=child_ref)
  let parent = @core.make_block(Section, "parent")
    |> @core.block_with_children([child])
  let assembly = generic_event_document_assembly(
    [parent],
    Map([("format", String("json"))]),
  )
  assert_true(
    assembly.heading_paths.get(child.block_id) == Some(["root", "items", "0"]),
  )
  assert_true(
    assembly.heading_paths.get(parent.block_id) == Some(["root", "items", "0"]),
  )
  let no_path = @core.make_block(Paragraph, "none")
  assert_true(
    generic_event_block_heading_paths(Map([]), no_path, "json") is None,
  )
  assert_true(
    event_source_ref_heading_path(@core.empty_source_ref(), "json") is None,
  )
  assert_true(
    event_source_ref_heading_path(@core.empty_source_ref(), "yaml") is None,
  )
  assert_true(
    event_source_ref_heading_path(@core.empty_source_ref(), "xml") is None,
  )
  assert_true(
    preferred_structural_heading_path("single", '/').join("/") == "single",
  )
}
