///|
test "pptx parser keeps nested lists speaker notes and asset boundaries stable" {
  let bullets = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/pptx/pptx_bullet_levels.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let bullet_document = bullets.document.unwrap_or_else(fn() {
    abort("missing pptx bullet document")
  })
  assert_true(bullet_document.blocks[2].kind == @core.BlockKind::List)
  let rendered_bullets = (@render.markdown_renderer().render)(
    bullet_document,
    @render.make_render_context(false),
  )
  let expected_bullets = read_utf8_text(
    "samples/fixtures/contracts/pptx/pptx_bullet_levels.expected.md",
  )
  assert_eq(
    rendered_bullets.content.trim().to_owned(),
    expected_bullets.trim().to_owned(),
  )

  let notes = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/pptx/pptx_speaker_notes_basic.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let notes_document = notes.document.unwrap_or_else(fn() {
    abort("missing pptx notes document")
  })
  assert_eq(notes_document.blocks[6].text, "Speaker Notes")

  let assets = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let asset_document = assets.document.unwrap_or_else(fn() {
    abort("missing pptx image document")
  })
  assert_true(asset_document.assets.length() == 1)
  assert_true(asset_document.assets[0].path == Some("assets/image01.png"))
}

///|
test "pptx accurate fidelity respects reading-order-driven grouped lowering" {
  let registry = @fmeta.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Pptx),
    @product.FidelityMode::Accurate,
    @product.OutputMode::Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate pptx parse failed: " + err)
  }
  assert_metric_eq(result.diagnostics, "fidelity_mode", "accurate")
  let document = result.document.unwrap_or_else(fn() {
    abort("missing accurate pptx document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Accurate,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  let expected = read_utf8_text(
    "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.expected.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
}
