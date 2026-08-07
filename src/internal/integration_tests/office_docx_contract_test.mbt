///|
test "docx parser preserves note ordering code blocks and comment spacing" {
  let notes = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/docx/docx_multiple_notes_order.docx",
    ),
    Docx,
  )
  let note_document = notes.document.unwrap_or_else(fn() {
    abort("missing note-order document")
  })
  let note_rendered = (@render.markdown_renderer().render)(
    note_document,
    @render.make_render_context(false),
  )
  assert_true(
    note_rendered.content.contains("First reference[^1] then second [^2]"),
  )
  assert_true(note_rendered.content.contains("Comment here [comment 1]"))
  assert_true(note_rendered.content.contains("Endnote here[^e1]"))

  let code = default_registry_parse(
    @input.input_from_path(
      "samples/fixtures/contracts/docx/docx_codeblock_basic.docx",
    ),
    Docx,
  )
  let code_document = code.document.unwrap_or_else(fn() {
    abort("missing code document")
  })
  assert_true(code_document.blocks.length() == 1)
  assert_true(code_document.blocks[0].kind == Code)
  assert_eq(code_document.blocks[0].text, "let x = 1\nprintln(x)")
}

///|
test "docx accurate fidelity inlines anchored textboxes into body order" {
  let registry = @fmeta.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(Docx),
    Accurate,
    Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/fixtures/contracts/docx/docx_textbox_basic.docx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate docx parse failed: " + err)
  }
  assert_metric_eq(result.diagnostics, "fidelity_mode", "accurate")
  let document = result.document.unwrap_or_else(fn() {
    abort("missing accurate docx document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(
      false,
      fidelity_mode=Accurate,
      output_mode=Markdown,
    ),
  )
  assert_true(
    rendered.content.contains("Body before.\n\nText box body.\n\nBody after."),
  )
  assert_true(!rendered.content.contains("## Text Boxes"))
}
