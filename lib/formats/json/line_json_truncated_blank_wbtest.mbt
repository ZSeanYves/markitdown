///|
fn truncated_blank_context(
  cap : Int64?,
  rows~ : Int32 = 200,
  line_chars~ : Int32 = 4000,
) -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.new_parse_context(Jsonl),
    Some(StreamingEvent),
    Some(rows),
    Some(50),
    Some(10000),
    Some(line_chars),
    false,
    limits=@product.make_resource_limits(
      rows,
      50,
      10000,
      max_line_chars=line_chars,
      max_temporary_bytes=cap,
    ),
  )
}

///|
async fn truncated_blank_reject(text : String) -> Unit {
  let source = @input.input_from_text_with_format(
    text,
    "prefix.jsonl",
    Some(Jsonl),
  )
  let ordinary = (jsonl_parser().parse)(source, truncated_blank_context(None)).unwrap()
  assert_true(ordinary.diagnostics.metrics.get("record_count") == Some("1"))
  assert_true(ordinary.event_stream.unwrap().length() > 0)
  let owner = @input.begin_input_session(source)
  defer @input.end_input_session(owner)
  let cleanup = @input.begin_input_cleanup_scope(owner)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let result = (jsonl_parser().parse)(
    owner.source,
    truncated_blank_context(Some(1024L)),
  )
  assert_true(
    result is Err(_),
    msg="a truncated prefix cannot prove that the whole record is blank",
  )
  assert_true(@input.input_source_failure(owner.source) is Some(InputError(_)))
  let snapshot = @input.input_source_budget_context(owner.source).unwrap().account.snapshot()
  assert_eq(snapshot.resident.temporary_bytes, 0L)
  assert_eq(snapshot.resident.working_bytes, 0L)
  assert_false(snapshot.closed)
}

///|
async test "collected Some rejects a scalar hidden after a truncated ASCII whitespace prefix" {
  truncated_blank_reject(" ".repeat(4000) + "0")
}

///|
async test "collected Some does not widen the pinned ASCII trim set to Unicode whitespace" {
  let source = @input.input_from_text_with_format(
    "\u{2003}".repeat(4000) + "0",
    "unicode.jsonl",
    Some(Jsonl),
  )
  let ordinary = (jsonl_parser().parse)(source, truncated_blank_context(None)).unwrap()
  assert_true(ordinary.diagnostics.metrics.get("json_valid") == Some("false"))
  assert_true(
    (jsonl_parser().parse)(source, truncated_blank_context(Some(1024L)))
    is Err(_),
  )
}

///|
async test "collected Some normalizes RS and one BOM before classifying the whole truncated record" {
  truncated_blank_reject("\u{001E}\u{FEFF}" + " ".repeat(4000) + "0")
}

///|
async test "collected Some stops blank diagnostics at an omitted nonblank truncated line" {
  let text = "{\"a\":1}\n" + " ".repeat(4000) + "0\n\n"
  let source = @input.input_from_text_with_format(
    text,
    "tail.jsonl",
    Some(Jsonl),
  )
  let ordinary = (jsonl_parser().parse)(
    source,
    truncated_blank_context(None, rows=1),
  ).unwrap()
  let spooled = (jsonl_parser().parse)(
    source,
    truncated_blank_context(Some(102L), rows=1),
  ).unwrap()
  assert_true(ordinary.diagnostics.metrics.get("blank_line_count") == Some("0"))
  assert_true(spooled.diagnostics.metrics.get("blank_line_count") == Some("0"))
  assert_eq(ordinary.diagnostics.warnings, spooled.diagnostics.warnings)
  assert_eq(
    ordinary.event_stream.unwrap().map(event => event.text),
    spooled.event_stream.unwrap().map(event => event.text),
  )
}

///|
async test "collected Some retains true blank diagnostics for a wholly whitespace truncated line" {
  let source = @input.input_from_text_with_format(
    " ".repeat(4001) + "\n",
    "blank.jsonl",
    Some(Jsonl),
  )
  let ordinary = (jsonl_parser().parse)(source, truncated_blank_context(None)).unwrap()
  let spooled = (jsonl_parser().parse)(
    source,
    truncated_blank_context(Some(0L)),
  ).unwrap()
  assert_true(ordinary.diagnostics.metrics.get("blank_line_count") == Some("2"))
  assert_true(spooled.diagnostics.metrics.get("blank_line_count") == Some("2"))
  assert_eq(ordinary.diagnostics.warnings, spooled.diagnostics.warnings)
}

///|
async test "collected Some keeps the existing hard line limit when a nonblank prefix is visible" {
  let source = @input.input_from_text_with_format(
    "\"01234\"",
    "nonblank.jsonl",
    Some(Jsonl),
  )
  assert_true(
    (jsonl_parser().parse)(source, truncated_blank_context(None, line_chars=4))
    is Ok(_),
  )
  assert_true(
    (jsonl_parser().parse)(
      source,
      truncated_blank_context(Some(1024L), line_chars=4),
    )
    is Err(_),
  )
}

///|
async test "Some pull uses the same full record fact before its existing hard line limit" {
  let owner = @input.begin_input_session(
    @input.input_from_text_with_format(
      " ".repeat(4000) + "0",
      "pull.jsonl",
      Some(Jsonl),
    ),
  )
  defer @input.end_input_session(owner)
  let cleanup = @input.begin_input_cleanup_scope(owner)
  defer ignore(@input.cleanup_input_scope(cleanup))
  assert_true(
    open_line_json_event_stream(
      "jsonl_parser",
      "jsonl",
      owner.source,
      truncated_blank_context(Some(1024L)),
      jsonl_parser_capability(),
    )
    is Err(_),
  )
  assert_true(@input.input_source_failure(owner.source) is Some(InputError(_)))
  assert_eq(
    @input.input_source_budget_context(owner.source).unwrap().account.snapshot().resident.temporary_bytes,
    0L,
  )
}

///|
async test "collected Some still validates a hard UTF8 tail after an omitted truncated nonblank record" {
  let bytes = @utf8.encode(
    "{\"a\":1}\n" + " ".repeat(4000) + "0\n" + " ".repeat(140000) + "\n",
  ).to_array()
  bytes.push(b'\xff')
  let owner = @input.begin_input_session(
    @input.input_from_bytes_with_format(
      Bytes::from_array(bytes),
      "bad-tail.jsonl",
      Some(Jsonl),
    ),
  )
  defer @input.end_input_session(owner)
  let cleanup = @input.begin_input_cleanup_scope(owner)
  defer ignore(@input.cleanup_input_scope(cleanup))
  assert_true(
    (jsonl_parser().parse)(
      owner.source,
      truncated_blank_context(Some(102L), rows=1),
    )
    is Err(_),
  )
  assert_true(@input.input_source_failure(owner.source) is Some(InputError(_)))
  assert_eq(
    @input.input_source_budget_context(owner.source).unwrap().account.snapshot().resident.temporary_bytes,
    0L,
  )
}
