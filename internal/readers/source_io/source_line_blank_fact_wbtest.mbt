///|
async test "whole-line blank facts inspect truncated suffixes using the pinned trim set" {
  let source = @input.input_from_text(" 0\n \t\n\u{2003}\n\u{000B}\n\u{000C}\n")
  let reader = open_source_text_line_reader(source, max_line_chars=1).unwrap()
  defer (reader.close)()
  let first = (reader.next)().unwrap().unwrap()
  assert_eq(first.text, " ")
  assert_true(first.truncated)
  assert_false(first.is_blank)
  let blank = (reader.next)().unwrap().unwrap()
  assert_true(blank.truncated)
  assert_true(blank.is_blank)
  for scalar in ["\u{2003}", "\u{000B}", "\u{000C}"] {
    let line = (reader.next)().unwrap().unwrap()
    assert_eq(line.text, scalar)
    assert_false(line.is_blank)
    assert_false(line.text.trim() == "")
  }
  assert_true((reader.next)().unwrap() is None)
}

///|
async test "whole-line blank optional prefixes are ordered single-use facts and leave text intact" {
  let source = @input.input_from_text(
    "\u{001E}\u{FEFF} \t\n\u{001E}\u{FEFF}\u{FEFF}\n \u{FEFF}\n\u{FEFF} \n\t\u{001E}\n",
  )
  let prefixes = ['\u{001E}', '\u{FEFF}']
  let reader = open_source_text_line_reader(
    source,
    max_line_chars=1,
    split_cr=false,
    skip_leading_bom=false,
    blank_prefix=prefixes,
  ).unwrap()
  defer (reader.close)()
  // Mutating the caller's array cannot change the selected classification.
  prefixes[0] = 'x'
  let expected = [true, false, false, true, false]
  for index in 0..<expected.length() {
    let line = (reader.next)().unwrap().unwrap()
    assert_eq(line.line_no, index + 1)
    assert_eq(line.is_blank, expected[index])
    assert_true(line.truncated)
    if index == 0 {
      assert_eq(line.text, "\u{001E}")
    }
  }
  assert_true((reader.next)().unwrap() is None)
}
