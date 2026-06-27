///|
test "pptx contract spec matches the active runtime parser" {
  let spec = @formats_root.pptx_parser_contract_spec()
  let parser = @fpptx.pptx_parser()
  assert_contract_spec_matches_parser(spec, parser)
  assert_true(
    @shared.pptx_contract_mode() == @parser.ParserMode::PackageSinglePass,
  )
  assert_true(
    @shared.pptx_contract_granularity() ==
    @parser.StreamingGranularity::PptxSlide,
  )
  assert_eq(@shared.pptx_contract_ir_input_kind(), "document")
  assert_true(
    @shared.pptx_contract_foundations() ==
    ["format_readers/ooxml/package", "format_readers/ooxml/pptx"],
  )
  assert_true(
    @shared.pptx_contract_excluded_runtime_foundations() ==
    [
      "convert/pptx", "old_core", "legacy_convert", "markdown_emitter", "main_cli_fallback",
    ],
  )
  assert_contains_all(@shared.pptx_contract_guardrails().join("\n"), [
    "PPTX is supported on the main CLI", "PackageSinglePass / IRInput::Document / pptx_slide",
    "format_readers/ooxml/package + format_readers/ooxml/pptx foundation", "slide order follows presentation.xml",
    "placeholder inheritance is slide -> layout -> master -> geometry inference",
    "document rendering stays in the shared renderer layer", "assets stay output-boundary only",
  ])
}

///|
test "pptx shared contracts keep placeholder reading-order and notes policies explicit" {
  let slide_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_office_fields(
                  @core.source_ref_with_container_entry(
                    @core.empty_source_ref(),
                    Some("deck.pptx"),
                    Some("pptx"),
                    Some("deck.pptx"),
                    Some("ppt/slides/slide2.xml"),
                    Some(1),
                    Some("pptx"),
                    Some("/p:sld/p:cSld/p:spTree/p:sp[3]"),
                  ),
                  Some("deck.pptx"),
                  Some("pptx"),
                  Some("/p:sld/p:cSld/p:spTree/p:sp[3]"),
                  None,
                  None,
                  Some(2),
                  Some("shape-3"),
                  Some("rIdSlide2"),
                ),
                "slide_index",
                "2",
              ),
              "slide_id",
              "257",
            ),
            "slide_part",
            "ppt/slides/slide2.xml",
          ),
          "layout_part",
          "ppt/slideLayouts/slideLayout3.xml",
        ),
        "master_part",
        "ppt/slideMasters/slideMaster1.xml",
      ),
      "theme_part",
      "ppt/theme/theme1.xml",
    ),
    "shape_name",
    "Agenda Body",
  )
  let placeholder_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(slide_ref, "placeholder_type", "body"),
      "placeholder_idx",
      "1",
    ),
    "shape_type",
    "body",
  )
  let run = @shared.make_pptx_text_run_model(
    "Quarterly review",
    relationship_id=Some("rIdHyper1"),
    source_ref=Some(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(placeholder_ref, "paragraph_index", "0"),
        "run_index",
        "0",
      ),
    ),
  )
  let para = @shared.make_pptx_paragraph_model(
    0,
    [run],
    level=Some(0),
    bullet_kind=Some("unordered"),
    source_ref=Some(
      @core.source_ref_with_extra(placeholder_ref, "paragraph_index", "0"),
    ),
  )
  let table = @shared.make_pptx_table_model([
    @shared.make_pptx_table_row_model(0, [
      @shared.make_pptx_table_cell_model(
        0,
        0,
        "North",
        source_ref=Some(
          @core.source_ref_with_extra(placeholder_ref, "shape_type", "table"),
        ),
      ),
      @shared.make_pptx_table_cell_model(0, 1, "42"),
    ]),
  ])
  let image = @shared.make_pptx_image_model(
    asset_part=Some("ppt/media/image1.png"),
    content_type=Some("image/png"),
    alt_text=Some("Trend chart"),
    title=Some("Trend"),
    relationship_id=Some("rIdImage1"),
    source_ref=Some(slide_ref),
  )
  let placeholder = @shared.make_pptx_placeholder_model(
    "body",
    placeholder_index=Some("1"),
    placeholder_name=Some("Body Placeholder"),
    resolved_from=@shared.PptxPlaceholderOrigin::LayoutPlaceholder,
    source_ref=Some(placeholder_ref),
  )
  let shape = @shared.make_pptx_shape_model(
    @shared.PptxShapeType::Body,
    text_paragraphs=[para],
    shape_id=Some("shape-3"),
    shape_name=Some("Agenda Body"),
    bbox=Some({ x0: 10.0, y0: 20.0, x1: 200.0, y1: 120.0 }),
    table=Some(table),
    image=Some(image),
    placeholder=Some(placeholder),
    source_ref=Some(placeholder_ref),
  )
  let notes = @shared.make_pptx_notes_model(
    ["speaker note"],
    notes_part=Some("ppt/notesSlides/notesSlide2.xml"),
    source_ref=Some(
      @core.source_ref_with_extra(
        slide_ref, "notes_part", "ppt/notesSlides/notesSlide2.xml",
      ),
    ),
  )
  let comment = @shared.make_pptx_comment_model(
    "comment-7",
    "Move this bullet higher",
    author=Some("reviewer"),
    source_ref=Some(
      @core.source_ref_with_extra(slide_ref, "comment_id", "comment-7"),
    ),
  )
  let order = @shared.make_pptx_reading_order_item(
    0,
    2,
    @shared.PptxReadingOrderStrategy::PlaceholderThenGeometry,
    shape_id=Some("shape-3"),
    confidence=Some("high"),
    source_ref=Some(
      @core.source_ref_with_extra(slide_ref, "reading_order_index", "0"),
    ),
  )
  let slide = @shared.make_pptx_slide_model(
    2,
    [shape],
    slide_id=Some("257"),
    slide_part=Some("ppt/slides/slide2.xml"),
    visibility=@shared.PptxSlideVisibility::Hidden,
    layout_part=Some("ppt/slideLayouts/slideLayout3.xml"),
    master_part=Some("ppt/slideMasters/slideMaster1.xml"),
    theme_part=Some("ppt/theme/theme1.xml"),
    notes=Some(notes),
    comments=[comment],
    reading_order=[order],
    source_ref=Some(slide_ref),
  )
  let presentation = @shared.make_pptx_presentation_model([slide])
  let plan = @shared.make_pptx_presentation_plan(presentation, ["257"], hidden_slide_ids=[
    "257",
  ])
  assert_true(plan.presentation.slides.length() == 1)
  assert_true(plan.ordered_slide_ids == ["257"])
  assert_true(plan.hidden_slide_ids == ["257"])
  assert_true(shape.table is Some(_))
  assert_true(shape.image is Some(_))
  assert_true(shape.placeholder is Some(_))
  assert_contains_all(@shared.pptx_contract_slide_policy().join("\n"), [
    "slide order is derived from presentation.xml and slide relationship ids", "hidden slides remain explicit semantic units with diagnostics-first visibility policy",
  ])
  assert_contains_all(@shared.pptx_contract_placeholder_policy().join("\n"), [
    "placeholder inheritance resolves through slide, layout, then master", "geometry/name inference is last-resort only",
  ])
  assert_contains_all(@shared.pptx_contract_reading_order_policy().join("\n"), [
    "reading order uses placeholder hints before geometry heuristics", "reading-order strategy remains observable in diagnostics metrics",
  ])
  assert_contains_all(@shared.pptx_contract_notes_policy().join("\n"), [
    "speaker notes remain attached per slide", "comments remain metadata-first and slide-scoped",
  ])
}

///|
test "pptx parser keeps diagnostics source refs and runtime behavior contract locked" {
  let parsed = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/markdown/pptx_hidden_slides_policy.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let spec = @formats_root.pptx_parser_contract_spec()
  assert_parse_result_matches_contract_spec(parsed, spec)
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx document")
  })
  assert_true(document.blocks.length() == 6)
  assert_eq(document.blocks[0].text, "Slide 1")
  assert_eq(document.blocks[3].text, "Slide 3")
  let slide1_ref = document.blocks[0].source_ref.unwrap_or(
    @core.empty_source_ref(),
  )
  assert_true(slide1_ref.entry_path == Some("ppt/slides/slide1.xml"))
  assert_true(slide1_ref.extra.get("slide_id") == Some("256"))
  assert_diagnostics_lists_contain_none(parsed.diagnostics, [
    "pptx_raw_fallback", "pptx_legacy_fallback", "xml_order_text_dump",
  ])
}

///|
test "pptx parser keeps nested lists speaker notes and asset boundaries stable" {
  let bullets = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/markdown/pptx_bullet_levels.pptx",
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
    "samples/main_process/pptx/expected/markdown/pptx_bullet_levels.md",
  )
  assert_eq(
    rendered_bullets.content.trim().to_owned(),
    expected_bullets.trim().to_owned(),
  )

  let notes = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/rag/pptx_speaker_notes_basic.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let notes_document = notes.document.unwrap_or_else(fn() {
    abort("missing pptx notes document")
  })
  assert_eq(notes_document.blocks[6].text, "Speaker Notes")
  assert_eq(notes_document.blocks[7].text, "本页核心信息")

  let assets = default_registry_parse(
    @input.input_from_path(
      "samples/main_process/pptx/assets/pptx_image_single.pptx",
    ),
    @input.DetectedFormat::Pptx,
  )
  let asset_document = assets.document.unwrap_or_else(fn() {
    abort("missing pptx image document")
  })
  assert_true(asset_document.assets.length() == 1)
  assert_true(asset_document.assets[0].path == Some("assets/image01.png"))
  let rendered_assets = (@render.markdown_renderer().render)(
    asset_document,
    @render.make_render_context(false),
  )
  let expected_assets = read_utf8_text(
    "samples/main_process/pptx/expected/assets/pptx_image_single/result.md",
  )
  assert_eq(
    rendered_assets.content.trim().to_owned(),
    expected_assets.trim().to_owned(),
  )
}

///|
test "pptx source ref debug json keeps contract-listed fields visible" {
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              @core.source_ref_with_extra(
                @core.source_ref_with_extra(
                  @core.source_ref_with_extra(
                    @core.source_ref_with_extra(
                      @core.source_ref_with_office_fields(
                        @core.source_ref_with_container_entry(
                          @core.empty_source_ref(),
                          Some("deck.pptx"),
                          Some("pptx"),
                          Some("deck.pptx"),
                          Some("ppt/slides/slide3.xml"),
                          Some(2),
                          Some("pptx"),
                          Some("/p:sld/p:cSld/p:spTree/p:sp[4]"),
                        ),
                        Some("deck.pptx"),
                        Some("pptx"),
                        Some("/p:sld/p:cSld/p:spTree/p:sp[4]"),
                        None,
                        None,
                        Some(3),
                        Some("shape-4"),
                        Some("rId9"),
                      ),
                      "slide_index",
                      "3",
                    ),
                    "slide_id",
                    "4096",
                  ),
                  "slide_part",
                  "ppt/slides/slide3.xml",
                ),
                "layout_part",
                "ppt/slideLayouts/slideLayout2.xml",
              ),
              "master_part",
              "ppt/slideMasters/slideMaster1.xml",
            ),
            "theme_part",
            "ppt/theme/theme1.xml",
          ),
          "shape_name",
          "Title 1",
        ),
        "shape_type",
        "title",
      ),
      "placeholder_type",
      "title",
    ),
    "placeholder_idx",
    "0",
  )
  let with_more = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(source_ref, "reading_order_index", "0"),
          "notes_part",
          "ppt/notesSlides/notesSlide3.xml",
        ),
        "comment_id",
        "comment-11",
      ),
      "part_name",
      "ppt/slides/slide3.xml",
    ),
    "paragraph_index",
    "0",
  )
  let block = @core.make_block(
    @core.BlockKind::Heading,
    "Quarterly review",
    source_ref=with_more,
  )
  let rendered = (@render.debug_json_renderer().render)(
    @core.document_from_blocks([block]),
    @render.make_render_context(true),
  )
  assert_true(rendered.content.contains("\"format\": \"pptx\""))
  assert_true(rendered.content.contains("\"shape_id\": \"shape-4\""))
  assert_true(rendered.content.contains("\"relationship_id\": \"rId9\""))
  assert_contains_all(
    @shared.pptx_contract_source_ref_extra_keys().join("\n"),
    [
      "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
      "shape_id", "shape_name", "shape_type", "placeholder_type", "placeholder_idx",
      "reading_order_index", "notes_part", "comment_id", "part_name", "relationship_id",
      "paragraph_index", "run_index",
    ],
  )
}
