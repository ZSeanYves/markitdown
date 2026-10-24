///|
fn output_test_account(limit : Int64?) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=limit,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
fn output_test_without_phase_timings(text : String) -> Json raise {
  let value = @json.parse(text)
  if value is Object(root) &&
    root.get("diagnostics") is Some(Object(diagnostics)) &&
    diagnostics.get("metrics") is Some(Object(metrics)) {
    for
      key in [
        "timing_detect_probe_ms", "timing_parse_lower_ms", "timing_pipeline_ms",
      ] {
      metrics.remove(key)
    }
  }
  value
}

///|
async test "collect and Sink account each admitted output UTF8 byte once in every view" {
  let source = @input.input_from_text_with_format(
    "Café\n\nsecond",
    "meter.txt",
    Some(Txt),
  )
  for mode in [@product.OutputMode::Markdown, Debug, Rag] {
    let options = { ..default_convert_options(), output_mode: mode, }
    let baseline = convert_input(source, options).unwrap()
    for sink_mode in [false, true] {
      // Each conversion measures its own bytes: JSON phase timings may differ
      // in both value and digit count between otherwise equivalent runs.
      let account = output_test_account(None)
      let session = @input.begin_input_session(source, budget=account)
      let writes : Array[String] = []
      let result = if sink_mode {
        convert_input_to_sink_unbuffered(
          session.source,
          options,
          make_output_sink(
            fn(part) {
              writes.push(part)
              Ok(())
            },
            fn() { Ok(()) },
          ),
        )
      } else {
        convert_input(session.source, options)
      }
      let result = result.unwrap()
      let content = if sink_mode { writes.join("") } else { result.content }
      if mode == Markdown {
        assert_eq(content, baseline.content)
      } else {
        assert_eq(
          output_test_without_phase_timings(content),
          output_test_without_phase_timings(baseline.content),
        )
      }
      let bytes = @input.validated_text_utf8_size(content).unwrap()
      assert_eq(account.snapshot().cumulative.output_utf8_bytes, bytes)
      assert_eq(
        result.diagnostics.metrics.get("budget_output_confirmed_utf8_bytes"),
        Some(bytes.to_string()),
      )
      @input.end_input_session(session)
      assert_true(account.snapshot().closed)
      assert_eq(account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "output budget admits the exact UTF8 byte boundary" {
  let text = "Café😀"
  let bytes = @input.validated_text_utf8_size(text).unwrap()
  let account = output_test_account(Some(bytes))
  let session = @input.begin_input_session(
    @input.input_from_text("source"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let writes : Array[String] = []
  let confirmed = Ref(0L)
  write_output_sink_bounded(
    make_output_sink(
      fn(part) {
        writes.push(part)
        Ok(())
      },
      () => fail("write helper must not finish a destination"),
    ),
    text,
    source=session.source,
    confirmed_bytes=confirmed,
  ).unwrap()
  assert_eq(writes.join(""), text)
  assert_eq(account.snapshot().cumulative.output_utf8_bytes, bytes)
  assert_eq(confirmed.val, bytes)
}

///|
async test "output budget stops collector and Sink without finish and preserves the domain error" {
  let source = @input.input_from_text_with_format(
    "Café",
    "meter.txt",
    Some(Txt),
  )
  for mode in [@product.OutputMode::Markdown, Debug, Rag] {
    let options = { ..default_convert_options(), output_mode: mode, }
    for sink_mode in [false, true] {
      let account = output_test_account(Some(0L))
      let session = @input.begin_input_session(source, budget=account)
      let writes = Ref(0)
      let finishes = Ref(0)
      let result = if sink_mode {
        convert_input_to_sink_unbuffered(
          session.source,
          options,
          make_output_sink(
            fn(_part) {
              writes.val += 1
              Ok(())
            },
            fn() {
              finishes.val += 1
              Ok(())
            },
          ),
        )
      } else {
        convert_input(session.source, options)
      }
      match result {
        Err(
          ResourceLimitExceeded(kind="output_utf8_bytes", observed~, limit=0L)
        ) => assert_true(observed > 0L)
        _ =>
          fail("output admission failure must preserve ResourceLimitExceeded")
      }
      assert_eq((writes.val, finishes.val), (0, 0))
      assert_eq(account.snapshot().cumulative.output_utf8_bytes, 0L)
      @input.end_input_session(session)
      assert_eq(account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "failed Sink write retains admitted bytes and confirms only the successful prefix" {
  let account = output_test_account(None)
  let session = @input.begin_input_session(
    @input.input_from_text("source"),
    budget=account,
  )
  defer @input.end_input_session(session)
  let confirmed = Ref(0L)
  let calls = Ref(0)
  let text = "a".repeat(OUTPUT_SINK_CHUNK_CHARS) + "é"
  let result = write_output_sink_bounded(
    make_output_sink(
      fn(_part) {
        calls.val += 1
        if calls.val == 2 {
          Err("partial destination failure")
        } else {
          Ok(())
        }
      },
      () => fail("write helper must not finish a destination"),
    ),
    text,
    source=session.source,
    confirmed_bytes=confirmed,
  )
  assert_eq(result, Err("partial destination failure"))
  assert_eq(
    account.snapshot().cumulative.output_utf8_bytes,
    OUTPUT_SINK_CHUNK_CHARS.to_int64() + 2L,
  )
  assert_eq(confirmed.val, OUTPUT_SINK_CHUNK_CHARS.to_int64())
  assert_eq(calls.val, 2)
}
