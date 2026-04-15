///|
fn zero_point() -> PdfPoint {
  { x: 0, y: 0 }
}

///|
fn zero_rect() -> PdfRect {
  { x0: 0, y0: 0, x1: 0, y1: 0 }
}

///|
fn dummy_source_ref() -> PdfSourceRef {
  {
    page_index: 0,
    source_stream_index: 0,
    source_op_index: 0,
    text_object_id: None,
    content_order_index: None,
    source_object_ref: None,
  }
}

///|
fn make_span(text : String) -> PdfTextSpan {
  {
    id: "s",
    bbox: zero_rect(),
    origin: zero_point(),
    text,
    font_name: None,
    font_family: None,
    font_size: None,
    is_bold: false,
    is_italic: false,
    is_monospace: false,
    fill_color: None,
    stroke_color: None,
    char_spacing: None,
    word_spacing: None,
    text_rise: None,
    scale_x: None,
    writing_direction: PdfWritingDirection::LeftToRight,
    language_hint: None,
    chars: [],
    source_refs: [dummy_source_ref()],
    break_before: false,
    break_reason: None,
  }
}

///|
fn make_line(spans : Array[PdfTextSpan]) -> PdfTextLine {
  {
    id: "l",
    bbox: zero_rect(),
    baseline_y: None,
    ascent: None,
    descent: None,
    line_height: None,
    indent_left: None,
    indent_right: None,
    alignment_hint: None,
    line_gap_before: None,
    line_gap_after: None,
    spans,
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
    source_refs: [dummy_source_ref()],
  }
}

///|
fn make_block(lines : Array[PdfTextLine]) -> PdfTextBlock {
  {
    id: "b",
    bbox: zero_rect(),
    kind: PdfTextBlockKind::Text,
    rotation: None,
    dominant_font_name: None,
    dominant_font_size: None,
    dominant_language: None,
    writing_direction: PdfWritingDirection::LeftToRight,
    z_index: None,
    lines,
    is_heading_candidate: false,
    is_header_footer_candidate: false,
    is_page_number_candidate: false,
    is_table_cell_candidate: false,
    is_caption_candidate: false,
    is_artifact_candidate: false,
    source_refs: [dummy_source_ref()],
  }
}

///|
fn debug_case(label : String, left : String, right : String) -> Unit {
  let glue = glue_between_spans(left, right)
  let line = make_line([make_span(left), make_span(right)])
  let line_final = line_text(line)
  let block_final = block_text(make_block([line]))

  println("== token: " + label + " ==")
  println("raw span text: [\"" + left + "\", \"" + right + "\"]")
  println("glue 后: \"" + (left + glue + right) + "\" (glue=\"" + glue + "\")")
  println("line text 最终值: \"" + line_final + "\"")
  println("block text 最终值: \"" + block_final + "\"")
}

///|
test "wb debug line glue target tokens" {
  debug_case("inter- national", "inter-", "national")
  debug_case("thefi rst", "thefi", "rst")
  debug_case("toflow", "to", "flow")
  debug_case("tocon firm", "tocon", "firm")
  debug_case("Thisfi nal", "Thisfi", "nal")
  debug_case("•First item", "•", "First item")
  debug_case("2)another", "2)", "another")
}
