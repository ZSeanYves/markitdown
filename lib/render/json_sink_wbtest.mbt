///|
async test "JSON sink shares collector bytes across output modes and IR shapes" {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("book.epub"),
    Some("epub"),
    Some(1),
    Some(1),
  )
  let asset = {
    ..@core.make_asset_ref(Image, "epub:cover", source_ref~),
    path: Some("assets/cover.png"),
    mime_type: Some("image/png"),
  }
  let blocks = [
    @core.make_block(Paragraph, "body", source_ref~),
    @core.make_block(Image, "Cover", source_ref~)
    |> @core.block_with_attr("asset_id", asset.asset_id),
  ]
  let document = { ..@core.empty_document_ir(), blocks, assets: [asset], }
  let inputs : Array[RenderInput] = [
    Document(document),
    BlockStream(blocks),
    EventStream([rag_test_event(TextLine, "body", source_ref=Some(source_ref))]),
  ]
  for mode in [@product.OutputMode::Debug, Rag] {
    for input in inputs {
      let context = make_render_context(
        false,
        output_mode=mode,
        assets=Some([asset]),
      )
      let renderer = match mode {
        Debug => debug_json_renderer()
        _ => rag_json_renderer()
      }
      let expected = (renderer.render_input)(input, context)
      let fragments : Array[String] = []
      let pending = Ref(false)
      let streamed = render_json_input_to_sink(input, context, async fn(
        fragment,
      ) {
        assert_false(pending.val)
        pending.val = true
        @async.pause()
        fragments.push(fragment)
        pending.val = false
        Ok(())
      }).unwrap()
      assert_eq(fragments.join(""), expected.content)
      assert_eq(streamed.content, "")
      assert_eq(
        streamed.chunks.map(chunks => chunks.map(chunk => chunk.id)),
        expected.chunks.map(chunks => chunks.map(chunk => chunk.id)),
      )
      assert_true(fragments.length() > 1)
    }
  }
}

///|
async test "JSON sink stops the shared cursor after a failed asynchronous write" {
  for mode in [@product.OutputMode::Debug, Rag] {
    let writes = Ref(0)
    let result = render_json_input_to_sink(
      BlockStream([@core.make_block(Paragraph, "body")]),
      make_render_context(false, output_mode=mode),
      async fn(_fragment) {
        @async.pause()
        writes.val += 1
        Err("write stopped")
      },
    )
    assert_eq(result.map(value => value.content), Err("write stopped"))
    assert_eq(writes.val, 1)
  }
}
