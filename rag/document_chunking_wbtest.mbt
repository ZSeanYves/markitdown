///|
fn rag_test_document(blocks : Array[@core.CoreBlock]) -> @core.DocumentIR {
  { ..@core.empty_document_ir(), blocks, }
}

///|
fn rag_test_source_ref(page : Int) -> @core.SourceRef {
  {
    ..@core.empty_source_ref(),
    file_id: Some("fixture"),
    format: Some("markdown"),
    page: Some(page),
    line_start: Some(page * 10),
  }
}

///|
test "document chunks preserve metadata headings sources and overlap" {
  let heading = @core.make_block(@core.BlockKind::Heading, "Overview")
    |> @core.block_with_attr("level", "1")
  let first = @core.make_block(
    @core.BlockKind::Paragraph,
    "alpha beta",
    source_ref=rag_test_source_ref(1),
  )
  let second = @core.make_block(
    @core.BlockKind::Paragraph,
    "gamma delta",
    source_ref=rag_test_source_ref(2),
  )
  let document = rag_test_document([heading, first, second])
  document.metadata.set("format", @core.JsonValue::String("markdown"))
  document.metadata.set("title", @core.JsonValue::String("Fixture title"))
  document.metadata.set("creator", @core.JsonValue::String("MoonBit"))
  let chunks = chunks_from_document(
    document,
    make_rag_options(12, 5, true, true, true, true),
  )
  assert_eq(chunks.length(), 3)
  assert_true(chunks[0].kind == ChunkKind::Metadata)
  assert_true(chunks[0].text.contains("title: Fixture title"))
  assert_true(chunks[1].heading_path == ["Overview"])
  assert_eq(chunks[1].source_refs.length(), 1)
  assert_true(chunks[2].text.contains("gamma delta"))
  assert_true(chunks[1].id.has_prefix("text-1-"))
}

///|
test "document chunks render lists quotes raw and rich inline text" {
  let nested = @core.make_block(@core.BlockKind::ListItem, "child")
  let item = @core.make_block(@core.BlockKind::ListItem, "parent")
    |> @core.block_with_children([nested])
  let list = @core.make_block(@core.BlockKind::List, "")
    |> @core.block_with_attr("ordered", "true")
    |> @core.block_with_children([item])
  let quote = @core.make_block(@core.BlockKind::BlockQuote, "one\ntwo")
  let raw = @core.make_block(@core.BlockKind::Raw, "<custom>raw</custom>")
  let rich = @core.make_block(@core.BlockKind::Paragraph, "ignored")
    |> @core.block_with_rich_inlines(
      Some([
        @core.make_inline_text("Docs "),
        @core.make_inline_link("site", "https://example.test"),
        @core.make_inline_line_break(),
        @core.make_inline_code("value"),
        @core.make_inline_image("chart", "chart.png", title=Some("Chart")),
      ]),
    )
  let chunks = chunks_from_document(
    rag_test_document([list, quote, raw, rich]),
    make_rag_options(1000, 0, true, true, true, true),
  )
  assert_eq(chunks.length(), 1)
  assert_true(chunks[0].kind == ChunkKind::Raw)
  assert_true(chunks[0].text.contains("1. parent"))
  assert_true(chunks[0].text.contains("  - child"))
  assert_true(chunks[0].text.contains("> one\n> two"))
  assert_true(chunks[0].text.contains("site (https://example.test)"))
  assert_true(chunks[0].text.contains("chart [Chart]"))
}

///|
fn rag_test_cell(text : String, column : Int) -> @core.CoreBlock {
  @core.make_block(@core.BlockKind::TableCell, text)
  |> @core.block_with_attr("column_index", column.to_string())
}

///|
test "document chunks split regular and sparse tables" {
  let header = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_children([
      rag_test_cell("Name", 1),
      rag_test_cell("Value", 2),
    ])
  let row1 = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_children([
      rag_test_cell("alpha", 1),
      rag_test_cell("one", 2),
    ])
  let row2 = @core.make_block(@core.BlockKind::TableRow, "")
    |> @core.block_with_children([
      rag_test_cell("beta", 1),
      rag_test_cell("two", 2),
    ])
  let table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_children([header, row1, row2])
  let sparse = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_children([
      @core.make_block(@core.BlockKind::TableRow, "")
      |> @core.block_with_attr("sparse_cell_columns", "true")
      |> @core.block_with_attr("declared_column_count", "3")
      |> @core.block_with_attr("sparse_row_payload", "1\tleft\\nline\n3\tright"),
    ])
  let chunks = chunks_from_document(
    rag_test_document([table, sparse]),
    make_rag_options(22, 0, true, true, true, true),
  )
  assert_true(chunks.length() >= 3)
  assert_true(chunks[0].kind == ChunkKind::Table)
  assert_true(chunks[0].text.contains("| Name | Value |"))
  assert_true(
    chunks.any(chunk => chunk.text.contains("| left\nline |  | right |")),
  )
}

///|
test "document chunks split code and resolve image assets" {
  let code = @core.make_block(
      @core.BlockKind::Code,
      "first line\nsecond line\nthird line",
    )
    |> @core.block_with_attr("language", "moonbit")
  let image = @core.make_block(@core.BlockKind::Image, "")
    |> @core.block_with_attr("caption", "Architecture diagram")
    |> @core.block_with_attr("asset_id", "asset-1")
  let asset = @core.make_asset_ref(@core.AssetKind::Image, "asset-1")
  let document = { ..rag_test_document([code, image]), assets: [asset] }
  let chunks = chunks_from_document(
    document,
    make_rag_options(24, 0, false, false, true, true),
  )
  assert_true(chunks.length() >= 3)
  assert_true(chunks[0].kind == ChunkKind::Code)
  assert_true(chunks[0].text.has_prefix("```moonbit"))
  let image_chunk = chunks[chunks.length() - 1]
  assert_true(image_chunk.kind == ChunkKind::ImageCaption)
  assert_eq(image_chunk.text, "Architecture diagram")
  assert_true(image_chunk.heading_path.length() == 0)
  assert_true(image_chunk.source_refs.length() == 0)
  assert_true(image_chunk.asset_refs.contains("asset-1"))
}

///|
test "document chunks force audio segments and ignore empty special blocks" {
  let before = @core.make_block(@core.BlockKind::Paragraph, "before")
  let audio = @core.make_block(@core.BlockKind::Paragraph, "00:01 speaker")
    |> @core.block_with_attr("audio_segment", "true")
  let after = @core.make_block(@core.BlockKind::Paragraph, "after")
  let empty_table = @core.make_block(@core.BlockKind::Table, "")
  let empty_image = @core.make_block(@core.BlockKind::Image, "")
  let chunks = chunks_from_document(
    rag_test_document([before, audio, after, empty_table, empty_image]),
    default_rag_options(),
  )
  assert_eq(chunks.length(), 3)
  assert_eq(chunks[0].text, "before")
  assert_eq(chunks[1].text, "00:01 speaker")
  assert_eq(chunks[2].text, "after")
}

///|
test "RAG text unit splitting covers overlap and disabled provenance" {
  let units : Array[ChunkUnit] = [
    {
      text: "alpha",
      char_count: 5,
      block_kind: "paragraph",
      force_single_chunk: false,
    },
    {
      text: "beta",
      char_count: 4,
      block_kind: "list_item",
      force_single_chunk: false,
    },
    {
      text: "gamma",
      char_count: 5,
      block_kind: "paragraph",
      force_single_chunk: false,
    },
  ]
  let slices = split_text_units(units, 9, 4)
  assert_true(slices.length() >= 2)
  assert_true(slices[0].length() == 2)
  assert_true(slices[1][0].text == "beta")
  assert_eq(
    build_text_chunks(
      [],
      [],
      [],
      [],
      false,
      0,
      "txt",
      None,
      default_rag_options(),
    ).length(),
    0,
  )
  let chunks = build_text_chunks(
    units,
    [rag_test_source_ref(1)],
    ["asset"],
    ["Heading"],
    false,
    0,
    "txt",
    None,
    make_rag_options(9, 0, false, false, true, true),
  )
  assert_true(chunks.length() >= 2)
  assert_eq(chunks[0].heading_path.length(), 0)
  assert_eq(chunks[0].source_refs.length(), 0)
  assert_true(chunks[0].asset_refs == ["asset"])
}

///|
test "RAG table chunking supports unsplit and disabled context" {
  let header = @core.make_block(@core.BlockKind::TableRow, "Name|Value")
  let body = @core.make_block(@core.BlockKind::TableRow, "alpha|one")
  let table = @core.make_block(@core.BlockKind::Table, "")
    |> @core.block_with_children([header, body])
  let chunks = table_chunks_from_block(
    table,
    ["Heading"],
    0,
    "csv",
    Some("Table"),
    make_rag_options(5, 0, false, false, false, true),
  )
  assert_eq(chunks.length(), 1)
  assert_eq(chunks[0].heading_path.length(), 0)
  assert_eq(chunks[0].source_refs.length(), 0)
  assert_true(chunks[0].text.contains("Name|Value"))
  assert_eq(
    block_to_special_chunks(
      @core.make_block(@core.BlockKind::Section, "section"),
      [],
      0,
      "txt",
      None,
      default_rag_options(),
      [],
    ).length(),
    0,
  )
}

///|
test "RAG heading paths cover same-level replacement and assembly fallback" {
  let first = @core.make_block(@core.BlockKind::Heading, "First")
    |> @core.block_with_attr("level", "1")
  let second = @core.make_block(@core.BlockKind::Heading, "Second")
    |> @core.block_with_attr("level", "1")
  assert_true(update_heading_path(["First"], second) == ["Second"])
  assert_true(!string_arrays_eq(["a"], ["a", "b"]))
  assert_true(!string_arrays_eq(["a"], ["b"]))
  let assembly = @core.empty_document_assembly()
  assembly.heading_paths.set("unrelated", ["Other"])
  let document = {
    ..rag_test_document([first, second]),
    assembly: Some(assembly),
  }
  assert_true(
    block_heading_path(document, assembly.heading_paths, first, []) == ["First"],
  )
  let paragraph = @core.make_block(@core.BlockKind::Paragraph, "body")
  assert_eq(
    block_heading_path(document, assembly.heading_paths, paragraph, ["First"]).join(
      "/",
    ),
    "First",
  )
}

///|
test "RAG metadata and list-item helpers cover non-text values" {
  let document = rag_test_document([])
  document.metadata.set("title", @core.JsonValue::Null)
  document.metadata.set("subject", @core.JsonValue::Bool(true))
  let chunk = metadata_chunk(
    document,
    make_rag_options(10, 0, false, false, true, true),
    0,
    "txt",
    None,
  ).unwrap()
  assert_true(chunk.text.contains("subject: true"))
  let list_item = @core.make_block(@core.BlockKind::ListItem, "item")
  assert_true(block_to_text_unit(list_item).unwrap().block_kind == "list_item")
}
