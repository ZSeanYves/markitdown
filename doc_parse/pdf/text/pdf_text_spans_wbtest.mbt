///|
fn make_source_ref(op_index : Int) -> @model.PdfSourceRef {
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
fn make_char(
  text : String,
  x0 : Double,
  x1 : Double,
  op_index : Int,
) -> @model.PdfChar {
  {
    unicode: text,
    raw_bytes: None,
    decoded_text: text,
    bbox: { x0, y0: 92.0, x1, y1: 104.0 },
    origin: { x: x0, y: 100.0 },
    quad: None,
    advance_width: None,
    glyph_width: None,
    font_name: Some("Dummy"),
    font_size: Some(12.0),
    fill_color: None,
    rotation: None,
    is_ligature: false,
    is_compat_glyph: false,
    decode_confidence: None,
    source: make_source_ref(op_index),
    break_before: false,
    break_reason: None,
  }
}

///|
fn make_char_at(
  text : String,
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
  origin_y : Double,
  op_index : Int,
) -> @model.PdfChar {
  {
    unicode: text,
    raw_bytes: None,
    decoded_text: text,
    bbox: { x0, y0, x1, y1 },
    origin: { x: x0, y: origin_y },
    quad: None,
    advance_width: None,
    glyph_width: None,
    font_name: Some("Dummy"),
    font_size: Some(12.0),
    fill_color: None,
    rotation: None,
    is_ligature: false,
    is_compat_glyph: false,
    decode_confidence: None,
    source: make_source_ref(op_index),
    break_before: false,
    break_reason: None,
  }
}

///|
fn make_char_at_with_order(
  text : String,
  x0 : Double,
  x1 : Double,
  y0 : Double,
  y1 : Double,
  origin_y : Double,
  op_index : Int,
  content_order : Int,
) -> @model.PdfChar {
  {
    ..make_char_at(text, x0, x1, y0, y1, origin_y, op_index),
    source: {
      ..make_source_ref(op_index),
      content_order_index: Some(content_order),
    },
  }
}

///|
fn make_ascii_word_chars(
  word : String,
  start_x : Double,
  step : Double,
  op_index : Int,
) -> Array[@model.PdfChar] {
  let chars = Array::new()
  let letters = word.to_array()
  for i = 0; i < letters.length(); i = i + 1 {
    let x0 = start_x + step * i.to_double()
    let x1 = x0 + step
    chars.push(make_char(letters[i].to_string(), x0, x1, op_index))
  }
  chars
}

///|
fn append_chars(
  base : Array[@model.PdfChar],
  more : Array[@model.PdfChar],
) -> Array[@model.PdfChar] {
  let out = Array::new()
  for ch in base {
    out.push(ch)
  }
  for ch in more {
    out.push(ch)
  }
  out
}

///|
test "pdf char join infers latin word boundary from x gap inside one span" {
  let chars = append_chars(
    make_ascii_word_chars("While", 0.0, 6.0, 10),
    make_ascii_word_chars("there", 36.0, 6.0, 10),
  )
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "While there")
}

///|
test "pdf char join infers appendix letter boundary from x gap inside one span" {
  let chars = append_chars(make_ascii_word_chars("Appendix", 0.0, 6.0, 10), [
    make_char("A", 58.0, 64.0, 10),
  ])
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "Appendix A")
}

///|
test "pdf char join keeps signed numeric value tight inside one span" {
  let chars = [
    make_char("-", 0.0, 3.0, 10),
    make_char("2", 7.5, 13.5, 10),
    make_char("3", 13.5, 19.5, 10),
  ]
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "-23")
}

///|
test "pdf char join still spaces bullet marker from following text" {
  let chars = append_chars([make_char("-", 0.0, 3.0, 10)], [
    make_char("i", 7.5, 10.5, 10),
    make_char("t", 10.5, 13.5, 10),
    make_char("e", 13.5, 19.5, 10),
    make_char("m", 19.5, 28.5, 10),
  ])
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "- item")
}

///|
test "pdf char join preserves cjk continuous text without inferred spaces" {
  let chars = [
    make_char("中", 0.0, 12.0, 10),
    make_char("文", 14.5, 26.5, 10),
  ]
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "中文")
}

///|
test "pdf char join does not add space before tight punctuation" {
  let chars = append_chars(make_ascii_word_chars("models", 0.0, 6.0, 10), [
    make_char("(", 36.5, 39.0, 10),
  ])
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "models(")
}

///|
test "pdf char join inserts space after ascii sentence punctuation when x gap is explicit" {
  let chars = append_chars(make_ascii_word_chars("capacities?", 0.0, 6.0, 10), [
    make_char("W", 74.0, 80.0, 10),
    make_char("e", 80.0, 86.0, 10),
  ])
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "capacities? We")
}

///|
test "pdf char join inserts space before open punctuation when x gap is explicit" {
  let chars = append_chars(make_ascii_word_chars("models", 0.0, 6.0, 10), [
    make_char("(", 40.5, 43.0, 10),
    make_char("L", 43.0, 49.0, 10),
  ])
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "models (L")
}

///|
test "pdf char join does not duplicate inferred space when raw text already contains one" {
  let chars = append_chars(
    [
      make_char("W", 0.0, 6.0, 10),
      make_char("h", 6.0, 12.0, 10),
      make_char("i", 12.0, 18.0, 10),
      make_char("l", 18.0, 24.0, 10),
      make_char("e", 24.0, 30.0, 10),
      make_char(" ", 30.0, 34.0, 10),
    ],
    make_ascii_word_chars("there", 42.0, 6.0, 10),
  )
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 1)
  assert_eq(spans[0].text, "While there")
}

///|
test "pdf char join splits vertically separated chars even within one source group" {
  let chars = [
    make_char_at("L", 70.86, 75.47, 73.06, 84.04, 81.30, 10),
    make_char_at("i", 75.47, 77.99, 73.06, 84.04, 81.30, 10),
    make_char_at("n", 77.99, 83.76, 73.06, 84.04, 81.30, 10),
    make_char_at("k", 83.76, 88.75, 73.06, 84.04, 81.30, 10),
    make_char_at("m", 70.86, 79.63, 95.56, 106.54, 103.80, 10),
  ]
  let spans = build_spans_from_chars(chars)
  assert_eq(spans.length(), 2)
  assert_eq(spans[0].text, "Link")
  assert_eq(spans[1].text, "m")
}

///|
test "pdf line build preserves same-row multi-text glyph chunks without fake gaps" {
  let spans = build_page_spans({
    page_index: 0,
    chars: [
      make_char_at_with_order("m", 70.86, 77.45, 95.56, 106.54, 103.80, 19, 2),
      make_char_at_with_order(
        "ozilla.", 79.64, 79.64, 95.56, 106.54, 103.80, 23, 3,
      ),
      make_char_at_with_order(
        "org", 105.38, 105.38, 95.56, 106.54, 103.80, 27, 4,
      ),
    ],
  })
  let lines = build_page_lines(spans)
  assert_eq(lines.lines.length(), 1)
  assert_eq(@model.line_text(lines.lines[0]).trim(), "mozilla.org")
}
