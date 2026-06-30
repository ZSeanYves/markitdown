///|
test "docx contract spec matches the active runtime parser" {
  let spec = @formats_root.docx_parser_contract_spec()
  let parser = @fdocx.docx_parser()
  assert_contract_spec_matches_parser(spec, parser)
  assert_true(
    @shared.docx_contract_mode() == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    @shared.docx_contract_granularity() ==
    @parser.StreamingGranularity::DocxBlock,
  )
  assert_eq(@shared.docx_contract_ir_input_kind(), "document")
  assert_true(
    @shared.docx_contract_foundations() ==
    ["format_readers/ooxml/docx", "format_readers/ooxml/package"],
  )
  assert_contains_all(@shared.docx_contract_guardrails().join("\n"), [
    "DOCX is supported on the main CLI", "PackageSinglePass / IRInput::Document / docx_block",
    "format_readers/ooxml/package + format_readers/ooxml/docx foundation", "document rendering stays in the shared renderer layer",
    "assets stay output-boundary only",
  ])
}

///|
test "docx parser is runtime-owned and avoids retired boundaries" {
  let parser = @fdocx.docx_parser()
  let context = @parser.new_parse_context(@input.DetectedFormat::Docx)
  let result = match
    (parser.parse)(
      @input.input_from_path(
        "samples/main_process/docx/markdown/docx_multiple_notes_order.docx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(msg) => fail("docx parser should return parse result: " + msg)
  }
  let spec = @formats_root.docx_parser_contract_spec()
  assert_parse_result_matches_contract_spec(result, spec)
  assert_true(result.document is Some(_))
  assert_true(result.event_stream is None)
  assert_true(result.block_stream is None)
  let document = result.document.unwrap_or_else(fn() {
    abort("missing docx document")
  })
  assert_true(document.blocks.length() > 0)

  let registry_source = read_utf8_text("formats/registry.mbt")
  let formats_pkg = read_utf8_text("formats/moon.pkg")
  let office_pkg = read_utf8_text("format_readers/ooxml/shared/moon.pkg")
  let office_impl = read_package_mbt_sources("format_readers/ooxml/shared")
  let docx_impl = read_package_mbt_sources("formats/docx")

  assert_true(registry_source.contains("DetectedFormat::Docx"))
  assert_true(registry_source.contains("docx_parser()"))
  assert_true(!registry_source.contains("docx_parser_contract()"))
  assert_contains_none(formats_pkg, [
    "ZSeanYves/markitdown/convert/docx", "ZSeanYves/markitdown/convert/docx_v2",
    "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_pkg, [
    "ZSeanYves/markitdown/convert/", "ZSeanYves/markitdown/unmigrated/",
  ])
  assert_contains_none(office_impl, [
    "ZSeanYves/markitdown/convert/", "ZSeanYves/markitdown/unmigrated/", "@legacy",
  ])
  assert_contains_none(docx_impl, [
    "convert/docx", "convert/docx_v2", "@legacy", "emitter_markdown", "legacy_dispatcher",
  ])
  assert_diagnostics_lists_contain_none(result.diagnostics, [
    "docx_raw_fallback", "docx_legacy_fallback", "convert_docx_v2_used",
  ])
}

///|
test "docx parser preserves note ordering code blocks and comment spacing" {
  let notes = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/markdown/docx_multiple_notes_order.docx",
    ),
    @input.DetectedFormat::Docx,
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
  assert_exact_count(note_rendered.content, "[comment 1]", 1)
  assert_exact_count(note_rendered.content, "[^e1]", 2)
  match note_rendered.content.split_once("[^1]: Second footnote body.") {
    Some((_, tail)) => assert_true(tail.contains("[^2]: First footnote body."))
    None => fail("docx note definition order should contain [^1] before [^2]")
  }

  let code = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/markdown/docx_codeblock_basic.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let code_document = code.document.unwrap_or_else(fn() {
    abort("missing code document")
  })
  assert_true(code_document.blocks.length() == 1)
  assert_true(code_document.blocks[0].kind == @core.BlockKind::Code)
  assert_eq(code_document.blocks[0].text, "let x = 1\nprintln(x)")

  let boundary = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/markdown/docx_note_comment_rich_content_boundary.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let boundary_document = boundary.document.unwrap_or_else(fn() {
    abort("missing note-comment boundary document")
  })
  let boundary_rendered = (@render.markdown_renderer().render)(
    boundary_document,
    @render.make_render_context(false),
  )
  assert_true(boundary_rendered.content.contains("Body[^1]  [comment 1]"))
  assert_contains_none(boundary_rendered.content, [
    "[^1][^1]", "[^e1][^e1]", "[comment 1][comment 1]",
  ])
  assert_exact_count(boundary_rendered.content, "[comment 1]", 1)
  assert_exact_count(boundary_rendered.content, "[^1]", 2)
}

///|
test "docx accurate fidelity inlines anchored textboxes into body order" {
  let registry = @formats_root.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Docx),
    @product.FidelityMode::Accurate,
    @product.OutputMode::Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/main_process/docx/markdown/docx_textbox_basic.docx",
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
      fidelity_mode=@product.FidelityMode::Accurate,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  assert_true(
    rendered.content.contains("Body before.\n\nText box body.\n\nBody after."),
  )
  assert_true(!rendered.content.contains("## Text Boxes"))
}

///|
test "docx accurate fidelity restores alternate-content textbox text into Complex01 body" {
  let registry = @formats_root.builtin_registry()
  let balanced_context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Docx),
    @product.FidelityMode::Balanced,
    @product.OutputMode::Markdown,
  )
  let accurate_context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Docx),
    @product.FidelityMode::Accurate,
    @product.OutputMode::Markdown,
  )
  let path = "markitdown-quality-lab/external_quality/docx/openxml-sdk/Complex01.docx"
  let balanced = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(path),
      balanced_context,
    ) {
    Ok(value) => value
    Err(err) => fail("balanced Complex01 docx parse failed: " + err)
  }
  let accurate = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(path),
      accurate_context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate Complex01 docx parse failed: " + err)
  }
  let balanced_rendered = (@render.markdown_renderer().render)(
    balanced.document.unwrap_or_else(fn() {
      abort("missing balanced Complex01 document")
    }),
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Balanced,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  let accurate_rendered = (@render.markdown_renderer().render)(
    accurate.document.unwrap_or_else(fn() {
      abort("missing accurate Complex01 document")
    }),
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Accurate,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  assert_true(
    !balanced_rendered.content.contains(
      "Eric White<br>This is my interesting abstract.",
    ),
  )
  assert_true(
    accurate_rendered.content.contains(
      "Eric White<br>This is my interesting abstract.",
    ),
  )
  assert_true(!accurate_rendered.content.contains("## Text Boxes"))
}

///|
test "docx parser keeps diagnostics source refs and renderer boundary contract locked" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/assets/docx_image_alt_title.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let spec = @formats_root.docx_parser_contract_spec()
  assert_parse_result_matches_contract_spec(parsed, spec)
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing docx document")
  })
  assert_true(document.blocks.length() > 0)
  let image = document.blocks[0]
  assert_true(image.kind == @core.BlockKind::Image)
  let image_ref = image.source_ref.unwrap_or(@core.empty_source_ref())
  assert_true(image_ref.format == Some("docx"))
  assert_true(image_ref.container_path is Some(_))
  assert_true(image_ref.entry_path is Some(_))
  assert_true(image_ref.inner_path is Some(_))
  assert_true(image_ref.extra.get("part_name") == Some("word/document.xml"))
  assert_true(image_ref.extra.get("paragraph_index") is Some(_))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_true(
    rendered.content.contains("![Figure alt text](assets/image01.png)"),
  )
  assert_true(rendered.content.contains("*Figure title text*"))

  let headings = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/docx/markdown/docx_heading_levels.docx",
    ),
    @input.DetectedFormat::Docx,
  )
  let heading_document = headings.document.unwrap_or_else(fn() {
    abort("missing heading document")
  })
  assert_true(heading_document.blocks.length() > 0)
  let heading = heading_document.blocks[0]
  assert_true(heading.kind == @core.BlockKind::Heading)
  assert_true(!heading.text.contains("# "))
  let heading_rendered = (@render.markdown_renderer().render)(
    heading_document,
    @render.make_render_context(false),
  )
  assert_true(heading_rendered.content.contains("# Heading Level 1"))
}
