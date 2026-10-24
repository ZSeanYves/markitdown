///|
async test "YAML logical-work hard error reaches both public APIs without Sink output" {
  for use_sink in [false, true] {
    let account = @budget.Budget::new(
      @budget.BudgetLimits::new(
        Enforced,
        inflate_bytes=Some(1048576L),
        parse_work=Some(20L),
        output_utf8_bytes=Some(1048576L),
        source_metadata_bytes=Some(1048576L),
        rag_metadata_bytes=Some(1048576L),
        read_traffic_bytes=Some(1048576L),
        cache_bytes=Some(1048576L),
        working_bytes=Some(1048576L),
        temporary_bytes=Some(1048576L),
        ir_bytes=Some(1048576L),
      ).unwrap(),
    )
    let owner = @input.begin_input_session(
      @input.input_from_text_with_format(
        "a: &a [x, x]\nb: &b [*a, *a]\nc: &c [*b, *b]\nroot: *c\n",
        "logical.yaml",
        Some(Yaml),
      ),
      budget=account,
    )
    defer @input.end_input_session(owner)
    let input : Input = { source: owner.source, kind: Text, }
    let writes = Ref(0)
    let finishes = Ref(0)
    let error = if use_sink {
      match
        convert_to_sink(
          input,
          OutputSink::new(
            fn(_) {
              writes.val += 1
              Ok(())
            },
            fn() {
              finishes.val += 1
              Ok(())
            },
          ),
        ) {
        Err(error) => error
        Ok(_) => fail("Sink accepted the exceeded logical work budget")
      }
    } else {
      match convert(input) {
        Err(error) => error
        Ok(_) => fail("collector accepted the exceeded logical work budget")
      }
    }
    assert_true(
      error is ResourceLimitExceeded(kind="parse_work", observed=26L, limit=20L),
    )
    assert_eq(error.exit_code(), 5)
    assert_eq(writes.val, 0)
    assert_eq(finishes.val, 0)
    assert_true(
      @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
    )
  }
}
