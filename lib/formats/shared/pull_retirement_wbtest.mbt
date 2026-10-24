///|
async test "delimited early close retires queued cells" {
  let caller = @input.begin_input_session(@input.input_from_text("a,b\n1,2\n"))
  defer @input.end_input_session(caller)
  let stream = open_delimited_event_stream(
      "csv_parser",
      Csv,
      false,
      caller.source,
      @parser.new_parse_context(Csv),
    )
    .unwrap()
    .unwrap()
  let first = (stream.next)().unwrap().unwrap()
  assert_eq(first.text, "a")
  stream.close().unwrap()
  stream.close().unwrap()
  assert_true((stream.next)() is Ok(None))
  assert_eq(first.text, "a")
  assert_true(first.source_ref.unwrap().line_start == Some(1))
  assert_true(@input.read_input_text(caller.source) is Ok("a,b\n1,2\n"))
}

///|
async test "private delimited reader close retires buffered rows" {
  let caller = @input.begin_input_session(@input.input_from_text("a,b\n1,2\n"))
  defer @input.end_input_session(caller)
  let rows = open_pull_delimited_reader(
    caller.source,
    @parser.new_parse_context(Csv),
    ',',
  ).unwrap()
  let row = (rows.next)().unwrap().unwrap()
  (rows.close)()
  assert_true((rows.next)() is Ok(None))
  assert_eq(row.fields, ["a", "b"])
}

///|
async test "CSV and TSV full consumption preserve cell order refs and finish" {
  for is_tsv in [false, true] {
    let format = if is_tsv { @input.DetectedFormat::Tsv } else { Csv }
    let name = if is_tsv { "tsv_parser" } else { "csv_parser" }
    let text = if is_tsv { "a\tb\r\n1\t2\n" } else { "a,b\r\n1,2\n" }
    let stream = open_delimited_event_stream(
        name,
        format,
        is_tsv,
        @input.input_from_text(text),
        @parser.new_parse_context(format),
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
    assert_eq(events.map(event => event.text), ["a", "b", "", "1", "2", ""])
    for index in 0..<events.length() {
      assert_true(
        events[index].source_ref.unwrap().line_start ==
        Some(if index < 3 { 1 } else { 2 }),
      )
    }
    let summary = (stream.finish)().unwrap()
    assert_true(summary.diagnostics.metrics.get("event_count") == Some("6"))
  }
}
