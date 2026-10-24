///|
fn rag_outline_event(
  kind : @core.BlockKind,
  text : String,
  path : String,
  line : Int32,
  depth : Int32,
) -> @core.CoreEvent {
  let source = {
    ..@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some("outline.xml"),
      Some("xml"),
      Some(line),
      Some(line),
    ),
    xpath: Some(path),
  }
  source.extra.set("ir_event_encoding", "xml_outline_v1")
  source.extra.set("xml_outline_depth", depth.to_string())
  { kind: StartBlock(kind), text, source_ref: Some(source), }
}

///|
fn rag_outline_fixture() -> Array[@core.CoreEvent] {
  [
    rag_outline_event(Heading, "<root>", "/root", 1, 0),
    rag_outline_event(ListItem, "@page: 1", "/root/@page", 1, 0),
    rag_outline_event(ListItem, "<record>", "/root/record[0]", 2, 0),
    rag_outline_event(ListItem, "name: A 😀", "/root/record[0]/name[0]", 3, 1),
    rag_outline_event(ListItem, "@id: x", "/root/record[0]/value[0]/@id", 4, 2),
  ]
}

///|
test "XML compact outline RAG preserves start-block labels without end-block events" {
  let events = rag_outline_fixture()
  let metadata : @core.DocumentMetadata = Map([("format", String("xml"))])
  let context = make_render_context(
    false,
    output_mode=Rag,
    metadata=Some(metadata),
    rag_options=@rag.make_rag_options(1200, 0, true, true, true, true),
  )
  let result = (rag_json_renderer().render_input)(EventStream(events), context)
  let chunks = result.chunks.unwrap()
  assert_true(chunks.length() > 0)
  assert_eq(
    chunks.map(chunk => chunk.text).join(""),
    "# <root>\n- @page: 1\n- <record>\n  - name: A 😀\n    - @id: x",
  )
  let refs : Array[@core.SourceRef] = []
  for chunk in chunks {
    refs.append(chunk.source_refs[:])
  }
  for event in events {
    let source = event.source_ref.unwrap()
    assert_true(
      refs.any(reference => {
        reference.xpath == source.xpath &&
        reference.line_start == source.line_start &&
        reference.extra.get("xml_outline_depth") ==
        source.extra.get("xml_outline_depth")
      }),
    )
  }
  assert_true(result.content.contains("name: A 😀"))
  assert_true(chunks.all(chunk => chunk.kind == Text))
}

///|
test "XML compact outline RAG uses bounded Unicode scalar windows and overlap" {
  let events = [
    rag_outline_event(
      Heading,
      "😀𝄞abcdefghijklmnopqrstuvwxyz",
      "/root",
      1,
      0,
    ),
  ]
  let metadata : @core.DocumentMetadata = Map([("format", String("xml"))])
  let options = @rag.make_rag_options(7, 2, true, true, true, true)
  let chunks = chunks_from_events(
    events,
    metadata,
    @core.empty_diagnostics(),
    [],
    None,
    None,
    options,
  )
  assert_true(chunks.length() > 1)
  let recovered : Array[Char] = []
  for index in 0..<chunks.length() {
    let chars = chunks[index].text.to_array()
    assert_true(chars.length() <= 7)
    assert_true(chars.length() > 0)
    if index == 0 {
      recovered.append(chars[:])
    } else {
      let previous = chunks[index - 1].text.to_array()
      assert_eq(
        previous[previous.length() - 2:].to_owned(),
        chars[:2].to_owned(),
      )
      recovered.append(chars[2:])
    }
    assert_eq(chunks[index].source_refs.length(), 1)
  }
  assert_eq(
    String::from_array(recovered),
    "# 😀𝄞abcdefghijklmnopqrstuvwxyz",
  )
}

///|
test "XML compact outline RAG heading and provenance options remain independent" {
  let events = rag_outline_fixture()
  for preserve_heading in [false, true] {
    for preserve_source in [false, true] {
      let metadata : @core.DocumentMetadata = Map([("format", String("xml"))])
      let chunks = chunks_from_events(
        events,
        metadata,
        @core.empty_diagnostics(),
        [],
        None,
        None,
        @rag.make_rag_options(
          1200, 0, preserve_heading, preserve_source, true, true,
        ),
      )
      assert_eq(chunks.length(), 1)
      assert_eq(
        chunks[0].heading_path,
        if preserve_heading {
          ["root"]
        } else {
          []
        },
      )
      assert_eq(
        chunks[0].source_refs.length(),
        if preserve_source {
          events.length()
        } else {
          0
        },
      )
    }
  }
}

///|
test "XML compact outline record profile keeps labels and bounded batches" {
  let events = rag_outline_fixture()
  let metadata : @core.DocumentMetadata = Map([("format", String("xml"))])
  let chunks = chunks_from_events(
    events,
    metadata,
    @core.empty_diagnostics(),
    [],
    None,
    None,
    @rag.make_rag_options(12, 0, true, true, true, true),
    record_batching=true,
  )
  assert_true(chunks.length() > 1)
  assert_eq(
    chunks.map(chunk => chunk.text).join(""),
    "# <root>\n- @page: 1\n- <record>\n  - name: A 😀\n    - @id: x",
  )
  for chunk in chunks {
    assert_true(chunk.text.to_array().length() <= 12)
    assert_true(chunk.metadata.get("record_batch_profile") == Some(Bool(true)))
  }
}

///|
async test "XML compact outline JSON sink matches the collector with bounded provenance windows" {
  let events : Array[@core.CoreEvent] = [
    rag_outline_event(Heading, "<root>", "/root", 1, 0),
  ]
  for index in 0..<2000 {
    events.push(
      rag_outline_event(
        ListItem,
        "value: " + index.to_string(),
        "/root/value[" + index.to_string() + "]",
        index + 2,
        0,
      ),
    )
  }
  let context = make_render_context(
    false,
    output_mode=Rag,
    metadata=Some(Map([("format", String("xml"))])),
    rag_options=@rag.make_rag_options(64, 0, true, true, true, true),
  )
  let expected = (rag_json_renderer().render_input)(
    EventStream(events),
    context,
  )
  let fragments : Array[String] = []
  let streamed = render_json_input_to_sink(EventStream(events), context, async fn(
    fragment,
  ) {
    @async.pause()
    fragments.push(fragment)
    Ok(())
  }).unwrap()
  assert_eq(fragments.join(""), expected.content)
  assert_true(
    expected.diagnostics.metrics.get("rag_xml_outline_window_peak_chars") ==
    Some("64"),
  )
  let seen : Map[String, Bool] = Map([])
  for chunk in streamed.chunks.unwrap() {
    assert_true(chunk.text.to_array().length() <= 64)
    for source in chunk.source_refs {
      if source.xpath is Some(path) {
        seen.set(path, true)
      }
    }
  }
  assert_eq(seen.length(), events.length())
}

///|
test "XML compact outline chunk IDs are stable and include same-line XPath identity" {
  let first = rag_outline_fixture()
  let second = first.copy()
  let source = {
    ..second[1].source_ref.unwrap(),
    xpath: Some("/root/@edition"),
  }
  second[1] = { ..second[1], source_ref: Some(source), }
  fn render(events : Array[@core.CoreEvent]) -> Array[@rag.RagChunk] {
    chunks_from_events(
      events,
      Map([("format", String("xml"))]),
      @core.empty_diagnostics(),
      [],
      None,
      None,
      @rag.make_rag_options(1200, 0, true, true, true, true),
    )
  }
  let original = render(first)
  assert_eq(
    original.map(chunk => chunk.id),
    render(first).map(chunk => chunk.id),
  )
  assert_true(original[0].id != render(second)[0].id)
}

///|
test "XML compact outline tiny windows make progress and malformed depth stays bounded" {
  let events = [
    rag_outline_event(Heading, "root", "/root", 1, 0),
    rag_outline_event(ListItem, "leaf", "/root/leaf[0]", 2, 2147483647),
  ]
  let diagnostics = @core.empty_diagnostics()
  let chunks = chunks_from_events(
    events,
    Map([("format", String("xml"))]),
    diagnostics,
    [],
    None,
    None,
    @rag.make_rag_options(1, 99, true, true, true, true),
  )
  assert_eq(chunks.map(chunk => chunk.text).join(""), "# root\n- leaf")
  assert_true(chunks.all(chunk => chunk.text.to_array().length() == 1))
  assert_true(
    chunks.all(chunk => {
      chunk.metadata.get("overlap_char_count") == Some(Number("0"))
    }),
  )
  assert_true(
    diagnostics.metrics.get("rag_xml_outline_window_peak_chars") == Some("1"),
  )
}
