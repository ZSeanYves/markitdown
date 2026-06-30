///|
fn pptx_contract_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn pptx_contract_append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn pptx_contract_append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn pptx_contract_crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
}

///|
fn pptx_contract_crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = pptx_contract_crc32_update_uint(
      crc,
      ch.to_int().reinterpret_as_uint(),
    )
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn pptx_contract_add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = pptx_contract_bytes_of_string(name)
  let data_bytes = pptx_contract_bytes_of_string(data)
  let crc32 = pptx_contract_crc32_of_string(data)
  pptx_contract_append_u32_le(out, 0x04034b50)
  pptx_contract_append_u16_le(out, 20)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u32_le(out, crc32)
  pptx_contract_append_u32_le(out, data_bytes.length())
  pptx_contract_append_u32_le(out, data_bytes.length())
  pptx_contract_append_u16_le(out, name_bytes.length())
  pptx_contract_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }
  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn pptx_contract_build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []
  for entry in entries {
    let (name, data) = entry
    pptx_contract_add_store_entry(out, central, name, data)
  }
  let central_offset = out.length()
  for item in central {
    let (name, size, local_offset, crc32) = item
    let name_bytes = pptx_contract_bytes_of_string(name)
    pptx_contract_append_u32_le(out, 0x02014b50)
    pptx_contract_append_u16_le(out, 20)
    pptx_contract_append_u16_le(out, 20)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u32_le(out, crc32)
    pptx_contract_append_u32_le(out, size)
    pptx_contract_append_u32_le(out, size)
    pptx_contract_append_u16_le(out, name_bytes.length())
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u16_le(out, 0)
    pptx_contract_append_u32_le(out, 0)
    pptx_contract_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let central_size = out.length() - central_offset
  pptx_contract_append_u32_le(out, 0x06054b50)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u16_le(out, 0)
  pptx_contract_append_u16_le(out, central.length())
  pptx_contract_append_u16_le(out, central.length())
  pptx_contract_append_u32_le(out, central_size)
  pptx_contract_append_u32_le(out, central_offset)
  pptx_contract_append_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
fn pptx_contract_rels(xml : String) -> String {
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  xml +
  "</Relationships>"
}

///|
fn pptx_contract_table_hyperlink_bytes() -> Bytes {
  pptx_contract_build_store_zip([
    (
      "[Content_Types].xml", "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/><Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/></Types>",
    ),
    (
      "_rels/.rels",
      pptx_contract_rels(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      pptx_contract_rels(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    (
      "ppt/slides/slide1.xml", "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/><p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"Table\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tr><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:hlinkClick r:id=\"rIdLink\"/></a:rPr><a:t>Spec</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame></p:spTree></p:cSld></p:sld>",
    ),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      pptx_contract_rels(
        "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com/spec\" TargetMode=\"External\"/>",
      ),
    ),
  ])
}

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
test "pptx accurate fidelity respects reading-order-driven grouped lowering" {
  let registry = @formats_root.builtin_registry()
  let context = @parser.parse_context_with_product_modes(
    @parser.new_parse_context(@input.DetectedFormat::Pptx),
    @product.FidelityMode::Accurate,
    @product.OutputMode::Markdown,
  )
  let result = match
    @parser.registry_parse(
      registry,
      @input.input_from_path(
        "samples/main_process/pptx/markdown/pptx_reading_order_geometry.pptx",
      ),
      context,
    ) {
    Ok(value) => value
    Err(err) => fail("accurate pptx parse failed: " + err)
  }
  assert_metric_eq(result.diagnostics, "fidelity_mode", "accurate")
  let document = result.document.unwrap_or_else(fn() {
    abort("missing accurate pptx document")
  })
  let rendered = (@render.markdown_renderer().render)(
    document,
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Accurate,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  let expected = read_utf8_text(
    "samples/main_process/pptx/expected/markdown/pptx_reading_order_geometry.md",
  )
  assert_eq(rendered.content.trim().to_owned(), expected.trim().to_owned())
}

///|
test "pptx balanced fidelity avoids accurate-only callout reading-order promotion" {
  let registry = @formats_root.builtin_registry()
  let source = @input.input_from_path(
    "samples/main_process/pptx/markdown/pptx_callout_blocks_basic.pptx",
  )
  let balanced = match
    @parser.registry_parse(
      registry,
      source,
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Balanced,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("balanced pptx parse failed: " + err)
  }
  let accurate = match
    @parser.registry_parse(
      registry,
      source,
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("accurate pptx parse failed: " + err)
  }
  let balanced_document = balanced.document.unwrap_or_else(fn() {
    abort("missing balanced pptx document")
  })
  let accurate_document = accurate.document.unwrap_or_else(fn() {
    abort("missing accurate pptx document")
  })
  let balanced_rendered = (@render.markdown_renderer().render)(
    balanced_document,
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Balanced,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  let accurate_rendered = (@render.markdown_renderer().render)(
    accurate_document,
    @render.make_render_context(
      false,
      fidelity_mode=@product.FidelityMode::Accurate,
      output_mode=@product.OutputMode::Markdown,
    ),
  )
  let balanced_lines = balanced_rendered.content
    .split("\n")
    .map(fn(line) { line.to_owned() })
    .to_array()
  let accurate_lines = accurate_rendered.content
    .split("\n")
    .map(fn(line) { line.to_owned() })
    .to_array()
  assert_ordered_strings(balanced_lines, "Security", "Secure by default")
  assert_ordered_strings(balanced_lines, "Secure by default", "Sharing")
  assert_ordered_strings(balanced_lines, "Sharing", "Team access controls")
  assert_ordered_strings(accurate_lines, "Export", "Security")
  assert_ordered_strings(accurate_lines, "Security", "Sharing")
  assert_ordered_strings(accurate_lines, "Sharing", "Markdown and PDF output")
  assert_true(
    balanced_rendered.content.trim().to_owned() !=
    accurate_rendered.content.trim().to_owned(),
  )
}

///|
test "pptx accurate fidelity upgrades merged tables to html span rendering" {
  let registry = @formats_root.builtin_registry()
  let source = @input.input_from_path(
    "markitdown-quality-lab/external_quality/pptx/python-pptx/tbl-cell.pptx",
  )
  let balanced = match
    @parser.registry_parse(
      registry,
      source,
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Balanced,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("balanced tbl-cell parse failed: " + err)
  }
  let accurate = match
    @parser.registry_parse(
      registry,
      source,
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("accurate tbl-cell parse failed: " + err)
  }
  let balanced_markdown = (@render.markdown_renderer().render)(
      balanced.document.unwrap_or_else(fn() {
        abort("missing balanced tbl-cell document")
      }),
      @render.make_render_context(
        false,
        fidelity_mode=@product.FidelityMode::Balanced,
        output_mode=@product.OutputMode::Markdown,
      ),
    ).content
  let accurate_markdown = (@render.markdown_renderer().render)(
      accurate.document.unwrap_or_else(fn() {
        abort("missing accurate tbl-cell document")
      }),
      @render.make_render_context(
        false,
        fidelity_mode=@product.FidelityMode::Accurate,
        output_mode=@product.OutputMode::Markdown,
      ),
    ).content
  assert_true(!balanced_markdown.contains("<table>"))
  assert_true(accurate_markdown.contains("<table>"))
  assert_true(accurate_markdown.contains("rowspan=\"2\""))
  assert_true(accurate_markdown.contains("colspan=\"2\""))
  assert_true(accurate_markdown.contains("merged cell"))
}

///|
test "pptx table-cell hyperlinks survive lowering into markdown rendering" {
  let source = @input.input_from_bytes_with_format(
    pptx_contract_table_hyperlink_bytes(),
    "table-link.pptx",
    Some(@input.DetectedFormat::Pptx),
  )
  let parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      source,
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("pptx table hyperlink parse failed: " + err)
  }
  let markdown = (@render.markdown_renderer().render)(
      parsed.document.unwrap_or_else(fn() {
        abort("missing pptx table hyperlink document")
      }),
      @render.make_render_context(
        false,
        fidelity_mode=@product.FidelityMode::Accurate,
        output_mode=@product.OutputMode::Markdown,
      ),
    ).content
  assert_true(markdown.contains("[Spec](https://example.com/spec)"))
}

///|
test "pptx accurate fidelity summarizes grouped decorative shapes instead of emitting fragmented raw placeholders" {
  let parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/pptx/python-pptx/shp-groupshape.pptx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("pptx grouped-shape parse failed: " + err)
  }
  let markdown = (@render.markdown_renderer().render)(
      parsed.document.unwrap_or_else(fn() {
        abort("missing pptx grouped-shape document")
      }),
      @render.make_render_context(
        false,
        fidelity_mode=@product.FidelityMode::Accurate,
        output_mode=@product.OutputMode::Markdown,
      ),
    ).content
  assert_true(markdown.contains("[PPTX grouped decorative shapes: Group 4"))
  assert_true(markdown.contains("roundRect: Rounded Rectangle 1"))
  assert_true(markdown.contains("ellipse: Oval 2"))
  assert_true(markdown.contains("triangle: Isosceles Triangle 3"))
  assert_true(
    !markdown.contains("[PPTX decorative shape omitted: Rounded Rectangle 1]"),
  )
}

///|
test "pptx accurate fidelity promotes center title placeholders to heading blocks" {
  let parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/pptx/openxml-sdk/Presentation.pptx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Debug,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("pptx center-title parse failed: " + err)
  }
  let document = parsed.document.unwrap_or_else(fn() {
    abort("missing pptx center-title document")
  })
  assert_true(document.blocks[1].kind == @core.BlockKind::Heading)
  assert_eq(document.blocks[1].text, "Title")
}

///|
test "pptx accurate fidelity folds decorative slide noise into a single summary block" {
  let parsed = match
    @parser.registry_parse(
      @formats_root.builtin_registry(),
      @input.input_from_path(
        "markitdown-quality-lab/external_quality/pptx/python-pptx/shp-shapes.pptx",
      ),
      @parser.parse_context_with_product_modes(
        @parser.new_parse_context(@input.DetectedFormat::Pptx),
        @product.FidelityMode::Accurate,
        @product.OutputMode::Markdown,
      ),
    ) {
    Ok(value) => value
    Err(err) => fail("pptx visual-noise parse failed: " + err)
  }
  let markdown = (@render.markdown_renderer().render)(
      parsed.document.unwrap_or_else(fn() {
        abort("missing pptx visual-noise document")
      }),
      @render.make_render_context(
        false,
        fidelity_mode=@product.FidelityMode::Accurate,
        output_mode=@product.OutputMode::Markdown,
      ),
    ).content
  assert_true(markdown.contains("[PPTX grouped decorative shapes: Group 4"))
  assert_true(markdown.contains("[PPTX visual-only objects omitted:"))
  assert_true(markdown.contains("connector: Straight Arrow Connector 6"))
  assert_true(markdown.contains("[PPTX unsupported objects summarized:"))
  assert_true(markdown.contains("SmartArt: ppt/diagrams/data1.xml"))
  assert_true(
    !markdown.contains("[PPTX connector omitted: Straight Arrow Connector 6]"),
  )
  assert_true(
    !markdown.contains("[Unsupported PPTX SmartArt: ppt/diagrams/data1.xml]"),
  )
  assert_true(!markdown.contains("## PPTX Warnings"))
  assert_true(!markdown.contains("- unsupported graphic frame: SmartArt"))
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
