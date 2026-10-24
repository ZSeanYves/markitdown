///|
fn json_child_text() -> String {
  "\u{FEFF}\r\n[\"é😀\\u0061\",true,12,\"repeat\",\"repeat\"]\r\n"
}

///|
fn json_child_options(output : @lib.OutputMode) -> @lib.ConvertOptions {
  @lib.ConvertOptions::default()
  .with_mode(Stream)
  .with_format_hint(Some("json"))
  .with_output_mode(output)
}

///|
fn json_child_field(value : Json, name : String) -> Json {
  match value {
    Object(fields) => fields.get(name).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn json_child_assert_refs(sources : Array[Json]) -> Unit raise {
  assert_eq(sources.length(), 6)
  assert_eq(json_child_field(sources[0], "json_pointer"), Json("/"))
  for
    (index, start, end) in [
      (0, 2, 16),
      (1, 17, 21),
      (2, 22, 24),
      (3, 25, 33),
      (4, 34, 42),
    ] {
    let source = sources[index + 1]
    assert_eq(
      json_child_field(source, "json_pointer"),
      Json("/" + index.to_string()),
    )
    assert_eq(json_child_field(source, "byte_start"), Json(start))
    assert_eq(json_child_field(source, "byte_end"), Json(end))
    assert_eq(
      json_child_field(json_child_field(source, "extra"), "byte_basis"),
      Json("normalized_decoded_utf8"),
    )
    assert_eq(
      json_child_field(json_child_field(source, "extra"), "byte_normalization"),
      Json("leading_bom_removed_crlf_to_lf"),
    )
  }
}

///|
async test "public JSON root array Debug already contains every child lexical source" {
  let output = @lib.convert(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    options=json_child_options(Debug),
  ).unwrap()
  let value = @source_json.parse(output.content, reject_duplicate_keys=true)
  guard json_child_field(value, "events") is Array(events) else {
    fail("events required")
  }
  let children : Array[Json] = [Json({ "json_pointer": "/" })]
  for index in 0..<5 {
    let matches = events.filter(event => {
      json_child_field(json_child_field(event, "source_ref"), "json_pointer") ==
      Json("/" + index.to_string())
    })
    assert_eq(matches.length(), 2)
    assert_eq(
      json_child_field(matches[0], "source_ref"),
      json_child_field(matches[1], "source_ref"),
    )
    children.push(json_child_field(matches[0], "source_ref"))
  }
  json_child_assert_refs(children)
}

///|
async test "public JSON root array collector retains root then every existing child source" {
  let output = @lib.convert(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    options=json_child_options(Rag),
  ).unwrap()
  assert_eq(output.chunks.length(), 1)
  assert_eq(
    output.chunks[0].text,
    "- é😀a\n- true\n- 12\n- repeat\n- repeat",
  )
  let value = @source_json.parse(output.content, reject_duplicate_keys=true)
  guard json_child_field(value, "chunks") is Array(chunks) else {
    fail("chunks required")
  }
  guard json_child_field(chunks[0], "source_refs") is Array(sources) else {
    fail("sources required")
  }
  json_child_assert_refs(sources)
  assert_eq(output.chunks[0].source_refs.map(source => source.json_pointer), [
    Some("/"),
    Some("/0"),
    Some("/1"),
    Some("/2"),
    Some("/3"),
    Some("/4"),
  ])
}

///|
async test "public JSON root array Sink retains every existing child and agrees with collector chunks" {
  let fragments : Array[String] = []
  let finishes = Ref(0)
  @lib.convert_to_sink(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    @lib.OutputSink::new(
      async fn(fragment) {
        @async.pause()
        fragments.push(fragment)
        Ok(())
      },
      fn() {
        finishes.val += 1
        Ok(())
      },
    ),
    options=json_child_options(Rag),
  ).unwrap()
  |> ignore
  assert_eq(finishes.val, 1)
  let value = @source_json.parse(fragments.join(""), reject_duplicate_keys=true)
  guard json_child_field(value, "chunks") is Array(chunks) else {
    fail("chunks required")
  }
  guard json_child_field(chunks[0], "source_refs") is Array(sources) else {
    fail("sources required")
  }
  json_child_assert_refs(sources)
  let collected = @lib.convert(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    options=json_child_options(Rag),
  ).unwrap()
  let other = @source_json.parse(collected.content, reject_duplicate_keys=true)
  assert_eq(
    json_child_field(value, "chunks"),
    json_child_field(other, "chunks"),
  )
}

///|
async test "public JSON child provenance flags preserve body old ID and the existing single-unit overlap policy" {
  for preserve_source in [false, true] {
    for preserve_heading in [false, true] {
      let options = json_child_options(Rag).with_rag(
        @lib.RagOptions::default()
        .with_chunk_size(7)
        .with_chunk_overlap(2)
        .with_preserve_source_ref(preserve_source)
        .with_preserve_heading_path(preserve_heading),
      )
      let output = @lib.convert(
        @lib.Input::from_text(json_child_text(), source_name="children.json"),
        options~,
      ).unwrap()
      assert_eq(output.chunks.length(), 1)
      assert_eq(
        output.chunks[0].text,
        "- é😀a\n- true\n- 12\n- repeat\n- repeat",
      )
      assert_eq(
        output.chunks[0].source_refs.length(),
        if preserve_source {
          6
        } else {
          0
        },
      )
      assert_eq(
        output.chunks[0].heading_path,
        if preserve_heading {
          ["0"]
        } else {
          []
        },
      )
      if preserve_source && preserve_heading {
        // Frozen actual baseline CLI id; provenance enrichment must keep it.
        assert_eq(output.chunks[0].id, "text-0-11ee925e")
      }
      let fragments : Array[String] = []
      @lib.convert_to_sink(
        @lib.Input::from_text(json_child_text(), source_name="children.json"),
        @lib.OutputSink::new(
          async fn(fragment) {
            @async.pause()
            fragments.push(fragment)
            Ok(())
          },
          fn() { Ok(()) },
        ),
        options~,
      ).unwrap()
      |> ignore
      let a = @source_json.parse(output.content, reject_duplicate_keys=true)
      let b = @source_json.parse(fragments.join(""), reject_duplicate_keys=true)
      assert_eq(json_child_field(a, "chunks"), json_child_field(b, "chunks"))
    }
  }
}

///|
async test "public JSON Bytes and one-byte Reader preserve all preexisting normalized child lexical refs" {
  let bytes = b"\xEF\xBB\xBF\r\n[\"\xC3\xA9\xF0\x9F\x98\x80\\u0061\",true,12,\"repeat\",\"repeat\"]\r\n"
  for
    input in [
      @lib.Input::from_bytes(bytes, source_name="children.json"),
      @lib.Input::from_async_reader(
        async fn(offset, length) {
          @async.pause()
          let start = offset.to_int().min(bytes.length())
          Ok(
            bytes
            .exact_view(start~, end=(start + length.min(1)).min(bytes.length()))
            .to_owned(),
          )
        },
        size=bytes.length().to_int64(),
        source_name="children.json",
      ),
    ] {
    let output = @lib.convert(input, options=json_child_options(Rag)).unwrap()
    let value = @source_json.parse(output.content, reject_duplicate_keys=true)
    guard json_child_field(value, "chunks") is Array(chunks) else {
      fail("chunks required")
    }
    guard json_child_field(chunks[0], "source_refs") is Array(sources) else {
      fail("refs required")
    }
    json_child_assert_refs(sources)
    assert_eq(output.chunks[0].id, "text-0-11ee925e")
  }
}

///|
async test "public DOM scalar list keeps child pointers without inventing absent byte proof" {
  let options = json_child_options(Rag).with_mode(Balanced)
  let output = @lib.convert(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    options~,
  ).unwrap()
  assert_eq(output.chunks.length(), 1)
  assert_eq(output.chunks[0].source_refs.map(source => source.json_pointer), [
    Some("/"),
    Some("/0"),
    Some("/1"),
    Some("/2"),
    Some("/3"),
    Some("/4"),
  ])
  for source in output.chunks[0].source_refs {
    assert_true(source.byte_start is None && source.byte_end is None)
    assert_true(source.extra.get("byte_basis") is None)
  }
  let fragments : Array[String] = []
  @lib.convert_to_sink(
    @lib.Input::from_text(json_child_text(), source_name="children.json"),
    @lib.OutputSink::new(
      async fn(fragment) {
        @async.pause()
        fragments.push(fragment)
        Ok(())
      },
      fn() { Ok(()) },
    ),
    options~,
  ).unwrap()
  |> ignore
  let collected = @source_json.parse(output.content, reject_duplicate_keys=true)
  let streamed = @source_json.parse(
    fragments.join(""),
    reject_duplicate_keys=true,
  )
  assert_eq(
    json_child_field(collected, "chunks"),
    json_child_field(streamed, "chunks"),
  )
}
