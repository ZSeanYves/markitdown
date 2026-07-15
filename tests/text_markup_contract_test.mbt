///|
test "rst canonical semantic blocks carry normalized attrs and stable markdown" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      ".. include:: shared.rst\n   :start-line: 1\n\n.. rubric:: Overview\n",
      "canonical.rst",
      Some(Rst),
    ),
    Rst,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() >= 2)
  assert_true(blocks[0].attrs.get("text_markup_semantic") == Some("true"))
  assert_true(blocks[0].attrs.get("semantic_kind") == Some("include"))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_contains_all(rendered.content, [
    "Include: shared.rst", "Directive: Rubric", ":start-line: 1", "Overview",
  ])
}

///|
test "asciidoc canonical semantic blocks stabilize admonition quote and include" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "[WARNING]\n====\nRead carefully.\n====\n\n[quote, Ada Lovelace]\n____\nThat brain of mine.\n____\n\ninclude::shared.adoc[leveloffset=+1]\n",
      "canonical.adoc",
      Some(Asciidoc),
    ),
    Asciidoc,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Read carefully."),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "QUOTE - Ada Lovelace"),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Include: shared.adoc"),
  )
}

///|
test "tex canonical semantic blocks expose environment inventory and debug attrs" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "\\input{shared.tex}\n\n\\begin{theorem}\nImportant statement.\n\\end{theorem}\n\n\\begin{remark}\nHelpful note.\n\\end{remark}\n",
      "canonical.tex",
      Some(Tex),
    ),
    Tex,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Include: shared.tex"),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Environment: Theorem"),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Environment: Remark"),
  )
  let debug = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_contains_all(debug.content, [
    "\"semantic_kind\": \"environment\"", "\"semantic_family\": \"tex\"", "\"include_target\": \"shared.tex\"",
  ])
}
