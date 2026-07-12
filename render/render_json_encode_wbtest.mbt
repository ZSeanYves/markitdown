///|
test "debug JSON event encoder covers every event kind" {
  let kinds : Array[@core.EventKind] = [
    @core.EventKind::StartDocument,
    @core.EventKind::EndDocument,
    @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
    @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
    @core.EventKind::Text,
    @core.EventKind::TextLine,
    @core.EventKind::BlankLine,
    @core.EventKind::Cell,
    @core.EventKind::RowBreak,
    @core.EventKind::StructureStart,
    @core.EventKind::StructureEnd,
    @core.EventKind::Key,
    @core.EventKind::Scalar,
  ]
  let events = kinds.map(kind => rag_test_event(kind, "value"))
  let encoded = render_debug_json_events(events, @core.empty_diagnostics())
  assert_true(encoded.contains("\"event_count\": 13"))
  for
    name in [
      "start_document", "end_document", "start_block:paragraph", "end_block:paragraph",
      "text", "text_line", "blank_line", "cell", "row_break", "structure_start",
      "structure_end", "key", "scalar",
    ] {
    assert_true(encoded.contains("\"kind\": \"" + name + "\""))
  }
}

///|
fn json_test_source_ref() -> @core.SourceRef {
  let source_ref = {
    ..@core.empty_source_ref(),
    file_id: Some("fixture"),
    format: Some("json"),
    line_start: Some(1),
    line_end: Some(2),
    json_pointer: Some("/items/0"),
    xpath: Some("/root/item"),
    yaml_path: Some("root.item"),
    html_path: Some("html/body"),
    markdown_path: Some("Heading"),
    container_path: Some("archive.zip"),
    entry_path: Some("doc.json"),
    entry_index: Some(3),
    entry_format: Some("json"),
    inner_path: Some("items[0]"),
    sheet: Some("Sheet1"),
    cell_range: Some("A1:B2"),
    slide: Some(4),
    shape_id: Some("shape-1"),
    relationship_id: Some("rId1"),
    chapter_href: Some("chapter.xhtml"),
  }
  source_ref.extra.set("z", "last")
  source_ref.extra.set("a", "first")
  source_ref
}

///|
test "debug JSON block encoder preserves source rich inline and assets" {
  let source_ref = json_test_source_ref()
  let inline = @core.make_inline_link(
    "Docs",
    "https://example.test",
    title=Some("Title"),
    source_ref~,
  )
  let child = @core.make_block(@core.BlockKind::Paragraph, "child", source_ref~)
  let block = @core.make_block(@core.BlockKind::Heading, "Heading", source_ref~)
    |> @core.block_with_attr("z", "last")
    |> @core.block_with_attr("a", "first")
    |> @core.block_with_rich_inlines(Some([inline]))
    |> @core.block_with_children([child])
  let asset = {
    ..@core.make_asset_ref(@core.AssetKind::Image, "asset-1", source_ref~),
    path: Some("assets/image.png"),
    mime_type: Some("image/png"),
  }
  asset.attrs.set("role", "figure")
  let encoded = render_debug_json_blocks(
    [block],
    @core.empty_diagnostics(),
    make_render_context(false, assets=Some([asset])),
  )
  assert_true(encoded.contains("\"block_count\": 1"))
  assert_true(encoded.contains("\"asset_count\": 1"))
  assert_true(encoded.contains("\"json_pointer\": \"/items/0\""))
  assert_true(encoded.contains("\"entry_index\": 3"))
  assert_true(encoded.contains("\"rich_inlines\": [{"))
  assert_true(encoded.contains("\"asset_id\": \"asset-1\""))
  assert_true(
    encoded.contains("\"attrs\": {\"a\": \"first\", \"z\": \"last\"}"),
  )
}

///|
test "debug JSON encodes metadata source maps and diagnostics" {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("string", @core.JsonValue::String("value"))
  metadata.set("number", @core.JsonValue::Number("42"))
  metadata.set("bool", @core.JsonValue::Bool(true))
  metadata.set("null", @core.JsonValue::Null)
  metadata.set(
    "array",
    @core.JsonValue::Array([@core.JsonValue::String("item")]),
  )
  metadata.set(
    "object",
    @core.JsonValue::Object(
      Map::from_array([("key", @core.JsonValue::Bool(false))]),
    ),
  )
  let metadata_json = render_document_metadata_json(metadata)
  assert_true(metadata_json.contains("\"number\": 42"))
  assert_true(metadata_json.contains("\"bool\": true"))
  assert_true(metadata_json.contains("\"null\": null"))
  assert_true(metadata_json.contains("\"array\": [\"item\"]"))
  assert_true(metadata_json.contains("\"object\": {\"key\": false}"))

  let source_ref = json_test_source_ref()
  let entry = @core.make_source_map_entry(
    primary_ref=Some(source_ref),
    refs=[source_ref],
    merged_from=[source_ref],
    confidence=Some(90),
    relation=Some("derived"),
  )
  let source_map = @core.empty_source_map()
    |> @core.source_map_with_document_ref(Some(source_ref))
    |> @core.source_map_add_block_entry(entry)
    |> @core.source_map_add_asset_entry(entry)
  let source_json = render_source_map_json(Some(source_map))
  assert_true(source_json.contains("\"confidence\": 90"))
  assert_true(source_json.contains("\"relation\": \"derived\""))
  assert_eq(render_source_map_json(None), "null")

  let dependency = @core.make_dependency_diagnostic(
    "binary",
    "tool",
    "required tool",
    @core.DependencyDiagnosticStatus::Missing,
    ["brew install tool"],
    ["apt install tool"],
    footer=Some("restart"),
  )
  let diagnostics = @core.empty_diagnostics()
    |> @core.diagnostics_with_parser(Some("parser"), Some("mode"))
    |> @core.diagnostics_add_warning("warning")
    |> @core.diagnostics_add_error("error")
    |> @core.diagnostics_add_dependency_diagnostic(dependency)
    |> @core.diagnostics_add_metric("z", "2")
    |> @core.diagnostics_add_metric("a", "1")
  let diagnostics_json = render_diagnostics_json(diagnostics)
  assert_true(diagnostics_json.contains("\"status\": \"missing\""))
  assert_true(diagnostics_json.contains("\"warnings\": [\"warning\"]"))
  assert_true(
    diagnostics_json.contains("\"metrics\": {\"a\": \"1\", \"z\": \"2\"}"),
  )
}
