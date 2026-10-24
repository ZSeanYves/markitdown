///|
test "JSONL schema reuse preserves order duplicate membership and empty objects" {
  let cases : Array[(String, Array[String], Array[String])] = [
    ("{\"a\":1,\"b\":2}\n{\"b\":3,\"a\":4}", ["a", "b", "1", "2", "4", "3"], []),
    ("{\"a\":1,\"b\":2}\n{\"a\":3,\"a\":4}", ["a", "b", "1", "2", "4", ""], []),
    (
      "{\"a\":1,\"a\":2}\n{\"a\":3,\"a\":4}\n{\"a\":5,\"b\":6}",
      ["a", "a", "2", "2", "4", "4"],
      ["{\"a\":5,\"b\":6}"],
    ),
    ("{}\n{}\n[]", [], ["[]"]),
    (
      "{\"😀\":1,\"列\":2}\n{\"列\":3,\"😀\":4}",
      ["😀", "列", "1", "2", "4", "3"],
      [],
    ),
  ]
  for (text, cells, codes) in cases {
    let source = @input.input_from_text_with_format(
      text,
      "schema.jsonl",
      Some(Jsonl),
    )
    let result = lower_line_delimited_json_events(
      "jsonl",
      text,
      source,
      @parser.new_parse_context(Jsonl),
    ).unwrap()
    assert_eq(
      result.0.filter(event => event.kind == Cell).map(event => event.text),
      cells,
    )
    assert_eq(
      result.0
      .filter(event => event.kind == StartBlock(Code))
      .map(event => event.text),
      codes,
    )
  }
}

///|
async test "JSONL pull replay retains schema and table before code ordering" {
  let text = "{\"a\":1,\"b\":2}\n\n[0]\n{\"b\":3,\"a\":4}\n{\"a\":5,\"a\":6}\n{\"c\":7}"
  let source = @input.input_from_text_with_format(
    text,
    "schema.jsonl",
    Some(Jsonl),
  )
  let stream = open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      source,
      @parser.new_parse_context(Jsonl),
      jsonl_parser_capability(),
    )
    .unwrap()
    .unwrap()
  let events : Array[@core.CoreEvent] = []
  while true {
    match (stream.next)().unwrap() {
      Some(event) => events.push(event)
      None => break
    }
  }
  assert_eq(
    events.filter(event => event.kind == Cell).map(event => event.text),
    ["a", "b", "1", "2", "4", "3", "6", ""],
  )
  let codes = events.filter(event => event.kind == StartBlock(Code))
  assert_eq(codes.map(event => event.text), ["[0]", "{\"c\":7}"])
  assert_eq(codes.map(event => event.source_ref.unwrap().line_start), [
    Some(3),
    Some(6),
  ])
  assert_eq(codes.map(event => event.source_ref.unwrap().json_pointer), [
    Some("/1"),
    Some("/4"),
  ])
  assert_true(events[events.length() - 1].kind == StartBlock(Code))
  let summary = (stream.finish)().unwrap()
  assert_eq(summary.diagnostics.metrics.get("record_count"), Some("5"))
  assert_eq(
    summary.diagnostics.metrics.get("non_table_record_count"),
    Some("2"),
  )
  assert_eq(summary.diagnostics.metrics.get("blank_line_count"), Some("1"))
}

///|
async test "JSONL schema remains conversion local and admits only bounded prefix" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Ndjson),
    None,
    Some(2),
    None,
    None,
    None,
    false,
  )
  for text in ["{\"a\":1}\n{\"a\":2}\ninvalid", "{\"b\":3}\n{\"b\":4}\ninvalid"] {
    let source = @input.input_from_text_with_format(
      text,
      "local.ndjson",
      Some(Ndjson),
    )
    let stream = open_line_json_event_stream(
        "ndjson_parser",
        "ndjson",
        source,
        context,
        ndjson_parser_capability(),
      )
      .unwrap()
      .unwrap()
    let cells : Array[String] = []
    while true {
      match (stream.next)().unwrap() {
        Some(event) if event.kind == Cell => cells.push(event.text)
        Some(_) => ()
        None => break
      }
    }
    assert_eq(
      cells,
      if text.has_prefix("{\"a\"") {
        ["a", "1", "2"]
      } else {
        ["b", "3", "4"]
      },
    )
    assert_eq(
      (stream.finish)().unwrap().diagnostics.metrics.get("record_count"),
      Some("2"),
    )
  }
}
