///|
test "docx marker spacing inlines do not inherit note ref metadata" {
  let note_ref = @core.empty_source_ref()
  let note_inline = @core.inline_with_attr(
    @core.inline_with_attr(
      @core.inline_with_attr(
        @core.inline_with_attr(
          @core.inline_with_attr(
            @core.make_inline_text("[^1]", source_ref=note_ref),
            "annotation_role",
            "note_ref",
          ),
          "annotation_kind",
          "footnote",
        ),
        "annotation_id",
        "1",
      ),
      "annotation_marker",
      "[^1]",
    ),
    "render_literal",
    "true",
  )
  let block = @core.block_with_rich_inlines(
    @core.make_block(Paragraph, ""),
    Some([
      @core.make_inline_text("Body "),
      note_inline,
      @core.make_inline_text("tail"),
    ]),
  )
  let normalized = normalize_docx_marker_rich_inlines(
    block.rich_inlines.unwrap_or([]),
  )
  assert_eq(normalized.length(), 4)
  let spacing = normalized[2]
  assert_true(spacing.text == " ")
  assert_true(spacing.attrs.length() == 0)
}

///|
test "DOCX parser capability and malformed package fail closed with full metrics" {
  let capability = docx_parser_capability()
  assert_true(capability.requires_random_access)
  assert_true(capability.supports_document_ir)
  assert_true(capability.produces_tables)
  assert_eq(docx_parser().name, "docx_parser")
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([1, 2, 3].map(Int::to_byte)),
    "broken.docx",
    Some(Docx),
  )
  let result = (docx_parser().parse)(source, @parser.new_parse_context(Docx)).unwrap()
  assert_true(result.document is Some(_))
  assert_true(result.document.unwrap().blocks.length() == 0)
  assert_true(result.diagnostics.errors.length() == 1)
  assert_true(
    result.diagnostics.degraded_features.contains("docx_parse_failure"),
  )
  assert_true(result.diagnostics.fallback_trace.length() == 1)
  assert_true(result.diagnostics.metrics.get("block_count") == Some("0"))
  assert_true(result.diagnostics.metrics.get("error_count") == Some("1"))
  assert_true(
    result.diagnostics.metrics.get("office_document_kind") == Some("docx"),
  )
  assert_true(result.diagnostics.pass_trace.contains("parse:docx_parser"))
}

///|
test "DOCX parser lowers repository complex image list and code fixtures" {
  let fixtures = [
    "samples/fixtures/contracts/docx/docx_textbox_basic.docx", "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
    "samples/fixtures/contracts/docx/docx_nested_lists_mixed.docx", "samples/fixtures/contracts/docx/docx_codeblock_basic.docx",
  ]
  for path in fixtures {
    let result = (docx_parser().parse)(
      @input.input_from_path(path),
      @parser.new_parse_context(Docx),
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    assert_true(result.document.unwrap().blocks.length() > 0)
    assert_true(result.diagnostics.metrics.get("block_count") != Some("0"))
  }
}

///|
test "DOCX parser covers headings quotes line breaks and baseline package" {
  let fixtures = [
    "samples/fixtures/contracts/docx/docx_blockquote_basic.docx", "samples/fixtures/contracts/docx/docx_heading_levels.docx",
    "samples/fixtures/contracts/docx/docx_paragraph_linebreak.docx", "samples/fixtures/contracts/docx/golden.docx",
  ]
  let mut heading_count = 0
  let mut quote_count = 0
  for path in fixtures {
    let result = (docx_parser().parse)(
      @input.input_from_path(path),
      @parser.new_parse_context(Docx),
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    for block in result.document.unwrap().blocks {
      if block.kind == Heading {
        heading_count += 1
      }
      if block.kind == BlockQuote {
        quote_count += 1
      }
    }
  }
  assert_true(heading_count > 0)
  assert_true(quote_count > 0)
}

///|
test "DOCX full contract corpus covers combined accurate feature lowering" {
  let fixtures = [
    "docx_blockquote_basic.docx", "docx_codeblock_basic.docx", "docx_heading_levels.docx",
    "docx_image_alt_title.docx", "docx_image_alt_title_basic.docx", "docx_multiple_notes_order.docx",
    "docx_nested_lists_mixed.docx", "docx_note_comment_rich_content_boundary.docx",
    "docx_paragraph_linebreak.docx", "docx_table_merged_cells_boundary.docx", "docx_textbox_basic.docx",
    "golden.docx",
  ]
  let context = @parser.parse_context_with_execution_profiles(
    @parser.parse_context_with_product_modes(
      @parser.new_parse_context(Docx),
      Accurate,
      Markdown,
    ),
    Standard,
    AccurateSemantic,
    NotesAppendixFirst,
    @product.make_accurate_feature_profile([
      DocxTextboxInline,
      DocxAlternateContentRestore,
      DocxNotesAppendix,
    ]),
  )
  let mut total_blocks = 0
  for fixture in fixtures {
    let result = (docx_parser().parse)(
      @input.input_from_path("samples/fixtures/contracts/docx/" + fixture),
      context,
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    total_blocks += result.document.unwrap().blocks.length()
  }
  assert_true(total_blocks > 30)
}

///|
test "DOCX parser lowers repository accurate note table and textbox contracts" {
  let fixtures = [
    "samples/fixtures/contracts/docx/docx_multiple_notes_order.docx", "samples/fixtures/contracts/docx/docx_note_comment_rich_content_boundary.docx",
    "samples/fixtures/contracts/docx/docx_table_merged_cells_boundary.docx", "samples/fixtures/contracts/docx/docx_textbox_basic.docx",
  ]
  let context = @parser.parse_context_with_execution_profiles(
    @parser.parse_context_with_product_modes(
      @parser.new_parse_context(Docx),
      Accurate,
      Markdown,
    ),
    Standard,
    AccurateSemantic,
    NotesAppendixFirst,
    @product.make_accurate_feature_profile([
      DocxTextboxInline,
      DocxAlternateContentRestore,
      DocxNotesAppendix,
    ]),
  )
  for path in fixtures {
    let result = (docx_parser().parse)(@input.input_from_path(path), context).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    assert_true(result.document.unwrap().blocks.length() > 0)
    assert_true(result.diagnostics.metrics.get("block_count") != Some("0"))
    assert_true(
      result.diagnostics.metrics.get("office_document_kind") == Some("docx"),
    )
  }
}

///|
test "DOCX parser extracts repository image contract assets" {
  let result = (docx_parser().parse)(
    @input.input_from_path(
      "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
    ),
    @parser.new_parse_context(Docx),
  ).unwrap()
  assert_eq(result.diagnostics.errors.length(), 0)
  assert_true(result.document.unwrap().assets.length() > 0)
}

///|
test "DOCX parser rejects lazy media references over the request asset budget" {
  let context = @parser.parse_context_with_asset_limits(
    @parser.new_parse_context(Docx),
    1L,
    1L,
  )
  let result = (docx_parser().parse)(
    @input.input_from_path(
      "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
    ),
    context,
  ).unwrap()
  assert_eq(result.document.unwrap().assets.length(), 0)
  assert_true(
    result.diagnostics.degraded_features.contains("asset_payload_limit_skip"),
  )
}

///|
test "DOCX advanced synthetic contract covers auxiliary parts rich objects and accurate lowering" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/docx/docx_advanced_synthetic.docx",
  )
  let balanced = (docx_parser().parse)(source, @parser.new_parse_context(Docx)).unwrap()
  let balanced_document = balanced.document.unwrap()
  assert_true(balanced.diagnostics.errors.length() == 0)
  assert_true(balanced_document.blocks.any(block => block.kind == Heading))
  assert_true(balanced_document.blocks.any(block => block.kind == Table))
  assert_true(balanced_document.blocks.any(block => block.kind == List))
  assert_true(balanced_document.blocks.any(block => block.kind == BlockQuote))
  assert_true(balanced_document.blocks.any(block => block.kind == Code))
  assert_true(
    balanced_document.blocks.any(block => {
      block.text.contains("Content control text")
    }),
  )
  assert_true(balanced_document.assets.length() == 1)

  let context = @parser.parse_context_with_execution_profiles(
    @parser.parse_context_with_product_modes(
      @parser.new_parse_context(Docx),
      Accurate,
      Markdown,
    ),
    Standard,
    AccurateSemantic,
    NotesAppendixFirst,
    @product.make_accurate_feature_profile([
      DocxTextboxInline,
      DocxAlternateContentRestore,
      DocxNotesAppendix,
    ]),
  )
  let accurate = (docx_parser().parse)(source, context).unwrap()
  let blocks = accurate.document.unwrap().blocks
  assert_true(accurate.diagnostics.errors.length() == 0)
  assert_true(blocks.any(block => block.text.contains("Textbox content")))
  assert_true(blocks.any(block => block.text.contains("Footnote body")))
  assert_true(blocks.any(block => block.text.contains("Endnote body")))
  assert_true(blocks.any(block => block.text.contains("Review comment")))
  assert_true(blocks.any(block => block.text.contains("Header text")))
  assert_true(blocks.any(block => block.text.contains("Footer text")))
}

///|
test "DOCX note and comment helpers preserve rich inline content" {
  let source_ref = @core.empty_source_ref()
  let image = @core.make_inline_image(
    "diagram",
    "assets/diagram.png",
    title=Some("Diagram"),
    source_ref~,
  )
  let link = @core.make_inline_link("docs", "https://example.test", source_ref~)
  let inlines = [
    @core.make_inline_text("before ", source_ref~),
    image,
    link,
    @core.make_inline_line_break(source_ref~),
    @core.make_inline_code("code", source_ref~),
  ]
  assert_eq(docx_prefixed_rich_inlines("", inlines).length(), inlines.length())
  let prefixed = docx_prefixed_rich_inlines("Note: ", inlines)
  assert_eq(prefixed.length(), inlines.length() + 1)
  let block = @core.block_with_rich_inlines(
    @core.make_block(Paragraph, "", source_ref~),
    Some(inlines),
  )
  let images = docx_collect_comment_inline_images([block])
  assert_eq(images.length(), 1)
  assert_true(images[0].attrs.get("path") == Some("assets/diagram.png"))
  assert_true(images[0].attrs.get("title") == Some("Diagram"))
  let cleaned = docx_comment_block_without_inline_images(block)
  assert_true(cleaned.text.contains("before docs\ncode"))
  assert_true(
    cleaned.rich_inlines.unwrap_or([]).all(inline => inline.kind != Image),
  )
  assert_true(
    docx_comment_block_without_inline_images(
      @core.make_block(Paragraph, "plain"),
    ).text ==
    "plain",
  )
  assert_eq(docx_comment_inline_text_fragment(image), "")
  assert_eq(docx_comment_inline_text_fragment(link), "docs")
  assert_eq(
    docx_comment_inline_text_fragment(@core.make_inline_line_break(source_ref~)),
    "\n",
  )
  assert_eq(docx_comment_cleanup_spacing("a \n b"), "a\nb")

  let labels : Map[String, String] = Map([
    ("ten", "10"),
    ("two", "2"),
    ("appendix", "A"),
  ])
  let sorted_labels = docx_note_ids_sorted_by_label(labels)
  assert_eq(sorted_labels.length(), 3)
  assert_eq(sorted_labels[0], "two")
  assert_eq(sorted_labels[1], "ten")
  assert_eq(sorted_labels[2], "appendix")
  assert_eq(docx_sortable_note_label("bad"), "1:bad")
  assert_eq(docx_zero_pad_int(7, 3), "007")
  assert_eq(docx_zero_pad_int(123, 2), "123")

  let multiline = @core.block_with_rich_inlines(
    @core.make_block(Paragraph, ""),
    Some([@core.make_inline_text("first\r\nsecond\nthird", source_ref~)]),
  )
  let expanded = docx_note_block_with_inline_breaks(multiline)
  let expanded_inlines = expanded.rich_inlines.unwrap_or([])
  assert_eq(expanded_inlines.length(), 5)
  assert_eq(
    expanded_inlines.filter(inline => inline.kind == LineBreak).length(),
    2,
  )
  assert_true(
    docx_note_block_with_inline_breaks(@core.make_block(Paragraph, "plain")).rich_inlines
    is None,
  )
}

///|
test "DOCX note inline boundary helpers trim breaks and preserve content" {
  let source_ref = @core.empty_source_ref()
  let br = @core.make_inline_line_break(source_ref~)
  let text = @core.make_inline_text("value", source_ref~)
  assert_true(!docx_all_rich_inlines_are_breaks([]))
  assert_true(docx_all_rich_inlines_are_breaks([br, br]))
  assert_true(!docx_all_rich_inlines_are_breaks([br, text]))
  assert_true(docx_first_non_break_inline_index([br, text, br]) == Some(1))
  assert_true(docx_last_non_break_inline_index([br, text, br]) == Some(1))
  assert_true(docx_first_non_break_inline_index([br]) is None)
  assert_true(docx_last_non_break_inline_index([br]) is None)
  let boundary = docx_trim_boundary_line_breaks([br, text, br])
  assert_true(boundary.length() == 1 && boundary[0].text == "value")
  assert_true(docx_trim_boundary_line_breaks([br, br]).length() == 0)
  let leading = docx_trim_leading_line_breaks([br, text, br])
  assert_true(leading.length() == 2)
  assert_true(leading[0].text == "value")
  assert_true(leading[1].kind == LineBreak)
  assert_true(docx_trim_leading_line_breaks([br]).length() == 0)
  assert_true(
    docx_block_has_rich_inlines(
      @core.block_with_rich_inlines(
        @core.make_block(Paragraph, ""),
        Some([text]),
      ),
    ),
  )
  assert_true(
    !docx_block_has_rich_inlines(@core.make_block(Paragraph, "plain")),
  )
  assert_eq(docx_sortable_note_label(""), "1:")
  assert_eq(docx_sortable_note_label(" 12 "), "0:000000000012")
}

///|
test "DOCX lowering policy helpers cover media styles markers unicode and tables" {
  assert_eq(docx_media_path_ext("word/media/image.PNG"), "png")
  assert_eq(docx_media_path_ext("word/media/noext"), "bin")
  assert_eq(docx_media_path_ext("word/media/trailing."), "bin")
  assert_true(docx_media_content_type_ext(Some("image/png")) == Some("png"))
  assert_true(docx_media_content_type_ext(Some("image/jpeg")) == Some("jpg"))
  assert_true(docx_media_content_type_ext(Some("image/gif")) == Some("gif"))
  assert_true(docx_media_content_type_ext(Some("image/webp")) == Some("webp"))
  assert_true(docx_media_content_type_ext(Some("image/svg+xml")) == Some("svg"))
  assert_true(docx_media_content_type_ext(Some("image/tiff")) == Some("tiff"))
  assert_true(
    docx_media_content_type_ext(Some("application/octet-stream")) is None,
  )
  assert_true(docx_media_content_type_ext(None) is None)
  assert_eq(docx_two_digits(0), "00")
  assert_eq(docx_two_digits(9), "09")
  assert_eq(docx_two_digits(12), "12")
  assert_true(normalize_docx_optional_text(None) is None)
  assert_true(normalize_docx_optional_text(Some("  ")) is None)
  assert_true(normalize_docx_optional_text(Some(" title ")) == Some("title"))
  assert_eq(docx_note_marker_label("7", "footnote"), "[^7]")
  assert_eq(docx_note_marker_label("7", "endnote"), "[^e7]")
  assert_true(docx_heading_level_from_label("Heading 1") == Some(1))
  assert_true(docx_heading_level_from_label("heading_6") == Some(6))
  assert_true(docx_heading_level_from_label("Title") is None)
  assert_true(docx_heading_level_from_label("body") is None)
  assert_eq(docx_numbering_level_index("0"), 0)
  assert_eq(docx_numbering_level_index("4"), 4)
  assert_eq(docx_numbering_level_index("bad"), 0)
  assert_true(docx_style_labels_match("Quote", Some("Body Text"), ["quote"]))
  assert_true(!docx_style_labels_match("Normal", Some("Body Text"), ["quote"]))
  assert_eq(docx_list_item_text("  item  "), "item")
  assert_true(parse_docx_hex_codepoint(Some("0041")) == Some(65))
  assert_true(parse_docx_hex_codepoint(Some("110000")) == Some(1114112))
  assert_true(parse_docx_hex_codepoint(Some("xyz")) is None)
  assert_true(parse_docx_hex_codepoint(None) is None)
  assert_eq(docx_comment_author_prefix(None), "")
  assert_eq(docx_comment_author_prefix(Some("  ")), "")
  assert_eq(docx_comment_author_prefix(Some("Ada")), "Ada: ")
  assert_eq(docx_part_body_slot_label_from_text("evenHeader"), "Even")
  assert_eq(docx_part_body_slot_label_from_text("firstFooter"), "First")
  assert_eq(docx_part_body_slot_label_from_text("custom"), "Default")
  assert_eq(normalize_docx_ref_marker_spacing("a[^1]b"), "a[^1]b")
  assert_eq(normalize_docx_ref_marker_spacing("a [^1] b"), "a[^1]  b")
  assert_eq(normalize_docx_ref_marker_spacing("a[comment-2]."), "a[comment-2].")
  assert_true(docx_trim_trailing_spaces("abc   ") == ("abc", true))
  assert_true(docx_trim_trailing_spaces("abc") == ("abc", false))
  assert_true(docx_inline_text_ends_with_space("a "))
  assert_true(!docx_inline_text_ends_with_space("a"))
  assert_true(docx_text_requires_leading_space("word"))
  assert_true(!docx_text_requires_leading_space(" punctuation"))
  for ch in [' ', '\t', '\n', '\r'] {
    assert_true(docx_marker_space_char(ch))
  }
  assert_true(!docx_marker_space_char('x'))
  assert_true(docx_chars_has_literal_at("xx[^1]".to_array(), 2, "[^"))
  assert_true(docx_marker_end("[^12] x".to_array(), 0) == Some(4))
  assert_true(docx_marker_end("plain".to_array(), 0) is None)
  assert_true(docx_marker_needs_following_space('x'))
  assert_true(!docx_marker_needs_following_space('.'))
  assert_eq(docx_normalize_style_label(" Heading-1_Name "), "heading1name")
  assert_true(docx_parse_nonnegative_int("0") == Some(0))
  assert_true(docx_parse_nonnegative_int("42") == Some(42))
  assert_true(docx_parse_nonnegative_int("-1") is None)
  assert_true(docx_parse_nonnegative_int("bad") is None)

  let visible = @core.make_block(Table, "table")
  let row = @core.make_block(TableRow, "")
  row.children.push(@core.make_block(TableCell, "value"))
  visible.children.push(row)
  assert_true(docx_rendered_table_has_visible_cells(visible))
  assert_true(
    !docx_rendered_table_has_visible_cells(@core.make_block(Table, "table")),
  )
}
