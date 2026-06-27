///|
test "convert provenance reports markdown huge block route" {
  let source = @input.input_from_path(
    "samples/bench/markdown/huge/markdown_huge_synthetic_book_v1.md",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected markdown huge provenance: " + err.to_string())
  }
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "block_streaming",
  )
  assert_true(
    execution.provenance.pipeline_output_kind == "block_stream" ||
    execution.provenance.pipeline_output_kind == "document",
  )
}

///|
test "convert provenance reports json large streaming route" {
  let source = @input.input_from_path(
    "samples/bench/json/large/json_large_worldbank_population_v1.json",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected json large provenance: " + err.to_string())
  }
  assert_eq(execution.provenance.route_plan.selected_route, "streaming_event")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "streaming_event",
  )
  assert_eq(execution.provenance.parse_result_kind, "event_stream")
}

///|
test "convert provenance reports zip container route" {
  let source = @input.input_from_path(
    "samples/bench/zip/small/zip_small_html_local_image_v1.zip",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected zip provenance: " + err.to_string())
  }
  assert_eq(
    execution.provenance.route_plan.selected_route,
    "container_recursive",
  )
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "container_recursive",
  )
  assert_true(
    execution.provenance.pipeline_output_kind == "block_stream" ||
    execution.provenance.pipeline_output_kind == "document",
  )
}

///|
test "convert provenance reports xlsx huge block streaming route fidelity" {
  let source = @input.input_from_path(
    "samples/bench/xlsx/huge/xlsx_huge_myeb_2011_2024_v1.xlsx",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected xlsx huge provenance: " + err.to_string())
  }
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "block_streaming",
  )
  assert_eq(execution.provenance.parse_result_kind, "block_stream")
  assert_eq(execution.provenance.pipeline_output_kind, "block_stream")
  assert_eq(execution.provenance.render_input_kind, "block_stream")
  assert_eq(execution.provenance.route_fidelity_status, "matched")
}

///|
test "convert provenance reports xml synthetic medium streaming route fidelity" {
  let source = @input.input_from_path(
    "samples/bench/xml/medium/xml_medium_synthetic_entries_v1.xml",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected xml medium provenance: " + err.to_string())
  }
  assert_eq(execution.provenance.route_plan.selected_route, "streaming_event")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "streaming_event",
  )
  assert_eq(execution.provenance.parse_result_kind, "event_stream")
  assert_eq(execution.provenance.pipeline_output_kind, "event_stream")
  assert_eq(execution.provenance.render_input_kind, "event_stream")
  assert_eq(execution.provenance.route_fidelity_status, "matched")
}

///|
test "convert provenance reports html large block streaming route fidelity" {
  let source = @input.input_from_path(
    "samples/bench/html/large/html_large_wai_aria_v1.html",
  )
  let execution = match
    @convert.convert_input_with_provenance(
      source,
      @convert.default_convert_options(),
    ) {
    Ok(value) => value
    Err(err) => fail("expected html large provenance: " + err.to_string())
  }
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "block_streaming",
  )
  assert_eq(execution.provenance.parse_result_kind, "block_stream")
  assert_eq(execution.provenance.pipeline_output_kind, "block_stream")
  assert_eq(execution.provenance.render_input_kind, "block_stream")
  assert_eq(execution.provenance.route_fidelity_status, "matched")
}
