///|
fn rag_json_child_fixture() -> @core.DocumentIR {
  let parent = {
    ..@core.empty_source_ref(),
    file_id: Some("child.json"),
    format: Some("json"),
    json_pointer: Some("/"),
  }
  let source = {
    ..parent,
    json_pointer: Some("/0"),
    line_start: Some(1),
    line_end: Some(1),
    byte_start: Some(1),
    byte_end: Some(4),
    page: Some(1),
  }
  source.extra.set("byte_basis", "normalized_decoded_utf8")
  source.extra.set("byte_normalization", "none")
  let reordered : Map[String, String] = Map([
    ("byte_normalization", "none"),
    ("byte_basis", "normalized_decoded_utf8"),
  ])
  let other = source.extra.copy()
  other.set("byte_basis", "other_explicit_view")
  let root = @core.block_with_attr(
    @core.make_block(List, "", source_ref=parent),
    "asset_id",
    "unchanged-asset",
  )
  for
    reference in [
      source,
      { ..source, extra: reordered, },
      { ..source, extra: other, },
      {
        ..source,
        page: Some(2),
        time_start: Some("00:00:01"),
        time_end: Some("00:00:02"),
      },
    ] {
    root.children.push(
      @core.make_block(ListItem, "same 😀", source_ref=reference),
    )
  }
  {
    ..@core.empty_document_ir(),
    blocks: [root],
    metadata: Map([("format", String("json"))]),
    assets: [@core.make_asset_ref(Image, "unchanged-asset")],
  }
}

///|
test "JSON root list child enrichment preserves legacy identities bodies headings assets and batch behavior" {
  let document = rag_json_child_fixture()
  for batching in [false, true] {
    for preserve_source in [false, true] {
      for preserve_heading in [false, true] {
        for overlap in [0, 2] {
          let options = @rag.make_rag_options(
            7, overlap, preserve_heading, preserve_source, true, true,
          )
          let expected = if batching {
            batched_chunks_from_blocks(
              document.blocks,
              document.metadata,
              document.diagnostics,
              document.assets,
              document.source_map,
              document.assembly,
              options,
            )
          } else {
            @rag.chunks_from_document(document, options)
          }
          let actual = chunks_from_document(
            document,
            options,
            record_batching=batching,
          )
          assert_eq(actual.length(), expected.length())
          assert_eq(actual.length(), 1)
          let before = expected[0]
          let after = actual[0]
          assert_eq(after.id, before.id)
          assert_eq(after.text, before.text)
          assert_eq(after.asset_refs, before.asset_refs)
          assert_eq(after.heading_path, before.heading_path)
          assert_eq(
            after.source_refs.length(),
            if preserve_source {
              4
            } else {
              0
            },
          )
          for key, value in before.metadata {
            if key == "source_count" || key == "location" {
              continue
            }
            assert_true(after.metadata.get(key) == Some(value))
          }
          if preserve_source {
            assert_true(after.metadata.get("source_count") == Some(Number("4")))
            guard after.metadata.get("location") is Some(Object(location)) else {
              fail("location required")
            }
            assert_true(
              location.get("pages") == Some(Array([String("1"), String("2")])),
            )
            assert_true(
              location.get("time_starts") == Some(Array([String("00:00:01")])),
            )
            assert_true(
              location.get("time_ends") == Some(Array([String("00:00:02")])),
            )
            assert_eq(
              after.source_refs[1].extra.get("byte_basis"),
              Some("normalized_decoded_utf8"),
            )
            assert_eq(
              after.source_refs[2].extra.get("byte_basis"),
              Some("other_explicit_view"),
            )
          }
        }
      }
    }
  }
}

///|
test "JSON child provenance enrichment excludes nested general and nonJSON list front doors" {
  let document = rag_json_child_fixture()
  let root = document.blocks[0]
  let nested_document = rag_json_child_fixture()
  let nested_root = nested_document.blocks[0]
  let nested = @core.make_block(ListItem, "nested")
  nested_root.children[0].children.push(nested)
  let options = @rag.default_rag_options()
  for
    next in [
      nested_document,
      { ..document, metadata: Map([("format", String("yaml"))]), },
      { ..document, blocks: [root, root], },
      {
        ..document,
        blocks: [
          {
            ..root,
            source_ref: Some({
              ..@core.block_source_ref(root).unwrap(),
              json_pointer: Some("/nested"),
            }),
          },
        ],
      },
    ] {
    let actual = chunks_from_document(next, options)
    let before = @rag.chunks_from_document(next, options)
    assert_eq(actual.map(chunk => chunk.id), before.map(chunk => chunk.id))
    assert_eq(
      actual.map(chunk => chunk.source_refs.length()),
      before.map(chunk => chunk.source_refs.length()),
    )
  }
}

///|
async test "JSON root child source array is identical in renderer collector and async sink" {
  let document = rag_json_child_fixture()
  let context = make_render_context(false, output_mode=Rag)
  let expected = (rag_json_renderer().render_input)(Document(document), context)
  let fragments : Array[String] = []
  let actual = render_json_input_to_sink(Document(document), context, async fn(
    fragment,
  ) {
    @async.pause()
    fragments.push(fragment)
    Ok(())
  }).unwrap()
  assert_eq(fragments.join(""), expected.content)
  assert_eq(actual.chunks.unwrap()[0].source_refs.length(), 4)
  assert_eq(actual.chunks.unwrap()[0].id, expected.chunks.unwrap()[0].id)
}
