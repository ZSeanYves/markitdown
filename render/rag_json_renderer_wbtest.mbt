///|
test "RAG JSON renderer covers document block and event front doors" {
  let source_ref = @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some("fixture.json"),
    Some("json"),
    Some("/name"),
  )
  let block = @core.make_block(@core.BlockKind::Paragraph, "value", source_ref~)
  let diagnostics = @core.empty_diagnostics()
    |> @core.diagnostics_with_input(Some("memory"), Some("json"))
  let document = {
    ..@core.empty_document_ir(),
    blocks: [block],
    metadata: Map([("title", @core.JsonValue::String("Fixture"))]),
    source_map: Some(
      @core.empty_source_map()
      |> @core.source_map_with_document_ref(Some(source_ref)),
    ),
    diagnostics,
  }
  let renderer = rag_json_renderer()
  assert_eq(renderer.name, "RagJsonRenderer")
  let context = make_render_context(false)
  let rendered = (renderer.render)(document, context)
  assert_true(rendered.content.contains("\"output_format\": \"rag_json\""))
  assert_true(rendered.content.contains("\"kind\": \"metadata\""))
  assert_true(rendered.content.contains("\"kind\": \"text\""))
  assert_true(rendered.content.contains("\"source_map\": {"))
  assert_true(rendered.chunks.unwrap().length() == 2)
  assert_true(rendered.diagnostics.metrics.get("chunk_count") == Some("2"))
  assert_true(
    rendered.diagnostics.metrics.get("metadata_chunk_emitted") == Some("true"),
  )

  let no_refs = @rag.make_rag_options(100, 0, true, false, true, true)
  let block_result = (renderer.render_input)(
    RenderInput::BlockStream([block]),
    make_render_context(
      false,
      rag_options=no_refs,
      metadata=Some(Map([("format", @core.JsonValue::String("json"))])),
      source_map=document.source_map,
    ),
  )
  assert_true(block_result.content.contains("\"source_map\": null"))
  assert_true(block_result.chunks.unwrap()[0].source_refs.length() == 0)

  let event : @core.CoreEvent = {
    kind: @core.EventKind::TextLine,
    text: "event value",
    source_ref: Some(source_ref),
  }
  let event_result = (renderer.render_input)(
    RenderInput::EventStream([event]),
    make_render_context(
      false,
      render_profile=@product.RenderProfile::RecordBatchMarkdown,
      base_diagnostics=Some(
        @core.empty_diagnostics()
        |> @core.diagnostics_with_input(Some("memory"), Some("json")),
      ),
    ),
  )
  assert_true(
    event_result.content.contains("\"source_name\": \"fixture.json\""),
  )
  assert_true(
    event_result.diagnostics.metrics.get("record_batch_chunking") ==
    Some("true"),
  )
}

///|
test "RAG JSON chunk encoding and metrics cover all chunk kinds" {
  let chunks : Array[@rag.RagChunk] = []
  for
    kind in [
      @rag.ChunkKind::Text,
      @rag.ChunkKind::Table,
      @rag.ChunkKind::Code,
      @rag.ChunkKind::ImageCaption,
      @rag.ChunkKind::Metadata,
      @rag.ChunkKind::Raw,
    ] {
    chunks.push(
      @rag.make_rag_chunk(
        @rag.chunk_kind_name(kind) + "-0-id",
        kind,
        "text",
        ["Heading"],
        [],
        ["asset"],
        Map([("ordinal", @core.JsonValue::Number("0"))]),
      ),
    )
  }
  assert_eq(chunk_kind_count(chunks, @rag.ChunkKind::Table), 1)
  assert_eq(chunk_kind_count(chunks, @rag.ChunkKind::Code), 1)
  for chunk in chunks {
    let encoded = render_rag_chunk_json(chunk)
    assert_true(encoded.contains("\"heading_path\": [\"Heading\"]"))
    assert_true(encoded.contains("\"asset_refs\": [\"asset\"]"))
  }
  let diagnostics = @core.empty_diagnostics()
  apply_rag_chunk_metrics(diagnostics, chunks, make_render_context(false))
  assert_true(diagnostics.metrics.get("table_chunk_split_count") == Some("1"))
  assert_true(diagnostics.metrics.get("code_chunk_split_count") == Some("1"))
  assert_true(diagnostics.metrics.get("metadata_chunk_emitted") == Some("true"))
}
