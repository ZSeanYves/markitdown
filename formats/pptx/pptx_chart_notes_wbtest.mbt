///|
test "PPTX chart caption detection covers supported prefixes and whitespace" {
  assert_true(pptx_caption_text_has_prefix("Figure 1"))
  assert_true(pptx_caption_text_has_prefix(" fig. 2"))
  assert_true(pptx_caption_text_has_prefix("CAPTION: result"))
  assert_true(!pptx_caption_text_has_prefix("diagram"))
  assert_true(!pptx_caption_text_has_prefix(""))
}

///|
test "PPTX chart serial parser rejects ambiguous and fractional dates" {
  assert_true(pptx_parse_chart_serial_int("") is None)
  assert_true(pptx_parse_chart_serial_int(" 45000 ") == Some(45000))
  assert_true(pptx_parse_chart_serial_int("45000.000") == Some(45000))
  assert_true(pptx_parse_chart_serial_int("45000.001") is None)
  assert_true(pptx_parse_chart_serial_int(".0") is None)
  assert_true(pptx_parse_chart_serial_int("45000.") is None)
  assert_true(pptx_parse_chart_serial_int("45.0.0") is None)
  assert_true(pptx_parse_chart_serial_int("4.5e4") is None)
  assert_true(pptx_parse_chart_serial_int("-1") is None)
  assert_true(pptx_parse_chart_serial_int("invalid") is None)
}

///|
test "PPTX chart Excel dates cover bounds leap years and display fallback" {
  assert_true(pptx_chart_excel_serial_date("19999") is None)
  assert_true(pptx_chart_excel_serial_date("50001") is None)
  assert_true(pptx_chart_excel_serial_date("invalid") is None)
  assert_true(pptx_chart_excel_serial_date("20000") == Some("1954-10-03"))
  assert_true(pptx_chart_excel_serial_date("25569") == Some("1970-01-01"))
  assert_true(pptx_chart_excel_serial_date("43890") == Some("2020-02-29"))
  assert_true(pptx_chart_excel_serial_date("50000") == Some("2036-11-21"))
  assert_eq(pptx_chart_display_value(" 25569 "), "1970-01-01")
  assert_eq(pptx_chart_display_value(" category "), "category")
  assert_true(pptx_excel_date_components(0) == (0, 0, 0))
  assert_true(pptx_excel_date_components(1) == (1900, 1, 1))
  assert_true(pptx_excel_date_components(59) == (1900, 2, 28))
  assert_true(pptx_excel_date_components(60) == (1900, 2, 28))
  assert_true(pptx_excel_date_components(61) == (1900, 3, 1))
}

///|
test "PPTX chart calendar helpers cover Gregorian leap rules and month tables" {
  assert_true(pptx_is_leap_year(2000))
  assert_true(!pptx_is_leap_year(1900))
  assert_true(pptx_is_leap_year(2024))
  assert_true(!pptx_is_leap_year(2023))
  assert_true(
    pptx_month_day_table(2024) ==
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
  )
  assert_true(
    pptx_month_day_table(2023) ==
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
  )
}

///|
test "PPTX malformed package fails closed with initialized product diagnostics" {
  let capability = pptx_parser_capability()
  assert_true(capability.requires_random_access)
  assert_true(capability.supports_document_ir)
  assert_true(capability.produces_tables)
  let source = @input.input_from_bytes_with_format(
    Bytes::from_array([1, 2, 3].map(Int::to_byte)),
    "broken.pptx",
    Some(Pptx),
  )
  let result = (pptx_parser().parse)(source, @parser.new_parse_context(Pptx)).unwrap()
  assert_true(result.document.unwrap().blocks.length() == 0)
  assert_true(result.diagnostics.errors.length() == 1)
  assert_true(
    result.diagnostics.degraded_features.contains("pptx_parse_failure"),
  )
  assert_true(
    result.diagnostics.metrics.get("office_document_kind") == Some("pptx"),
  )
  assert_true(result.diagnostics.metrics.get("pptx_slide_count") == Some("0"))
  assert_true(result.diagnostics.metrics.get("error_count") == Some("1"))
  assert_true(result.diagnostics.pass_trace.contains("parse:pptx_parser"))
}

///|
test "PPTX parser lowers repository notes groups tables hidden and reading-order fixtures" {
  let fixtures = [
    "samples/fixtures/contracts/pptx/pptx_speaker_notes_basic.pptx", "samples/fixtures/contracts/pptx/pptx_hidden_slides_policy.pptx",
    "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx",
  ]
  for path in fixtures {
    let result = (pptx_parser().parse)(
      @input.input_from_path(path),
      @parser.new_parse_context(Pptx),
    ).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    assert_true(result.document.unwrap().blocks.length() > 0)
    assert_true(result.diagnostics.metrics.get("pptx_slide_count") != Some("0"))
  }
}

///|
test "PPTX parser lowers repository accurate presentation contracts" {
  let fixtures = [
    "samples/fixtures/contracts/pptx/pptx_callout_blocks_basic.pptx", "samples/fixtures/contracts/pptx/pptx_hidden_slides_policy.pptx",
    "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx", "samples/fixtures/contracts/pptx/pptx_speaker_notes_basic.pptx",
  ]
  let context = @parser.parse_context_with_execution_profiles(
    @parser.parse_context_with_product_modes(
      @parser.new_parse_context(Pptx),
      Accurate,
      Markdown,
    ),
    Standard,
    AccurateSemantic,
    NotesAppendixFirst,
    @product.make_accurate_feature_profile([
      PptxReadingOrder,
      PptxGroupSummary,
      PptxHiddenSlideSemantics,
      PptxNotesAppendix,
    ]),
  )
  for path in fixtures {
    let result = (pptx_parser().parse)(@input.input_from_path(path), context).unwrap()
    assert_eq(result.diagnostics.errors.length(), 0)
    assert_true(result.document.unwrap().blocks.length() > 0)
    assert_true(result.diagnostics.metrics.get("pptx_slide_count") != Some("0"))
    assert_true(
      result.diagnostics.metrics.get("office_document_kind") == Some("pptx"),
    )
  }
}

///|
test "PPTX parser extracts repository image contract assets" {
  let result = (pptx_parser().parse)(
    @input.input_from_path(
      "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
    ),
    @parser.new_parse_context(Pptx),
  ).unwrap()
  assert_eq(result.diagnostics.errors.length(), 0)
  assert_true(result.document.unwrap().assets.length() > 0)
}

///|
test "PPTX synthetic chart cache lowers title date categories and series table" {
  let path = "samples/fixtures/contracts/pptx/pptx_chart_cache_synthetic.pptx"
  let prepared = @pptxdoc.prepare_pptx_document_from_source(
    @input.input_from_path(path),
  ).unwrap()
  assert_true(prepared.document.slides.length() == 1)
  let result = (pptx_parser().parse)(
    @input.input_from_path(path),
    @parser.new_parse_context(Pptx),
  ).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text == "Quarterly revenue"))
  let tables = blocks.filter(block => block.kind == Table)
  assert_true(tables.length() == 2)
  let table = tables[0]
  assert_true(table.children.length() == 3)
  assert_true(table.children[1].children[0].text == "1970-01-01")
  assert_true(table.children[1].children[1].text == "10")
  assert_true(table.children[1].children[2].text == "30")
  assert_true(result.diagnostics.errors.length() == 0)
}

///|
test "PPTX synthetic fixtures cover shape source references and hidden notes" {
  let paths = [
    "samples/fixtures/contracts/pptx/pptx_reading_order_geometry.pptx", "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
    "samples/fixtures/contracts/pptx/pptx_hidden_slides_policy.pptx",
  ]
  let mut seen_shape = false
  let mut seen_group = false
  let mut seen_picture = false
  let mut seen_table = false
  for path in paths {
    let source = @input.input_from_path(path)
    let prepared = @pptxdoc.prepare_pptx_document_from_source(source).unwrap()
    assert_true(prepared.document.slides.length() > 0)
    ignore(pptx_root_source_ref(source))
    for slide in prepared.document.slides {
      ignore(pptx_slide_source_ref(source, slide, None, None))
      ignore(hidden_slide_note_text(slide))
      for obj in slide.objects {
        match obj {
          Shape(shape) => {
            seen_shape = true
            let source_ref = pptx_shape_source_ref(
              source,
              slide,
              shape,
              None,
              true,
            )
            assert_true(
              source_ref.extra.get("slide_part") == Some(slide.part_name),
            )
            ignore(pptx_next_shape_top(slide, shape))
            ignore(pptx_slide_reading_order_key(slide, shape.source_key))
          }
          Group(group) => {
            seen_group = true
            ignore(pptx_group_source_ref(source, slide, group, true))
            ignore(pptx_object_reading_order_key(obj, group.source_key))
          }
          Picture(picture) => {
            seen_picture = true
            ignore(pptx_picture_source_ref(source, slide, picture, true))
            ignore(pptx_object_reading_order_key(obj, picture.source_key))
          }
          Table(table) => {
            seen_table = true
            ignore(pptx_table_source_ref(source, slide, table, true))
            ignore(pptx_object_reading_order_key(obj, table.source_key))
          }
          _ => ()
        }
      }
    }
  }
  assert_true(seen_shape)
  ignore(seen_group)
  ignore(seen_table)
  assert_true(!seen_picture)
  assert_true(
    [
      @pptxdoc.PptxPlaceholderKind::Title,
      CenterTitle,
      Subtitle,
      Body,
      Footer,
      Date,
      SlideNumber,
      Picture,
      Table,
      Unknown,
    ].map(pptx_placeholder_kind_to_string) ==
    [
      "title", "center_title", "subtitle", "body", "footer", "date", "slide_number",
      "picture", "table", "unknown",
    ],
  )
  let diagnostics = @core.empty_diagnostics()
  pptx_note_hidden_slide_skipped(diagnostics, 2)
  pptx_note_hidden_slide_skipped(diagnostics, 2)
  assert_eq(diagnostics.warnings.length(), 1)
}
