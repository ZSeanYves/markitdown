///|
async fn retirement_assert_jsonl_early_close(code_phase : Bool) -> Unit {
  let text = "{\"a\":1,\"b\":2}\n{\"a\":3,\"b\":4}\n[5]\n[6]\n"
  let caller = @input.begin_input_session(
    @input.input_from_text_with_format(text, "retirement.jsonl", Some(Jsonl)),
  )
  defer @input.end_input_session(caller)
  let stream = open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      caller.source,
      @parser.new_parse_context(Jsonl),
      jsonl_parser_capability(),
    )
    .unwrap()
    .unwrap()
  let mut first = (stream.next)().unwrap().unwrap()
  if code_phase {
    // Header and two two-cell rows contain nine events.
    for _ in 0..<9 {
      first = (stream.next)().unwrap().unwrap()
    }
    assert_eq(first.text, "[5]")
    assert_true(first.source_ref.unwrap().line_start == Some(3))
  } else {
    assert_eq(first.text, "a")
    assert_true(first.kind == Cell)
  }
  let retained = first.text
  stream.close().unwrap()
  stream.close().unwrap()
  assert_true((stream.next)() is Ok(None))
  assert_eq(first.text, retained)
  assert_false(
    @input.input_source_budget_context(caller.source).unwrap().account.snapshot().closed,
  )
  assert_true(@input.read_input_text(caller.source) is Ok(_))
}

///|
async test "JSONL early close retires queued table cells" {
  retirement_assert_jsonl_early_close(false)
}

///|
async test "JSONL early close retires an already-open code phase" {
  retirement_assert_jsonl_early_close(true)
}

///|
async test "JSONL full consumption preserves both phases and finish counters" {
  let text = "{\"a\":1,\"b\":2}\n{\"a\":3,\"b\":4}\n[5]\n[6]\n"
  let stream = open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      @input.input_from_text_with_format(text, "retirement.jsonl", Some(Jsonl)),
      @parser.new_parse_context(Jsonl),
      jsonl_parser_capability(),
    )
    .unwrap()
    .unwrap()
  defer ignore(stream.close())
  let events : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => events.push(event)
      None => break
    }
  }
  assert_eq(events.map(event => event.text), [
    "a", "b", "", "1", "2", "", "3", "4", "", "[5]", "[6]",
  ])
  for index in 0..<9 {
    assert_true(
      events[index].kind == (if index % 3 == 2 { RowBreak } else { Cell }),
    )
  }
  assert_true(events[9].source_ref.unwrap().json_pointer == Some("/2"))
  assert_true(events[10].source_ref.unwrap().json_pointer == Some("/3"))
  let summary = (stream.finish)().unwrap()
  assert_true(summary.diagnostics.metrics.get("record_count") == Some("4"))
  assert_true(summary.diagnostics.metrics.get("event_count") == Some("11"))
}
