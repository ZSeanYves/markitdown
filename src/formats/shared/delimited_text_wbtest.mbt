///|
test "CSV parser covers quoted multiline ragged rows and resource limits" {
  let csv = "name,value,notes\nalpha,1,\"line one\nline two\"\nbeta,2\ngamma,3,ok,extra"
  let source = @input.input_from_text_with_format(csv, "complex.csv", Some(Csv))
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(Csv),
    Some(StreamingEvent),
    Some(3),
    Some(3),
    Some(6),
    None,
    false,
  )
  let result = (csv_parser().parse)(source, context).unwrap()
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 8)
  assert_true(events.any(event => event.kind == RowBreak))
  assert_true(
    result.diagnostics.metrics.get("quoted_newline_observed") == Some("true"),
  )
  assert_true(result.diagnostics.metrics.get("ragged_row_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("row_count") == Some("2"))
  assert_true(
    result.diagnostics.degraded_features.contains("ragged_rows_normalized"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("max_rows_truncation"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("max_cols_truncation"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("max_cells_truncation"),
  )
  assert_true(
    result.diagnostics.degraded_features.contains("cell_budget_row_trim"),
  )
}

///|
test "TSV parser emits tab-delimited cells and source cell ranges" {
  let source = @input.input_from_text_with_format(
    "name\tvalue\nalpha\t1",
    "table.tsv",
    Some(Tsv),
  )
  let result = (tsv_parser().parse)(source, @parser.new_parse_context(Tsv)).unwrap()
  let events = result.event_stream.unwrap()
  assert_eq(events.length(), 6)
  assert_eq(events[0].text, "name")
  assert_true(events[0].source_ref.unwrap().cell_range == Some("R1C1"))
  assert_true(result.diagnostics.metrics.get("delimiter") == Some("tab"))
  assert_true(
    result.diagnostics.metrics.get("quoted_delimiter_support") ==
    Some("quoted_tab"),
  )
}

///|
test "CSV malformed quoted input returns raw document fallback" {
  let source = @input.input_from_text_with_format(
    "name,value\nalpha,\"unterminated",
    "broken.csv",
    Some(Csv),
  )
  let result = (csv_parser().parse)(source, @parser.new_parse_context(Csv)).unwrap()
  assert_true(result.document is Some(_))
  assert_eq(result.document.unwrap().blocks.length(), 1)
  assert_true(result.diagnostics.degraded_features.contains("csv_raw_fallback"))
  assert_true(
    result.diagnostics.metrics.get("fallback_reason_kind") ==
    Some("unterminated_quoted_field"),
  )
  assert_true(result.diagnostics.metrics.get("event_count") == Some("0"))
}

///|
test "Delimited parser helpers classify errors and expose streaming capability" {
  assert_eq(
    delimited_parse_error_kind_name("Unterminated quoted field at EOF"),
    "unterminated_quoted_field",
  )
  assert_eq(delimited_parse_error_kind_name("other"), "unknown")
  let capability = csv_parser_capability()
  assert_true(capability.supports_streaming)
  assert_true(capability.produces_tables)
}
