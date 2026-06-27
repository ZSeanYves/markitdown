///|
pub fn convert_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertResult, ConvertError] {
  match convert_input_with_provenance(source, options) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}

///|
pub fn plan_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[RoutePlan, ConvertError] {
  let effective_source = match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    return Err(ConvertError::DetectFailed("unknown format"))
  }
  if detected.format == @input.DetectedFormat::Pdf &&
    options.ocr_options.intent == @parser.OcrIntent::Explicit {
    return Err(
      ConvertError::ParseFailed(
        "PDF OCR is not supported on the this runtime; native-text PDF restore is enabled, but scanned/image-only PDFs and PDF --ocr remain fail-closed.",
      ),
    )
  }
  if @input.detected_format_is_image_candidate(detected.format) {
    let requested_mode = match options.ocr_options.intent {
      @parser.OcrIntent::Explicit => Some(@parser.ParserMode::LayoutTwoStage)
      _ => None
    }
    return Ok({
      detected_format: detected.format,
      selected_route: "layout_two_stage",
      route_reason: if requested_mode is Some(_) {
        "image_explicit_ocr_layout_two_stage"
      } else {
        "image_auto_or_disabled_layout_two_stage"
      },
      route_probe_summary: "route_probe:image:ocr_intent=" +
      ocr_intent_name(options.ocr_options.intent),
      requested_parser_mode: requested_mode,
    })
  }
  let route_decision = plan_route(effective_source, detected.format, options)
  let requested_mode = requested_parser_mode_for_route(
    detected.format,
    options,
    route_decision,
  )
  Ok(route_plan_from_decision(detected.format, route_decision, requested_mode))
}

///|
pub fn convert_input_with_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_provenance_and_image_ocr_provider(
    source, options, @focr.run_tesseract_provider,
  )
}

///|
pub fn convert_input_with_provenance_and_image_ocr_provider(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_image_ocr_provider_and_provenance(
    source, options, image_ocr_provider,
  )
}

///|
pub fn convert_input_with_image_ocr_provider(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  match
    convert_input_with_provenance_and_image_ocr_provider(
      source, options, image_ocr_provider,
    ) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}

///|
fn convert_input_with_image_ocr_provider_and_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  let effective_source = match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    return Err(ConvertError::DetectFailed("unknown format"))
  }
  if detected.format == @input.DetectedFormat::Pdf &&
    options.ocr_options.intent == @parser.OcrIntent::Explicit {
    return Err(
      ConvertError::ParseFailed(
        "PDF OCR is not supported on the this runtime; native-text PDF restore is enabled, but scanned/image-only PDFs and PDF --ocr remain fail-closed.",
      ),
    )
  }
  if @input.detected_format_is_image_candidate(detected.format) {
    let requested_mode = match options.ocr_options.intent {
      @parser.OcrIntent::Explicit => Some(@parser.ParserMode::LayoutTwoStage)
      _ => None
    }
    let parsed = match
      @focr.image_ocr_parser_result_with_provider(
        effective_source,
        detected.format,
        options.ocr_options,
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(value) => value
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
    let route_plan : RoutePlan = {
      detected_format: detected.format,
      selected_route: "layout_two_stage",
      route_reason: if requested_mode is Some(_) {
        "image_explicit_ocr_layout_two_stage"
      } else {
        "image_auto_or_disabled_layout_two_stage"
      },
      route_probe_summary: "route_probe:image:ocr_intent=" +
      ocr_intent_name(options.ocr_options.intent),
      requested_parser_mode: requested_mode,
    }
    let execution = finalize_image_convert_execution(
      effective_source,
      detected.format,
      options,
      parsed,
      route_plan,
    )
    return Ok(execution)
  }
  let detect_trace = format_detection_trace(detected)
  let route_decision = plan_route(effective_source, detected.format, options)
  let prepared_source = route_decision.prepared_source
  let registry = @formats.builtin_registry()
  let requested_mode = requested_parser_mode_for_route(
    detected.format,
    options,
    route_decision,
  )
  let parse_context = @parser.parse_context_with_limits(
    parse_context_with_product_pdf_modes(
      @parser.parse_context_with_ocr_options(
        @parser.new_parse_context(detected.format),
        options.ocr_options,
      ),
      detected.format,
      options,
    ),
    requested_mode,
    Some(options.limits.max_rows),
    Some(options.limits.max_cols),
    Some(options.limits.max_cells),
    Some(options.limits.max_line_chars),
    options.mode == ConvertMode::Debug,
  )
  let parsed = match
    parse_with_route_probe_artifact(
      prepared_source,
      detected.format,
      parse_context,
      route_decision.probe_artifact,
    ) {
    Some(Ok(result)) => result
    Some(Err(err)) => return Err(ConvertError::ParseFailed(err))
    None =>
      match @parser.registry_parse(registry, prepared_source, parse_context) {
        Ok(result) => result
        Err(err) => return Err(ConvertError::ParseFailed(err))
      }
  }
  let diagnostics = inject_preparse_diagnostics(
    parsed.diagnostics,
    detect_trace,
    route_decision,
    detected,
  )
  let route_plan = route_plan_from_decision(
    detected.format,
    route_decision,
    requested_mode,
  )
  Ok(
    finalize_pipeline_convert_execution(
      effective_source,
      detected.format,
      options,
      parsed,
      diagnostics,
      route_plan,
    ),
  )
}

///|
pub async fn convert_input_with_image_ocr_provider_async(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  let effective_source = match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    return Err(ConvertError::DetectFailed("unknown format"))
  }
  if detected.format == @input.DetectedFormat::Pdf &&
    options.ocr_options.intent == @parser.OcrIntent::Explicit {
    return Err(
      ConvertError::ParseFailed(
        "PDF OCR is not supported on the this runtime; native-text PDF restore is enabled, but scanned/image-only PDFs and PDF --ocr remain fail-closed.",
      ),
    )
  }
  if @input.detected_format_is_image_candidate(detected.format) {
    let requested_mode = match options.ocr_options.intent {
      @parser.OcrIntent::Explicit => Some(@parser.ParserMode::LayoutTwoStage)
      _ => None
    }
    let parsed = match
      @focr.image_ocr_parser_result_with_async_provider(
        effective_source,
        detected.format,
        options.ocr_options,
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(value) => value
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
    return Ok(
      finalize_image_convert_result(
        effective_source,
        detected.format,
        options,
        parsed,
      ),
    )
  }
  convert_input(effective_source, { ..options, explicit_format: None })
}

///|
fn route_plan_from_decision(
  detected_format : @input.DetectedFormat,
  route_decision : RouteDecision,
  requested_mode : @parser.ParserMode?,
) -> RoutePlan {
  {
    detected_format,
    selected_route: canonical_route_name(route_decision.selected_route),
    route_reason: route_decision.reason,
    route_probe_summary: format_route_probe_summary(
      route_decision.probe_summary_format,
      route_decision.probe_summary_parts,
    ),
    requested_parser_mode: requested_mode,
  }
}

///|
fn parse_result_kind(result : @parser.ParseResult) -> String {
  if result.document is Some(_) {
    "document"
  } else if result.block_stream is Some(_) {
    "block_stream"
  } else if result.event_stream is Some(_) {
    "event_stream"
  } else {
    "empty"
  }
}

///|
fn ir_input_kind_name(input : @core.IRInput) -> String {
  match input {
    @core.IRInput::Document(_) => "document"
    @core.IRInput::BlockStream(_) => "block_stream"
    @core.IRInput::EventStream(_) => "event_stream"
  }
}

///|
fn render_input_kind_name(input : @render.RenderInput) -> String {
  match input {
    @render.RenderInput::Document(_) => "document"
    @render.RenderInput::BlockStream(_) => "block_stream"
    @render.RenderInput::EventStream(_) => "event_stream"
  }
}

///|
fn route_fidelity_status(
  route_plan : RoutePlan,
  effective_parser_mode : @parser.ParserMode,
  parse_result_kind : String,
  pipeline_output_kind : String,
  render_input_kind : String,
) -> String {
  let expected_mode = route_plan.requested_parser_mode
  let mode_ok = match expected_mode {
    Some(mode) => mode == effective_parser_mode
    None => true
  }
  let output_ok = pipeline_output_kind == render_input_kind
  let parse_ok = parse_result_kind != "empty"
  if mode_ok && output_ok && parse_ok {
    "matched"
  } else if !parse_ok {
    "missing_parse_result_kind"
  } else if !mode_ok {
    "parser_mode_mismatch"
  } else {
    "ir_shape_mismatch"
  }
}

///|
fn ocr_intent_name(intent : @parser.OcrIntent) -> String {
  match intent {
    @parser.OcrIntent::Disabled => "disabled"
    @parser.OcrIntent::Auto => "auto"
    @parser.OcrIntent::Explicit => "explicit"
  }
}

///|
pub fn route_plan_to_json(route_plan : RoutePlan) -> Json {
  Json::object({
    "detected_format": @input.detected_format_name(route_plan.detected_format).to_json(),
    "selected_route": route_plan.selected_route.to_json(),
    "route_reason": route_plan.route_reason.to_json(),
    "route_probe_summary": route_plan.route_probe_summary.to_json(),
    "requested_parser_mode": route_plan.requested_parser_mode
    .map(mode => @parser.mode_name(mode))
    .to_json(),
  })
}

///|
pub fn convert_provenance_to_json(provenance : ConvertProvenance) -> Json {
  Json::object({
    "route_plan": route_plan_to_json(provenance.route_plan),
    "effective_parser_mode": @parser.mode_name(provenance.effective_parser_mode).to_json(),
    "parse_result_kind": provenance.parse_result_kind.to_json(),
    "pipeline_output_kind": provenance.pipeline_output_kind.to_json(),
    "render_input_kind": provenance.render_input_kind.to_json(),
    "route_fidelity_status": provenance.route_fidelity_status.to_json(),
  })
}

///|
fn inject_preparse_diagnostics(
  diagnostics : @core.Diagnostics,
  detect_trace : String,
  route_decision : RouteDecision,
  detected : @input.FormatDetectionResult,
) -> @core.Diagnostics {
  let next = diagnostics
  let existing_trace : Array[String] = []
  existing_trace.append(diagnostics.pass_trace[:])
  next.pass_trace.clear()
  next.pass_trace.push("detect:" + detect_trace)
  next.pass_trace.push("registry:lookup")
  next.pass_trace.append(existing_trace[:])
  next.metrics.set(
    "selected_route",
    canonical_route_name(route_decision.selected_route),
  )
  next.metrics.set("route_reason", route_decision.reason)
  next.metrics.set(
    "route_probe_summary",
    format_route_probe_summary(
      route_decision.probe_summary_format,
      route_decision.probe_summary_parts,
    ),
  )
  if detected.notes.length() > 0 {
    next.metrics.set(
      "format_detector_notes",
      format_detector_notes(detected.notes),
    )
  }
  for degradation in route_decision.same_mode_degradation {
    if !next.same_mode_degradation.contains(degradation) {
      next.same_mode_degradation.push(degradation)
    }
  }
  next
}

///|
fn format_route_probe_summary(
  format_name : String,
  parts : Array[String],
) -> String {
  if parts.length() == 0 {
    return "route_probe:" + format_name
  }
  "route_probe:" + format_name + ":" + parts.join(":")
}

///|
fn format_detector_notes(notes : Array[String]) -> String {
  notes.join("|")
}

///|
fn parse_with_route_probe_artifact(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
  artifact : RouteProbeArtifact?,
) -> Result[@parser.ParseResult, String]? {
  match artifact {
    Some(RouteProbeArtifact::MarkdownScan(scanned, inspect)) =>
      if format == @input.DetectedFormat::Markdown {
        Some(
          Ok(
            @fmarkdown.markdown_parse_with_scanned_document(
              source, context, scanned, inspect,
            ),
          ),
        )
      } else {
        None
      }
    Some(RouteProbeArtifact::HtmlEvents(events)) =>
      if format == @input.DetectedFormat::Html &&
        context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
        let text = match source.text {
          Some(value) => value
          None => return None
        }
        Some(
          Ok(@fhtml.html_parse_with_token_events(source, context, text, events)),
        )
      } else {
        None
      }
    Some(RouteProbeArtifact::JsonStream(stream)) =>
      if format == @input.DetectedFormat::Json &&
        context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
        let text = match source.text {
          Some(value) => value
          None => return None
        }
        Some(
          Ok(
            @fjson.json_parse_with_stream_document(
              source, context, text, stream,
            ),
          ),
        )
      } else {
        None
      }
    Some(RouteProbeArtifact::XmlTokens(tokens)) =>
      if format == @input.DetectedFormat::Xml &&
        context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
        let text = match @fxml.read_xml_input_text(source) {
          Ok(value) => value
          Err(err) => return Some(Err(err))
        }
        Some(
          Ok(
            @fxml.xml_parse_with_structure_tokens(source, context, text, tokens),
          ),
        )
      } else {
        None
      }
    Some(RouteProbeArtifact::XlsxPackage(pkg)) =>
      if format == @input.DetectedFormat::Xlsx {
        Some(Ok(@dxlsx.xlsx_parse_with_package(source, context, pkg)))
      } else {
        None
      }
    Some(RouteProbeArtifact::YamlEvents(events, inspect)) =>
      if format == @input.DetectedFormat::Yaml &&
        context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
        let text = match source.text {
          Some(value) => value
          None => return None
        }
        Some(
          Ok(
            @fyaml.yaml_parse_with_structure_events(
              source, context, text, inspect, events,
            ),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}
