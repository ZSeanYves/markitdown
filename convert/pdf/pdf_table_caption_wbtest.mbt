///|
fn table_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_table_test_line(
  line_index : Int,
  text : String,
  bbox : @model.PdfRect,
) -> PdfConvertLine {
  {
    _page_index: 0,
    line_index,
    text,
    _source_block_index: line_index,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: bbox,
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
    _bbox: bbox,
    font_size: Some(12.0),
    font_name: Some("Test"),
    indent_left: Some(bbox.x0),
    indent_right: None,
    alignment_hint: Some("left"),
    line_gap_before: Some(4.0),
    _line_gap_after: Some(4.0),
    line_height: Some(12.0),
    baseline_y: Some((bbox.y0 + bbox.y1) / 2.0),
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn make_table_test_block(
  block_index : Int,
  line_start : Int,
  text : String,
  bbox : @model.PdfRect,
) -> PdfConvertBlock {
  {
    _page_index: 0,
    block_index,
    kind: PdfConvertBlockKind::Paragraph,
    text,
    rich_inlines: None,
    line_start,
    line_end: line_start,
    source_block_index: block_index,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: bbox,
    source_block_dominant_font_size: Some(12.0),
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: false,
    is_noise_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: bbox,
    dominant_font_size: Some(12.0),
    dominant_font_name: Some("Test"),
    top_y: bbox.y1,
    left_x: bbox.x0,
    line_count: 1,
    first_indent_left: Some(bbox.x0),
    last_indent_left: Some(bbox.x0),
    first_indent_right: None,
    last_indent_right: None,
    first_alignment_hint: Some("left"),
    last_alignment_hint: Some("left"),
    first_line_gap_before: Some(4.0),
    last_line_gap_after: Some(4.0),
    first_line_height: Some(12.0),
    last_line_height: Some(12.0),
    first_baseline_y: Some((bbox.y0 + bbox.y1) / 2.0),
    last_baseline_y: Some((bbox.y0 + bbox.y1) / 2.0),
    first_is_wrapped_candidate: false,
    last_is_wrapped_candidate: false,
    first_is_same_paragraph_with_prev_candidate: false,
    last_is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn make_caption_test_image(
  bbox : @model.PdfRect,
  image_index : Int,
) -> PdfConvertImage {
  {
    _page_index: 0,
    _image_index: image_index,
    path: "assets/image" + image_index.to_string() + ".jpg",
    alt_text: None,
    _caption: None,
    _bbox: bbox,
    top_y: bbox.y1,
    left_x: bbox.x0,
    _width_px: 100,
    _height_px: 80,
    colorspace: None,
    bits_per_component: None,
    image_filter: None,
    object_ref: Some("img-" + image_index.to_string()),
    inline_image: false,
    source_refs_count: 0,
    source_image_id: "img-" + image_index.to_string(),
  }
}

///|
fn make_table_test_page(
  lines : Array[PdfConvertLine],
  blocks : Array[PdfConvertBlock],
  images : Array[PdfConvertImage],
) -> PdfConvertPage {
  {
    _page_index: 0,
    media_box: Some(table_rect(0.0, 0.0, 400.0, 800.0)),
    crop_box: None,
    lines,
    blocks,
    images,
    annotations: [],
    objects: build_page_objects(blocks, images),
  }
}

///|
test "pdf table detector matches simple grid rows" {
  let lines : Array[PdfConvertLine] = []
  let blocks = [
    make_table_test_block(
      0,
      0,
      "Quarter",
      table_rect(40.0, 700.0, 100.0, 714.0),
    ),
    make_table_test_block(
      1,
      1,
      "Revenue",
      table_rect(150.0, 700.0, 220.0, 714.0),
    ),
    make_table_test_block(
      2,
      2,
      "Profit",
      table_rect(250.0, 700.0, 300.0, 714.0),
    ),
    make_table_test_block(3, 3, "Q1", table_rect(40.0, 680.0, 70.0, 694.0)),
    make_table_test_block(4, 4, "120", table_rect(150.0, 680.0, 180.0, 694.0)),
    make_table_test_block(5, 5, "30", table_rect(250.0, 680.0, 280.0, 694.0)),
    make_table_test_block(6, 6, "Q2", table_rect(40.0, 660.0, 70.0, 674.0)),
    make_table_test_block(7, 7, "140", table_rect(150.0, 660.0, 180.0, 674.0)),
    make_table_test_block(8, 8, "35", table_rect(250.0, 660.0, 280.0, 674.0)),
  ]
  let page = make_table_test_page(lines, blocks, [])
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].header_rows, 1)
  assert_eq(tables[0].rows[0], ["Quarter", "Revenue", "Profit"])
  assert_eq(tables[0].rows[1], ["Q1", "120", "30"])
}

///|
test "pdf table detector rejects paragraph-like aligned lines" {
  let lines = [
    make_table_test_line(
      0,
      "This paragraph starts here and keeps flowing naturally",
      table_rect(40.0, 700.0, 330.0, 714.0),
    ),
    make_table_test_line(
      1,
      "with another continuation line that should stay body text",
      table_rect(40.0, 680.0, 330.0, 694.0),
    ),
  ]
  let page = make_table_test_page(lines, [], [])
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 0)
}

///|
test "pdf image caption inference matches only high-confidence figure text" {
  let image = make_caption_test_image(table_rect(80.0, 420.0, 280.0, 560.0), 1)
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "Figure 1. Revenue trend",
      table_rect(100.0, 392.0, 260.0, 406.0),
    ),
    left_x: 100.0,
  }
  let page = make_table_test_page([], [caption_block], [image])
  let (captions, consumed) = infer_page_image_captions(page, false)
  assert_eq(captions.length(), 1)
  match captions[0] {
    Some("Figure 1. Revenue trend") => ()
    _ => fail("expected matched figure caption")
  }
  assert_true(consumed.contains(0))
}

///|
test "pdf image caption inference rejects ambiguous nearby text with two images" {
  let image1 = make_caption_test_image(table_rect(60.0, 420.0, 160.0, 520.0), 1)
  let image2 = make_caption_test_image(
    table_rect(220.0, 420.0, 320.0, 520.0),
    2,
  )
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "Figure 1. Shared label",
      table_rect(120.0, 392.0, 260.0, 406.0),
    ),
    left_x: 120.0,
  }
  let page = make_table_test_page([], [caption_block], [image1, image2])
  let (captions, consumed) = infer_page_image_captions(page, false)
  assert_eq(captions.length(), 2)
  match captions[0] {
    None => ()
    _ => fail("expected first caption to stay None")
  }
  match captions[1] {
    None => ()
    _ => fail("expected second caption to stay None")
  }
  assert_true(!consumed.contains(0))
}

///|
test "pdf table detector supports numeric columns with headerless rows" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(
        0,
        0,
        "Alpha",
        table_rect(40.0, 700.0, 100.0, 714.0),
      ),
      make_table_test_block(1, 1, "12", table_rect(170.0, 700.0, 190.0, 714.0)),
      make_table_test_block(
        2,
        2,
        "4.5%",
        table_rect(280.0, 700.0, 320.0, 714.0),
      ),
      make_table_test_block(3, 3, "Beta", table_rect(40.0, 678.0, 90.0, 692.0)),
      make_table_test_block(4, 4, "9", table_rect(170.0, 678.0, 185.0, 692.0)),
      make_table_test_block(
        5,
        5,
        "3.2%",
        table_rect(280.0, 678.0, 320.0, 692.0),
      ),
      make_table_test_block(
        6,
        6,
        "Gamma",
        table_rect(40.0, 656.0, 100.0, 670.0),
      ),
      make_table_test_block(7, 7, "7", table_rect(170.0, 656.0, 185.0, 670.0)),
      make_table_test_block(
        8,
        8,
        "2.1%",
        table_rect(280.0, 656.0, 320.0, 670.0),
      ),
    ],
    [],
  )
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].rows[0], ["Alpha", "12", "4.5%"])
  assert_eq(tables[0].header_rows, 0)
}

///|
test "pdf table detector rejects toc-like dot leaders" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(
        0,
        0,
        "Overview .... 1",
        table_rect(40.0, 700.0, 240.0, 714.0),
      ),
      make_table_test_block(
        1,
        1,
        "Methods .... 3",
        table_rect(40.0, 678.0, 240.0, 692.0),
      ),
      make_table_test_block(
        2,
        2,
        "Results .... 7",
        table_rect(40.0, 656.0, 240.0, 670.0),
      ),
    ],
    [],
  )
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 0)
}

///|
test "pdf table detector rejects list-like aligned rows" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(
        0,
        0,
        "1. Gather requirements",
        table_rect(40.0, 700.0, 220.0, 714.0),
      ),
      make_table_test_block(
        1,
        1,
        "Done",
        table_rect(280.0, 700.0, 330.0, 714.0),
      ),
      make_table_test_block(
        2,
        2,
        "2. Implement fixes",
        table_rect(40.0, 678.0, 220.0, 692.0),
      ),
      make_table_test_block(
        3,
        3,
        "Open",
        table_rect(280.0, 678.0, 330.0, 692.0),
      ),
      make_table_test_block(
        4,
        4,
        "3. Review output",
        table_rect(40.0, 656.0, 220.0, 670.0),
      ),
      make_table_test_block(
        5,
        5,
        "Queued",
        table_rect(280.0, 656.0, 330.0, 670.0),
      ),
    ],
    [],
  )
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 0)
}

///|
test "pdf image caption inference supports caption above image" {
  let image = make_caption_test_image(table_rect(80.0, 420.0, 280.0, 560.0), 1)
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "Figure 2: Revenue trend",
      table_rect(100.0, 566.0, 260.0, 580.0),
    ),
    left_x: 100.0,
  }
  let page = make_table_test_page([], [caption_block], [image])
  let (captions, consumed) = infer_page_image_captions(page, false)
  match captions[0] {
    Some("Figure 2: Revenue trend") => ()
    _ => fail("expected above-image caption to match")
  }
  assert_true(consumed.contains(0))
}

///|
test "pdf image caption inference supports chinese figure prefix" {
  let image = make_caption_test_image(table_rect(80.0, 420.0, 280.0, 560.0), 1)
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "图1：营收趋势",
      table_rect(110.0, 392.0, 250.0, 406.0),
    ),
    left_x: 110.0,
  }
  let page = make_table_test_page([], [caption_block], [image])
  let (captions, consumed) = infer_page_image_captions(page, false)
  match captions[0] {
    Some("图1：营收趋势") => ()
    _ => fail("expected chinese figure caption to match")
  }
  assert_true(consumed.contains(0))
}

///|
test "pdf image caption inference rejects table-like caption near image" {
  let image = make_caption_test_image(table_rect(80.0, 420.0, 280.0, 560.0), 1)
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "Table 1. Revenue trend",
      table_rect(100.0, 392.0, 260.0, 406.0),
    ),
    left_x: 100.0,
  }
  let page = make_table_test_page([], [caption_block], [image])
  let (captions, consumed) = infer_page_image_captions(page, false)
  match captions[0] {
    None => ()
    _ => fail("expected table-like label to be rejected as image caption")
  }
  assert_true(!consumed.contains(0))
}

///|
test "pdf image caption inference rejects body-like no-prefix paragraph" {
  let image = make_caption_test_image(table_rect(80.0, 420.0, 280.0, 560.0), 1)
  let caption_block = {
    ..make_table_test_block(
      0,
      0,
      "This paragraph explains the chart in more detail.",
      table_rect(80.0, 392.0, 300.0, 406.0),
    ),
    left_x: 80.0,
  }
  let page = make_table_test_page([], [caption_block], [image])
  let (captions, consumed) = infer_page_image_captions(page, false)
  match captions[0] {
    None => ()
    _ => fail("expected body-like paragraph to stay unattached")
  }
  assert_true(!consumed.contains(0))
}
