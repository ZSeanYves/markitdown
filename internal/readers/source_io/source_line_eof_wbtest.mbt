///|
async test "line EOF split state is explicit and never inferred from early retirement" {
  for
    (text, split_cr, expected, final_empty) in [
      ("a\n", true, ["a"], true),
      ("a\r\n", true, ["a"], true),
      ("a\r", true, ["a"], true),
      ("a\r", false, ["a\r"], false),
      ("a\r\n", false, ["a\r"], true),
      ("", false, [], true),
      ("\u{FEFF}", false, ["\u{FEFF}"], false),
      ("last", false, ["last"], false),
    ] {
    let reader = open_source_text_line_reader(
      @input.input_from_text(text),
      split_cr~,
      skip_leading_bom=false,
    ).unwrap()
    defer (reader.close)()
    let lines : Array[String] = []
    assert_false((reader.eof_has_empty_line)())
    while true {
      match (reader.next)().unwrap() {
        Some(line) => lines.push(line.text)
        None => break
      }
    }
    assert_eq(lines, expected)
    assert_eq((reader.eof_has_empty_line)(), final_empty)
  }
  let reader = open_source_text_line_reader(
    @input.input_from_text("one\ntwo\n"),
  ).unwrap()
  assert_eq((reader.next)().unwrap().unwrap().text, "one")
  (reader.close)()
  assert_false((reader.eof_has_empty_line)())
  assert_true((reader.next)().unwrap() is None)
  let invalid = open_source_text_line_reader(
    @input.input_from_bytes(b"line\n\xff"),
  ).unwrap()
  defer (invalid.close)()
  assert_true((invalid.next)() is Err(_))
  assert_false((invalid.eof_has_empty_line)())
}
