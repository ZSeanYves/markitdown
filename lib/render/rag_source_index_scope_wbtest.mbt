///|
fn rag_index_without_sources() -> @rag.RagOptions {
  let options = @rag.default_rag_options()
  @rag.make_rag_options(
    options.chunk_size,
    options.chunk_overlap,
    options.preserve_heading_path,
    false,
    options.split_tables,
    options.split_code_blocks,
  )
}

///|
test "subtitle source index preserves first occurrence order and source option" {
  let first = rag_test_line_ref(2)
  let second = rag_test_line_ref(1)
  let events = [
    rag_test_event(StartBlock(Paragraph), "two", source_ref=Some(first)),
    rag_test_event(StartBlock(Paragraph), "one", source_ref=Some(second)),
    rag_test_event(StartBlock(Paragraph), "again", source_ref=Some(first)),
  ]
  let metadata : @core.DocumentMetadata = Map([])
  let diagnostics = @core.empty_diagnostics()
  let options = @rag.default_rag_options()
  let chunks = rag_subtitle_chunks_from_events(
    events, metadata, diagnostics, options,
  )
  assert_eq(chunks.length(), 1)
  assert_eq(chunks[0].text, "two\none\nagain")
  assert_eq(chunks[0].source_refs.map(source => source.line_start), [
    Some(2),
    Some(1),
  ])
  let expected = make_event_rag_chunk(
    Text,
    0,
    "two\none\nagain",
    [first, second],
    [],
    metadata,
    diagnostics,
  )
  assert_eq(chunks[0].id, expected.id)
  let hidden = rag_subtitle_chunks_from_events(
    events,
    metadata,
    diagnostics,
    rag_index_without_sources(),
  )
  assert_eq(hidden[0].text, chunks[0].text)
  assert_eq(hidden[0].source_refs.length(), 0)
}

///|
test "table source index retains rowbreak order and deduplicates cell sources" {
  let events = [
    rag_test_event(Cell, "Header", source_ref=Some(rag_test_line_ref(2))),
    rag_test_event(RowBreak, "", source_ref=Some(rag_test_line_ref(1))),
    rag_test_event(Cell, "Value", source_ref=Some(rag_test_line_ref(2))),
    rag_test_event(RowBreak, "", source_ref=Some(rag_test_line_ref(3))),
  ]
  let options = @rag.default_rag_options()
  let chunks = rag_table_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(chunks[0].source_refs.map(source => source.line_start), [
    Some(2),
    Some(1),
    Some(3),
  ])
  let hidden = rag_table_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    rag_index_without_sources(),
  )
  assert_eq(hidden[0].text, chunks[0].text)
  assert_eq(hidden[0].source_refs.length(), 0)
}

///|
test "batched table indexes belong to each row and batch" {
  let first = rag_test_line_ref(2)
  let shared = rag_test_line_ref(1)
  let events = [
    rag_test_event(Cell, "head", source_ref=Some(first)),
    rag_test_event(RowBreak, ""),
    rag_test_event(Cell, "short", source_ref=Some(shared)),
    rag_test_event(Cell, "duplicate", source_ref=Some(shared)),
    rag_test_event(RowBreak, ""),
    rag_test_event(Cell, "x".repeat(610), source_ref=Some(shared)),
    rag_test_event(RowBreak, ""),
  ]
  let options = @rag.default_rag_options()
  let chunks = batched_table_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(chunks.length(), 2)
  assert_eq(chunks[0].source_refs.map(source => source.line_start), [
    Some(2),
    Some(1),
  ])
  assert_eq(chunks[1].source_refs.map(source => source.line_start), [Some(1)])
  let hidden = batched_table_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    rag_index_without_sources(),
  )
  assert_true(hidden.all(chunk => chunk.source_refs.is_empty()))
}

///|
test "batched text and generic indexes retain a shared source in every batch" {
  let source = rag_test_line_ref(7)
  let options = @rag.default_rag_options()
  let text = batched_text_chunks_from_events(
    [
      rag_test_event(TextLine, "x".repeat(610), source_ref=Some(source)),
      rag_test_event(BlankLine, ""),
      rag_test_event(TextLine, "tail", source_ref=Some(source)),
    ],
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  let generic_events = [
    rag_test_event(StartBlock(Code), "first", source_ref=Some(source)),
    rag_test_event(EndBlock(Code), "", source_ref=Some(source)),
    rag_test_event(StartBlock(Raw), "second", source_ref=Some(source)),
    rag_test_event(EndBlock(Raw), "", source_ref=Some(source)),
  ]
  let generic = batched_generic_chunks_from_events(
    generic_events,
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  for chunks in [text, generic] {
    assert_eq(chunks.length(), 2)
    assert_true(chunks.all(chunk => chunk.source_refs.length() == 1))
    assert_true(chunks.all(chunk => chunk.source_refs[0].line_start == Some(7)))
  }
  let hidden = batched_generic_chunks_from_events(
    generic_events,
    Map([]),
    @core.empty_diagnostics(),
    rag_index_without_sources(),
  )
  assert_true(hidden.all(chunk => chunk.source_refs.is_empty()))
}
