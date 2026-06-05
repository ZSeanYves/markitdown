///|
test "pdf convert lines normalize numeric punctuation spacing" {
  assert_eq(
    normalize_convert_line_text("Print Date 12/15/2024 14: 30: 22"),
    "Print Date 12/15/2024 14:30:22",
  )
  assert_eq(normalize_convert_line_text("$11, 250.00"), "$11,250.00")
  assert_eq(normalize_convert_line_text("7: 00 PM"), "7:00 PM")
}

///|
fn line_test_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn line_test_source_ref(op_index : Int) -> @model.PdfSourceRef {
  {
    page_index: 0,
    source_stream_index: 0,
    source_op_index: op_index,
    text_object_id: None,
    content_order_index: Some(op_index),
    source_object_ref: None,
  }
}

///|
fn line_test_span(
  text : String,
  x0 : Double,
  x1 : Double,
  y : Double,
  op_index : Int,
) -> @model.PdfTextSpan {
  {
    id: "s-" + op_index.to_string(),
    bbox: line_test_rect(x0, y - 8.0, x1, y + 4.0),
    origin: { x: x0, y },
    text,
    font_name: Some("Test"),
    font_family: Some("Test"),
    font_size: Some(12.0),
    is_bold: false,
    is_italic: false,
    is_monospace: false,
    fill_color: None,
    stroke_color: None,
    char_spacing: None,
    word_spacing: None,
    text_rise: None,
    scale_x: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    language_hint: None,
    chars: [],
    source_refs: [line_test_source_ref(op_index)],
    break_before: false,
    break_reason: None,
  }
}

///|
fn line_test_line(spans : Array[@model.PdfTextSpan]) -> @model.PdfTextLine {
  {
    id: "l",
    bbox: @model.spans_bbox(spans).unwrap_or(line_test_rect(0.0, 0.0, 0.0, 0.0)),
    baseline_y: Some(spans[0].origin.y),
    ascent: None,
    descent: None,
    line_height: Some(12.0),
    indent_left: Some(spans[0].bbox.x0),
    indent_right: Some(spans[spans.length() - 1].bbox.x1),
    alignment_hint: Some("left"),
    line_gap_before: Some(4.0),
    line_gap_after: Some(4.0),
    spans,
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
    source_refs: [line_test_source_ref(0)],
  }
}

///|
fn line_test_block(lines : Array[@model.PdfTextLine]) -> @model.PdfTextBlock {
  {
    id: "b",
    bbox: @model.lines_bbox(lines).unwrap_or(line_test_rect(0.0, 0.0, 0.0, 0.0)),
    kind: @model.PdfTextBlockKind::Text,
    rotation: None,
    dominant_font_name: Some("Test"),
    dominant_font_size: Some(12.0),
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    z_index: None,
    lines,
    is_heading_candidate: false,
    is_header_footer_candidate: false,
    is_page_number_candidate: false,
    is_table_cell_candidate: false,
    is_caption_candidate: false,
    is_artifact_candidate: false,
    source_refs: [line_test_source_ref(0)],
  }
}

///|
fn line_test_block_with_flags(
  lines : Array[@model.PdfTextLine],
  is_heading_candidate : Bool,
  is_page_number_candidate : Bool,
  is_header_footer_candidate : Bool,
) -> @model.PdfTextBlock {
  {
    ..line_test_block(lines),
    is_heading_candidate,
    is_page_number_candidate,
    is_header_footer_candidate,
  }
}

///|
fn line_test_page(blocks : Array[@model.PdfTextBlock]) -> @model.PdfPageModel {
  {
    page_index: 0,
    page_label: None,
    rotation: 0,
    user_unit: None,
    boxes: {
      media_box: line_test_rect(0.0, 0.0, 600.0, 800.0),
      crop_box: None,
      bleed_box: None,
      trim_box: None,
      art_box: None,
    },
    text_blocks: blocks,
    images: [],
    vectors: [],
    annotations: [],
    forms: [],
    reading_order_candidates: [],
    artifact_candidates: [],
    raw_content_stream_refs: [],
  }
}

///|
fn line_test_document(
  blocks : Array[@model.PdfTextBlock],
) -> @model.PdfDocumentModel {
  {
    version: "test",
    page_count: 1,
    metadata: {
      title: None,
      author: None,
      subject: None,
      keywords: [],
      creator: None,
      producer: None,
      creation_date: None,
      mod_date: None,
    },
    is_encrypted: false,
    has_xref_stream: false,
    has_object_stream: false,
    outlines: [],
    pages: [line_test_page(blocks)],
  }
}

///|
test "pdf convert lines split repeated-anchor form rows into separate cell segments" {
  let doc = line_test_document([
    line_test_block([
      line_test_line([
        line_test_span("Insured name", 80.0, 148.0, 480.0, 1),
        line_test_span("Gabriel Diaz", 160.0, 228.0, 480.0, 2),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Claim #", 80.0, 118.0, 466.0, 3),
        line_test_span("SF-1008", 160.0, 200.0, 466.0, 4),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Email", 80.0, 108.0, 452.0, 5),
        line_test_span("gabriel@contoso.com", 160.0, 272.0, 452.0, 6),
      ]),
    ]),
  ])

  let converted = build_convert_lines(doc, "")
  assert_eq(converted.pages.length(), 1)
  assert_eq(converted.pages[0].lines.length(), 6)
  assert_eq(converted.pages[0].lines[0].text, "Insured name")
  assert_eq(converted.pages[0].lines[1].text, "Gabriel Diaz")
  assert_eq(converted.pages[0].lines[4].text, "Email")
  assert_eq(converted.pages[0].lines[5].text, "gabriel@contoso.com")
}

///|
test "pdf convert lines keep citation-like span pairs unsplit even on repeated anchors" {
  let doc = line_test_document([
    line_test_block([
      line_test_line([
        line_test_span("Insured name", 80.0, 148.0, 480.0, 1),
        line_test_span("Gabriel Diaz", 160.0, 228.0, 480.0, 2),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Claim #", 80.0, 118.0, 466.0, 3),
        line_test_span("SF-1008", 160.0, 200.0, 466.0, 4),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Xi", 80.0, 92.0, 452.0, 5),
        line_test_span("et al.", 160.0, 198.0, 452.0, 6),
      ]),
    ]),
  ])

  let converted = build_convert_lines(doc, "")
  assert_eq(converted.pages.length(), 1)
  assert_eq(converted.pages[0].lines.length(), 5)
  assert_eq(converted.pages[0].lines[4].text, "Xi et al.")
}

///|
test "pdf convert lines keep repeated-anchor heading candidates unsplit" {
  let doc = line_test_document([
    line_test_block([
      line_test_line([
        line_test_span("Insured name", 80.0, 148.0, 480.0, 1),
        line_test_span("Gabriel Diaz", 160.0, 228.0, 480.0, 2),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Claim #", 80.0, 118.0, 466.0, 3),
        line_test_span("SF-1008", 160.0, 200.0, 466.0, 4),
      ]),
    ]),
    line_test_block_with_flags(
      [
        line_test_line([
          line_test_span("1.1 研究", 80.0, 138.0, 452.0, 5),
          line_test_span("目", 160.0, 172.0, 452.0, 6),
          line_test_span("标", 196.0, 208.0, 452.0, 7),
        ]),
      ],
      false,
      false,
      false,
    ),
  ])

  let converted = build_convert_lines(doc, "")
  assert_eq(converted.pages[0].lines.length(), 5)
  assert_eq(converted.pages[0].lines[4].text, "1.1 研究目标")
}

///|
test "pdf convert lines keep repeated-anchor bullet rows unsplit" {
  let doc = line_test_document([
    line_test_block([
      line_test_line([
        line_test_span("Insured name", 80.0, 148.0, 480.0, 1),
        line_test_span("Gabriel Diaz", 160.0, 228.0, 480.0, 2),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Claim #", 80.0, 118.0, 466.0, 3),
        line_test_span("SF-1008", 160.0, 200.0, 466.0, 4),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("•", 80.0, 88.0, 452.0, 5),
        line_test_span("First item", 160.0, 220.0, 452.0, 6),
      ]),
    ]),
  ])

  let converted = build_convert_lines(doc, "")
  assert_eq(converted.pages[0].lines.length(), 5)
  assert_eq(converted.pages[0].lines[4].text, "• First item")
}

///|
test "pdf convert lines keep repeated-anchor short page labels unsplit" {
  let doc = line_test_document([
    line_test_block([
      line_test_line([
        line_test_span("Insured name", 80.0, 148.0, 480.0, 1),
        line_test_span("Gabriel Diaz", 160.0, 228.0, 480.0, 2),
      ]),
    ]),
    line_test_block([
      line_test_line([
        line_test_span("Claim #", 80.0, 118.0, 466.0, 3),
        line_test_span("SF-1008", 160.0, 200.0, 466.0, 4),
      ]),
    ]),
    line_test_block_with_flags(
      [
        line_test_line([
          line_test_span("/", 80.0, 88.0, 452.0, 5),
          line_test_span("2", 160.0, 168.0, 452.0, 6),
        ]),
      ],
      false,
      true,
      true,
    ),
  ])

  let converted = build_convert_lines(doc, "")
  assert_eq(converted.pages[0].lines.length(), 5)
  assert_eq(converted.pages[0].lines[4].text, "/2")
}
