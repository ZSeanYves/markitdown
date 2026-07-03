///|
fn convert_with_provenance(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  limits : @convert.ResourceLimits,
  stream_requested? : Bool = false,
) -> @convert.ConvertExecution raise {
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    limits,
    stream_requested~,
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
  )
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
  )
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
  )
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
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_eq(
    @convert.output_mode_name(execution.provenance.output_mode),
    "markdown",
  )
}

///|
test "convert provenance reports html explicit stream route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/html/markdown/html_semantic_sectioning.html",
    ),
    @input.DetectedFormat::Html,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
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
test "convert provenance reports epub explicit stream container route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/epub/markdown/epub_basic_package.epub",
    ),
    @input.DetectedFormat::Epub,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(
    execution.provenance.route_plan.selected_route,
    "container_recursive",
  )
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "container_recursive",
  )
  assert_eq(execution.provenance.parse_result_kind, "block_stream")
  assert_eq(execution.provenance.pipeline_output_kind, "block_stream")
  assert_eq(execution.provenance.render_input_kind, "block_stream")
  assert_eq(execution.provenance.route_fidelity_status, "matched")
}

///|
test "convert provenance reports xlsx explicit stream route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/xlsx/markdown/sheet_simple.xlsx",
    ),
    @input.DetectedFormat::Xlsx,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
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
test "convert provenance reports odt explicit stream route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/odt/markdown/odt_basic_sample.odt",
    ),
    @input.DetectedFormat::Odt,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
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
test "convert provenance reports ods explicit stream route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/ods/markdown/ods_basic_sample.ods",
    ),
    @input.DetectedFormat::Ods,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
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
test "convert provenance reports odp explicit stream route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/odp/markdown/odp_basic_sample.odp",
    ),
    @input.DetectedFormat::Odp,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "block_streaming")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_mode",
  )
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
test "convert provenance reports toml explicit stream fallback honestly" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/main_process/toml/markdown/toml_object_basic.toml",
    ),
    @input.DetectedFormat::Toml,
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  assert_eq(execution.provenance.route_plan.selected_route, "dom_ast_model")
  assert_eq(
    execution.provenance.route_plan.route_reason,
    "explicit_stream_unsupported_fell_back",
  )
  assert_eq(
    @parser.mode_name(execution.provenance.effective_parser_mode),
    "dom_ast_model",
  )
  assert_eq(execution.provenance.parse_result_kind, "document")
  assert_eq(execution.provenance.pipeline_output_kind, "document")
  assert_eq(execution.provenance.render_input_kind, "document")
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
