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
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(false),
  )
  assert_eq(rendered.content, "# Title\n\nBody")
  assert_true(
    rendered.diagnostics.metrics.get("renderer_name") ==
    Some("MarkdownRenderer"),
  )
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
  assert_true(
    result.diagnostics.metrics.get("renderer_name") == Some("DebugJsonRenderer"),
  )
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
test "debug json source ref serialization keeps office and container fields visible" {
  let office_ref = @core.source_ref_with_office_fields(
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
  let office_block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Docx paragraph",
    source_ref=@core.source_ref_with_extra(
      office_ref, "part_name", "word/document.xml",
    ),
  )
  let container_block = @core.make_block(
    @core.BlockKind::Paragraph,
    "Entry text",
    source_ref=@core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      Some("sample.zip"),
      Some("zip"),
      Some("sample.zip"),
      Some("docs/readme.md"),
      Some(4),
      Some("markdown"),
      Some("#/heading[0]"),
    ),
  )
  let rendered = (@render.debug_json_renderer().render)(
    @core.document_from_blocks([office_block, container_block]),
    @render.make_render_context(true),
  )
  assert_contains_all(rendered.content, [
    "\"sheet\": \"Sheet A\"", "\"cell_range\": \"B7:C9\"", "\"slide\": 2", "\"shape_id\": \"shape-4\"",
    "\"relationship_id\": \"rId5\"", "\"part_name\": \"word/document.xml\"", "\"container_path\": \"sample.zip\"",
    "\"entry_path\": \"docs/readme.md\"", "\"entry_index\": 4",
  ])
}
