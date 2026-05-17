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
fn render_table_rows_for_test(tables : Array[PdfTableCandidate]) -> String {
  let out : Array[String] = []
  for i = 0; i < tables.length(); i = i + 1 {
    out.push("table[" + i.to_string() + "]")
    for row in tables[i].rows {
      out.push("  " + row.join(" | "))
    }
  }
  out.join("\n")
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
  assert_true(tables[0].rows[0] == ["Quarter", "Revenue", "Profit"])
  assert_true(tables[0].rows[1] == ["Q1", "120", "30"])
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
  assert_true(tables[0].rows[0] == ["Alpha", "12", "4.5%"])
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
test "pdf table detector supports sparse borderless rows with heading cells" {
  let page = make_table_test_page(
    [],
    [
      {
        ..make_table_test_block(
          0,
          0,
          "Product Code",
          table_rect(40.0, 700.0, 110.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      {
        ..make_table_test_block(
          1,
          1,
          "Location",
          table_rect(120.0, 700.0, 180.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      {
        ..make_table_test_block(
          2,
          2,
          "Expected",
          table_rect(200.0, 700.0, 260.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      make_table_test_block(
        3,
        3,
        "Actual",
        table_rect(290.0, 700.0, 340.0, 714.0),
      ),
      {
        ..make_table_test_block(
          4,
          4,
          "Variance",
          table_rect(380.0, 700.0, 450.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      make_table_test_block(
        5,
        5,
        "Status",
        table_rect(470.0, 700.0, 520.0, 714.0),
      ),
      {
        ..make_table_test_block(
          6,
          6,
          "SKU-8847",
          table_rect(40.0, 678.0, 100.0, 692.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      make_table_test_block(
        7,
        7,
        "A-12",
        table_rect(120.0, 678.0, 150.0, 692.0),
      ),
      make_table_test_block(8, 8, "450", table_rect(200.0, 678.0, 225.0, 692.0)),
      make_table_test_block(
        9,
        9,
        "B-07",
        table_rect(120.0, 656.0, 150.0, 670.0),
      ),
      make_table_test_block(
        10,
        10,
        "289",
        table_rect(290.0, 656.0, 315.0, 670.0),
      ),
      make_table_test_block(
        11,
        11,
        "- 23",
        table_rect(380.0, 656.0, 410.0, 670.0),
      ),
      {
        ..make_table_test_block(
          12,
          12,
          "SKU-9201",
          table_rect(40.0, 634.0, 100.0, 648.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      make_table_test_block(
        13,
        13,
        "780",
        table_rect(200.0, 634.0, 225.0, 648.0),
      ),
      make_table_test_block(
        14,
        14,
        "778",
        table_rect(290.0, 634.0, 315.0, 648.0),
      ),
      make_table_test_block(
        15,
        15,
        "OK",
        table_rect(470.0, 634.0, 490.0, 648.0),
      ),
      make_table_test_block(
        16,
        16,
        "C-15",
        table_rect(120.0, 612.0, 150.0, 626.0),
      ),
      make_table_test_block(
        17,
        17,
        "+15",
        table_rect(380.0, 612.0, 410.0, 626.0),
      ),
    ],
    [],
  )
  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].header_rows, 1)
  assert_true(
    tables[0].rows[0] ==
    ["Product Code", "Location", "Expected", "Actual", "Variance", "Status"],
  )
  assert_true(tables[0].rows[1] == ["SKU-8847", "A-12", "450", "", "", ""])
  assert_true(tables[0].rows[2] == ["", "B-07", "", "289", "-23", ""])
  assert_true(tables[0].rows[3] == ["SKU-9201", "", "780", "778", "", "OK"])
  assert_true(tables[0].rows[4] == ["", "C-15", "", "", "+15", ""])
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
test "pdf table detector grows union anchors for form-style offset rows" {
  let page = make_table_test_page(
    [],
    [
      {
        ..make_table_test_block(
          0,
          0,
          "Customer Information",
          table_rect(120.0, 700.0, 238.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      {
        ..make_table_test_block(
          1,
          1,
          "Vehicle Information",
          table_rect(350.0, 700.0, 462.0, 714.0),
        ),
        kind: PdfConvertBlockKind::Heading,
        is_heading_candidate: true,
      },
      make_table_test_block(
        2,
        2,
        "Insured name",
        table_rect(80.0, 678.0, 156.0, 692.0),
      ),
      make_table_test_block(
        3,
        3,
        "Bruce Wayne",
        table_rect(167.0, 678.0, 237.0, 692.0),
      ),
      make_table_test_block(
        4,
        4,
        "Year",
        table_rect(333.0, 678.0, 360.0, 692.0),
      ),
      make_table_test_block(
        5,
        5,
        "2025",
        table_rect(398.0, 678.0, 425.0, 692.0),
      ),
      make_table_test_block(
        6,
        6,
        "Claim #",
        table_rect(80.0, 656.0, 122.0, 670.0),
      ),
      make_table_test_block(7, 7, "999", table_rect(256.0, 656.0, 276.0, 670.0)),
      make_table_test_block(
        8,
        8,
        "Make",
        table_rect(333.0, 656.0, 360.0, 670.0),
      ),
      make_table_test_block(
        9,
        9,
        "Batman",
        table_rect(398.0, 656.0, 438.0, 670.0),
      ),
      make_table_test_block(
        10,
        10,
        "Email",
        table_rect(80.0, 634.0, 112.0, 648.0),
      ),
      make_table_test_block(
        11,
        11,
        "batman@wayneindustries.com",
        table_rect(167.0, 634.0, 337.0, 648.0),
      ),
      make_table_test_block(
        12,
        12,
        "VIN",
        table_rect(333.0, 634.0, 353.0, 648.0),
      ),
      make_table_test_block(
        13,
        13,
        "XXX",
        table_rect(398.0, 634.0, 418.0, 648.0),
      ),
    ],
    [],
  )

  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].header_rows, 1)
  assert_true(
    tables[0].rows[0] ==
    ["", "Customer Information", "", "", "Vehicle Information", ""],
  )
  assert_true(
    tables[0].rows[1] == ["Insured name", "", "Bruce Wayne", "", "Year", "2025"],
  )
  assert_true(tables[0].rows[2] == ["Claim #", "", "", "999", "Make", "Batman"])
  assert_true(
    tables[0].rows[3] ==
    ["Email", "", "batman@wayneindustries.com", "", "VIN", "XXX"],
  )
}

///|
test "pdf table detector keeps alternating sparse form rows in one table" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(0, 0, "Name:", table_rect(50.0, 700.0, 80.0, 714.0)),
      make_table_test_block(
        1,
        1,
        "Premier Entertainment Group",
        table_rect(150.0, 700.0, 280.0, 714.0),
      ),
      make_table_test_block(
        2,
        2,
        "Billing Type:",
        table_rect(350.0, 694.0, 412.0, 708.0),
      ),
      make_table_test_block(
        3,
        3,
        "Net 30",
        table_rect(450.0, 694.0, 490.0, 708.0),
      ),
      make_table_test_block(
        4,
        4,
        "Contact:",
        table_rect(50.0, 688.0, 92.0, 702.0),
      ),
      make_table_test_block(
        5,
        5,
        "Michael Chen",
        table_rect(150.0, 688.0, 224.0, 702.0),
      ),
      make_table_test_block(
        6,
        6,
        "Payment Terms:",
        table_rect(350.0, 682.0, 420.0, 696.0),
      ),
      make_table_test_block(
        7,
        7,
        "Corporate",
        table_rect(450.0, 682.0, 510.0, 696.0),
      ),
      make_table_test_block(
        8,
        8,
        "Billing Contact:",
        table_rect(50.0, 676.0, 128.0, 690.0),
      ),
      make_table_test_block(
        9,
        9,
        "accounting@premierent.com",
        table_rect(150.0, 676.0, 320.0, 690.0),
      ),
      make_table_test_block(
        10,
        10,
        "Commission:",
        table_rect(350.0, 670.0, 410.0, 684.0),
      ),
      make_table_test_block(
        11,
        11,
        "10%",
        table_rect(450.0, 670.0, 476.0, 684.0),
      ),
    ],
    [],
  )

  let tables = detect_pdf_tables(page, false)
  if tables.length() != 1 {
    fail(render_table_rows_for_test(tables))
  }
  let flattened = tables[0].rows.map(row => row.join(" | ")).join("\n")
  if !flattened.contains("Name: | Premier Entertainment Group") ||
    !flattened.contains("Contact: | Michael Chen") ||
    !flattened.contains("Billing Type: | Net 30") {
    fail(render_table_rows_for_test(tables))
  }
}

///|
test "pdf table detector supports two-row summary tables" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(
        0,
        0,
        "Start Date",
        table_rect(50.0, 700.0, 96.0, 714.0),
      ),
      make_table_test_block(
        1,
        1,
        "End Date",
        table_rect(140.0, 700.0, 182.0, 714.0),
      ),
      make_table_test_block(
        2,
        2,
        "# Shows",
        table_rect(220.0, 700.0, 260.0, 714.0),
      ),
      make_table_test_block(
        3,
        3,
        "Gross Amount",
        table_rect(300.0, 700.0, 358.0, 714.0),
      ),
      make_table_test_block(
        4,
        4,
        "Net Amount",
        table_rect(400.0, 700.0, 452.0, 714.0),
      ),
      make_table_test_block(
        5,
        5,
        "12/20/24",
        table_rect(50.0, 678.0, 90.0, 692.0),
      ),
      make_table_test_block(
        6,
        6,
        "12/31/24",
        table_rect(140.0, 678.0, 182.0, 692.0),
      ),
      make_table_test_block(7, 7, "48", table_rect(230.0, 678.0, 242.0, 692.0)),
      make_table_test_block(
        8,
        8,
        "$12,500.00",
        table_rect(300.0, 678.0, 354.0, 692.0),
      ),
      make_table_test_block(
        9,
        9,
        "$11,250.00",
        table_rect(400.0, 678.0, 454.0, 692.0),
      ),
    ],
    [],
  )

  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 1)
  assert_eq(tables[0].header_rows, 1)
  assert_true(
    tables[0].rows[0] ==
    ["Start Date", "End Date", "# Shows", "Gross Amount", "Net Amount"],
  )
  assert_true(
    tables[0].rows[1] ==
    ["12/20/24", "12/31/24", "48", "$12,500.00", "$11,250.00"],
  )
}

///|
test "pdf table detector breaks table run across skipped section label rows" {
  let page = make_table_test_page(
    [],
    [
      make_table_test_block(
        0,
        0,
        "Hours",
        table_rect(258.0, 700.0, 288.0, 714.0),
      ),
      make_table_test_block(
        1,
        1,
        "Rate",
        table_rect(310.0, 700.0, 334.0, 714.0),
      ),
      make_table_test_block(
        2,
        2,
        "Cost",
        table_rect(370.0, 700.0, 394.0, 714.0),
      ),
      make_table_test_block(
        3,
        3,
        "Parts",
        table_rect(80.0, 678.0, 108.0, 692.0),
      ),
      make_table_test_block(
        4,
        4,
        "2,100",
        table_rect(370.0, 678.0, 400.0, 692.0),
      ),
      make_table_test_block(
        5,
        5,
        "Body Labor",
        table_rect(80.0, 656.0, 142.0, 670.0),
      ),
      make_table_test_block(6, 6, "2", table_rect(258.0, 656.0, 264.0, 670.0)),
      make_table_test_block(7, 7, "150", table_rect(310.0, 656.0, 328.0, 670.0)),
      make_table_test_block(8, 8, "300", table_rect(370.0, 656.0, 388.0, 670.0)),
      make_table_test_block(
        9,
        9,
        "Supplies",
        table_rect(80.0, 634.0, 132.0, 648.0),
      ),
      make_table_test_block(
        10,
        10,
        "Paint Supplies",
        table_rect(160.0, 612.0, 240.0, 626.0),
      ),
      make_table_test_block(
        11,
        11,
        "60",
        table_rect(370.0, 612.0, 382.0, 626.0),
      ),
      make_table_test_block(
        12,
        12,
        "Body Supplies",
        table_rect(160.0, 590.0, 236.0, 604.0),
      ),
      make_table_test_block(
        13,
        13,
        "30",
        table_rect(370.0, 590.0, 382.0, 604.0),
      ),
      make_table_test_block(
        14,
        14,
        "Other Charges",
        table_rect(80.0, 568.0, 154.0, 582.0),
      ),
      make_table_test_block(
        15,
        15,
        "15",
        table_rect(370.0, 568.0, 382.0, 582.0),
      ),
    ],
    [],
  )

  let tables = detect_pdf_tables(page, false)
  assert_eq(tables.length(), 2)
  assert_true(tables[0].rows[0] == ["", "Hours", "Rate", "Cost"])
  assert_true(tables[0].rows[1] == ["Parts", "", "", "2,100"])
  assert_true(tables[1].rows[0] == ["", "Paint Supplies", "60"])
  assert_true(tables[1].rows[1] == ["", "Body Supplies", "30"])
  assert_true(tables[1].rows[2] == ["Other Charges", "", "15"])
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
