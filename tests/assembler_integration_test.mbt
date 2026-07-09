///|
test "pipeline assigns stable block ids and assembly summary" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Alpha",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "1")
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    "Body",
    source_ref=@core.empty_source_ref(),
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([heading, paragraph]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(heading.block_id != "")
  assert_true(paragraph.block_id != "")
  let assembly = document.assembly.unwrap_or(@core.empty_document_assembly())
  assert_true(assembly.root_block_ids.length() == 2)
  assert_true(assembly.sections.length() == 1)
  assert_true(assembly.sections[0].title == "Alpha")
  assert_true(assembly.heading_paths.get(paragraph.block_id) == Some(["Alpha"]))
  assert_metric_eq(document.diagnostics, "assembly_section_count", "1")
}

///|
test "assembler resolves asset ownership from block asset ids" {
  let source_ref = @core.source_ref_with_html_path(
    @core.empty_source_ref(),
    Some("sample.html"),
    Some("html"),
    Some("/html/body/p/img[1]"),
  )
  let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  image.attrs.set("asset_id", "asset-image-1")
  image.attrs.set("path", "assets/image01.jpg")

  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    "asset-image-1",
    source_ref~,
  )
  let asset = { ..asset, path: Some("assets/image01.jpg") }

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::Document({
      ..@core.document_from_blocks([image]),
      assets: [asset],
    }),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let assembly = document.assembly.unwrap_or(@core.empty_document_assembly())
  assert_true(assembly.asset_bindings.length() == 1)
  assert_true(assembly.asset_bindings[0].asset_id == "asset-image-1")
  assert_true(
    assembly.asset_bindings[0].owner_block_id == document.blocks[0].block_id,
  )
  assert_true(assembly.asset_bindings[0].relation == "rendered_image_block")
  assert_metric_eq(document.diagnostics, "resolved_asset_binding_count", "1")
}
