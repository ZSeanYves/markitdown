///|
fn contract_balanced_markdown_options(
  format : @input.DetectedFormat,
) -> ConvertOptions {
  make_convert_options(
    ConvertMode::Balanced,
    OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
}

///|
test "heavy route probes produce reusable typed artifacts before parse" {
  let html_source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/html/html_simple.html",
    Some(@input.DetectedFormat::Html),
  )
  let html_plan = match
    detect_and_resolve_execution_plan(
      html_source,
      contract_balanced_markdown_options(@input.DetectedFormat::Html),
    ) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(html_plan.probe_artifacts.length(), 1)
  let html_context = parse_context_from_execution_plan(
    @input.DetectedFormat::Html,
    html_plan,
  )
  let html_parsed = match
    parse_with_route_probe_artifact(
      html_plan.prepared_source,
      @input.DetectedFormat::Html,
      html_context,
      @formats.builtin_registry(),
      html_plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected html route probe artifact")
  }
  assert_true(
    html_parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )

  let ipynb_source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/ipynb/ipynb_markdown_basic.ipynb",
    Some(@input.DetectedFormat::Ipynb),
  )
  let ipynb_plan = match
    detect_and_resolve_execution_plan(
      ipynb_source,
      contract_balanced_markdown_options(@input.DetectedFormat::Ipynb),
    ) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(ipynb_plan.probe_artifacts.length(), 1)
  let ipynb_context = parse_context_from_execution_plan(
    @input.DetectedFormat::Ipynb,
    ipynb_plan,
  )
  let ipynb_parsed = match
    parse_with_route_probe_artifact(
      ipynb_plan.prepared_source,
      @input.DetectedFormat::Ipynb,
      ipynb_context,
      @formats.builtin_registry(),
      ipynb_plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected ipynb route probe artifact")
  }
  assert_true(
    ipynb_parsed.diagnostics.metrics.get("probe_artifact_reused") ==
    Some("true"),
  )

  let docx_source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/docx/docx_paragraph_linebreak.docx",
    Some(@input.DetectedFormat::Docx),
  )
  let docx_plan = match
    detect_and_resolve_execution_plan(
      docx_source,
      contract_balanced_markdown_options(@input.DetectedFormat::Docx),
    ) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(docx_plan.probe_artifacts.length(), 1)
  let docx_context = parse_context_from_execution_plan(
    @input.DetectedFormat::Docx,
    docx_plan,
  )
  let docx_parsed = match
    parse_with_route_probe_artifact(
      docx_plan.prepared_source,
      @input.DetectedFormat::Docx,
      docx_context,
      @formats.builtin_registry(),
      docx_plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected docx route probe artifact")
  }
  assert_true(
    docx_parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )

  let pptx_source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pptx/pptx_link_basic.pptx",
    Some(@input.DetectedFormat::Pptx),
  )
  let pptx_plan = match
    detect_and_resolve_execution_plan(
      pptx_source,
      contract_balanced_markdown_options(@input.DetectedFormat::Pptx),
    ) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(pptx_plan.probe_artifacts.length(), 1)
  let pptx_context = parse_context_from_execution_plan(
    @input.DetectedFormat::Pptx,
    pptx_plan,
  )
  let pptx_parsed = match
    parse_with_route_probe_artifact(
      pptx_plan.prepared_source,
      @input.DetectedFormat::Pptx,
      pptx_context,
      @formats.builtin_registry(),
      pptx_plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected pptx route probe artifact")
  }
  assert_true(
    pptx_parsed.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
}

///|
test "heavy route probe formats fail closed when probe artifact is missing" {
  let heavy_formats = [
    @input.DetectedFormat::Html,
    @input.DetectedFormat::Ipynb,
    @input.DetectedFormat::Docx,
    @input.DetectedFormat::Pptx,
    @input.DetectedFormat::Xlsx,
    @input.DetectedFormat::Odt,
    @input.DetectedFormat::Ods,
    @input.DetectedFormat::Odp,
    @input.DetectedFormat::Epub,
    @input.DetectedFormat::Zip,
    @input.DetectedFormat::Pdf,
  ]
  for format in heavy_formats {
    assert_true(heavy_probe_artifact_required(format))
    let source = @input.input_from_text_with_format(
      "placeholder",
      "missing." + @input.detected_format_name(format),
      Some(format),
    )
    let context = @parser.new_parse_context(format)
    let result = parse_with_route_probe_artifact(
      source,
      format,
      context,
      @formats.builtin_registry(),
      [],
    )
    match result {
      None => ()
      Some(_) =>
        fail(
          "heavy probe format must not parse without artifact: " +
          @input.detected_format_name(format),
        )
    }
  }
}
