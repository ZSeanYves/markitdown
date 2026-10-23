///|
fn rag_json_list_event(
  text : String,
  pointer : String,
  start : Int32,
) -> @core.CoreEvent {
  let source = {
    ..@core.empty_source_ref(),
    file_id: Some("list.json"),
    format: Some("json"),
    json_pointer: Some(pointer),
    line_start: Some(1),
    line_end: Some(1),
    byte_start: Some(start),
    byte_end: Some(start + 3),
  }
  source.extra.set("ir_event_encoding", "json_list_v1")
  source.extra.set("byte_basis", "normalized_decoded_utf8")
  source.extra.set("byte_normalization", "none")
  { kind: StartBlock(ListItem), text, source_ref: Some(source), }
}

///|
fn rag_json_list_chunks(
  events : Array[@core.CoreEvent],
  options : @rag.RagOptions,
  record_batching~ : Bool = false,
) -> Array[@rag.RagChunk] {
  chunks_from_events(
    events,
    Map([("format", String("json"))]),
    @core.empty_diagnostics(),
    [],
    None,
    None,
    options,
    record_batching~,
  )
}

///|
test "JSON compact list RAG consumes literal labels in supplied order" {
  let events = [
    rag_json_list_event("[0] object (2 fields)", "/0", 1),
    rag_json_list_event("[1] 😀𝄞\\n <raw>", "/1", 4),
    rag_json_list_event("", "/2", 7),
  ]
  let options = @rag.make_rag_options(1200, 0, true, true, true, true)
  let chunks = rag_json_list_chunks(events, options)
  assert_eq(chunks.length(), 1)
  assert_eq(
    chunks[0].text,
    "- [0] object (2 fields)\n- [1] 😀𝄞\\n <raw>\n- ",
  )
  assert_eq(chunks[0].source_refs.map(source => source.json_pointer), [
    Some("/0"),
    Some("/1"),
    Some("/2"),
  ])
  assert_eq(chunks[0].source_refs.map(source => source.byte_start), [
    Some(1),
    Some(4),
    Some(7),
  ])
  assert_true(
    chunks[0].metadata.get("ir_event_encoding") == Some(String("json_list_v1")),
  )
}

///|
test "JSON compact list scalar overlap reconstructs every supplied label and row source" {
  let events = [
    rag_json_list_event("😀𝄞abcdefghijklmnop", "/0", 1),
    rag_json_list_event("第二", "/1", 4),
  ]
  let chunks = rag_json_list_chunks(
    events,
    @rag.make_rag_options(7, 2, true, true, true, true),
  )
  assert_true(chunks.length() > 1)
  let recovered : Array[Char] = []
  for index in 0..<chunks.length() {
    let chars = chunks[index].text.to_array()
    assert_true(chars.length() <= 7)
    assert_true(chunks[index].source_refs.length() > 0)
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
  }
  assert_eq(
    String::from_array(recovered),
    "- 😀𝄞abcdefghijklmnop\n- 第二",
  )
}

///|
test "JSON compact list full source identity retains distinct byte basis and positions" {
  let first = rag_json_list_event("same", "/items/0", 1)
  let changed = {
    ..first,
    source_ref: Some({ ..first.source_ref.unwrap(), byte_end: Some(9), }),
  }
  let other_basis = first.source_ref.unwrap()
  let extras = Map::from_array(other_basis.extra.to_array())
  extras.set("byte_basis", "other_explicit_view")
  let other_basis = {
    ..first,
    source_ref: Some({ ..other_basis, extra: extras, }),
  }
  let events = [first, changed, first, other_basis]
  let options = @rag.make_rag_options(1200, 0, true, true, true, true)
  let chunks = rag_json_list_chunks(events, options)
  assert_eq(chunks.length(), 1)
  assert_eq(chunks[0].source_refs.length(), 3)
  assert_eq(chunks[0].source_refs[0].byte_end, Some(4))
  assert_eq(chunks[0].source_refs[1].byte_end, Some(9))
  assert_eq(
    chunks[0].source_refs[2].extra.get("byte_basis"),
    Some("other_explicit_view"),
  )
  assert_eq(
    chunks.map(chunk => chunk.id),
    rag_json_list_chunks(events, options).map(chunk => chunk.id),
  )
  assert_true(
    chunks[0].id !=
    rag_json_list_chunks([first, first, first, other_basis], options)[0].id,
  )
}

///|
test "JSON compact list heading and source flags are independent and batching preserves rows" {
  let events = [
    rag_json_list_event("one", "/items/0", 1),
    rag_json_list_event("two", "/items/1", 4),
  ]
  for preserve_heading in [false, true] {
    for preserve_source in [false, true] {
      let chunks = rag_json_list_chunks(
        events,
        @rag.make_rag_options(
          1200, 0, preserve_heading, preserve_source, true, true,
        ),
        record_batching=true,
      )
      assert_eq(chunks.length(), 1)
      assert_eq(chunks[0].text, "- one\n- two")
      assert_eq(
        chunks[0].heading_path,
        if preserve_heading {
          ["items"]
        } else {
          []
        },
      )
      assert_eq(
        chunks[0].source_refs.length(),
        if preserve_source {
          2
        } else {
          0
        },
      )
      assert_true(
        chunks[0].metadata.get("record_batch_profile") == Some(Bool(true)),
      )
    }
  }
  assert_eq(rag_json_list_chunks([], @rag.default_rag_options()).length(), 0)
}

///|
test "JSON compact list IDs distinguish complete source fields and ignore Map insertion order" {
  let event = rag_json_list_event("label", "/items/0", 1)
  let source = event.source_ref.unwrap()
  let variants = [
    { ..source, page: Some(1), },
    { ..source, bbox: Some({ x0: -1.25, y0: 0.0, x1: 2.5, y1: -0.5, }), },
    { ..source, byte_start: Some(0), },
    { ..source, time_start: Some("00:00:01.000"), },
    { ..source, time_end: Some("00:00:02.000"), },
    { ..source, json_pointer: Some("/items/1"), },
  ]
  let options = @rag.make_rag_options(1200, 0, true, true, true, true)
  let original = rag_json_list_chunks([event], options)[0].id
  for variant in variants {
    assert_true(
      original !=
      rag_json_list_chunks([{ ..event, source_ref: Some(variant), }], options)[0].id,
    )
  }
  let reordered : Map[String, String] = Map([])
  let entries = source.extra.to_array()
  for index = entries.length() - 1; index >= 0; index = index - 1 {
    reordered.set(entries[index].0, entries[index].1)
  }
  let reordered_event = {
    ..event,
    source_ref: Some({ ..source, extra: reordered, }),
  }
  let chunks = rag_json_list_chunks([event, reordered_event], options)
  assert_eq(chunks[0].source_refs.length(), 1)
  assert_eq(original, rag_json_list_chunks([reordered_event], options)[0].id)
}

///|
async test "JSON compact list collector and async sink share all labels sources flags and IDs" {
  let events : Array[@core.CoreEvent] = []
  for index in 0..<1000 {
    events.push(
      rag_json_list_event(
        "[" + index.to_string() + "] 😀value",
        "/items/" + index.to_string(),
        index * 3,
      ),
    )
  }
  for preserve_heading in [false, true] {
    for preserve_source in [false, true] {
      let context = make_render_context(
        false,
        output_mode=Rag,
        metadata=Some(Map([("format", String("json"))])),
        rag_options=@rag.make_rag_options(
          31, 2, preserve_heading, preserve_source, true, true,
        ),
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
      assert_eq(
        streamed.chunks.unwrap().map(chunk => chunk.id),
        expected.chunks.unwrap().map(chunk => chunk.id),
      )
      assert_eq(
        expected.diagnostics.metrics.get("rag_json_list_window_peak_chars"),
        Some("31"),
      )
      let seen : Map[String, Bool] = Map([])
      let recovered : Array[Char] = []
      for index in 0..<streamed.chunks.unwrap().length() {
        let chunk = streamed.chunks.unwrap()[index]
        let scalars = chunk.text.to_array()
        assert_true(scalars.length() <= 31)
        recovered.append(scalars[if index == 0 { 0 } else { 2 }:])
        for source in chunk.source_refs {
          seen.set(source.json_pointer.unwrap(), true)
          assert_eq(
            source.extra.get("byte_basis"),
            Some("normalized_decoded_utf8"),
          )
        }
      }
      assert_eq(
        String::from_array(recovered),
        events.map(event => "- " + event.text).join("\n"),
      )
      assert_eq(
        seen.length(),
        if preserve_source {
          events.length()
        } else {
          0
        },
      )
      @probe_json.parse(expected.content) |> ignore
    }
  }
}

///|
async test "JSON compact list nonfinite source reaches existing controlled JSON error boundary" {
  let event = rag_json_list_event("label", "/0", 1)
  let source = {
    ..event.source_ref.unwrap(),
    bbox: Some({ x0: 1.0 / 0.0, y0: 0.0, x1: 1.0, y1: 1.0, }),
  }
  let events = [{ ..event, source_ref: Some(source), }]
  let context = make_render_context(false, output_mode=Rag)
  let rejected = try {
    (rag_json_renderer().render_input)(EventStream(events), context) |> ignore
    false
  } catch {
    NonFiniteSourceBBox("x0") => true
    _ => false
  }
  assert_true(rejected)
  let writes = Ref(0)
  let result = render_json_input_to_sink(EventStream(events), context, async fn(
    _,
  ) {
    @async.pause()
    writes.val += 1
    Ok(())
  })
  assert_eq(
    result.map(value => value.content),
    Err("SourceRef bbox x0 must be finite"),
  )
  assert_true(writes.val > 0)
}
