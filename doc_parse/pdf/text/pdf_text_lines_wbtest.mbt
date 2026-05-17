///|
fn make_line_test_source_ref(op_index : Int) -> @model.PdfSourceRef {
  {
    page_index: 0,
    source_stream_index: 0,
    source_op_index: op_index,
    text_object_id: Some(1),
    content_order_index: Some(op_index),
    source_object_ref: None,
  }
}

///|
fn make_line_test_span(
  text : String,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  origin_y : Double,
  op_index : Int,
) -> @model.PdfTextSpan {
  {
    id: "s" + op_index.to_string(),
    bbox: { x0, y0, x1, y1 },
    origin: { x: x0, y: origin_y },
    text,
    font_name: Some("Dummy"),
    font_family: None,
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
    source_refs: [make_line_test_source_ref(op_index)],
    break_before: false,
    break_reason: None,
  }
}

///|
test "build lines keeps vertically separated spans apart even with noisy origins" {
  let link = make_line_test_span("Link", 70.86, 73.06, 88.75, 84.04, 100.0, 10)
  let link_space = make_line_test_span(
    " ", 88.76, 73.06, 91.24, 84.04, 100.0, 11,
  )
  let domain = make_line_test_span(
    "mozilla.org", 70.86, 95.56, 120.19, 106.54, 100.1, 19,
  )
  let domain_space = make_line_test_span(
    " ", 120.2, 95.56, 122.68, 106.54, 100.1, 35,
  )
  let text = make_line_test_span(
    "Text", 70.86, 140.52, 90.08, 151.50, 100.2, 52,
  )
  let spans = [link, link_space, domain, domain_space, text]

  assert_false(should_join_same_line([link], domain))
  assert_false(should_join_same_line([link, link_space], domain))
  assert_false(should_join_same_line([domain], text))

  let lines = build_lines_from_spans(0, spans)
  assert_eq(lines.length(), 3)
  assert_eq(@model.line_text(lines[0]).trim(), "Link")
  assert_eq(@model.line_text(lines[1]).trim(), "mozilla.org")
  assert_eq(@model.line_text(lines[2]).trim(), "Text")
}

///|
test "build lines still joins overlapping same-row spans" {
  let spans = [
    make_line_test_span("Hello", 10.0, 90.0, 40.0, 102.0, 96.0, 20),
    make_line_test_span("world", 42.0, 90.5, 75.0, 102.5, 96.2, 21),
  ]

  let lines = build_lines_from_spans(0, spans)
  assert_eq(lines.length(), 1)
  assert_eq(@model.line_text(lines[0]).trim(), "Hello world")
}

///|
test "line merge does not join vertically separated short label and domain line" {
  let left = make_line([
    make_line_test_span("Link", 70.86, 751.28, 97.21, 763.36, 760.62, 7),
  ])
  let right = {
    ..make_line([
      make_line_test_span(
        "mozilla.org", 70.86, 728.78, 125.14, 740.86, 738.12, 19,
      ),
    ]),
    baseline_y: Some(738.12),
    line_gap_before: Some(11.52),
    line_gap_after: Some(0.0),
  }
  let left_with_layout = {
    ..left,
    baseline_y: Some(760.62),
    line_gap_before: None,
    line_gap_after: Some(11.52),
  }
  assert_false(should_merge_lines(left_with_layout, right))
}
