///|
fn block_test_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_block_test_line(
  line_index : Int,
  source_block_index : Int,
  source_block_line_count : Int,
  text : String,
) -> PdfConvertLine {
  {
    _page_index: 0,
    line_index,
    text,
    _source_block_index: source_block_index,
    source_block_line_count,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: block_test_rect(12.0, 700.0, 300.0, 760.0),
    source_block_dominant_font_size: Some(12.0),
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: false,
    is_page_number_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: block_test_rect(12.0, 720.0, 300.0, 732.0),
    font_size: Some(12.0),
    font_name: Some("Test"),
    indent_left: Some(12.0),
    indent_right: Some(300.0),
    alignment_hint: Some("left"),
    line_gap_before: Some(2.0),
    _line_gap_after: Some(2.0),
    line_height: Some(12.0),
    baseline_y: Some(726.0 - line_index.to_double() * 14.0),
    is_wrapped_candidate: true,
    is_same_paragraph_with_prev_candidate: true,
  }
}

///|
fn make_block_test_page(lines : Array[PdfConvertLine]) -> PdfConvertPage {
  {
    _page_index: 0,
    media_box: Some(block_test_rect(0.0, 0.0, 400.0, 800.0)),
    crop_box: None,
    lines,
    blocks: [],
    images: [],
    annotations: [],
    objects: [],
  }
}

///|
test "pdf convert blocks regroup same source block hard wraps with spaces" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(
        0, 0, 2, "This project aims to build a pipeline for docx, pdf, xlsx,",
      ),
      make_block_test_line(1, 0, 2, "pptx, and html."),
      make_block_test_line(2, 1, 1, "Next paragraph."),
    ]),
  )

  assert_eq(page.blocks.length(), 2)
  assert_eq(
    page.blocks[0].text,
    "This project aims to build a pipeline for docx, pdf, xlsx, pptx, and html.",
  )
  assert_eq(page.blocks[0].line_count, 2)
  assert_eq(page.blocks[1].text, "Next paragraph.")
}

///|
test "pdf convert blocks keep same source short receipt-like lines separate" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      {
        ..make_block_test_line(0, 0, 3, "Store #0342 - Downtown SF"),
        is_wrapped_candidate: false,
        is_same_paragraph_with_prev_candidate: false,
      },
      {
        ..make_block_test_line(1, 0, 3, "11/23/2024 14:32:18 PST"),
        is_wrapped_candidate: false,
        is_same_paragraph_with_prev_candidate: false,
      },
      {
        ..make_block_test_line(2, 0, 3, "TXN: TXN-98765-2024"),
        is_wrapped_candidate: false,
        is_same_paragraph_with_prev_candidate: false,
      },
    ]),
  )

  assert_eq(page.blocks.length(), 3)
  assert_eq(page.blocks[0].text, "Store #0342 - Downtown SF")
  assert_eq(page.blocks[1].text, "11/23/2024 14:32:18 PST")
  assert_eq(page.blocks[2].text, "TXN: TXN-98765-2024")
}

///|
test "pdf convert blocks keep same source lowercase continuation grouped without flags" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      {
        ..make_block_test_line(0, 0, 2, "Visit the example website"),
        is_wrapped_candidate: false,
        is_same_paragraph_with_prev_candidate: false,
      },
      {
        ..make_block_test_line(1, 0, 2, "for details."),
        is_wrapped_candidate: false,
        is_same_paragraph_with_prev_candidate: false,
      },
    ]),
  )

  assert_eq(page.blocks.length(), 1)
  assert_eq(page.blocks[0].text, "Visit the example website for details.")
}

///|
test "pdf convert blocks keep cjk wrapped lines tight without extra spaces" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(
        0, 0, 2, "首先完成统一 IR，然后逐步支持 docx、pdf、xlsx、",
      ),
      make_block_test_line(1, 0, 2, "pptx 和 html。"),
    ]),
  )

  assert_eq(page.blocks.length(), 1)
  assert_eq(
    page.blocks[0].text,
    "首先完成统一 IR，然后逐步支持 docx、pdf、xlsx、pptx 和 html。",
  )
}

///|
test "pdf convert blocks repair hyphenated line wraps when regrouping a source block" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "inter-"),
      make_block_test_line(1, 0, 2, "national"),
    ]),
  )

  assert_eq(page.blocks.length(), 1)
  assert_eq(page.blocks[0].text, "international")

  let complex = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "com-"),
      make_block_test_line(1, 0, 2, "plex"),
    ]),
  )
  assert_eq(complex.blocks.length(), 1)
  assert_eq(complex.blocks[0].text, "complex")
}

///|
test "pdf convert blocks preserve semantic hyphen compounds and connector phrases" {
  let compound = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "conversation-"),
      make_block_test_line(1, 0, 2, "centric computation and control."),
    ]),
  )
  assert_eq(compound.blocks.length(), 1)
  assert_eq(
    compound.blocks[0].text,
    "conversation-centric computation and control.",
  )

  let connector = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "single-"),
      make_block_test_line(1, 0, 2, "or multi-turn dialogs"),
    ]),
  )
  assert_eq(connector.blocks.length(), 1)
  assert_eq(connector.blocks[0].text, "single- or multi-turn dialogs")
}

///|
test "pdf convert blocks insert space after wrapped ascii sentence punctuation" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "How can we support different capacities?"),
      make_block_test_line(1, 0, 2, "We desire a unified interface."),
    ]),
  )

  assert_eq(page.blocks.length(), 1)
  assert_eq(
    page.blocks[0].text,
    "How can we support different capacities? We desire a unified interface.",
  )
}

///|
test "pdf convert blocks keep numeric separators tight across wrapped lines" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 3, "Print Date 12/15/2024 14:"),
      make_block_test_line(1, 0, 3, "30:"),
      make_block_test_line(2, 0, 3, "22"),
      make_block_test_line(3, 1, 2, "$11,"),
      make_block_test_line(4, 1, 2, "250.00"),
    ]),
  )

  assert_eq(page.blocks.length(), 2)
  assert_eq(page.blocks[0].text, "Print Date 12/15/2024 14:30:22")
  assert_eq(page.blocks[1].text, "$11,250.00")
}

///|
test "pdf convert blocks keep same-row split cells as separate blocks" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      {
        ..make_block_test_line(0, 0, 1, "Email"),
        _bbox: block_test_rect(80.0, 720.0, 112.0, 732.0),
        baseline_y: Some(726.0),
        line_height: Some(12.0),
      },
      {
        ..make_block_test_line(1, 0, 1, "gabriel@contoso.com"),
        _bbox: block_test_rect(160.0, 720.0, 272.0, 732.0),
        baseline_y: Some(726.0),
        line_height: Some(12.0),
      },
      {
        ..make_block_test_line(2, 0, 1, "VIN"),
        _bbox: block_test_rect(312.0, 720.0, 332.0, 732.0),
        baseline_y: Some(726.0),
        line_height: Some(12.0),
      },
      {
        ..make_block_test_line(3, 0, 1, "1C4RJFBG2NC123456"),
        _bbox: block_test_rect(372.0, 720.0, 474.0, 732.0),
        baseline_y: Some(726.0),
        line_height: Some(12.0),
      },
    ]),
  )

  assert_eq(page.blocks.length(), 4)
  assert_eq(page.blocks[0].text, "Email")
  assert_eq(page.blocks[1].text, "gabriel@contoso.com")
  assert_eq(page.blocks[2].text, "VIN")
  assert_eq(page.blocks[3].text, "1C4RJFBG2NC123456")
}

///|
test "pdf convert blocks keep cjk punctuation tight across wrapped lines" {
  let page = build_convert_page_blocks(
    make_block_test_page([
      make_block_test_line(0, 0, 2, "第一句。"),
      make_block_test_line(1, 0, 2, "第二句继续。"),
    ]),
  )

  assert_eq(page.blocks.length(), 1)
  assert_eq(page.blocks[0].text, "第一句。第二句继续。")
}
