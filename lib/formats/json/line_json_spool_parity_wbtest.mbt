///|
fn spool_parity_context(
  cap : Int64?,
  rows~ : Int32 = 200,
) -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.new_parse_context(Jsonl),
    Some(StreamingEvent),
    Some(rows),
    Some(50),
    Some(10000),
    Some(4000),
    false,
    limits=@product.make_resource_limits(
      rows,
      50,
      10000,
      max_temporary_bytes=cap,
    ),
  )
}

///|
async test "collected JSONL spool preserves legacy newline blanks and parser diagnostics" {
  for
    text in [
      "{\"a\":1}\n", "{\"a\":1}\r\n", "{\"a\":1}\r", "\u{FEFF}{\"a\":\"😀\"}\n\n",
      "", "\u{FEFF}", "\u{FEFF}\u{FEFF}{\"a\":1}\n", "\u{FEFF}\u{FEFF}\u{FEFF}{\"a\":1}\n",
      "{\"a\":1}\r{\"a\":2}\r",
    ] {
    let source = @input.input_from_text_with_format(
      text,
      "parity.jsonl",
      Some(Jsonl),
    )
    let ordinary = (jsonl_parser().parse)(source, spool_parity_context(None)).unwrap()
    let spooled = (jsonl_parser().parse)(
      source,
      spool_parity_context(Some(4096L)),
    ).unwrap()
    for
      key in [
        "blank_line_count", "record_count", "row_count", "table_count", "image_count",
        "asset_count", "block_count", "event_count", "warning_count", "fallback_count",
        "degraded_feature_count",
      ] {
      assert_true(
        ordinary.diagnostics.metrics.get(key) ==
        spooled.diagnostics.metrics.get(key),
        msg=key + ": " + text,
      )
    }
    assert_eq(ordinary.diagnostics.warnings, spooled.diagnostics.warnings)
    assert_eq(
      ordinary.diagnostics.degraded_features,
      spooled.diagnostics.degraded_features,
    )
    assert_eq(
      ordinary.diagnostics.fallback_trace,
      spooled.diagnostics.fallback_trace,
    )
    assert_eq(ordinary.diagnostics.pass_trace, spooled.diagnostics.pass_trace)
    assert_true(
      ordinary.event_stream.map(events => events.map(event => event.text)) ==
      spooled.event_stream.map(events => events.map(event => event.text)),
    )
    assert_true(
      ordinary.block_stream.map(blocks => blocks.map(block => block.text)) ==
      spooled.block_stream.map(blocks => blocks.map(block => block.text)),
    )
    assert_true(
      ordinary.document.map(document => document.blocks.map(block => block.text)) ==
      spooled.document.map(document => document.blocks.map(block => block.text)),
    )
  }
}

///|
async test "collected JSONL cap preserves blank before first omitted record" {
  for
    (text, blank) in [
      ("{\"a\":1}\n", "1"),
      ("{\"a\":1}\n\n\n{\"a\":2}\n\n", "2"),
      ("{\"a\":1}\r\n\r\n", "2"),
    ] {
    let source = @input.input_from_text_with_format(
      text,
      "capped.jsonl",
      Some(Jsonl),
    )
    let ordinary = (jsonl_parser().parse)(
      source,
      spool_parity_context(None, rows=1),
    ).unwrap()
    let spooled = (jsonl_parser().parse)(
      source,
      spool_parity_context(Some(102L), rows=1),
    ).unwrap()
    assert_true(
      ordinary.diagnostics.metrics.get("blank_line_count") == Some(blank),
    )
    assert_true(
      spooled.diagnostics.metrics.get("blank_line_count") == Some(blank),
    )
    assert_eq(ordinary.diagnostics.warnings, spooled.diagnostics.warnings)
    assert_eq(
      ordinary.event_stream.unwrap().map(event => event.text),
      spooled.event_stream.unwrap().map(event => event.text),
    )
  }
}

///|
async test "collected JSONL cap validates complete UTF8 even beyond its first input prefetch" {
  // The old collector reads and validates all input before applying max_rows.
  // Put the bad byte beyond the bounded first prefetch so stopping at the row
  // cap cannot accidentally pass this contract.
  let bytes = @utf8.encode("{\"a\":1}\n" + " ".repeat(140000) + "\n").to_array()
  bytes.push(b'\xff')
  for cap in [None, Some(102L)] {
    let source = @input.input_from_bytes_with_format(
      Bytes::from_array(bytes),
      "invalid-tail.jsonl",
      Some(Jsonl),
    )
    assert_true(
      (jsonl_parser().parse)(source, spool_parity_context(cap, rows=1))
      is Err(_),
    )
  }
}

///|
async test "collected JSONL cap cannot swallow late reader failure after its admitted rows" {
  for cap in [None, Some(102L)] {
    let reads = Ref(0)
    let reader = @input.make_async_input_reader(fn(_, _) {
      reads.val += 1
      if reads.val == 1 {
        Ok(b"{\"a\":1}\n")
      } else {
        Err("late parity IO failure")
      }
    })
    let source = @input.input_from_reader(reader, source_name="late.jsonl")
    assert_true(
      (jsonl_parser().parse)(source, spool_parity_context(cap, rows=1))
      is Err(_),
    )
    assert_eq(reads.val, 2)
  }
}

///|
async test "JSONL successful borrowed parent uses its tighter effective cap and preserves parent ownership" {
  let account = spool_test_account(102L)
  let parent = @input.begin_input_session(
    @input.input_from_text("parent"),
    budget=account,
  )
  defer @input.end_input_session(parent)
  let cleanup = @input.begin_input_cleanup_scope(parent)
  defer ignore(@input.cleanup_input_scope(cleanup))
  let source = @input.input_source_inherit_session(
    @input.input_from_text_with_format(
      "{\"a\":1}\n",
      "borrowed.jsonl",
      Some(Jsonl),
    ),
    parent.source,
  )
  let result = (jsonl_parser().parse)(source, spool_parity_context(Some(204L))).unwrap()
  assert_eq(result.event_stream.unwrap().map(event => event.text), [
    "a", "", "1", "",
  ])
  assert_true(account.snapshot().limits.temporary_bytes == Some(102L))
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 102L)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_false(account.snapshot().closed)
  assert_true(@input.input_source_failure(parent.source) is None)
  assert_true(@input.cleanup_input_scope(cleanup) is Ok(_))
}
