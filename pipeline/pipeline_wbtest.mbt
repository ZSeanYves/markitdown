///|
test "pipeline context covers stream debug and accurate modes" {
  let stream = make_pass_context(true, "stream", pdf_cleanup_enabled=true)
  assert_true(stream.mode == @product.ConvertMode::Stream)
  assert_true(stream.output_mode == @product.OutputMode::Debug)
  assert_true(
    stream.diagnostics.val.metrics.get("pdf_header_footer_filter_enabled") ==
    Some("true"),
  )
  let accurate = make_pass_context(false, "accurate")
  assert_true(accurate.mode == @product.ConvertMode::Accurate)
}

///|
test "pipeline rejects unnamed and failing passes with original errors" {
  let context = make_pass_context(false, "balanced")
  let unnamed : IRPass = { name: " ", run: fn(_, input) { Ok(input) } }
  let unnamed_result = run_pipeline(
    { passes: [unnamed] },
    @core.IRInput::BlockStream([]),
    context,
  )
  let unnamed_error = match unnamed_result {
    Err(err) => err.message == "pipeline pass must have a stable name"
    Ok(_) => false
  }
  assert_true(unnamed_error)
  let failing : IRPass = {
    name: "FailingPass",
    run: fn(_, _) { Err(pass_error("failure")) },
  }
  let failed = run_pipeline(
    { passes: [failing] },
    @core.IRInput::BlockStream([]),
    context,
  )
  let failure_preserved = match failed {
    Err(err) => err.message == "failure"
    Ok(_) => false
  }
  assert_true(failure_preserved)
}

///|
test "large lowered HTML uses the bounded block-stream pipeline profile" {
  let options = @product.default_product_options()
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("detected_format", "html")
  let context = make_pass_context_with_product_options(
    @product.ConvertMode::Balanced,
    options,
    execution_profile=@product.ExecutionProfile::LargeAdaptive,
    lowering_profile=@product.LoweringProfile::LargeAdaptive,
    render_profile=@product.RenderProfile::SectionFlushMarkdown,
    diagnostics~,
  )
  let result = run_default_pipeline(@core.IRInput::BlockStream([]), context).unwrap()
  assert_true(result is @core.IRInput::BlockStream(_))
  assert_true(
    context.diagnostics.val.metrics.get("pipeline_profile") ==
    Some("html_large_lowered"),
  )
  assert_eq(context.diagnostics.val.pass_trace.length(), 1)
  assert_eq(context.diagnostics.val.pass_trace[0], "CollectAssetRefsPass")
}

///|
test "large lowered structured text keeps only the asset collection pass" {
  for format in ["toml", "tex", "rst", "asciidoc"] {
    let diagnostics = @core.empty_diagnostics()
    diagnostics.metrics.set("detected_format", format)
    let context = make_pass_context_with_product_options(
      @product.ConvertMode::Balanced,
      @product.default_product_options(),
      execution_profile=@product.ExecutionProfile::LargeAdaptive,
      lowering_profile=@product.LoweringProfile::LargeAdaptive,
      diagnostics~,
    )
    let input = @core.IRInput::Document(
      @core.document_with_diagnostics(@core.empty_document_ir(), diagnostics),
    )
    let result = run_default_pipeline(input, context).unwrap()
    assert_true(result is @core.IRInput::Document(_))
    assert_true(
      context.diagnostics.val.metrics.get("pipeline_profile") ==
      Some(format + "_large_lowered"),
    )
    if format == "tex" {
      assert_eq(context.diagnostics.val.pass_trace.length(), 3)
      assert_eq(context.diagnostics.val.pass_trace[0], "NormalizeTextPass")
      assert_eq(
        context.diagnostics.val.pass_trace[1],
        "NormalizeWhitespacePass",
      )
      assert_eq(context.diagnostics.val.pass_trace[2], "CollectAssetRefsPass")
    } else {
      assert_eq(context.diagnostics.val.pass_trace.length(), 1)
      assert_eq(context.diagnostics.val.pass_trace[0], "CollectAssetRefsPass")
    }
  }
}

///|
test "large lowered YAML document skips redundant canonical passes" {
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set("char_count", "1048576")
  let context = make_pass_context_with_product_options(
    @product.ConvertMode::Balanced,
    @product.default_product_options(),
    diagnostics~,
  )
  let input = @core.IRInput::Document(
    @core.document_with_diagnostics(@core.empty_document_ir(), diagnostics),
  )
  ignore(run_default_pipeline(input, context).unwrap())
  assert_true(
    context.diagnostics.val.metrics.get("pipeline_profile") ==
    Some("yaml_large_lowered"),
  )
  assert_eq(context.diagnostics.val.pass_trace.length(), 1)
  assert_eq(context.diagnostics.val.pass_trace[0], "CollectAssetRefsPass")
}
