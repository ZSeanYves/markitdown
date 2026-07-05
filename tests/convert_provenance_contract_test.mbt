///|
fn convert_with_provenance(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  limits : @convert.ResourceLimits,
  stream_requested? : Bool = false,
  fidelity_mode? : @convert.FidelityMode = @convert.FidelityMode::Balanced,
) -> @convert.ConvertExecution raise {
  let options = @convert.make_convert_options(
    @convert.derived_convert_mode(fidelity_mode, stream_requested),
    @convert.OutputFormat::Markdown,
    Some(format),
    @parser.default_ocr_options(),
    limits,
    fidelity_mode~,
    stream_requested~,
  )
  match @convert.convert_input_with_provenance(source, options) {
    Ok(value) => value
    Err(err) => fail("expected convert provenance: " + err.to_string())
  }
}

///|
fn convert_with_provenance_and_image_ocr_provider(
  source : @input.InputSource,
  options : @convert.ConvertOptions,
  provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> @convert.ConvertExecution raise {
  match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      source, options, provider,
    ) {
    Ok(value) => value
    Err(err) =>
      fail(
        "expected convert provenance with injected OCR provider: " +
        err.to_string(),
      )
  }
}

///|
test "convert provenance reports markdown huge block route" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
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
      "samples/fixtures/contracts/json/large_array_streaming.json",
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
      "samples/fixtures/contracts/zip/zip_assets_namespace.zip",
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
    @input.input_from_path("samples/fixtures/contracts/xlsx/sheet_simple.xlsx"),
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
    @product.execution_profile_name(execution.provenance.execution_profile),
    "large_adaptive",
  )
  assert_eq(
    execution.provenance.execution_profile_reason,
    "hard_limit_threshold",
  )
  assert_true(execution.provenance.profile_trigger_signals.length() > 0)
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
    @input.input_from_path("samples/fixtures/contracts/xml/xml_nested.xml"),
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
      "samples/fixtures/contracts/html/html_semantic_sectioning.html",
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
      "samples/fixtures/contracts/html/html_semantic_sectioning.html",
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
  assert_eq(execution.provenance.applied_accurate_features.length(), 0)
}

///|
test "convert provenance reports audio canonical media pipeline and honest fallbacks" {
  with_mock_audio_runtime(fn() raise {
    let balanced = convert_with_provenance(
      @input.input_from_path("samples/fixtures/contracts/audio/contract.wav"),
      @input.DetectedFormat::Audio(@input.AudioFormat::Wav),
      @convert.default_resource_limits(),
    )
    assert_eq(balanced.provenance.route_plan.selected_route, "media_pipeline")
    assert_eq(
      balanced.provenance.route_plan.route_reason,
      "wav_canonical_media_pipeline",
    )
    assert_eq(
      @parser.mode_name(balanced.provenance.effective_parser_mode),
      "media_pipeline",
    )
    assert_true(
      balanced.provenance.audio_backend_transport == Some("native_cli"),
    )
    assert_true(balanced.provenance.audio_backend_name == Some("whisper_cpp"))

    let stream = convert_with_provenance(
      @input.input_from_path("samples/fixtures/contracts/audio/contract.mp3"),
      @input.DetectedFormat::Audio(@input.AudioFormat::Mp3),
      @convert.default_resource_limits(),
      stream_requested=true,
    )
    assert_eq(stream.provenance.route_plan.selected_route, "media_pipeline")
    assert_eq(
      stream.provenance.route_plan.route_reason,
      "explicit_stream_unsupported_fell_back",
    )

    let accurate_options = @convert.make_convert_options(
      @convert.ConvertMode::Accurate,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Audio(@input.AudioFormat::M4a)),
      @parser.default_ocr_options(),
      @convert.default_resource_limits(),
      audio_options=@parser.explicit_audio_options(language=Some("eng")),
    )
    let accurate = match
      @convert.convert_input_with_provenance(
        @input.input_from_path("samples/fixtures/contracts/audio/contract.m4a"),
        accurate_options,
      ) {
      Ok(value) => value
      Err(err) => fail("expected accurate audio provenance: " + err.to_string())
    }
    assert_eq(accurate.provenance.route_plan.selected_route, "media_pipeline")
    assert_eq(
      accurate.provenance.route_plan.route_reason,
      "accurate_unsupported_fell_back",
    )
    assert_eq(
      @convert.fidelity_mode_name(accurate.provenance.fidelity_mode),
      "balanced",
    )
    assert_true(
      accurate.provenance.same_mode_strategy_switches.contains(
        "accurate_unsupported_fell_back",
      ),
    )
  })
}

///|
test "convert provenance reports medium adaptive profile without route switch" {
  let execution = convert_with_provenance(
    @input.input_from_path("samples/fixtures/contracts/ods/MergedCells.ods"),
    @input.DetectedFormat::Ods,
    @convert.make_resource_limits(10, 10, 1000),
  )
  assert_eq(
    execution.provenance.route_plan.selected_route,
    "package_single_pass",
  )
  assert_eq(
    @product.execution_profile_name(execution.provenance.execution_profile),
    "medium_adaptive",
  )
  assert_eq(
    execution.provenance.execution_profile_reason,
    "soft_limit_threshold",
  )
  assert_true(execution.provenance.profile_trigger_signals.length() > 0)
}

///|
test "convert provenance reports epub explicit stream container route fidelity" {
  let execution = convert_with_provenance(
    @input.input_from_path(
      "samples/fixtures/contracts/epub/epub_basic_package.epub",
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
    @input.input_from_path("samples/fixtures/contracts/xlsx/sheet_simple.xlsx"),
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
      "samples/fixtures/contracts/odt/odt_basic_sample.odt",
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
      "samples/fixtures/contracts/ods/ods_basic_sample.ods",
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
      "samples/fixtures/contracts/odp/odp_basic_sample.odp",
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
      "samples/fixtures/contracts/toml/toml_object_basic.toml",
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

///|
test "route planner keeps explicit stream fallback honest for toml" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/toml/toml_object_basic.toml",
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Toml),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    stream_requested=true,
  )
  let plan = match @convert.plan_input(source, options) {
    Ok(value) => value
    Err(err) => fail("expected toml route plan: " + err.to_string())
  }
  assert_eq(plan.selected_route, "dom_ast_model")
  assert_eq(plan.route_reason, "explicit_stream_unsupported_fell_back")
  assert_true(
    plan.requested_parser_mode.map(mode => @parser.mode_name(mode)) ==
    Some("dom_ast_model"),
  )
}

///|
test "route planner keeps unsupported accurate fallback honest for toml" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/toml/toml_object_basic.toml",
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Accurate,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Toml),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    fidelity_mode=@convert.FidelityMode::Accurate,
  )
  let plan = match @convert.plan_input(source, options) {
    Ok(value) => value
    Err(err) => fail("expected toml accurate route plan: " + err.to_string())
  }
  assert_eq(plan.selected_route, "dom_ast_model")
  assert_eq(plan.route_reason, "accurate_unsupported_fell_back")
  let execution = convert_with_provenance(
    source,
    @input.DetectedFormat::Toml,
    @convert.default_resource_limits(),
    fidelity_mode=@convert.FidelityMode::Accurate,
  )
  assert_eq(
    @convert.fidelity_mode_name(execution.provenance.fidelity_mode),
    "balanced",
  )
  assert_true(
    execution.provenance.requested_fidelity_mode ==
    Some(@convert.FidelityMode::Accurate),
  )
  assert_true(
    execution.provenance.same_mode_strategy_switches.contains(
      "accurate_unsupported_fell_back",
    ),
  )
  assert_true(execution.result.content.contains("| Key | Value |"))
}

///|
test "route planner preserves image accurate OCR target instead of downgrading early" {
  let source = @input.input_from_path_with_format(
    "scan.png",
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
    @parser.explicit_ocr_options(language=Some("eng")),
    @convert.default_resource_limits(),
    fidelity_mode=@convert.FidelityMode::Accurate,
  )
  let plan = match @convert.plan_input(source, options) {
    Ok(value) => value
    Err(err) => fail("expected image accurate route plan: " + err.to_string())
  }
  assert_eq(plan.route_reason, "png_canonical_layout_two_stage")
  assert_true(
    plan.ocr_provider_selection_target == Some("direct_image_accurate"),
  )
  assert_true(plan.ocr_provider_requested_kind == Some("paddle_ocr"))
  assert_true(plan.ocr_provider_resolved_kind == Some("paddle_ocr"))
}

///|
test "route planner keeps unsupported accurate fallback honest for audio" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/audio/contract.m4a",
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Accurate,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Audio(@input.AudioFormat::M4a)),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    fidelity_mode=@convert.FidelityMode::Accurate,
    audio_options=@parser.explicit_audio_options(language=Some("eng")),
  )
  let plan = match @convert.plan_input(source, options) {
    Ok(value) => value
    Err(err) => fail("expected audio accurate route plan: " + err.to_string())
  }
  assert_eq(plan.route_reason, "accurate_unsupported_fell_back")
}

///|
test "route planner keeps pdf accurate and explicit ocr routes stable" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
  )
  let accurate_options = @convert.make_convert_options(
    @convert.ConvertMode::Accurate,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Pdf),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  let accurate_plan = match @convert.plan_input(source, accurate_options) {
    Ok(value) => value
    Err(err) => fail("expected pdf accurate route plan: " + err.to_string())
  }
  assert_eq(accurate_plan.selected_route, "page_single_pass")
  assert_eq(accurate_plan.route_reason, "pdf_canonical_page_single_pass")
  assert_true(
    accurate_plan.requested_parser_mode.map(mode => @parser.mode_name(mode)) ==
    Some("page_single_pass"),
  )
  assert_true(accurate_plan.ocr_provider_selection_target == None)
  assert_true(accurate_plan.ocr_provider_requested_kind == None)
  assert_true(accurate_plan.ocr_provider_resolved_kind == None)

  let explicit_ocr_options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Pdf),
    @parser.explicit_ocr_options(),
    @convert.default_resource_limits(),
    pdf_ocr_policy=@convert.PdfOcrPolicy::Explicit,
  )
  let explicit_ocr_plan = match
    @convert.plan_input(source, explicit_ocr_options) {
    Ok(value) => value
    Err(err) => fail("expected pdf explicit ocr route plan: " + err.to_string())
  }
  assert_eq(explicit_ocr_plan.selected_route, "layout_two_stage")
  assert_eq(explicit_ocr_plan.route_reason, "pdf_explicit_ocr_layout_two_stage")
  assert_true(
    explicit_ocr_plan.requested_parser_mode.map(mode => @parser.mode_name(mode)) ==
    Some("layout_two_stage"),
  )
  assert_true(
    explicit_ocr_plan.ocr_provider_selection_target == Some("pdf_balanced"),
  )
  assert_true(
    explicit_ocr_plan.ocr_provider_requested_kind == Some("tesseract"),
  )
  assert_true(explicit_ocr_plan.ocr_provider_resolved_kind == Some("tesseract"))
}

///|
test "convert provenance falls back from pdf accurate OCR dependency failure to balanced OCR provider" {
  let source = @input.input_from_path(
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf",
  )
  let options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Pdf),
    @parser.explicit_ocr_options(language=Some("eng")),
    @convert.default_resource_limits(),
    fidelity_mode=@convert.FidelityMode::Accurate,
    pdf_ocr_policy=@convert.PdfOcrPolicy::Explicit,
  )
  let provider = fn(request : @focr.OcrProviderRequest) {
    if request.provider_kind == @focr.OcrProviderKind::PaddleOcr {
      Err(
        @focr.OcrProviderError::NotConfigured(
          @focr.paddle_ocr_not_configured_message(),
        ),
      )
    } else {
      let tsv = [
        "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
        "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tPDF", "5\t1\t1\t1\t1\t2\t35\t10\t20\t10\t94\tOCR",
      ].join("\n")
      match @focr.parse_tesseract_tsv(tsv, language=request.language) {
        Ok(value) => Ok(value)
        Err(err) =>
          abort(
            "expected injected fallback OCR TSV parse success: " +
            err.to_string(),
          )
      }
    }
  }
  let execution = convert_with_provenance_and_image_ocr_provider(
    source, options, provider,
  )
  assert_true(
    execution.provenance.ocr_provider_selection_target == Some("pdf_accurate"),
  )
  assert_true(
    execution.provenance.ocr_provider_requested_kind == Some("paddle_ocr"),
  )
  assert_true(
    execution.provenance.ocr_provider_resolved_kind == Some("paddle_ocr"),
  )
  assert_true(execution.result.content.contains("PDF OCR"))
  assert_true(
    execution.result.diagnostics.warnings.any(fn(item) {
      item.contains("pdf_ocr_provider_fallback:index=1") &&
      item.contains("from=paddle_ocr") &&
      item.contains("to=tesseract")
    }),
  )
}

///|
test "route planner resolves lowering profile by runtime precedence" {
  let markdown_source = @input.input_from_path(
    "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
  )
  let markdown_options = @convert.make_convert_options(
    @convert.ConvertMode::Balanced,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Markdown),
    @parser.default_ocr_options(),
    @convert.make_resource_limits(1, 1, 10000),
  )
  let markdown_execution = match
    @convert.convert_input_with_provenance(markdown_source, markdown_options) {
    Ok(value) => value
    Err(err) => fail("expected markdown execution: " + err.to_string())
  }
  assert_eq(
    @product.lowering_profile_name(
      markdown_execution.provenance.lowering_profile,
    ),
    "large_adaptive",
  )

  let html_source = @input.input_from_path(
    "samples/fixtures/contracts/html/html_semantic_sectioning.html",
  )
  let html_options = @convert.make_convert_options(
    @convert.ConvertMode::Stream,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Html),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  let html_execution = match
    @convert.convert_input_with_provenance(html_source, html_options) {
    Ok(value) => value
    Err(err) => fail("expected html stream execution: " + err.to_string())
  }
  assert_eq(
    @product.lowering_profile_name(html_execution.provenance.lowering_profile),
    "stream_canonical",
  )

  let docx_source = @input.input_from_path(
    "samples/fixtures/contracts/docx/docx_textbox_basic.docx",
  )
  let docx_options = @convert.make_convert_options(
    @convert.ConvertMode::Accurate,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Docx),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
  )
  let docx_execution = match
    @convert.convert_input_with_provenance(docx_source, docx_options) {
    Ok(value) => value
    Err(err) => fail("expected docx accurate execution: " + err.to_string())
  }
  assert_eq(
    @product.lowering_profile_name(docx_execution.provenance.lowering_profile),
    "accurate_semantic",
  )
}

///|
test "convert provenance carries accurate image OCR provider selection explicitly" {
  let tsv = [
    "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
    "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t10\t15\t10\t94\tOCR",
  ].join("\n")
  let provider = fn(request : @focr.OcrProviderRequest) {
    if request.provider_kind != @focr.OcrProviderKind::PaddleOcr {
      abort("expected convert accurate image OCR to request PaddleOCR")
    }
    match @focr.parse_tesseract_tsv(tsv, language=request.language) {
      Ok(result) => Ok(result)
      Err(err) =>
        abort("expected injected OCR TSV parse success: " + err.to_string())
    }
  }
  let execution = convert_with_provenance_and_image_ocr_provider(
    @input.input_from_path_with_format(
      "scan.png",
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
    ),
    @convert.make_convert_options(
      @convert.ConvertMode::Balanced,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
      @parser.explicit_ocr_options(language=Some("eng")),
      @convert.default_resource_limits(),
      fidelity_mode=@convert.FidelityMode::Accurate,
    ),
    provider,
  )
  assert_true(
    execution.provenance.ocr_provider_selection_target ==
    Some("direct_image_accurate"),
  )
  assert_true(
    execution.provenance.ocr_provider_requested_kind == Some("paddle_ocr"),
  )
  assert_true(
    execution.provenance.ocr_provider_resolved_kind == Some("paddle_ocr"),
  )
  let json = @convert.convert_provenance_to_json(execution.provenance).stringify(
    indent=2,
  )
  assert_true(json.contains("\"ocr_provider_selection_target\""))
  assert_true(json.contains("direct_image_accurate"))
  assert_true(json.contains("\"ocr_provider_requested_kind\""))
  assert_true(json.contains("paddle_ocr"))
  assert_true(json.contains("\"ocr_provider_resolved_kind\""))
  assert_true(json.contains("paddle_ocr"))
  assert_true(!json.contains("\"ocr_provider_fallback\""))
  assert_true(!json.contains("\"dependency_diagnostics\""))
  assert_true(json.contains("\"requested_fidelity_mode\""))
}

///|
test "convert provenance falls back from accurate image OCR dependency failure to balanced OCR provider" {
  let provider = fn(request : @focr.OcrProviderRequest) {
    if request.provider_kind == @focr.OcrProviderKind::PaddleOcr {
      Err(
        @focr.OcrProviderError::NotConfigured(
          @focr.paddle_ocr_not_configured_message(),
        ),
      )
    } else {
      let tsv = [
        "level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext",
        "5\t1\t1\t1\t1\t1\t10\t10\t20\t10\t95\tMoonBit", "5\t1\t1\t1\t1\t2\t35\t10\t15\t10\t94\tOCR",
      ].join("\n")
      match @focr.parse_tesseract_tsv(tsv, language=request.language) {
        Ok(result) => Ok(result)
        Err(err) =>
          abort(
            "expected injected image fallback OCR TSV parse success: " +
            err.to_string(),
          )
      }
    }
  }
  let execution = convert_with_provenance_and_image_ocr_provider(
    @input.input_from_path_with_format(
      "scan.png",
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
    ),
    @convert.make_convert_options(
      @convert.ConvertMode::Balanced,
      @convert.OutputFormat::Markdown,
      Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
      @parser.explicit_ocr_options(language=Some("eng")),
      @convert.default_resource_limits(),
      fidelity_mode=@convert.FidelityMode::Accurate,
    ),
    provider,
  )
  assert_true(execution.result.content.contains("MoonBit OCR"))
  assert_true(
    execution.provenance.ocr_provider_selection_target ==
    Some("direct_image_accurate"),
  )
  assert_true(
    execution.provenance.ocr_provider_requested_kind == Some("paddle_ocr"),
  )
  assert_true(
    execution.provenance.ocr_provider_resolved_kind == Some("paddle_ocr"),
  )
  assert_true(
    execution.result.diagnostics.warnings.any(fn(item) {
      item.contains("image_ocr_provider_fallback") &&
      item.contains("from=paddle_ocr") &&
      item.contains("to=tesseract")
    }),
  )
}
