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
    page_index: 0,
    source_stream_index: 0,
    source_op_index: 0,
    text_object_id: None,
    content_order_index: None,
    source_object_ref: None,
  }
}

///|
fn make_span(text : String) -> @model.PdfTextSpan {
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
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    language_hint: None,
    chars: [],
    source_refs: [dummy_source_ref()],
    break_before: false,
    break_reason: None,
  }
}

///|
fn make_source_ref(
  page_index : Int,
  source_stream_index : Int,
  source_op_index : Int,
  content_order_index : Int?,
) -> @model.PdfSourceRef {
  {
    page_index,
    source_stream_index,
    source_op_index,
    text_object_id: None,
    content_order_index,
    source_object_ref: None,
  }
}

///|
fn make_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_word_merge_span(
  text : String,
  x0 : Double,
  x1 : Double,
  y : Double,
  source_op_index : Int,
) -> @model.PdfTextSpan {
  {
    id: "s-" + text,
    bbox: make_rect(x0, y - 8.0, x1, y + 2.0),
    origin: { x: x0, y },
    text,
    font_name: Some("Dummy"),
    font_family: Some("Dummy"),
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
    source_refs: [make_source_ref(0, 0, source_op_index, Some(source_op_index))],
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
fn make_block(lines : Array[@model.PdfTextLine]) -> @model.PdfTextBlock {
  {
    id: "b",
    bbox: zero_rect(),
    kind: @model.PdfTextBlockKind::Text,
    rotation: None,
    dominant_font_name: None,
    dominant_font_size: None,
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
    source_refs: [dummy_source_ref()],
  }
}

///|
fn debug_case(_label : String, left : String, right : String) -> Unit {
  let _glue = @model.glue_between_spans(left, right)
  let line = make_line([make_span(left), make_span(right)])
  let _line_final = @model.line_text(line)
  let _block_final = @model.block_text(make_block([line]))

  //println("== token: " + label + " ==")
  //println("raw span text: [\"" + left + "\", \"" + right + "\"]")
  //println("glue 后: \"" + (left + glue + right) + "\" (glue=\"" + glue + "\")")
  //println("line text 最终值: \"" + line_final + "\"")
  //println("block text 最终值: \"" + block_final + "\"")
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

///|
test "glue_between_spans fallback stays conservative without pdf context" {
  assert_eq(@model.glue_between_spans("confi", "rms"), " ")
  assert_eq(@model.glue_between_spans("to", "flow"), " ")
}

///|
test "line_text merges tight broken word spans with pdf context signals" {
  let line = make_line([
    make_word_merge_span("confi", 0.0, 28.0, 100.0, 10),
    make_word_merge_span("rms", 28.8, 44.0, 100.2, 11),
  ])

  assert_eq(@model.line_text(line), "confirms")
}

///|
test "line_text merges bound prefix fragments with pdf context signals" {
  let line = make_line([
    make_word_merge_span("inter", 0.0, 24.0, 100.0, 10),
    make_word_merge_span("national", 24.6, 66.0, 100.1, 11),
  ])

  assert_eq(@model.line_text(line), "international")
}

///|
test "line_text merges ligature fragment spans with pdf context signals" {
  let line = make_line([
    make_word_merge_span("di", 0.0, 10.0, 100.0, 10),
    {
      ..make_word_merge_span("ff", 10.5, 16.0, 100.0, 11),
      chars: [
        {
          unicode: "\u{FB00}",
          raw_bytes: None,
          decoded_text: "\u{FB00}",
          bbox: make_rect(10.5, 92.0, 16.0, 102.0),
          origin: { x: 10.5, y: 100.0 },
          quad: None,
          advance_width: None,
          glyph_width: None,
          font_name: Some("Dummy"),
          font_size: Some(12.0),
          fill_color: None,
          rotation: None,
          is_ligature: true,
          is_compat_glyph: false,
          decode_confidence: None,
          source: make_source_ref(0, 0, 11, Some(11)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    make_word_merge_span("erent", 16.4, 42.0, 100.0, 12),
  ])

  assert_eq(@model.line_text(line), "different")
}

///|
test "line_text preserves semantic raw hyphen joins on the same line" {
  let line = make_line([
    {
      ..make_word_merge_span("chat", 0.0, 20.0, 100.0, 10),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(19.0, 92.0, 20.0, 102.0),
          origin: { x: 19.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 10, Some(10)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    make_word_merge_span("optimized", 20.8, 58.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "chat-optimized")
}

///|
test "line_text removes raw hyphen for wrapped continuation on the next line" {
  let line = make_line([
    {
      ..make_word_merge_span("inter", 0.0, 24.0, 100.0, 10),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(23.0, 92.0, 24.0, 102.0),
          origin: { x: 23.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 10, Some(10)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    {
      ..make_word_merge_span("national", 2.0, 44.0, 88.0, 11),
      break_before: true,
    },
  ])

  assert_eq(@model.line_text(line), "international")
}

///|
test "line_text preserves semantic wrapped hyphen compounds on the next line" {
  let chat = make_line([
    {
      ..make_word_merge_span("chat", 0.0, 20.0, 100.0, 10),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(19.0, 92.0, 20.0, 102.0),
          origin: { x: 19.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 10, Some(10)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    {
      ..make_word_merge_span("optimized", 2.0, 44.0, 88.0, 11),
      break_before: true,
    },
  ])
  assert_eq(@model.line_text(chat), "chat-optimized")

  let conversation = make_line([
    {
      ..make_word_merge_span("conversation", 0.0, 52.0, 100.0, 20),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(51.0, 92.0, 52.0, 102.0),
          origin: { x: 51.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 20, Some(20)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    {
      ..make_word_merge_span("centric", 2.0, 34.0, 88.0, 21),
      break_before: true,
    },
  ])
  assert_eq(@model.line_text(conversation), "conversation-centric")
}

///|
test "line_text keeps coordinator boundary after semantic wrapped hyphen" {
  let line = make_line([
    make_word_merge_span("single-", 0.0, 28.0, 100.0, 10),
    { ..make_word_merge_span("or", 2.0, 12.0, 88.0, 11), break_before: true },
  ])

  assert_eq(@model.line_text(line), "single- or")
}

///|
test "line_text still drops wrapped hyphen for suffix continuation" {
  let line = make_line([
    {
      ..make_word_merge_span("flexibil", 0.0, 36.0, 100.0, 10),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(35.0, 92.0, 36.0, 102.0),
          origin: { x: 35.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 10, Some(10)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    { ..make_word_merge_span("ity", 2.0, 14.0, 88.0, 11), break_before: true },
  ])

  assert_eq(@model.line_text(line), "flexibility")

  let confirming = make_line([
    {
      ..make_word_merge_span("con", 0.0, 18.0, 100.0, 20),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(17.0, 92.0, 18.0, 102.0),
          origin: { x: 17.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 20, Some(20)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    {
      ..make_word_merge_span("firming", 2.0, 34.0, 88.0, 21),
      break_before: true,
    },
  ])
  assert_eq(@model.line_text(confirming), "confirming")

  let complex = make_line([
    {
      ..make_word_merge_span("com", 0.0, 18.0, 100.0, 25),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(17.0, 92.0, 18.0, 102.0),
          origin: { x: 17.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 25, Some(25)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    { ..make_word_merge_span("plex", 2.0, 22.0, 88.0, 26), break_before: true },
  ])
  assert_eq(@model.line_text(complex), "complex")

  let programming = make_line([
    {
      ..make_word_merge_span("program", 0.0, 36.0, 100.0, 30),
      chars: [
        {
          unicode: "-",
          raw_bytes: None,
          decoded_text: "-",
          bbox: make_rect(35.0, 92.0, 36.0, 102.0),
          origin: { x: 35.0, y: 100.0 },
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
          source: make_source_ref(0, 0, 30, Some(30)),
          break_before: false,
          break_reason: None,
        },
      ],
    },
    { ..make_word_merge_span("ming", 2.0, 18.0, 88.0, 31), break_before: true },
  ])
  assert_eq(@model.line_text(programming), "programming")
}

///|
test "line_text merges very tight short ascii fragment spans" {
  let second = make_line([
    make_word_merge_span("sec", 0.0, 18.0, 100.0, 10),
    make_word_merge_span("ond", 18.4, 36.0, 100.1, 11),
  ])
  assert_eq(@model.line_text(second), "second")

  let simple = make_line([
    make_word_merge_span("si", 0.0, 10.0, 100.0, 10),
    make_word_merge_span("m", 10.2, 14.0, 100.0, 11),
    make_word_merge_span("pl", 14.2, 23.0, 100.0, 12),
    make_word_merge_span("e", 23.2, 27.0, 100.0, 13),
  ])
  assert_eq(@model.line_text(simple), "simple")

  let pdf = make_line([
    make_word_merge_span("pd", 0.0, 10.0, 100.0, 20),
    make_word_merge_span("f", 10.2, 14.0, 100.0, 21),
  ])
  assert_eq(@model.line_text(pdf), "pdf")
}

///|
test "line_text inserts spaces between ascii and other script words" {
  let line = make_line([
    make_word_merge_span("Hello", 0.0, 20.0, 100.0, 10),
    {
      ..make_word_merge_span("ﺪﻤﺤﻣ", 20.8, 36.0, 100.0, 11),
      writing_direction: @model.PdfWritingDirection::RightToLeft,
    },
    make_word_merge_span("World.", 36.8, 60.0, 100.0, 12),
  ])

  assert_eq(@model.line_text(line), "Hello ﺪﻤﺤﻣ World.")
}

///|
test "line_text keeps normal short words separated" {
  let line = make_line([
    make_word_merge_span("to", 0.0, 10.0, 100.0, 10),
    make_word_merge_span("flow", 11.0, 30.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "to flow")
}

///|
test "line_text preserves citation surname boundary before et al" {
  let line = make_line([
    make_word_merge_span("Xi", 0.0, 12.0, 100.0, 10),
    make_word_merge_span("et al., 2023", 12.2, 48.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "Xi et al., 2023")
}

///|
test "line_text keeps signed numeric spans tight" {
  let negative = make_line([
    make_word_merge_span("-", 0.0, 4.0, 100.0, 10),
    make_word_merge_span("23", 8.0, 18.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(negative), "-23")

  let positive = make_line([
    make_word_merge_span("+", 0.0, 4.0, 100.0, 20),
    make_word_merge_span("15", 8.0, 18.0, 100.0, 21),
  ])
  assert_eq(@model.line_text(positive), "+15")
}

///|
test "line_text keeps numeric separators tight" {
  let amount = make_line([
    make_word_merge_span("$11,", 0.0, 18.0, 100.0, 10),
    make_word_merge_span("250.00", 18.8, 46.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(amount), "$11,250.00")

  let time = make_line([
    make_word_merge_span("14:", 0.0, 12.0, 100.0, 20),
    make_word_merge_span("30:", 12.8, 24.0, 100.0, 21),
    make_word_merge_span("22", 24.8, 32.0, 100.0, 22),
  ])
  assert_eq(@model.line_text(time), "14:30:22")
}

///|
test "line_text still spaces bullet marker from body text" {
  let line = make_line([
    make_word_merge_span("-", 0.0, 4.0, 100.0, 10),
    make_word_merge_span("item", 8.0, 26.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "- item")
}

///|
test "line_text keeps common short right words separated" {
  let ended_yet = make_line([
    make_word_merge_span("ended", 0.0, 24.0, 100.0, 10),
    make_word_merge_span("yet", 24.2, 42.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(ended_yet), "ended yet")

  let confirms_the = make_line([
    make_word_merge_span("confirms", 0.0, 32.0, 100.0, 10),
    make_word_merge_span("the", 32.2, 46.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(confirms_the), "confirms the")

  let not_be = make_line([
    make_word_merge_span("not", 0.0, 14.0, 100.0, 10),
    make_word_merge_span("be", 14.2, 24.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(not_be), "not be")
}

///|
test "line_text does not merge across large gap" {
  let line = make_line([
    make_word_merge_span("confi", 0.0, 28.0, 100.0, 10),
    make_word_merge_span("rms", 40.5, 56.0, 100.1, 11),
  ])

  assert_eq(@model.line_text(line), "confi rms")
}

///|
test "line_text does not merge across punctuation boundary" {
  let line = make_line([
    make_word_merge_span("word.", 0.0, 28.0, 100.0, 10),
    make_word_merge_span("next", 28.7, 46.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "word. next")
}

///|
test "line_text keeps ascii sentence punctuation separated from following text" {
  let question = make_line([
    make_word_merge_span("capacities?", 0.0, 54.0, 100.0, 10),
    make_word_merge_span("We", 54.8, 66.0, 100.0, 11),
  ])
  assert_eq(@model.line_text(question), "capacities? We")

  let parenthetical = make_line([
    make_word_merge_span("collaboration?", 0.0, 72.0, 100.0, 20),
    make_word_merge_span("(2)", 72.8, 84.0, 100.0, 21),
  ])
  assert_eq(@model.line_text(parenthetical), "collaboration? (2)")
}

///|
test "line_text inserts space before parenthetical prose spans" {
  let line = make_line([
    make_word_merge_span("models", 0.0, 28.0, 100.0, 10),
    make_word_merge_span("(LLMs)", 29.2, 52.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "models (LLMs)")
}

///|
test "line_text keeps cjk latin spacing intact" {
  let line = make_line([
    make_word_merge_span("中文", 0.0, 20.0, 100.0, 10),
    make_word_merge_span("AI", 21.0, 30.0, 100.0, 11),
  ])

  assert_eq(@model.line_text(line), "中文 AI")
}
