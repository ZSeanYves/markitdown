///|
async test "early close preserves returned lines blocks and the borrowed Path owner" {
  let caller = @input.begin_input_session(
    @input.input_from_path("lib/input/README.md"),
  )
  defer @input.end_input_session(caller)
  let cursor = @input.open_source_cursor(caller.source).unwrap()
  let reader = open_source_text_line_reader(caller.source).unwrap()
  let first = (reader.next)().unwrap().unwrap()
  let retained = first.text
  (reader.close)()
  (reader.close)()
  assert_true((reader.next)() is Ok(None))
  assert_eq(first.text, retained)
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
  assert_true(@input.source_cursor_read_at(cursor, 0L, length=1) is Ok(_))

  let blocks = open_source_text_block_reader(
    @input.input_from_text("one😀\nsecond\n\nthird\n"),
  ).unwrap()
  let block = (blocks.next)().unwrap().unwrap()
  (blocks.close)()
  (blocks.close)()
  assert_true((blocks.next)() is Ok(None))
  assert_eq(block.lines, ["one😀", "second"])
  assert_eq(block.line_start, 1)
  assert_eq(block.line_end, 2)
}

///|
async test "early line and chunk close do not invoke a caller Reader again" {
  let calls = Ref(0)
  let bytes = b"one\r\ntwo\n"
  let source = @input.input_from_reader(
    @input.make_input_reader(
      fn(offset, length) {
        calls.val += 1
        let start = offset.to_int().min(bytes.length())
        let end = (start + length).min(bytes.length())
        Ok(bytes.exact_view(start~, end~).to_owned())
      },
      size=bytes.length().to_int64(),
    ),
  )
  let caller = @input.begin_input_session(source)
  defer @input.end_input_session(caller)
  let lines = open_source_text_line_reader(caller.source).unwrap()
  assert_eq((lines.next)().unwrap().unwrap().text, "one")
  (lines.close)()
  let previous = calls.val
  assert_true((lines.next)() is Ok(None))
  assert_eq(calls.val, previous)
  assert_true(@input.read_input_bytes(caller.source) is Ok(b"one\r\ntwo\n"))
  assert_true(calls.val > previous)

  let chunks = open_source_text_chunk_reader(
    @input.input_from_text("😀tail"),
    chunk_size=1,
  ).unwrap()
  let first = (chunks.next)().unwrap().unwrap()
  (chunks.close)()
  assert_true((chunks.next)() is Ok(None))
  assert_eq(first.text, "😀")
}

///|
async test "full line and block consumption preserves CRLF Unicode and final records" {
  let lines = open_source_text_line_reader(
    @input.input_from_text("\u{FEFF}one😀\r\ntwo\rthree"),
  ).unwrap()
  defer (lines.close)()
  for (expected, line_no) in [("one😀", 1), ("two", 2), ("three", 3)] {
    let line = (lines.next)().unwrap().unwrap()
    assert_eq(line.text, expected)
    assert_eq(line.line_no, line_no)
    assert_false(line.truncated)
  }
  assert_true((lines.next)() is Ok(None))
  let blocks = open_source_text_block_reader(
    @input.input_from_text("a\r\nb\r\n\r\nc"),
  ).unwrap()
  defer (blocks.close)()
  for (expected, start, end) in [(["a", "b"], 1, 2), (["c"], 4, 4)] {
    let block = (blocks.next)().unwrap().unwrap()
    assert_eq(block.lines, expected)
    assert_eq(block.line_start, start)
    assert_eq(block.line_end, end)
  }
  assert_true((blocks.next)() is Ok(None))
}
