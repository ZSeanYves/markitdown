///|
test "text RAG keeps ordered source references across index growth and nonconsecutive repeats" {
  let events : Array[@core.CoreEvent] = []
  let expected : Array[@core.SourceRef] = []
  for line in 0..<513 {
    let source_ref = rag_test_line_ref(line)
    expected.push(source_ref)
    events.push(rag_test_event(TextLine, "line", source_ref=Some(source_ref)))
    events.push(rag_test_event(BlankLine, ""))
    if line % 17 == 0 {
      events.push(
        rag_test_event(TextLine, "repeated", source_ref=Some(expected[0])),
      )
      events.push(rag_test_event(BlankLine, ""))
    }
  }
  let chunks = rag_text_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    @rag.default_rag_options(),
  )
  assert_eq(chunks.length(), 1)
  assert_eq(chunks[0].source_refs.length(), expected.length())
  for index in 0..<expected.length() {
    assert_eq(chunks[0].source_refs[index].file_id, expected[index].file_id)
    assert_eq(chunks[0].source_refs[index].format, expected[index].format)
    assert_eq(chunks[0].source_refs[index].line_start, Some(index))
    assert_eq(chunks[0].source_refs[index].line_end, Some(index))
  }
  assert_true(chunks[0].text.has_prefix("line\n\nrepeated\n\nline"))
  assert_true(chunks[0].text.has_suffix("line"))
  let options = @rag.make_rag_options(1200, 150, true, false, true, true)
  let without_refs = rag_text_chunks_from_events(
    events,
    Map([]),
    @core.empty_diagnostics(),
    options,
  )
  assert_eq(without_refs[0].text, chunks[0].text)
  assert_eq(without_refs[0].source_refs.length(), 0)
}

///|
test "generic RAG preserves text and first source order across nonconsecutive repeats" {
  let chunks = rag_text_chunks_from_generic_events(
    [
      rag_test_event(Text, "a", source_ref=Some(rag_test_line_ref(1))),
      rag_test_event(Text, "b", source_ref=Some(rag_test_line_ref(2))),
      rag_test_event(Text, "a2", source_ref=Some(rag_test_line_ref(1))),
      rag_test_event(Text, "c", source_ref=Some(rag_test_line_ref(3))),
    ],
    Map([]),
    @core.empty_diagnostics(),
    @rag.default_rag_options(),
  )
  assert_eq(chunks.length(), 1)
  assert_eq(chunks[0].text, "a\nb\na2\nc")
  assert_eq(chunks[0].source_refs.map(source_ref => source_ref.line_start), [
    Some(1),
    Some(2),
    Some(3),
  ])
}
