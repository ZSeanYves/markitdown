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
test "assembler promotes heading candidates and builds section tree" {
  let candidate = @core.make_block(
    @core.BlockKind::Paragraph,
    "Candidate Title",
    source_ref=@core.empty_source_ref(),
  )
  candidate.attrs.set("heading_candidate", "true")
  candidate.attrs.set("heading_level", "2")
  let body = @core.make_block(
    @core.BlockKind::Paragraph,
    "Body",
    source_ref=@core.empty_source_ref(),
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([candidate, body]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[0].attrs.get("level") == Some("2"))
  let assembly = document.assembly.unwrap_or(@core.empty_document_assembly())
  assert_true(assembly.sections.length() == 1)
  assert_true(assembly.sections[0].title == "Candidate Title")
  assert_true(
    assembly.heading_paths.get(body.block_id) == Some(["Candidate Title"]),
  )
  assert_metric_eq(document.diagnostics, "resolved_heading_count", "1")
}

///|
test "assembler groups flat list items without breaking nested parser-owned lists" {
  let item_a = @core.make_block(
    @core.BlockKind::ListItem,
    "First",
    source_ref=@core.empty_source_ref(),
  )
  item_a.attrs.set("ordered", "false")
  item_a.attrs.set("level", "0")
  let item_b = @core.make_block(
    @core.BlockKind::ListItem,
    "Second",
    source_ref=@core.empty_source_ref(),
  )
  item_b.attrs.set("ordered", "false")
  item_b.attrs.set("level", "0")
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([item_a, item_b]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks.length() == 1)
  assert_true(document.blocks[0].kind == @core.BlockKind::List)
  assert_true(document.blocks[0].children.length() == 2)
  assert_true(document.blocks[0].children[0].text == "First")
  assert_true(document.blocks[0].children[1].text == "Second")
  assert_metric_eq(document.diagnostics, "resolved_list_count", "1")
}

///|
test "rag prefers assembler heading paths over local heading scan state" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Root",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "1")
  let paragraph = @core.make_block(
    @core.BlockKind::Paragraph,
    "Body under root",
    source_ref=@core.empty_source_ref(),
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([heading, paragraph]),
    @pipeline.make_pass_context(false, "rag"),
  )
  let chunks = @rag.chunks_from_document(
    document,
    @rag.make_rag_options(1200, 150, true, true, true, true),
  )
  let mut text_chunk : @rag.RagChunk? = None
  for chunk in chunks {
    if chunk.kind == @rag.ChunkKind::Text {
      text_chunk = Some(chunk)
      break
    }
  }
  let text_chunk = match text_chunk {
    Some(chunk) => chunk
    None => fail("expected text chunk")
  }
  assert_true(text_chunk.heading_path == ["Root"])
  assert_true(
    text_chunk.metadata.get("heading_depth") ==
    Some(@core.JsonValue::Number("1")),
  )
}

///|
test "assembler resolves adjacent logical table continuations" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Data",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "1")

  let left_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("book.xlsx"),
    Some("xlsx"),
    None,
    Some("Sheet1"),
    Some("A1:B3"),
    None,
    None,
    None,
  )
  let right_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("book.xlsx"),
    Some("xlsx"),
    None,
    Some("Sheet1"),
    Some("A4:B6"),
    None,
    None,
    None,
  )

  let left_base = @core.make_block(
    @core.BlockKind::Table,
    "",
    source_ref=left_ref,
  )
  left_base.attrs.set("header_rows", "1")
  left_base.attrs.set("table_column_count", "2")
  let left = @core.block_with_children(left_base, [
    @core.block_with_children(@core.make_block(@core.BlockKind::TableRow, ""), [
      @core.make_block(@core.BlockKind::TableCell, "H1"),
      @core.make_block(@core.BlockKind::TableCell, "H2"),
    ]),
    @core.block_with_children(@core.make_block(@core.BlockKind::TableRow, ""), [
      @core.make_block(@core.BlockKind::TableCell, "A1"),
      @core.make_block(@core.BlockKind::TableCell, "A2"),
    ]),
  ])

  let right_base = @core.make_block(
    @core.BlockKind::Table,
    "",
    source_ref=right_ref,
  )
  right_base.attrs.set("header_rows", "1")
  right_base.attrs.set("table_column_count", "2")
  let right = @core.block_with_children(right_base, [
    @core.block_with_children(@core.make_block(@core.BlockKind::TableRow, ""), [
      @core.make_block(@core.BlockKind::TableCell, "H1"),
      @core.make_block(@core.BlockKind::TableCell, "H2"),
    ]),
    @core.block_with_children(@core.make_block(@core.BlockKind::TableRow, ""), [
      @core.make_block(@core.BlockKind::TableCell, "B1"),
      @core.make_block(@core.BlockKind::TableCell, "B2"),
    ]),
  ])

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([heading, left, right]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let assembly = document.assembly.unwrap_or(@core.empty_document_assembly())
  assert_true(assembly.table_continuations.length() == 1)
  assert_true(
    assembly.table_continuations[0].table_block_id ==
    document.blocks[2].block_id,
  )
  assert_true(
    assembly.table_continuations[0].continues_from_block_id ==
    Some(document.blocks[1].block_id),
  )
  assert_true(
    assembly.table_continuations[0].relation == "adjacent_same_logical_table",
  )
  assert_metric_eq(
    document.diagnostics,
    "resolved_table_continuation_count",
    "1",
  )
}

///|
test "assembler resolves embedded image captions into caption bindings" {
  let image_ref = @core.source_ref_with_html_path(
    @core.empty_source_ref(),
    Some("sample.html"),
    Some("html"),
    Some("/html/body/figure/img[1]"),
  )
  let image = @core.make_block(@core.BlockKind::Image, "", source_ref=image_ref)
  image.attrs.set("asset_id", "img-1")
  image.attrs.set("path", "assets/image01.png")
  image.attrs.set("caption", "Figure 1. Example")

  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    "img-1",
    source_ref=image_ref,
  )
  let asset = { ..asset, path: Some("assets/image01.png") }

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::Document({
      ..@core.document_from_blocks([image]),
      assets: [asset],
    }),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let assembly = document.assembly.unwrap_or(@core.empty_document_assembly())
  assert_true(assembly.caption_bindings.length() == 1)
  assert_true(
    assembly.caption_bindings[0].target_block_id == document.blocks[0].block_id,
  )
  assert_true(
    assembly.caption_bindings[0].caption_block_id ==
    document.blocks[0].block_id + ":caption",
  )
  assert_true(assembly.caption_bindings[0].relation == "embedded_caption_attr")
  assert_metric_eq(document.diagnostics, "resolved_caption_binding_count", "1")
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

///|
test "merge text line pass merges pdf line fragments within one text block only" {
  let line_a_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      {
        ..@core.source_ref_with_lines(
          @core.empty_source_ref(),
          Some("sample.pdf"),
          Some("pdf"),
          Some(1),
          Some(1),
        ),
        page: Some(1),
      },
      "pdf_text_block_index",
      "7",
    ),
    "reading_order_index",
    "3",
  )
  let line_a = @core.make_block(
    @core.BlockKind::Paragraph,
    "Alpha-",
    source_ref=line_a_ref,
  )

  let line_b_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.empty_source_ref(),
      "reading_order_index",
      "3",
    ),
    "pdf_text_block_index",
    "7",
  )
  let line_b_ref = {
    ..@core.source_ref_with_lines(
      line_b_ref,
      Some("sample.pdf"),
      Some("pdf"),
      Some(2),
      Some(2),
    ),
    page: Some(1),
  }
  let line_b = @core.make_block(
    @core.BlockKind::Paragraph,
    "Beta",
    source_ref=line_b_ref,
  )

  let other_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.empty_source_ref(),
      "reading_order_index",
      "3",
    ),
    "pdf_text_block_index",
    "8",
  )
  let other_ref = {
    ..@core.source_ref_with_lines(
      other_ref,
      Some("sample.pdf"),
      Some("pdf"),
      Some(3),
      Some(3),
    ),
    page: Some(1),
  }
  let line_c = @core.make_block(
    @core.BlockKind::Paragraph,
    "Gamma",
    source_ref=other_ref,
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([line_a, line_b, line_c]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks.length() == 2)
  assert_true(document.blocks[0].text == "AlphaBeta")
  assert_true(document.blocks[1].text == "Gamma")
  assert_metric_eq(document.diagnostics, "merged_text_line_count", "1")
}

///|
test "resolve reading order pass reorders only hinted siblings" {
  let slide_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("slides.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(2),
      Some("shape-a"),
      None,
    )
  }
  slide_ref.extra.set("reading_order_key", "0020")
  let first = @core.make_block(
    @core.BlockKind::Paragraph,
    "Second visually",
    source_ref=slide_ref,
  )
  let slide_ref2 = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("slides.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(2),
      Some("shape-b"),
      None,
    )
  }
  slide_ref2.extra.set("reading_order_key", "0010")
  let second = @core.make_block(
    @core.BlockKind::Paragraph,
    "First visually",
    source_ref=slide_ref2,
  )
  let plain = @core.make_block(
    @core.BlockKind::Paragraph,
    "Unhinted tail",
    source_ref=@core.empty_source_ref(),
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([first, second, plain]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks[0].text == "First visually")
  assert_true(document.blocks[1].text == "Second visually")
  assert_true(document.blocks[2].text == "Unhinted tail")
  assert_metric_eq(
    document.diagnostics,
    "resolved_reading_order_block_count",
    "2",
  )
}

///|
test "resolve reading order pass does not reorder across slide boundaries" {
  let slide1_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("slides.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-a"),
      None,
    )
  }
  slide1_ref.extra.set("reading_order_key", "030")
  let slide1 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Slide 1 body",
    source_ref=slide1_ref,
  )
  let slide3_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("slides.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(3),
      Some("shape-b"),
      None,
    )
  }
  slide3_ref.extra.set("reading_order_key", "010")
  let slide3 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Slide 3 heading-like",
    source_ref=slide3_ref,
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([slide1, slide3]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks[0].text == "Slide 1 body")
  assert_true(document.blocks[1].text == "Slide 3 heading-like")
}

///|
test "resolve reading order pass does not reorder across pdf pages" {
  let page1_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("sample.pdf"),
    Some("pdf"),
    Some(1),
    Some(1),
  )
  page1_ref.extra.set("reading_order_index", "1")
  let page1 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Page 1 first",
    source_ref=page1_ref,
  )
  let page2_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some("sample.pdf"),
    Some("pdf"),
    Some(2),
    Some(2),
  )
  page2_ref.extra.set("reading_order_index", "1")
  let page2 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Page 2 first",
    source_ref=page2_ref,
  )
  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([page1, page2]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(document.blocks[0].text == "Page 1 first")
  assert_true(document.blocks[1].text == "Page 2 first")
}

///|
test "resolve reading order pass sorts grouped pptx-like sibling keys by geometry rank" {
  let title_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("grouped.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-title"),
      None,
    )
  }
  title_ref.extra.set(
    "reading_order_key", "010:0000000000:0000469681:00001:shape-title",
  )
  let title = @core.make_block(
    @core.BlockKind::Heading,
    "Highlights",
    source_ref=title_ref,
  )

  let main_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("grouped.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-main"),
      None,
    )
  }
  main_ref.extra.set(
    "reading_order_key", "030:0012417387:0000634190:00002:group-200/shape-175",
  )
  let main = @core.make_block(
    @core.BlockKind::Paragraph,
    "Main paragraph",
    source_ref=main_ref,
  )

  let item_a_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("grouped.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-a"),
      None,
    )
  }
  item_a_ref.extra.set(
    "reading_order_key", "030:0004880051:0011536527:00001:group-200/group-200/group-201/shape-172",
  )
  let item_a = @core.make_block(
    @core.BlockKind::Paragraph,
    "Item A",
    source_ref=item_a_ref,
  )

  let item_b_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("grouped.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-b"),
      None,
    )
  }
  item_b_ref.extra.set(
    "reading_order_key", "030:0005618345:0011525250:00002:group-200/group-200/group-201/shape-173",
  )
  let item_b = @core.make_block(
    @core.BlockKind::Paragraph,
    "Item B",
    source_ref=item_b_ref,
  )

  let item_c_ref = {
    ..@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("grouped.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("shape-c"),
      None,
    )
  }
  item_c_ref.extra.set(
    "reading_order_key", "030:0006453784:0011513972:00003:group-200/group-200/group-201/shape-174",
  )
  let item_c = @core.make_block(
    @core.BlockKind::Paragraph,
    "Item C",
    source_ref=item_c_ref,
  )

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([title, main, item_a, item_b, item_c]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let block_texts = document.blocks.map(block => block.text)
  assert_true(
    block_texts ==
    ["Highlights", "Item A", "Item B", "Item C", "Main paragraph"],
  )
}

///|
test "resolve reading order pass reorders mixed hinted pptx siblings by full key" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Slide 1",
    source_ref=@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("sample.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("title"),
      None,
    ),
  )
  let picture_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("picture-6"),
    None,
  )
  picture_ref.extra.set(
    "reading_order_key", "050:0001988840:0005580112:00003:picture-6",
  )
  let picture = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=picture_ref,
  )

  let body_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("shape-7"),
    None,
  )
  body_ref.extra.set(
    "reading_order_key", "060:0002924944:0005580112:00004:shape-7",
  )
  let body = @core.make_block(
    @core.BlockKind::Paragraph,
    "Test text",
    source_ref=body_ref,
  )

  let grouped_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("group-11/shape-10"),
    None,
  )
  grouped_ref.extra.set(
    "reading_order_key", "060:0004581128:0005580112:00002:group-11/shape-10",
  )
  let grouped = @core.make_block(
    @core.BlockKind::Paragraph,
    "Group test text",
    source_ref=grouped_ref,
  )

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([heading, grouped, picture, body]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let block_texts = document.blocks.map(block => block.text)
  assert_true(block_texts == ["Slide 1", "", "Test text", "Group test text"])
}

///|
test "resolve reading order pass preserves full hinted pptx stream order" {
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Slide 1",
    source_ref=@core.source_ref_with_office_fields(
      @core.empty_source_ref(),
      Some("sample.pptx"),
      Some("pptx"),
      None,
      None,
      None,
      Some(1),
      Some("title"),
      None,
    ),
  )
  let box1_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("shape-12"),
    None,
  )
  box1_ref.extra.set(
    "reading_order_key", "030:0005517232:0005652120:00006:shape-12",
  )
  let box1 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Box 1",
    source_ref=box1_ref,
  )

  let box2_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("shape-13"),
    None,
  )
  box2_ref.extra.set(
    "reading_order_key", "030:0005517232:0007668344:00007:shape-13",
  )
  let box2 = @core.make_block(
    @core.BlockKind::Paragraph,
    "Box 2",
    source_ref=box2_ref,
  )

  let picture1_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("picture-6"),
    None,
  )
  picture1_ref.extra.set(
    "reading_order_key", "050:0001988840:0005580112:00003:picture-6",
  )
  let picture1 = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=picture1_ref,
  )

  let picture2_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("group-11/picture-9"),
    None,
  )
  picture2_ref.extra.set(
    "reading_order_key", "050:0003645024:0005580112:00001:group-11/picture-9",
  )
  let picture2 = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=picture2_ref,
  )

  let body_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("shape-7"),
    None,
  )
  body_ref.extra.set(
    "reading_order_key", "060:0002924944:0005580112:00004:shape-7",
  )
  let body = @core.make_block(
    @core.BlockKind::Paragraph,
    "Test text",
    source_ref=body_ref,
  )

  let grouped_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("group-11/shape-10"),
    None,
  )
  grouped_ref.extra.set(
    "reading_order_key", "060:0004581128:0005580112:00002:group-11/shape-10",
  )
  let grouped = @core.make_block(
    @core.BlockKind::Paragraph,
    "Group test text",
    source_ref=grouped_ref,
  )

  let raw_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("connector-15"),
    None,
  )
  raw_ref.extra.set("reading_order_key", "950:999999999:999999999:connector-15")
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "[PPTX connector omitted: Straight Arrow Connector 14]",
    source_ref=raw_ref,
  )

  let table_ref = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.pptx"),
    Some("pptx"),
    None,
    None,
    None,
    Some(1),
    Some("graphicFrame-16"),
    None,
  )
  table_ref.extra.set(
    "reading_order_key", "950:999999999:999999999:graphicFrame-16",
  )
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=table_ref,
  )

  let document = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([
      heading, box1, box2, picture1, picture2, body, grouped, raw, table,
    ]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  let block_texts = document.blocks.map(block => block.text)
  assert_true(
    block_texts ==
    [
      "Slide 1", "Box 1", "Box 2", "", "", "Test text", "Group test text", "[PPTX connector omitted: Straight Arrow Connector 14]",
      "table",
    ],
  )
}

///|
test "remove header footer pass honors cleanup flag and debug retention" {
  let header = @core.make_block(
    @core.BlockKind::Paragraph,
    "Repeated Header",
    source_ref=@core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some("sample.pdf"),
      Some("pdf"),
      Some(1),
      Some(1),
    ),
  )
  header.signals.push(
    @core.make_signal(@core.SignalType::HeaderFooterCandidate, 95),
  )
  let body = @core.make_block(
    @core.BlockKind::Paragraph,
    "Body",
    source_ref=@core.empty_source_ref(),
  )

  let kept = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([header, body]),
    @pipeline.make_pass_context(false, "balanced"),
  )
  assert_true(kept.blocks.length() == 2)
  assert_metric_eq(kept.diagnostics, "removed_header_footer_count", "0")

  let cleaned = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([header, body]),
    @pipeline.make_pass_context(false, "balanced", pdf_cleanup_enabled=true),
  )
  assert_true(cleaned.blocks.length() == 1)
  assert_true(cleaned.blocks[0].text == "Body")
  assert_metric_eq(cleaned.diagnostics, "removed_header_footer_count", "1")

  let debug_cleaned = @pipeline.build_document_with_default_pipeline(
    @core.IRInput::BlockStream([header, body]),
    @pipeline.make_pass_context(true, "debug", pdf_cleanup_enabled=true),
  )
  assert_true(debug_cleaned.blocks.length() == 2)
  assert_true(
    debug_cleaned.blocks[0].attrs.get("header_footer_candidate") == Some("true"),
  )
  assert_metric_eq(
    debug_cleaned.diagnostics,
    "removed_header_footer_count",
    "0",
  )
}
