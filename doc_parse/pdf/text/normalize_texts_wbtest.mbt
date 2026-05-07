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
