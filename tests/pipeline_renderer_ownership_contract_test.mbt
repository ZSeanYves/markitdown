///|
test "html parser keeps renderer boundary for link image table and br semantics" {
  let linked = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/html/html_link_in_paragraph.html",
    ),
    Html,
  )
  let linked_doc = linked.document.unwrap_or(@core.empty_document_ir())
  assert_true(linked.mode == DomAstModel)
  assert_true(linked_doc.blocks.length() == 1)
  let paragraph = linked_doc.blocks[0]
  assert_true(paragraph.kind == Paragraph)
  assert_true(paragraph.text == "Read the docs first.")
  let paragraph_inlines = paragraph.rich_inlines.unwrap_or([])
  assert_true(paragraph_inlines[1].kind == Link)
  assert_true(
    paragraph_inlines[1].href == Some("https://example.com/paragraph"),
  )
  assert_contains_none(paragraph.text, ["[the docs](", "<a "])

  let table = default_registry_parse(
    @input.input_from_path("samples/fixtures/contracts/html/html_br_table.html"),
    Html,
  )
  let table_doc = table.document.unwrap_or(@core.empty_document_ir())
  let first_cell = table_doc.blocks[0].children[0].children[0]
  let cell_inlines = first_cell.rich_inlines.unwrap_or([])
  assert_true(cell_inlines[1].kind == LineBreak)

  let imaged = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/html/html_img_single.html",
    ),
    Html,
  )
  let image_doc = imaged.document.unwrap_or(@core.empty_document_ir())
  assert_true(image_doc.blocks[0].kind == Image)
  assert_true(image_doc.assets.length() == 1)
}

///|
test "markdown parser keeps semantic IR and renderer owns markdown syntax" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "# Title\n\nSee [spec](https://example.com/spec) and `alpha`.\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n",
      "semantic.md",
      Some(Markdown),
    ),
    Markdown,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks[0].kind == Heading)
  assert_eq(blocks[0].text, "Title")
  assert_true(blocks[1].kind == Paragraph)
  let inlines = blocks[1].rich_inlines.unwrap_or([])
  assert_true(inlines[1].kind == Link)
  assert_true(inlines[3].kind == Code)
  assert_true(blocks[2].kind == Table)
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("# Title"))
  assert_true(rendered.content.contains("[spec](https://example.com/spec)"))
  assert_true(rendered.content.contains("`alpha`"))
}

///|
test "asset ref stays first class even when renderer uses core blocks only" {
  let asset_source = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("asset.md"),
    Some("markdown"),
    Some(1),
    Some(1),
  )
  let asset = @core.make_asset_ref(Image, "img-1", source_ref=asset_source)
  let asset = {
    ..asset,
    path: Some("images/demo.png"),
    mime_type: Some("image/png"),
  }
  let image = @core.make_block(Image, "", source_ref=asset_source)
  image.attrs.set("alt", "demo")
  image.attrs.set("path", asset.path.unwrap_or("#"))
  let document = @core.document_from_blocks([image])
  document.assets.push(asset)
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(rendered.content.contains("![demo](images/demo.png)"))
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_kind == Image)
}

///|
test "markdown image blocks keep linked asset refs in the root-pipeline document" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "![diagram](images/demo.png)\n",
      "asset.md",
      Some(Markdown),
    ),
    Markdown,
  )
  let document = unwrap_pipeline_output(
    @pipeline.run_pipeline(
      @pipeline.default_pass_pipeline(),
      @runtime.parse_result_to_ir_input(parsed),
      @pipeline.make_pass_context(false, "balanced"),
    ),
    "markdown image pipeline",
  )
  assert_true(document.blocks.length() == 1)
  assert_true(document.assets.length() == 1)
  assert_true(document.assets[0].asset_kind == Image)
  assert_true(document.assets[0].path == Some("assets/image01.png"))
  assert_true(
    document.blocks[0].attrs.get("asset_id") == Some("markdown-image-1"),
  )
}
