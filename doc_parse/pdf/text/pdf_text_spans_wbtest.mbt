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
