///|
test "collected JSONL table sources follow actual input records after scalars and schema mismatches" {
  let text = "0\n{\"a\":1}\n{\"b\":2}\n{\"a\":3}\n"
  let source = @input.input_from_text_with_format(
    text,
    "mixed.jsonl",
    Some(Jsonl),
  )
  let lowered = lower_line_delimited_json_events(
    "jsonl",
    text,
    source,
    @parser.new_parse_context(Jsonl),
  ).unwrap()
  let cells = lowered.0.filter(event => event.kind == Cell)
  assert_eq(cells.length(), 3)
  assert_eq(cells.map(event => event.text), ["a", "1", "3"])
  let header = cells[0].source_ref.unwrap()
  assert_true(header.json_pointer == Some("/header"))
  assert_true(header.extra.get("synthetic_header") == Some("true"))
  for (at, ordinal, line, cell) in [(1, 1, 2, "R2C1"), (2, 3, 4, "R3C1")] {
    let reference = cells[at].source_ref.unwrap()
    assert_eq(reference.line_start.unwrap_or(-1), line)
    assert_eq(reference.line_end.unwrap_or(-1), line)
    assert_eq(
      reference.json_pointer.unwrap_or("MISSING"),
      "/" + ordinal.to_string(),
    )
    assert_eq(
      reference.extra.get("record_index").unwrap_or("MISSING"),
      ordinal.to_string(),
    )
    assert_true(reference.cell_range == Some(cell))
  }
  let code = lowered.0.filter(event => event.kind == StartBlock(Code))
  assert_eq(code.map(event => event.text), ["0", "{\"b\":2}"])
  assert_true(code[0].source_ref.unwrap().json_pointer == Some("/0"))
  assert_true(code[0].source_ref.unwrap().line_start == Some(1))
  assert_true(code[1].source_ref.unwrap().json_pointer == Some("/2"))
  assert_true(code[1].source_ref.unwrap().line_start == Some(3))
}
