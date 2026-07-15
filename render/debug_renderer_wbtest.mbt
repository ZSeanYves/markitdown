///|
test "debug renderer covers document block and event input front doors" {
  let block = @core.make_block(Paragraph, "body")
  let asset = @core.make_asset_ref(Image, "image")
  let document = {
    ..@core.empty_document_ir(),
    blocks: [block],
    assets: [asset],
  }
  let renderer = debug_json_renderer()
  let context = make_render_context(true, render_profile=SectionFlushMarkdown)
  let direct = (renderer.render_input)(Document(document), context)
  assert_true(direct.content.contains("\"block_count\": 1"))
  assert_true(direct.content.contains("\"asset_id\": \"image\""))
  let blocks = (renderer.render_input)(BlockStream([block]), context)
  assert_true(blocks.content.contains("\"block_count\": 1"))
  assert_true(
    blocks.diagnostics.metrics.get("applied_render_profile") ==
    Some("section_flush_markdown"),
  )
  let event = rag_test_event(Text, "event")
  let events = (renderer.render_input)(EventStream([event]), context)
  assert_true(events.content.contains("\"event_count\": 1"))
  let markdown = markdown_renderer()
  assert_eq(
    (markdown.render_input)(Document(document), context).content,
    "body",
  )
}

///|
test "RAG option normalization handles negative overlap" {
  let options = @rag.make_rag_options(100, -1, true, true, true, true)
  assert_eq(options.chunk_overlap, @rag.default_rag_options().chunk_overlap)
}
