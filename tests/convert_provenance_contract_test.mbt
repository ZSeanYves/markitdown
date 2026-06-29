///|
fn convert_with_provenance(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  limits : @convert.ResourceLimits,
) -> @convert.ConvertExecution raise {
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    limits,
  )
  match @convert.convert_input_with_provenance(source, options) {
    Ok(value) => value
    Err(err) => fail("expected convert provenance: " + err.to_string())
  }
}

///|
test "convert provenance reports markdown huge block route" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/markdown/markdown/markdown_basic_heading_paragraph.md",
    ),
    @input.DetectedFormat::Markdown,
    @convert.make_resource_limits(1, 1, 10000),
  )
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
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/json/markdown/large_array_streaming.json",
    ),
    @input.DetectedFormat::Json,
    @convert.make_resource_limits(1, 50, 10000),
  )
  assert_eq(execution.provenance.route_plan.selected_route, "streaming_event")
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "streaming_event",
  )
  assert_eq(execution.provenance.parse_result_kind, "event_stream")
}

///|
test "convert provenance reports zip container route" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/zip/markdown/zip_assets_namespace.zip",
    ),
    @input.DetectedFormat::Zip,
    @convert.default_resource_limits(),
  )
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
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
    @convert.make_resource_limits(1, 1, 1),
  )
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
  let execution = convert_with_provenance(
    @input.input_from_path("samples/main_process/xml/markdown/xml_nested.xml"),
    @input.DetectedFormat::Xml,
    @convert.make_resource_limits(1, 50, 10000, max_line_chars=8),
  )
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
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_semantic_sectioning.html",
    ),
    @input.DetectedFormat::Html,
    @convert.make_resource_limits(1, 50, 100000),
  )
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
test "convert provenance keeps html block token offsets source-aligned" {
  let text = "\u{FEFF}<html>\r\n<body>\r\n<section><h1>A &amp; B</h1>\r\n<p>First &lt; second.</p></section>\r\n</body></html>"
  let source = @input.input_from_text_with_format(
    text,
    "offset.html",
    Some(@input.DetectedFormat::Html),
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Html),
    @parser.default_ocr_options(),
    @convert.make_resource_limits(1, 50, 100000, max_line_chars=8),
  )
  let execution = match
    @convert.convert_input_with_provenance(source, options) {
    Ok(value) => value
    Err(err) => fail("expected html offset provenance: " + err.to_string())
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
  assert_true(execution.result.content.contains("# A & B"))
  assert_true(execution.result.content.contains("First \\< second."))
}
