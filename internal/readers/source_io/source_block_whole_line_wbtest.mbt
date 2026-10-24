///|
async test "block reader retains a truncated nonblank line even when its retained prefix is blank" {
  for suffix in ["0", "😀"] {
    let reader = open_source_text_block_reader(
      @input.input_from_text(" ".repeat(4) + suffix),
      max_line_chars=4,
    ).unwrap()
    defer (reader.close)()
    let result = (reader.next)().unwrap()
    assert_true(
      result is Some(_),
      msg="a blank prefix cannot erase a nonblank logical line",
    )
    let block = result.unwrap()
    assert_eq(block.lines, ["    "])
    assert_eq(block.line_start, 1)
    assert_eq(block.line_end, 1)
    assert_true(block.truncated)
    assert_true((reader.next)().unwrap() is None)
  }
}

///|
async test "block reader does not use a truncated blank prefix as a record delimiter" {
  let reader = open_source_text_block_reader(
    @input.input_from_text("left\n    0\n\nend\n"),
    max_line_chars=4,
  ).unwrap()
  defer (reader.close)()
  let first = (reader.next)().unwrap().unwrap()
  assert_eq(first.lines, ["left", "    "])
  assert_eq(first.line_start, 1)
  assert_eq(first.line_end, 2)
  assert_true(first.truncated)
  let last = (reader.next)().unwrap().unwrap()
  assert_eq(last.lines, ["end"])
  assert_eq(last.line_start, 4)
  assert_eq(last.line_end, 4)
  assert_false(last.truncated)
  assert_true((reader.next)().unwrap() is None)
}

///|
async test "block reader preserves a genuinely blank truncated line as a delimiter" {
  let reader = open_source_text_block_reader(
    @input.input_from_text("left\n" + " ".repeat(9) + "\nend\n"),
    max_line_chars=4,
  ).unwrap()
  defer (reader.close)()
  let first = (reader.next)().unwrap().unwrap()
  assert_eq(first.lines, ["left"])
  assert_eq(first.line_start, 1)
  assert_eq(first.line_end, 1)
  assert_false(first.truncated)
  let last = (reader.next)().unwrap().unwrap()
  assert_eq(last.lines, ["end"])
  assert_eq(last.line_start, 3)
  assert_false(last.truncated)
  assert_true((reader.next)().unwrap() is None)
}
