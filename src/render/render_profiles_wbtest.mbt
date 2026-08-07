///|
fn profile_context(
  profile : @product.RenderProfile,
  assets? : Array[@core.AssetRef]? = None,
) -> RenderContext {
  make_render_context(false, render_profile=profile, assets~)
}

///|
test "render profiles flush section and page groups with stable spacers" {
  let a = @core.make_block(Paragraph, "A")
    |> @core.block_with_attr("render_boundary_key", "one")
  let b = @core.make_block(Paragraph, "B")
    |> @core.block_with_attr("render_boundary_key", "two")
  let c = @core.make_block(Paragraph, "C")
  let section = profiled_blocks(
    [a, b, c],
    profile_context(SectionFlushMarkdown),
  )
  assert_eq(section.length(), 4)
  assert_true(section[1].kind == Raw)
  assert_true(section[1].attrs.get("raw_kind") == Some("markdown_literal"))

  let page_a = @core.block_with_attr(a, "render_window_group", "page-1")
  let page_b = @core.block_with_attr(b, "render_window_group", "page-2")
  let pages = profiled_blocks(
    [page_a, page_b],
    profile_context(PageWindowMarkdown),
  )
  assert_eq(pages.length(), 3)
  assert_true(pages[1].kind == Raw)
}

///|
test "render sparse profile marks nested sparse tables" {
  let table = @core.make_block(Table, "")
    |> @core.block_with_attr("render_table_mode", "sparse")
  let wrapper = @core.make_block(BlockQuote, "")
    |> @core.block_with_children([table])
  let blocks = profiled_blocks([wrapper], profile_context(SparseTableMarkdown))
  assert_true(
    blocks[0].children[0].attrs.get("sparse_render_enabled") == Some("true"),
  )
}

///|
test "render notes profile moves appendix blocks before body" {
  let body = @core.make_block(Paragraph, "body")
  let note = @core.make_block(Paragraph, "note")
    |> @core.block_with_attr("note_definition_id", "n")
  let comment = @core.make_block(Paragraph, "comment")
    |> @core.block_with_attr("render_appendix_group", "comments")
  let blocks = profiled_blocks(
    [body, note, comment],
    profile_context(NotesAppendixFirst),
  )
  assert_eq(blocks[0].text, "note")
  assert_eq(blocks[1].text, "comment")
  assert_eq(blocks[2].text, "body")
  let unchanged = profiled_blocks([body], profile_context(NotesAppendixFirst))
  assert_eq(unchanged.length(), 1)
}

///|
test "render asset profile prepends a manifest and handles missing paths" {
  let first = {
    ..@core.make_asset_ref(Image, "image-1"),
    path: Some("assets/image.png"),
  }
  let second = @core.make_asset_ref(Attachment, "file-1")
  let body = @core.make_block(Paragraph, "body")
  let blocks = profiled_blocks(
    [body],
    profile_context(AssetManifestFirst, assets=Some([first, second])),
  )
  assert_eq(blocks.length(), 4)
  assert_eq(blocks[0].text, "Assets")
  assert_eq(blocks[1].text, "- image-1: assets/image.png")
  assert_eq(blocks[2].text, "- file-1")
  assert_true(blocks[0].attrs.get("appendix_kind") == Some("assets"))
  let unchanged = profiled_blocks([body], profile_context(AssetManifestFirst))
  assert_eq(unchanged.length(), 1)
}

///|
test "render default and event profiles preserve input identity" {
  let blocks = [@core.make_block(Paragraph, "body")]
  let profiled = profiled_blocks(blocks, profile_context(DefaultMarkdown))
  assert_eq(profiled.length(), 1)
  let events = [rag_test_event(Text, "value")]
  assert_eq(
    profiled_events(events, profile_context(RecordBatchMarkdown)).length(),
    1,
  )
}
