///|
fn text_markup_probe_source(
  text : String,
  format : @input.DetectedFormat,
) -> @input.InputSource {
  @input.input_from_text_with_format(
    text,
    "sample." + @input.detected_format_name(format),
    Some(format),
  )
}

///|
fn balanced_markdown_options(format : @input.DetectedFormat) -> ConvertOptions {
  make_convert_options(
    Balanced,
    Markdown,
    Some(format),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
}

///|
test "route probe metric vocabulary covers empty and structured signal branches" {
  assert_eq(format_route_probe_summary("json", []), "route_probe:json")
  assert_eq(probe_signals_metric([]), "")
  assert_eq(probe_failures_metric([]), "")
  let signals = [
    make_probe_signal(CellCount, 12),
    make_probe_signal(ScalarCount, 4, limit=Some(10)),
    make_probe_signal(ArrayCount, 2, note=Some("nested")),
  ]
  let metric = probe_signals_metric(signals)
  assert_true(metric.contains("cell_count=12"))
  assert_true(metric.contains("scalar_count=4/limit=10"))
  assert_true(metric.contains("array_count=2/note=nested"))
  assert_eq(
    probe_failures_metric([
      make_probe_failure("decode", "invalid"),
      make_probe_failure("budget", "limit"),
    ]),
    "decode:invalid|budget:limit",
  )
}

///|
test "route policy rejects unsupported modes and keeps declared stream routes" {
  let toml_source = text_markup_probe_source("title = \"demo\"\n", Toml)
  let accurate_toml = make_convert_options(
    Accurate,
    Markdown,
    Some(Toml),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
  match detect_and_resolve_execution_plan(toml_source, accurate_toml) {
    Err(err) =>
      assert_true(
        err.to_string().contains("accurate mode is unsupported for `toml`"),
      )
    Ok(_) => fail("unsupported accurate mode must fail closed")
  }

  let pdf_source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(Pdf),
  )
  let stream_pdf = make_convert_options(
    Stream,
    Markdown,
    Some(Pdf),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
  match detect_and_resolve_execution_plan(pdf_source, stream_pdf) {
    Err(err) =>
      assert_true(
        err.to_string().contains("stream mode is unsupported for `pdf`"),
      )
    Ok(_) => fail("unsupported PDF stream mode must fail closed")
  }

  let json_source = text_markup_probe_source("{\"ok\":true}", Json)
  let stream_json = make_convert_options(
    Stream,
    Markdown,
    Some(Json),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
  match detect_and_resolve_execution_plan(json_source, stream_json) {
    Ok(value) => assert_true(value.2.reason == "explicit_stream_mode")
    Err(err) =>
      fail(
        "declared JSON stream route must remain supported: " + err.to_string(),
      )
  }
}

///|
test "text markup preflight probe reuses preparsed tex document artifact" {
  let source = text_markup_probe_source(
    "\\section{Intro}\n\nHello world.\n",
    Tex,
  )
  let options = balanced_markdown_options(Tex)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Tex, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Tex,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed tex artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == Heading)
  assert_true(document.blocks[0].text.contains("Intro"))
}

///|
test "text markup preflight probe reuses preparsed rst document artifact" {
  let source = text_markup_probe_source(
    "Title\n=====\n\nBody paragraph.\n",
    Rst,
  )
  let options = balanced_markdown_options(Rst)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Rst, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Rst,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed rst artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == Heading)
  assert_true(document.blocks[1].text.contains("Body paragraph"))
}

///|
test "text markup preflight probe reuses preparsed asciidoc document artifact" {
  let source = text_markup_probe_source(
    "= Title\n\nA short paragraph.\n",
    Asciidoc,
  )
  let options = balanced_markdown_options(Asciidoc)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Asciidoc, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Asciidoc,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed asciidoc artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == Heading)
  assert_true(document.blocks[0].text.contains("Title"))
}

///|
test "pdf preflight probe reuses native document artifact on product parse path" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(Pdf),
  )
  let options = balanced_markdown_options(Pdf)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Pdf, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Pdf,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed pdf artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 3)
  assert_true(
    parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
}

///|
test "zip preflight probe reuses archive artifact on product parse path" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/zip/zip_assets_namespace.zip",
    Some(Zip),
  )
  let options = balanced_markdown_options(Zip)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Zip, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Zip,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed zip artifact reuse")
  }
  assert_true(parsed.block_stream is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
}

///|
test "epub preflight probe reuses package artifact on product parse path" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/epub/epub_basic_package.epub",
    Some(Epub),
  )
  let options = balanced_markdown_options(Epub)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(Epub, plan)
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      Epub,
      context,
      @formats.builtin_registry(),
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed epub artifact reuse")
  }
  assert_true(parsed.block_stream is Some(_))
  assert_true(
    parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
  assert_true(
    parsed.diagnostics.metrics.get("process_cache_hit") == Some("false"),
  )
}

///|
test "structured text preflight probes expose signals and controlled failures" {
  let markdown = markdown_preflight_probe(
    text_markup_probe_source("# Title\n\n- one\n- two\n", Markdown),
    balanced_markdown_options(Markdown),
  )
  assert_true(markdown.probe_signals.length() >= 3)
  assert_true(markdown.probe_artifacts.length() == 1)

  let json = json_preflight_probe(
    text_markup_probe_source("{\"a\":[1,2]}", Json),
    balanced_markdown_options(Json),
  )
  assert_eq(json.probe_signals.length(), 3)
  assert_eq(json.probe_artifacts.length(), 1)
  let invalid_json = json_preflight_probe(
    text_markup_probe_source("{invalid", Json),
    balanced_markdown_options(Json),
  )
  assert_true(invalid_json.probe_failures.length() >= 1)

  let yaml = yaml_preflight_probe(
    text_markup_probe_source("root:\n  items:\n    - one\n", Yaml),
    balanced_markdown_options(Yaml),
  )
  assert_eq(yaml.probe_signals.length(), 2)
  assert_eq(yaml.probe_artifacts.length(), 1)
  let invalid_yaml = yaml_preflight_probe(
    text_markup_probe_source("root: [unterminated", Yaml),
    balanced_markdown_options(Yaml),
  )
  assert_true(
    invalid_yaml.probe_failures.length() >= 1 ||
    invalid_yaml.probe_signals.length() >= 1,
  )

  let toml = toml_preflight_probe(
    text_markup_probe_source(
      "title = \"Fixture\"\n[section]\nvalue = 1\n",
      Toml,
    ),
    balanced_markdown_options(Toml),
  )
  assert_eq(toml.probe_signals.length(), 2)
}

///|
test "notebook XML HTML and audio preflight probes cover normal and damaged inputs" {
  let ipynb_text = "{\"cells\":[{\"cell_type\":\"markdown\",\"metadata\":{},\"source\":[\"hello\"]}],\"metadata\":{},\"nbformat\":4,\"nbformat_minor\":5}"
  let ipynb = ipynb_preflight_probe(
    text_markup_probe_source(ipynb_text, Ipynb),
    balanced_markdown_options(Ipynb),
  )
  assert_eq(ipynb.probe_signals.length(), 4)
  assert_eq(ipynb.probe_artifacts.length(), 1)
  let invalid_ipynb = ipynb_preflight_probe(
    text_markup_probe_source("{invalid", Ipynb),
    balanced_markdown_options(Ipynb),
  )
  assert_true(invalid_ipynb.probe_failures.length() >= 1)

  let xml = xml_preflight_probe(
    text_markup_probe_source(
      "<?xml version=\"1.0\"?><root><item a=\"1\">text</item></root>",
      Xml,
    ),
    balanced_markdown_options(Xml),
  )
  assert_eq(xml.probe_signals.length(), 3)
  assert_eq(xml.probe_artifacts.length(), 1)
  let invalid_xml = xml_preflight_probe(
    text_markup_probe_source("<root><item></root>", Xml),
    balanced_markdown_options(Xml),
  )
  assert_true(invalid_xml.probe_failures.length() >= 1)

  let html = html_preflight_probe(
    text_markup_probe_source(
      "<!doctype html><main><section><p>text</p></section></main>",
      Html,
    ),
    balanced_markdown_options(Html),
  )
  assert_true(html.probe_signals.length() >= 4)
  assert_eq(html.probe_artifacts.length(), 1)

  let audio = audio_preflight_probe(
    @input.input_from_bytes_with_format(
      Bytes::from_array([]),
      "empty.wav",
      Some(Audio(Wav)),
    ),
    Audio(Wav),
  )
  assert_eq(audio.probe_failures.length(), 0)
  assert_true(audio.summary_parts.length() >= 1)
}

///|
test "route rejects known input payloads above the configured byte limit" {
  let limits = make_resource_limits(2000, 50, 100000, max_input_bytes=3L)
  let options = {
    ..default_convert_options(),
    limits,
    explicit_format: Some(Txt),
  }
  let source = @input.input_from_bytes(Bytes::from_array([1, 2, 3, 4]))
  match plan_input(source, options) {
    Err(ResourceLimitExceeded(kind="input_bytes", observed=4L, limit=3L)) => ()
    Err(other) => fail("unexpected error: " + other.to_string())
    Ok(_) => fail("oversized input should fail before detection")
  }
}

///|
test "route rejects path input by size before reading content" {
  let limits = make_resource_limits(2000, 50, 100000, max_input_bytes=1L)
  let options = {
    ..default_convert_options(),
    limits,
    explicit_format: Some(Txt),
  }
  match plan_input(@input.input_from_path("input/README.md"), options) {
    Err(ResourceLimitExceeded(kind~, observed~, limit~)) => {
      assert_eq(kind, "input_bytes")
      assert_true(observed > 1L)
      assert_eq(limit, 1L)
    }
    Err(other) => fail("unexpected error: " + other.to_string())
    Ok(_) => fail("oversized path should fail before detection")
  }
}

///|
test "asset payload limits clear oversized payloads and remove markdown targets" {
  let first = {
    ..@core.make_asset_ref(Image, "large"),
    path: Some("assets/large.bin"),
  }
  first.payload = Some(Bytes(Bytes::new(5)))
  let diagnostics = @core.empty_diagnostics()
  let limits = make_resource_limits(
    2000,
    50,
    100000,
    max_asset_bytes=4L,
    max_total_asset_bytes=8L,
  )
  let limited = apply_asset_payload_limits([first], limits, diagnostics)
  assert_eq(limited.0.length(), 1)
  assert_eq(limited.1.length(), 1)
  assert_true(limited.0[0].payload is None)
  assert_true(
    diagnostics.degraded_features.contains("asset_payload_limit_skip"),
  )
  assert_eq(
    remove_skipped_asset_references(
      "before ![large](assets/large.bin) after",
      limited.1,
    ),
    "before large after",
  )
}
