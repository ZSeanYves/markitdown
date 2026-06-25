///|
test "micro.render.synthetic_blocks" (b : @bench.T) {
  let renderer = @render.markdown_renderer()
  let context = @render.make_render_context(false)
  let document = synthetic_render_document()
  b.bench(name="micro.render.synthetic_blocks/markdown_document", fn() {
    let rendered = (renderer.render)(document, context)
    @shared.keep_string(b, rendered.content)
  })
}

///|
fn synthetic_render_document() -> @core.DocumentIR {
  let heading = @core.block_with_attr(
    @core.make_block(
      @core.BlockKind::Heading,
      "Benchmark Native Harness",
      source_ref=@core.empty_source_ref(),
    ),
    "level",
    "1",
  )
  let paragraph = @core.block_with_rich_inlines(
    @core.make_block(
      @core.BlockKind::Paragraph,
      "",
      source_ref=@core.empty_source_ref(),
    ),
    Some([
      @core.make_inline_text("Synthetic document with "),
      @core.make_inline_code("code"),
      @core.make_inline_text(" and "),
      @core.make_inline_link("links", "https://example.com/bench"),
      @core.make_inline_text("."),
    ]),
  )
  let list = @core.block_with_children(
    @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=@core.empty_source_ref(),
    ),
    [
      @core.make_block(
        @core.BlockKind::ListItem,
        "first item",
        source_ref=@core.empty_source_ref(),
      ),
      @core.make_block(
        @core.BlockKind::ListItem,
        "second item",
        source_ref=@core.empty_source_ref(),
      ),
    ],
  )
  @core.document_from_blocks([heading, paragraph, list])
}
