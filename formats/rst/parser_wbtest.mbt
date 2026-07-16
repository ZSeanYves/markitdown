///|
test "RST parser lowers headings lists directives notes tables and includes" {
  let text = [
    "Title", "=====", "", "Paragraph with **bold** and `link <https://example.test>`_.",
    "", "- First", "- Second", "", ".. note::", "   Important body", "", ".. include:: chapter.rst",
    "", ".. code-block:: python", "", "   print(1)", "", "+------+-------+", "| Name | Value |",
    "+======+=======+", "| A    | 1     |", "+------+-------+",
  ].join("\n")
  let result = (rst_parser().parse)(
    @input.input_from_text_with_format(text, "complex.rst", Some(Rst)),
    @parser.new_parse_context(Rst),
  ).unwrap()
  assert_true(result.document.unwrap().blocks.length() >= 4)
  assert_true(result.diagnostics.metrics.get("heading_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("block_count") != Some("0"))
  assert_true(result.diagnostics.pass_trace.contains("parse:rst_parser"))
}

///|
test "RST semantic edge cases retain empty directives roles and references" {
  let text = [
    ".. warning::", "", ".. include:: local-only.rst", "", "A :code:`role value` and [#]_ reference.",
    "", ".. [#] Footnote body", "", ":Author: Example",
  ].join("\n")
  let result = (rst_parser().parse)(
    @input.input_from_text_with_format(text, "edge.rst", Some(Rst)),
    @parser.new_parse_context(Rst),
  ).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text.contains("Warning")))
  assert_true(blocks.any(block => block.text.contains("local-only.rst")))
  assert_true(blocks.any(block => block.text.contains("role value")))
  assert_eq(rst_strip_directive_label(".. code-block::"), "code-block")
  assert_eq(rst_strip_directive_label("plain"), "plain")
  assert_eq(text_markup_display_label("  mixed   CASE "), "Mixed Case")
}

///|
test "RST semantic hooks expose include and directive recovery consistently" {
  let parsed = @dmark.parse_rst_document(
    ".. include:: appendix.rst\n\n.. topic::\n   body\n\nplain",
  )
  let include_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") == Some("include")
  })
  let directive_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") == Some("directive")
  })
  let plain_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") is None && block.text.contains("plain")
  })
  assert_true(include_blocks.length() > 0)
  assert_true(directive_blocks.length() > 0)
  assert_true(plain_blocks.length() > 0)
  let source_ref = @core.empty_source_ref()
  assert_true(
    rst_semantic_raw_block(include_blocks[0], source_ref, "rst").unwrap().text.contains(
      "appendix.rst",
    ),
  )
  assert_true(
    rst_semantic_raw_block(directive_blocks[0], source_ref, "rst").unwrap().text.contains(
      "body",
    ),
  )
  assert_true(
    rst_semantic_raw_block(plain_blocks[0], source_ref, "rst") is None,
  )
  assert_eq(rst_semantic_quote_text(plain_blocks[0], "rst"), "plain")
  assert_eq(text_markup_display_label(""), "")
}

///|
test "RST malformed unclosed directive content degrades under control" {
  let parsed = @dmark.parse_rst_document(
    ".. code-block:: python\n\n   print('visible')\n  malformed",
  )
  assert_true(parsed.blocks.length() > 0)
  assert_true(parsed.blocks.any(block => block.text.contains("visible")))
}

///|
test "RST footnote citation and role content remain readable" {
  let parsed = @dmark.parse_rst_document(
    "Text [1]_ [paper]_ and :code:`value`.\n\n.. [1] Footnote body\n.. [paper] Citation body",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Footnote body"))
  assert_true(joined.contains("Citation body"))
  assert_true(joined.contains("value"))
}

///|
test "RST field and definition lists retain labels and values" {
  let parsed = @dmark.parse_rst_document(
    ":Author: Ada\n:Version: 1\n\nTerm\n  Definition body",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Author"))
  assert_true(joined.contains("Ada"))
  assert_true(joined.contains("Definition body"))
}

///|
test "RST simple table retains headers and cells" {
  let parsed = @dmark.parse_rst_document(
    "=====  =====\nName   Value\n=====  =====\nA      1\n=====  =====",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Name"))
  assert_true(joined.contains("Value"))
  assert_true(joined.contains("A"))
}

///|
test "RST image and code directives retain safe references" {
  let parsed = @dmark.parse_rst_document(
    ".. image:: local.png\n   :alt: Local image\n\n.. code-block:: text\n\n   raw body",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("local.png"))
  assert_true(joined.contains("raw body"))
}

///|
test "RST parser exports local image directives as sidecar assets" {
  let result = (rst_parser().parse)(
    @input.input_from_text_with_format(
      ".. image:: local.png\n   :alt: Local image",
      "image.rst",
      Some(Rst),
    ),
    @parser.new_parse_context(Rst),
  ).unwrap()
  let images = result.document.unwrap().blocks.filter(block => {
    block.kind == Image
  })
  assert_eq(images.length(), 1)
  let image = images[0]
  assert_true(image.attrs.get("path") == Some("assets/rst-local.png"))
  assert_true(image.attrs.get("source_path") == Some("local.png"))
  assert_true(image.attrs.get("alt") == Some("Local image"))
}

///|
test "RST nested lists preserve ordered and bullet items" {
  let parsed = @dmark.parse_rst_document("1. one\n\n   - nested\n\n2. two")
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("one"))
  assert_true(joined.contains("nested"))
  assert_true(joined.contains("two"))
}

///|
test "RST include remains a reference and does not read files" {
  let parsed = @dmark.parse_rst_document(".. include:: ../../secret.rst")
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("../../secret.rst"))
}

///|
test "RST large document uses compact events with complete structure metrics" {
  let out = StringBuilder::new()
  let paragraph = "Paragraph with `link <https://example.test>`_ and stable repeated payload."
  for i in 0..<6000 {
    out.write_string("Section ")
    out.write_string(i.to_string())
    out.write_string("\n=========\n\n")
    out.write_string(paragraph)
    out.write_string(
      "\n\n- `first item <https://example.test>`_\n- second item\n\n",
    )
    out.write_string(".. note::\n   retained note body\n\n")
    out.write_string(".. code-block:: text\n\n   literal body\n\n")
  }
  out.write_string(".. include:: local-chapter.rst\n\n")
  out.write_string(
    "Footnote reference [1]_.\n\n.. [1] Compact footnote body.\n\n",
  )
  out.write_string("+------+-------+\n")
  out.write_string("| Name | Value |\n")
  out.write_string("+======+=======+\n")
  out.write_string("| A    | 1     |\n")
  out.write_string("+------+-------+\n")
  let text = out.to_string()
  assert_true(text.length() >= 1_048_576)
  let context = @parser.new_parse_context(Rst)
  let result = (rst_parser().parse)(
    @input.input_from_text_with_format(text, "large-compact.rst", Some(Rst)),
    context,
  ).unwrap()
  let events = result.event_stream.unwrap()
  assert_true(events.length() > 20000)
  assert_true(
    result.diagnostics.metrics.get("text_markup_compact_events") == Some("true"),
  )
  assert_true(result.diagnostics.metrics.get("heading_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("list_item_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("code_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("blockquote_count") != Some("0"))
  assert_true(events.any(event => event.source_ref is Some(_)))
}
