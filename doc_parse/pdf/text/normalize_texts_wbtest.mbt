///|
fn zero_point() -> @model.PdfPoint {
  { x: 0, y: 0 }
}

///|
fn zero_rect() -> @model.PdfRect {
  { x0: 0, y0: 0, x1: 0, y1: 0 }
}

///|
fn dummy_source_ref() -> @model.PdfSourceRef {
  {
    page_index: 2,
    source_stream_index: 3,
    source_op_index: 4,
    text_object_id: Some(5),
    content_order_index: Some(6),
    source_object_ref: Some("7 0 R"),
  }
}

///|
fn make_span(text : String) -> @model.PdfTextSpan {
  {
    id: "s",
    bbox: zero_rect(),
    origin: zero_point(),
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
    source_refs: [dummy_source_ref()],
    break_before: false,
    break_reason: None,
  }
}

///|
fn make_line(spans : Array[@model.PdfTextSpan]) -> @model.PdfTextLine {
  {
    id: "l",
    bbox: zero_rect(),
    baseline_y: None,
    ascent: None,
    descent: None,
    line_height: Some(12.0),
    indent_left: Some(0.0),
    indent_right: Some(0.0),
    alignment_hint: None,
    line_gap_before: Some(0.0),
    line_gap_after: Some(0.0),
    spans,
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
    source_refs: [dummy_source_ref()],
  }
}

///|
test "single span pdf normalization preserves source refs" {
  let span = make_span("o\u{FB03}ce\u{00A0}\u{200B}hy\u{00AD}phen⻅")
  let normalized = normalize_single_span(span)

  assert_eq(normalized.text, "office hyphen见")
  assert_eq(normalized.source_refs.length(), span.source_refs.length())
  assert_eq(
    normalized.source_refs[0].page_index,
    span.source_refs[0].page_index,
  )
  assert_eq(
    normalized.source_refs[0].source_stream_index,
    span.source_refs[0].source_stream_index,
  )
  assert_eq(
    normalized.source_refs[0].source_op_index,
    span.source_refs[0].source_op_index,
  )
  assert_eq(normalized.bbox.x0, span.bbox.x0)
  assert_eq(normalized.bbox.y0, span.bbox.y0)
  assert_eq(normalized.bbox.x1, span.bbox.x1)
  assert_eq(normalized.bbox.y1, span.bbox.y1)
  assert_eq(normalized.id, span.id)
}

///|
test "single span normalization does not alter chars provenance array" {
  let span = make_span("A\u{00A0}B")
  let normalized = normalize_single_span(span)

  assert_eq(normalized.chars.length(), span.chars.length())
  assert_eq(normalized.source_refs.length(), 1)
  assert_eq(normalized.source_refs[0].page_index, 2)
  assert_eq(normalized.source_refs[0].source_stream_index, 3)
}

///|
test "pdf lower layer now delegates pure string cleanup to core rule engine" {
  assert_eq(normalize_text("中 文 ， 标题"), "中文，标题")
  assert_eq(normalize_text("•First item"), "• First item")
  assert_eq(normalize_text("1)another"), "1) another")
}

///|
test "pdf lower layer no longer applies phrase or slash post patches globally" {
  assert_eq(normalize_text("A - B"), "A - B")
  assert_eq(normalize_text("inter-national"), "inter-national")
  assert_eq(normalize_text("/1"), "/1")
}

///|
test "pdf span fragment merge repairs tight broken english words without phrase whitelist" {
  let spans = normalize_line_spans_with_glue([
    make_span("confi"),
    make_span("rms"),
  ])
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "confirms")
}

///|
test "pdf span fragment merge keeps normal short word boundaries" {
  let first = normalize_line_spans_with_glue([
    make_span("the"),
    make_span("first"),
  ])
  assert_eq(first.length(), 2)
  assert_eq(first[0].text, "the")
  assert_eq(first[1].text, "first")

  let flow = normalize_line_spans_with_glue([make_span("to"), make_span("flow")])
  assert_eq(flow.length(), 2)
  assert_eq(flow[0].text, "to")
  assert_eq(flow[1].text, "flow")
}

///|
test "pdf span fragment merge repairs bound prefix and ligature fragments" {
  let international = normalize_line_spans_with_glue([
    make_span("inter"),
    make_span("national"),
  ])
  assert_eq(international.length(), 1)
  assert_eq(international[0].text, "international")
}

///|
test "pdf line merge repairs wrapped hyphen with line context only" {
  let merged = merge_two_lines(
    0,
    0,
    make_line([make_span("inter-")]),
    make_line([make_span("national")]),
  )
  assert_eq(@model.line_text(merged), "international")
}
