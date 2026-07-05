///|
test "rst canonical semantic blocks carry normalized attrs and stable markdown" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      ".. include:: shared.rst\n   :start-line: 1\n\n.. rubric:: Overview\n",
      "canonical.rst",
      Some(@input.DetectedFormat::Rst),
    ),
    @input.DetectedFormat::Rst,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  let blocks = document.blocks
  assert_true(blocks.length() >= 2)
  assert_true(blocks[0].attrs.get("text_markup_semantic") == Some("true"))
  assert_true(blocks[0].attrs.get("semantic_kind") == Some("include"))
  assert_true(blocks[0].attrs.get("semantic_family") == Some("rst"))
  assert_true(blocks[0].attrs.get("semantic_label") == Some("Include"))
  assert_true(blocks[0].attrs.get("include_target") == Some("shared.rst"))
  assert_true(blocks[1].attrs.get("semantic_kind") == Some("directive"))
  assert_true(blocks[1].attrs.get("semantic_family") == Some("rst"))
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
      Some(@input.DetectedFormat::Asciidoc),
    ),
    @input.DetectedFormat::Asciidoc,
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
  let include_block = match
    find_block_in_tree(
      document.blocks,
      @core.BlockKind::Paragraph,
      "Include: shared.adoc\nleveloffset=+1",
    ) {
    Some(block) => block
    None => fail("missing asciidoc include semantic block")
  }
  assert_true(include_block.attrs.get("text_markup_semantic") == Some("true"))
  assert_true(include_block.attrs.get("semantic_kind") == Some("include"))
  assert_true(include_block.attrs.get("semantic_family") == Some("asciidoc"))
  let debug = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_contains_all(debug.content, [
    "\"semantic_kind\": \"include\"", "\"semantic_family\": \"asciidoc\"", "\"semantic_label\": \"Admonition\"",
    "\"semantic_label\": \"Quote\"",
  ])
}

///|
test "tex canonical semantic blocks expose environment inventory and debug attrs" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "\\input{shared.tex}\n\n\\begin{theorem}\nImportant statement.\n\\end{theorem}\n\n\\begin{remark}\nHelpful note.\n\\end{remark}\n",
      "canonical.tex",
      Some(@input.DetectedFormat::Tex),
    ),
    @input.DetectedFormat::Tex,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Include: shared.tex"),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Environment: Theorem"),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Important statement."),
  )
  assert_true(
    block_tree_contains_text_fragment(document.blocks, "Environment: Remark"),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_contains_all(rendered.content, [
    "Include: shared.tex", "> Environment: Theorem", "Important statement.", "> Environment: Remark",
  ])
  let debug = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_contains_all(debug.content, [
    "\"semantic_kind\": \"environment\"", "\"semantic_family\": \"tex\"", "\"semantic_label\": \"Environment\"",
    "\"include_target\": \"shared.tex\"",
  ])
}

///|
test "tex nested list environments preserve ordered state without backward rescans" {
  let parsed = default_registry_parse(
    @input.input_from_text_with_format(
      "\\begin{enumerate}\n\\item One\n\\begin{itemize}\n\\item Nested bullet\n\\end{itemize}\n\\item Two\n\\end{enumerate}\n",
      "lists.tex",
      Some(@input.DetectedFormat::Tex),
    ),
    @input.DetectedFormat::Tex,
  )
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 1)
  let ordered_flags : Array[String] = []
  collect_list_item_ordered_flags(document.blocks, ordered_flags)
  assert_true(ordered_flags.length() == 3)
  assert_true(ordered_flags[0] == "true")
  assert_true(ordered_flags[1] == "false")
  assert_true(ordered_flags[2] == "true")
}

///|
fn collect_list_item_ordered_flags(
  blocks : Array[@core.CoreBlock],
  out : Array[String],
) -> Unit {
  for block in blocks {
    if block.kind == @core.BlockKind::ListItem {
      out.push(block.attrs.get("ordered").unwrap_or(""))
    }
    if block.children.length() > 0 {
      collect_list_item_ordered_flags(block.children, out)
    }
  }
}
