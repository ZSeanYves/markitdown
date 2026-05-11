///|
fn render_tj_text(values : Array[@pdf.PdfObject], font_size : Double) -> String {
  let parts = extract_text_fragments_from_tj_array(
    @pdf.PdfObject::Array(values),
    Some(font_size),
  )
  parts.join("")
}

///|
test "TJ negative spacing inserts word spaces for english fragments" {
  let text = render_tj_text(
    [
      String("While"),
      Integer(-361),
      String("there"),
      Integer(-362),
      String("is"),
    ],
    10.0,
  )
  assert_eq(text, "While there is")
}

///|
test "TJ small kerning does not insert space inside split word" {
  let text = render_tj_text(
    [String("Lar"), Integer(18), String("ge"), Integer(-40), String("language")],
    10.0,
  )
  assert_eq(text, "Largelanguage")
}

///|
test "TJ appendix letter spacing inserts word boundaries" {
  let text = render_tj_text(
    [
      String("refer"),
      Integer(-250),
      String("to"),
      Integer(-250),
      String("Appendix"),
      Integer(-250),
      String("A"),
    ],
    10.0,
  )
  assert_eq(text, "refer to Appendix A")
}

///|
test "TJ acronym and parentheses keep tight punctuation but separate next word" {
  let text = render_tj_text(
    [
      String("models"),
      Integer(-250),
      String("(LLMs)"),
      Integer(-250),
      String("are"),
    ],
    10.0,
  )
  assert_eq(text, "models(LLMs) are")
}

///|
test "TJ hyphenated words stay joined but next word may separate" {
  let text = render_tj_text(
    [
      String("multi"),
      Integer(-20),
      String("-"),
      Integer(-20),
      String("agent"),
      Integer(-250),
      String("approaches"),
    ],
    10.0,
  )
  assert_eq(text, "multi-agent approaches")
}

///|
test "TJ explicit space glyph does not double insert spaces" {
  let text = render_tj_text(
    [String("While "), Integer(-361), String("there")],
    10.0,
  )
  assert_eq(text, "While there")
}

///|
test "TJ cjk fragments stay compact despite large negative spacing" {
  let text = render_tj_text(
    [
      String("中"),
      Integer(-300),
      String("文"),
      Integer(-300),
      String("测试"),
    ],
    10.0,
  )
  assert_eq(text, "中文测试")
}

///|
test "TJ punctuation does not add space before comma but may after comma" {
  let text = render_tj_text(
    [
      String("hello"),
      Integer(-250),
      String(","),
      Integer(-250),
      String("world"),
    ],
    10.0,
  )
  assert_eq(text, "hello, world")
}

///|
test "TJ decimal fragments stay tight before following word" {
  let text = render_tj_text(
    [
      String("3"),
      Integer(-20),
      String("."),
      Integer(-20),
      String("14"),
      Integer(-250),
      String("value"),
    ],
    10.0,
  )
  assert_eq(text, "3.14 value")
}
