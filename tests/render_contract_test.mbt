///|
test "renderer only consumes core ir and accepts irinput via builder" {
  let builder = @pipeline.default_ir_builder()
  let document = (builder.build)(
    @core.IRInput::BlockStream([
      @core.make_block(
        @core.BlockKind::Heading,
        "Title",
        source_ref=@core.empty_source_ref(),
      ),
      @core.make_block(
        @core.BlockKind::Paragraph,
        "Body",
        source_ref=@core.empty_source_ref(),
      ),
    ]),
  )
  let renderer = @render.markdown_renderer()
  let rendered = (renderer.render)(document, @render.make_render_context(false))
  assert_eq(rendered.content, "# Title\n\nBody")
  assert_true(
    rendered.diagnostics.metrics.get("renderer_name") ==
    Some("MarkdownRenderer"),
  )
}

///|
test "renderer does not over-escape hyphen inside heading text" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "a-first.md",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "1")
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::BlockStream([heading]),
  )
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "# a-first.md")
}

///|
test "renderer keeps plain exclamation while preserving inline link image and markdown escapes" {
  let paragraph = @core.block_with_rich_inlines(
    @core.make_block(
      @core.BlockKind::Paragraph,
      "unused",
      source_ref=@core.empty_source_ref(),
    ),
    Some([
      @core.make_inline_text("Hello! See "),
      @core.make_inline_link("spec", "https://example.com/spec"),
      @core.make_inline_text(" and "),
      @core.make_inline_image("diagram", "https://example.com/diagram.png"),
      @core.make_inline_text(" with [literal] <tag>"),
    ]),
  )
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([paragraph]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "Hello! See [spec](https://example.com/spec) and ![diagram](https://example.com/diagram.png) with \\[literal\\] \\<tag\\>",
  )
  assert_true(!rendered.content.contains("\\!"))
}

///|
test "renderer keeps declared table width when header row is narrower than body rows" {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=@core.empty_source_ref(),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", "3")

  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Merged Head",
      source_ref=@core.empty_source_ref(),
    ),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Right",
      source_ref=@core.empty_source_ref(),
    ),
  )

  let row = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "A",
      source_ref=@core.empty_source_ref(),
    ),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "B",
      source_ref=@core.empty_source_ref(),
    ),
  )
  row.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "C",
      source_ref=@core.empty_source_ref(),
    ),
  )

  table.children.push(header)
  table.children.push(row)

  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([table]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "| Merged Head | Right |\n| --- | --- |\n| A | B | C |",
  )
}

///|
test "renderer upgrades span-aware accurate tables to html table output" {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=@core.empty_source_ref(),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", "3")
  table.attrs.set("render_html_table", "true")

  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  let merged = @core.make_block(
    @core.BlockKind::TableCell,
    "Merged Range",
    source_ref=@core.empty_source_ref(),
  )
  merged.attrs.set("colspan", "3")
  header.children.push(merged)

  let body = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.empty_source_ref(),
  )
  body.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Tail",
      source_ref=@core.empty_source_ref(),
    ),
  )

  table.children.push(header)
  table.children.push(body)

  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([table]),
    @render.make_render_context(false),
  )
  assert_eq(
    rendered.content,
    "<table>\n<tr><th colspan=\"3\">Merged Range</th></tr>\n<tr><td>Tail</td></tr>\n</table>",
  )
}

///|
test "generic block event stream preserves inline attrs for renderer contracts" {
  let source_ref = @core.empty_source_ref()
  let block_ref = @core.source_ref_with_extra(
    source_ref, "ir_event_encoding", "generic_block",
  )
  block_ref.extra.set("ir_block_kind", "paragraph")
  let inline_ref = @core.source_ref_with_extra(
    source_ref, "ir_event_encoding", "generic_block",
  )
  inline_ref.extra.set("ir_inline_kind", "text")
  let marker_ref = @core.source_ref_with_extra(
    source_ref, "ir_event_encoding", "generic_block",
  )
  marker_ref.extra.set("ir_inline_kind", "text")
  marker_ref.extra.set("ir_inline_attr_annotation_role", "note_ref")
  marker_ref.extra.set("ir_inline_attr_annotation_kind", "footnote")
  marker_ref.extra.set("ir_inline_attr_annotation_marker", "[^1]")
  marker_ref.extra.set("ir_inline_attr_render_literal", "true")
  let events : Array[@core.CoreEvent] = [
    {
      kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      text: "",
      source_ref: Some(block_ref),
    },
    { kind: @core.EventKind::Text, text: "Body", source_ref: Some(inline_ref) },
    { kind: @core.EventKind::Text, text: "[^1]", source_ref: Some(marker_ref) },
    {
      kind: @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
      text: "",
      source_ref: Some(block_ref),
    },
  ]
  let document = (@pipeline.default_ir_builder().build)(
    @core.IRInput::EventStream(events),
  )
  let inlines = document.blocks[0].rich_inlines.unwrap_or([])
  assert_eq(inlines.length(), 2)
  assert_true(inlines[1].attrs.get("annotation_role") == Some("note_ref"))
  assert_true(inlines[1].attrs.get("annotation_marker") == Some("[^1]"))
  assert_true(inlines[1].attrs.get("render_literal") == Some("true"))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "Body[^1]")
}

///|
test "renderer keeps plain exclamation in literal markdown lines" {
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    "paragraph!\n# heading!\n1. ordered!",
    source_ref=@core.empty_source_ref(),
  )
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([paragraph]),
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "paragraph! \\# heading! 1\\. ordered!")
  assert_true(!rendered.content.contains("\\!"))
}

///|
test "debug mode emits diagnostics parser metadata and pass trace" {
  let result = convert_memory_text(
    "Alpha\n\nBeta",
    "debug.txt",
    @input.DetectedFormat::Txt,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::DebugJson,
  )
  assert_true(result.content.contains("\"diagnostics\""))
  assert_true(result.content.contains("\"parser_name\""))
  assert_true(result.content.contains("\"fallback_trace\""))
  assert_true(result.content.contains("\"pass_trace\""))
  assert_true(result.content.contains("\"source_ref\""))
  assert_true(result.diagnostics.convert_mode == Some("balanced"))
  assert_true(result.diagnostics.output_mode == Some("debug"))
  assert_true(
    result.diagnostics.metrics.get("renderer_name") == Some("DebugJsonRenderer"),
  )
}

///|
test "rag mode emits chunk json metadata source map and diagnostics" {
  let result = convert_memory_text(
    "# Alpha\n\nBody one.\n\nBody two.\n",
    "rag.md",
    @input.DetectedFormat::Markdown,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  assert_true(result.content.contains("\"output_format\": \"rag_json\""))
  assert_true(result.content.contains("\"chunks\""))
  assert_true(result.content.contains("\"heading_path\": [\"Alpha\"]"))
  assert_true(result.content.contains("\"source_map\":"))
  assert_true(result.chunks is Some(_))
  let chunks = result.chunks.unwrap_or([])
  assert_true(chunks.length() >= 1)
  assert_true(chunks[0].metadata.get("document_format") is Some(_))
  assert_true(
    result.diagnostics.metrics.get("renderer_name") == Some("RagJsonRenderer"),
  )
  assert_true(
    result.content.contains("\"source_map\": null") ||
    result.source_map is Some(_),
  )
  assert_true(result.debug_ir is None)
}

///|
test "rag chunking keeps text overlap and table code chunk splitting" {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("demo.txt"),
    Some("txt"),
    Some(1),
    Some(3),
  )
  let paragraph_a = @core.make_block(
    @core.BlockKind::Paragraph,
    "Alpha body text.",
    source_ref~,
  )
  let paragraph_b = @core.make_block(
    @core.BlockKind::Paragraph,
    "Beta body text.",
    source_ref~,
  )
  let table = @core.block_with_children(
    @core.make_block(
      @core.BlockKind::Table,
      "",
      source_ref=@core.source_ref_with_cell_range(
        @core.empty_source_ref(),
        Some("book.xlsx"),
        Some("xlsx"),
        Some("A1:B4"),
      ),
    ),
    [
      @core.block_with_children(
        @core.make_block(@core.BlockKind::TableRow, ""),
        [
          @core.make_block(@core.BlockKind::TableCell, "H1"),
          @core.make_block(@core.BlockKind::TableCell, "H2"),
        ],
      ),
      @core.block_with_children(
        @core.make_block(@core.BlockKind::TableRow, ""),
        [
          @core.make_block(@core.BlockKind::TableCell, "R1"),
          @core.make_block(@core.BlockKind::TableCell, "V1"),
        ],
      ),
      @core.block_with_children(
        @core.make_block(@core.BlockKind::TableRow, ""),
        [
          @core.make_block(@core.BlockKind::TableCell, "R2"),
          @core.make_block(@core.BlockKind::TableCell, "V2"),
        ],
      ),
    ],
  )
  let code = @core.block_with_attr(
    @core.make_block(
      @core.BlockKind::Code,
      "line1\nline2\nline3\nline4",
      source_ref=@core.empty_source_ref(),
    ),
    "language",
    "moonbit",
  )
  let document = @core.document_from_blocks([
    paragraph_a, paragraph_b, table, code,
  ])
  document.metadata.set("format", @core.JsonValue::String("xlsx"))
  let chunks = @rag.chunks_from_document(
    document,
    @rag.make_rag_options(20, 5, true, true, true, true),
  )
  assert_true(chunks.length() >= 4)
  assert_true(chunks[0].kind == @rag.ChunkKind::Text)
  assert_true(chunks[1].kind == @rag.ChunkKind::Text)
  assert_true(chunks[0].text.contains("Alpha"))
  assert_true(chunks[1].text.contains("Beta"))
  assert_true(chunks.any(fn(chunk) { chunk.kind == @rag.ChunkKind::Table }))
  assert_true(chunks.any(fn(chunk) { chunk.kind == @rag.ChunkKind::Code }))
}

///|
test "rag output can suppress source refs while keeping library source map" {
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::RagJson,
    Some(@input.DetectedFormat::Markdown),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    output_mode=@convert.OutputMode::Rag,
    rag_options=@rag.make_rag_options(1200, 150, true, false, true, true),
  )
  let result = match
    @convert.convert_input(
      @input.input_from_text_with_format(
        "# Title\n\nBody\n",
        "rag.md",
        Some(@input.DetectedFormat::Markdown),
      ),
      options,
    ) {
    Ok(value) => value
    Err(err) => abort("rag convert failed: " + err.to_string())
  }
  assert_true(result.content.contains("\"source_map\": null"))
  let chunks = result.chunks.unwrap_or([])
  assert_true(chunks.length() >= 1)
  for chunk in chunks {
    assert_eq(chunk.source_refs.length(), 0)
  }
}

///|
test "rag true stream preserves structural heading paths for json yaml and xml" {
  let json = convert_memory_text(
    "{\"person\":{\"name\":\"Alice\",\"role\":\"Engineer\",\"details\":{\"team\":\"Core\",\"level\":\"Senior\"}}}\n",
    "rag.json",
    @input.DetectedFormat::Json,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
    limits=limits(1, 1, 1),
  )
  let yaml = convert_memory_text(
    "person:\n  name: Alice\n  role: Engineer\n  details:\n    team: Core\n    level: Senior\n",
    "rag.yaml",
    @input.DetectedFormat::Yaml,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
    limits=limits(1, 1, 1),
  )
  let xml = convert_memory_text(
    "<person><name>Alice</name><role>Engineer</role></person>\n",
    "rag.xml",
    @input.DetectedFormat::Xml,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
    limits=limits(1, 1, 1),
  )
  assert_true(
    json.parser_mode == @parser.ParserMode::StreamingEvent ||
    json.parser_mode == @parser.ParserMode::DomAstModel,
  )
  assert_true(
    yaml.parser_mode == @parser.ParserMode::StreamingEvent ||
    yaml.parser_mode == @parser.ParserMode::DomAstModel,
  )
  assert_true(
    xml.parser_mode == @parser.ParserMode::StreamingEvent ||
    xml.parser_mode == @parser.ParserMode::DomAstModel,
  )
  assert_true(json.content.contains("\"heading_path\": ["))
  assert_true(yaml.content.contains("\"heading_path\": ["))
  assert_true(xml.content.contains("\"heading_path\": ["))
  assert_true(json.content.contains("\"source_map\":"))
  assert_true(yaml.content.contains("\"source_map\":"))
  assert_true(xml.content.contains("\"source_map\":"))
}

///|
test "rag sample outputs preserve location metadata across html docx pdf pptx and xlsx" {
  let html = convert_path(
    "samples/main_process/html/markdown/html_link_in_paragraph.html",
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  let docx = convert_path(
    "samples/main_process/docx/markdown/docx_heading_levels.docx",
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  let pdf = convert_path(
    "samples/main_process/pdf/markdown/text_simple.pdf",
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  let pptx = convert_path(
    "samples/main_process/pptx/markdown/pptx_bullet_levels.pptx",
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  let xlsx = convert_path(
    "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::RagJson,
  )
  assert_true(html.content.contains("\"heading_path\""))
  assert_true(docx.content.contains("\"heading_path\""))
  assert_true(pdf.content.contains("\"pages\""))
  assert_true(pptx.content.contains("\"slides\""))
  assert_true(xlsx.content.contains("\"sheets\""))
  assert_true(xlsx.content.contains("\"cell_ranges\""))
}

///|
test "xlsx block stream sparse rows preserve markdown table shape" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
    requested_mode=Some(@parser.ParserMode::BlockStreaming),
  )
  assert_true(parsed.mode == @parser.ParserMode::BlockStreaming)
  let document = final_document_from_parse_result(parsed)
  let table = document.blocks[1]
  let header = table.children[0]
  assert_true(header.attrs.get("sparse_cell_columns") == Some("true"))
  assert_true(header.children.length() == 0)
  assert_true(header.attrs.get("sparse_row_payload") is Some(_))
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let expected = read_utf8_text(
    "samples/main_process/xlsx/expected/markdown/sheet_simple.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
}

///|
test "debug json source ref serialization keeps json xpath and yaml path fields visible" {
  let json = convert_memory_text(
    "{\"name\":\"Alice\"}\n",
    "debug.json",
    @input.DetectedFormat::Json,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::DebugJson,
  )
  let xml = convert_memory_text(
    "<root><item>Hello</item></root>\n",
    "debug.xml",
    @input.DetectedFormat::Xml,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::DebugJson,
  )
  let yaml = convert_memory_text(
    "name: Alice\nrole: Engineer\n",
    "debug.yaml",
    @input.DetectedFormat::Yaml,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::DebugJson,
  )
  let markdown = convert_memory_text(
    "# Title\n\nBody\n",
    "debug.md",
    @input.DetectedFormat::Markdown,
    mode=@convert.ConvertMode::Balanced,
    output=@convert.OutputFormat::DebugJson,
  )
  assert_true(json.content.contains("\"json_pointer\": \"/\""))
  assert_true(json.content.contains("\"xpath\": null"))
  assert_true(json.content.contains("\"yaml_path\": null"))
  assert_true(xml.content.contains("\"xpath\": \"/root\""))
  assert_true(xml.content.contains("\"json_pointer\": null"))
  assert_true(xml.content.contains("\"yaml_path\": null"))
  assert_true(yaml.content.contains("\"yaml_path\": \"/\""))
  assert_true(yaml.content.contains("\"json_pointer\": null"))
  assert_true(yaml.content.contains("\"xpath\": null"))
  assert_true(markdown.content.contains("\"markdown_path\": \"/heading[0]\""))
  assert_true(markdown.content.contains("\"yaml_path\": null"))
  assert_true(markdown.content.contains("\"xpath\": null"))
}

///|
test "debug json source ref serialization keeps office fields visible" {
  let source_ref = @core.source_ref_with_office_fields(
    @core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      Some("sample.docx"),
      Some("docx"),
      Some("sample.docx"),
      Some("word/document.xml"),
      Some(0),
      Some("docx"),
      Some("/w:document/w:body/w:p[3]"),
    ),
    Some("sample.docx"),
    Some("docx"),
    Some("/w:document/w:body/w:p[3]"),
    Some("Sheet A"),
    Some("B7:C9"),
    Some(2),
    Some("shape-4"),
    Some("rId5"),
  )
  let with_extra = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref, "ooxml_part_type", "main_document",
          ),
          "part_name",
          "word/document.xml",
        ),
        "relationship_type",
        "image",
      ),
      "sheet_name",
      "Sheet A",
    ),
    "paragraph_index",
    "3",
  )
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Docx paragraph",
    source_ref=with_extra,
  )
  let document = @core.document_from_blocks([block])
  let rendered = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_true(
    rendered.content.contains("\"inner_path\": \"/w:document/w:body/w:p[3]\""),
  )
  assert_true(rendered.content.contains("\"sheet\": \"Sheet A\""))
  assert_true(rendered.content.contains("\"cell_range\": \"B7:C9\""))
  assert_true(rendered.content.contains("\"slide\": 2"))
  assert_true(rendered.content.contains("\"shape_id\": \"shape-4\""))
  assert_true(rendered.content.contains("\"relationship_id\": \"rId5\""))
  assert_true(
    rendered.content.contains("\"ooxml_part_type\": \"main_document\""),
  )
  assert_true(rendered.content.contains("\"part_name\": \"word/document.xml\""))
  assert_true(rendered.content.contains("\"relationship_type\": \"image\""))
  assert_true(rendered.content.contains("\"sheet_name\": \"Sheet A\""))
  assert_true(rendered.content.contains("\"paragraph_index\": \"3\""))
}

///|
test "debug json source ref serialization keeps container fields visible" {
  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("sample.zip"),
    Some("zip"),
    Some("sample.zip"),
    Some("docs/readme.md"),
    Some(4),
    Some("markdown"),
    Some("#/heading[0]"),
  )
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Entry text",
    source_ref~,
  )
  let document = @core.document_from_blocks([block])
  let rendered = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(true),
  )
  assert_contains_all(rendered.content, [
    "\"container_path\": \"sample.zip\"", "\"entry_path\": \"docs/readme.md\"", "\"entry_index\": 4",
    "\"entry_format\": \"markdown\"", "\"inner_path\": \"#/heading[0]\"",
  ])
}

///|
test "notes appendix first profile moves appendix-ready blocks ahead of body" {
  let body = @core.make_block(@core.BlockKind::Paragraph, "Body")
  let note = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "Footnote body"),
    "appendix_ready",
    "true",
  )
  note.attrs.set("note_definition_id", "1")
  let document = @core.document_from_blocks([body, note])
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::NotesAppendixFirst,
    ),
  )
  assert_eq(rendered.content, "[^1]: Footnote body\n\nBody")
  assert_true(
    rendered.diagnostics.metrics.get("applied_render_profile") ==
    Some("notes_appendix_first"),
  )
}

///|
test "asset manifest first profile emits asset appendix before body" {
  let body = @core.make_block(@core.BlockKind::Paragraph, "Body")
  let document = @core.document_from_blocks([body])
  let asset = {
    ..@core.make_asset_ref(@core.AssetKind::Image, "asset-1"),
    path: Some("assets/demo.png"),
  }
  let rendered = (@render.markdown_renderer().render)(
    { ..document, assets: [asset] },
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::AssetManifestFirst,
      assets=Some([asset]),
    ),
  )
  assert_true(rendered.content.has_prefix("## Assets"))
  assert_true(rendered.content.contains("- asset-1: assets/demo.png"))
}

///|
test "page window profile inserts spacer between slide-local blocks" {
  let first = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "Slide 1 text"),
    "slide_local",
    "true",
  )
  let second = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "Slide 2 text"),
    "slide_local",
    "true",
  )
  let document = @core.document_from_blocks([first, second])
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::PageWindowMarkdown,
    ),
  )
  assert_eq(rendered.content, "Slide 1 text\n\nSlide 2 text")
}

///|
test "section flush profile inserts spacer across section groups" {
  let intro = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "Intro"),
    "render_boundary_key",
    "section:intro",
  )
  let body = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "Body"),
    "render_boundary_key",
    "section:body",
  )
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([intro, body]),
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::SectionFlushMarkdown,
    ),
  )
  assert_eq(rendered.content, "Intro\n\nBody")
}

///|
test "sparse table profile keeps sparse rows observable in markdown" {
  let table = @core.make_block(@core.BlockKind::Table, "table")
  table.attrs.set("render_table_mode", "sparse")
  let header = @core.make_block(@core.BlockKind::TableRow, "")
  header.attrs.set("sparse_cell_columns", "true")
  header.attrs.set("declared_column_count", "3")
  header.attrs.set("sparse_row_payload", "1\tName\n3\tScore")
  let row = @core.make_block(@core.BlockKind::TableRow, "")
  row.attrs.set("sparse_cell_columns", "true")
  row.attrs.set("declared_column_count", "3")
  row.attrs.set("sparse_row_payload", "1\tAlice\n3\t9")
  table.children.push(header)
  table.children.push(row)
  let rendered = (@render.markdown_renderer().render)(
    @core.document_from_blocks([table]),
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::SparseTableMarkdown,
    ),
  )
  assert_true(rendered.content.contains("| Name |  | Score |"))
  assert_true(rendered.content.contains("| Alice |  | 9 |"))
}

///|
test "record batch profile stays visible in rag chunk metrics" {
  let events : Array[@core.CoreEvent] = [
    {
      kind: @core.EventKind::TextLine,
      text: "alpha",
      source_ref: Some(@core.empty_source_ref()),
    },
    {
      kind: @core.EventKind::TextLine,
      text: "beta",
      source_ref: Some(@core.empty_source_ref()),
    },
  ]
  let rendered = (@render.rag_json_renderer().render_input)(
    @render.RenderInput::EventStream(events),
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::RecordBatchMarkdown,
      metadata=Some(Map([("format", @core.JsonValue::String("txt"))])),
    ),
  )
  assert_true(
    rendered.diagnostics.metrics.get("applied_render_profile") ==
    Some("record_batch_markdown"),
  )
  let chunks = rendered.chunks.unwrap_or([])
  assert_true(chunks.length() == 1)
  assert_true(
    rendered.diagnostics.metrics.get("record_batch_chunking") == Some("true"),
  )
  assert_true(
    chunks[0].metadata.get("record_batch_profile") ==
    Some(@core.JsonValue::Bool(true)),
  )
  assert_true(
    chunks[0].metadata.get("batch_ordinal") ==
    Some(@core.JsonValue::Number("0")),
  )
}

///|
test "record batch profile changes rag document chunking semantics across section groups" {
  let first = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "alpha one"),
    "render_boundary_key",
    "section:a",
  )
  let second = @core.block_with_attr(
    @core.make_block(@core.BlockKind::Paragraph, "beta two"),
    "render_boundary_key",
    "section:b",
  )
  let document = @core.document_from_blocks([first, second])
  document.metadata.set("format", @core.JsonValue::String("markdown"))
  let default_rendered = (@render.rag_json_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  let batched_rendered = (@render.rag_json_renderer().render)(
    document,
    @render.make_render_context(
      false,
      render_profile=@product.RenderProfile::RecordBatchMarkdown,
    ),
  )
  let default_chunks = default_rendered.chunks.unwrap_or([])
  let batched_chunks = batched_rendered.chunks.unwrap_or([])
  assert_true(default_chunks.length() == 1)
  assert_true(batched_chunks.length() == 2)
  assert_true(
    batched_rendered.diagnostics.metrics.get("record_batch_chunking") ==
    Some("true"),
  )
  assert_true(
    batched_chunks[0].metadata.get("batch_ordinal") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(
    batched_chunks[1].metadata.get("batch_ordinal") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(
    batched_chunks[0].metadata.get("ordinal") ==
    Some(@core.JsonValue::Number("0")),
  )
  assert_true(
    batched_chunks[1].metadata.get("ordinal") ==
    Some(@core.JsonValue::Number("1")),
  )
  assert_true(batched_chunks[0].text.contains("alpha one"))
  assert_true(batched_chunks[1].text.contains("beta two"))
  assert_true(batched_chunks[0].id != batched_chunks[1].id)
}

///|
test "debug renderer reports applied render profile" {
  let document = @core.document_from_blocks([
    @core.make_block(@core.BlockKind::Paragraph, "Body"),
  ])
  let rendered = (@render.debug_json_renderer().render)(
    document,
    @render.make_render_context(
      true,
      render_profile=@product.RenderProfile::NotesAppendixFirst,
    ),
  )
  assert_true(
    rendered.content.contains(
      "\"applied_render_profile\": \"notes_appendix_first\"",
    ),
  )
}
