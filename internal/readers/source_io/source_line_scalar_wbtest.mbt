///|
async test "physical line cap preserves UTF16 units and scalar boundaries across CR pushback" {
  let reader = open_source_text_line_reader(
    @input.input_from_text("a😀z\r😀x\r\nok"),
    max_line_chars=2,
  ).unwrap()
  defer (reader.close)()
  for
    (text, truncated, line_no) in [
      ("a", true, 1),
      ("😀", true, 2),
      ("ok", false, 3),
    ] {
    let line = (reader.next)().unwrap().unwrap()
    assert_true(@input.validated_text_utf8_size(line.text) is Ok(_))
    assert_eq(line.text, text)
    assert_eq(line.truncated, truncated)
    assert_eq(line.line_no, line_no)
  }
  assert_true((reader.next)().unwrap() is None)
}
