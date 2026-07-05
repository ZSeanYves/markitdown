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
    ConvertMode::Balanced,
    OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    default_resource_limits(),
  )
}

///|
test "text markup preflight probe reuses preparsed tex document artifact" {
  let source = text_markup_probe_source(
    "\\section{Intro}\n\nHello world.\n",
    @input.DetectedFormat::Tex,
  )
  let options = balanced_markdown_options(@input.DetectedFormat::Tex)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(
    @input.DetectedFormat::Tex,
    plan,
  )
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      @input.DetectedFormat::Tex,
      context,
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed tex artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[0].text.contains("Intro"))
}

///|
test "text markup preflight probe reuses preparsed rst document artifact" {
  let source = text_markup_probe_source(
    "Title\n=====\n\nBody paragraph.\n",
    @input.DetectedFormat::Rst,
  )
  let options = balanced_markdown_options(@input.DetectedFormat::Rst)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(
    @input.DetectedFormat::Rst,
    plan,
  )
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      @input.DetectedFormat::Rst,
      context,
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed rst artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[1].text.contains("Body paragraph"))
}

///|
test "text markup preflight probe reuses preparsed asciidoc document artifact" {
  let source = text_markup_probe_source(
    "= Title\n\nA short paragraph.\n",
    @input.DetectedFormat::Asciidoc,
  )
  let options = balanced_markdown_options(@input.DetectedFormat::Asciidoc)
  let plan = match detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value.2
    Err(err) => fail(err.to_string())
  }
  assert_eq(plan.probe_artifacts.length(), 1)
  let context = parse_context_from_execution_plan(
    @input.DetectedFormat::Asciidoc,
    plan,
  )
  let parsed = match
    parse_with_route_probe_artifact(
      plan.prepared_source,
      @input.DetectedFormat::Asciidoc,
      context,
      plan.probe_artifacts,
    ) {
    Some(Ok(value)) => value
    Some(Err(err)) => fail(err)
    None => fail("expected preparsed asciidoc artifact reuse")
  }
  let document = parsed.document.unwrap_or(@core.empty_document_ir())
  assert_true(document.blocks.length() >= 2)
  assert_true(document.blocks[0].kind == @core.BlockKind::Heading)
  assert_true(document.blocks[0].text.contains("Title"))
}
