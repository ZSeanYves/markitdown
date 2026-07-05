///|
/// Convert one input through the canonical product path and return only the
/// end-user result payload.
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
/// Resolve routing without fully executing conversion.
pub fn plan_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[RoutePlan, ConvertError] {
  match detect_and_resolve_execution_plan(source, options) {
    Ok((_effective_source, _detected, execution_plan)) =>
      Ok(route_plan_from_execution_plan(execution_plan))
    Err(err) => Err(err)
  }
}

///|
/// Convert one input and return both the result payload and execution
/// provenance.
pub fn convert_input_with_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_provenance_and_image_ocr_provider(
    source, options, @focr.run_ocr_provider,
  )
}

///|
/// Convert one input with an injected image OCR provider while preserving full
/// provenance.
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
/// Convert one input with an injected image OCR provider and return only the
/// end-user result payload.
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
  let (effective_source, detected, execution_plan) = match
    detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let detect_trace = format_detection_trace(detected)
  let prepared_source = execution_plan.prepared_source
  let requested_mode = execution_plan.requested_parser_mode
  let parse_context = parse_context_from_execution_plan(
    detected.format,
    execution_plan,
  )
  let parsed = if @input.detected_format_is_image_candidate(detected.format) {
    match
      @focr.image_ocr_parser_result_with_provider_target(
        prepared_source,
        detected.format,
        execution_plan.ocr_options,
        @focr.image_ocr_selection_target_for_accuracy(
          execution_plan.fidelity_mode == FidelityMode::Accurate,
        ),
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(result) => result
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
  } else if detected.format == @input.DetectedFormat::Pdf &&
    requested_mode == Some(@parser.ParserMode::LayoutTwoStage) {
    match
      @fpdf.pdf_ocr_parser_result(
        prepared_source,
        parse_context,
        image_ocr_provider~,
      ) {
      Ok(result) => result
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
  } else {
    let registry = @formats.builtin_registry()
    match
      parse_with_route_probe_artifact(
        prepared_source,
        detected.format,
        parse_context,
        execution_plan.probe_artifacts,
      ) {
      Some(Ok(result)) => result
      Some(Err(err)) => return Err(ConvertError::ParseFailed(err))
      None =>
        match @parser.registry_parse(registry, prepared_source, parse_context) {
          Ok(result) => result
          Err(err) => return Err(ConvertError::ParseFailed(err))
        }
    }
  }
  let diagnostics = inject_preparse_diagnostics(
    parsed.diagnostics,
    detect_trace,
    execution_plan,
    detected,
  )
  Ok(
    finalize_pipeline_convert_execution(
      effective_source,
      detected.format,
      options,
      parsed,
      diagnostics,
      execution_plan,
    ),
  )
}

///|
/// Translate a resolved execution plan into the parser context consumed by the
/// selected parser route.
fn parse_context_from_execution_plan(
  detected_format : @input.DetectedFormat,
  execution_plan : ResolvedExecutionPlan,
) -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.parse_context_with_pdf_table_reconstruction_policy(
      @parser.parse_context_with_pdf_header_footer_filter_policy(
        @parser.parse_context_with_pdf_native_runtime_policy(
          @parser.parse_context_with_pdf_ocr_policy(
            @parser.parse_context_with_audio_options(
              @parser.parse_context_with_ocr_options(
                @parser.parse_context_with_execution_profiles(
                  @parser.parse_context_with_product_modes(
                    @parser.new_parse_context(detected_format),
                    execution_plan.fidelity_mode,
                    execution_plan.output_mode,
                  ),
                  execution_plan.execution_profile,
                  execution_plan.lowering_profile,
                  execution_plan.render_profile,
                  execution_plan.accurate_feature_profile,
                ),
                execution_plan.ocr_options,
              ),
              execution_plan.audio_options,
            ),
            execution_plan.pdf_ocr_policy,
          ),
          execution_plan.pdf_native_runtime_policy,
        ),
        execution_plan.pdf_header_footer_filter_policy,
      ),
      execution_plan.pdf_table_reconstruction_policy,
    ),
    execution_plan.requested_parser_mode,
    Some(execution_plan.limits.max_rows),
    Some(execution_plan.limits.max_cols),
    Some(execution_plan.limits.max_cells),
    Some(execution_plan.limits.max_line_chars),
    execution_plan.output_mode == OutputMode::Debug,
  )
}

///|
/// Async variant of `convert_input_with_image_ocr_provider`.
pub async fn convert_input_with_image_ocr_provider_async(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  match
    convert_input_with_provenance_and_image_ocr_provider_async(
      source, options, image_ocr_provider,
    ) {
    Ok(execution) => Ok(execution.result)
    Err(err) => Err(err)
  }
}

///|
/// Async variant of provenance-preserving conversion with an injected image OCR
/// provider.
pub async fn convert_input_with_provenance_and_image_ocr_provider_async(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  let (effective_source, detected, execution_plan) = match
    detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let detect_trace = format_detection_trace(detected)
  let prepared_source = execution_plan.prepared_source
  let requested_mode = execution_plan.requested_parser_mode
  let parse_context = parse_context_from_execution_plan(
    detected.format,
    execution_plan,
  )
  let parsed = if detected.format == @input.DetectedFormat::Pdf &&
    requested_mode == Some(@parser.ParserMode::LayoutTwoStage) {
    match
      @fpdf.pdf_ocr_parser_result_async(
        prepared_source,
        parse_context,
        image_ocr_provider~,
      ) {
      Ok(result) => result
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
  } else if @input.detected_format_is_image_candidate(detected.format) {
    match
      @focr.image_ocr_parser_result_with_async_provider_target(
        prepared_source,
        detected.format,
        execution_plan.ocr_options,
        @focr.image_ocr_selection_target_for_accuracy(
          execution_plan.fidelity_mode == FidelityMode::Accurate,
        ),
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(result) => result
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
  } else {
    let registry = @parser.async_registry_from_sync(@formats.builtin_registry())
    match
      parse_with_route_probe_artifact(
        prepared_source,
        detected.format,
        parse_context,
        execution_plan.probe_artifacts,
      ) {
      Some(Ok(result)) => result
      Some(Err(err)) => return Err(ConvertError::ParseFailed(err))
      None =>
        match
          @parser.async_registry_parse(registry, prepared_source, parse_context) {
          Ok(result) => result
          Err(err) => return Err(ConvertError::ParseFailed(err))
        }
    }
  }
  let diagnostics = inject_preparse_diagnostics(
    parsed.diagnostics,
    detect_trace,
    execution_plan,
    detected,
  )
  Ok(
    finalize_pipeline_convert_execution(
      effective_source,
      detected.format,
      options,
      parsed,
      diagnostics,
      execution_plan,
    ),
  )
}

///|
fn route_plan_from_execution_plan(
  execution_plan : ResolvedExecutionPlan,
) -> RoutePlan {
  {
    detected_format: execution_plan.detected_format,
    selected_route: canonical_route_name(execution_plan.selected_route),
    route_reason: execution_plan.reason,
    route_probe_summary: format_route_probe_summary(
      execution_plan.probe_summary_format,
      execution_plan.probe_summary_parts,
    ),
    requested_parser_mode: execution_plan.requested_parser_mode,
    ocr_provider_selection_target: execution_plan.ocr_provider_selection_target.map(target => {
        @focr.ocr_provider_selection_target_name(target)
      },
    ),
    ocr_provider_requested_kind: execution_plan.ocr_provider_requested_kind.map(kind => {
        @focr.ocr_provider_kind_name(kind)
      },
    ),
    ocr_provider_resolved_kind: execution_plan.ocr_provider_resolved_kind.map(kind => {
      @focr.ocr_provider_kind_name(kind)
    }),
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
pub fn route_plan_to_json(route_plan : RoutePlan) -> Json {
  Json::object({
    "detected_format": @input.detected_format_name(route_plan.detected_format).to_json(),
    "selected_route": route_plan.selected_route.to_json(),
    "route_reason": route_plan.route_reason.to_json(),
    "route_probe_summary": route_plan.route_probe_summary.to_json(),
    "requested_parser_mode": route_plan.requested_parser_mode
    .map(mode => @parser.mode_name(mode))
    .to_json(),
    "ocr_provider_selection_target": route_plan.ocr_provider_selection_target.to_json(),
    "ocr_provider_requested_kind": route_plan.ocr_provider_requested_kind.to_json(),
    "ocr_provider_resolved_kind": route_plan.ocr_provider_resolved_kind.to_json(),
  })
}

///|
pub fn convert_provenance_to_json(provenance : ConvertProvenance) -> Json {
  Json::object({
    "route_plan": route_plan_to_json(provenance.route_plan),
    "fidelity_mode": fidelity_mode_name(provenance.fidelity_mode).to_json(),
    "output_mode": output_mode_name(provenance.output_mode).to_json(),
    "execution_profile": @product.execution_profile_name(
      provenance.execution_profile,
    ).to_json(),
    "execution_profile_reason": provenance.execution_profile_reason.to_json(),
    "lowering_profile": @product.lowering_profile_name(
      provenance.lowering_profile,
    ).to_json(),
    "render_profile": @product.render_profile_name(provenance.render_profile).to_json(),
    "profile_trigger_signals": provenance.profile_trigger_signals.to_json(),
    "effective_parser_mode": @parser.mode_name(provenance.effective_parser_mode).to_json(),
    "parse_result_kind": provenance.parse_result_kind.to_json(),
    "pipeline_output_kind": provenance.pipeline_output_kind.to_json(),
    "render_input_kind": provenance.render_input_kind.to_json(),
    "route_fidelity_status": provenance.route_fidelity_status.to_json(),
    "applied_accurate_features": provenance.applied_accurate_features.to_json(),
    "same_mode_strategy_switches": provenance.same_mode_strategy_switches.to_json(),
    "ocr_provider_selection_target": provenance.ocr_provider_selection_target.to_json(),
    "ocr_provider_requested_kind": provenance.ocr_provider_requested_kind.to_json(),
    "ocr_provider_resolved_kind": provenance.ocr_provider_resolved_kind.to_json(),
    "audio_backend_transport": provenance.audio_backend_transport.to_json(),
    "audio_backend_name": provenance.audio_backend_name.to_json(),
    "audio_backend_version": provenance.audio_backend_version.to_json(),
    "requested_fidelity_mode": provenance.requested_fidelity_mode
    .map(mode => fidelity_mode_name(mode))
    .to_json(),
  })
}

///|
fn inject_preparse_diagnostics(
  diagnostics : @core.Diagnostics,
  detect_trace : String,
  execution_plan : ResolvedExecutionPlan,
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
    canonical_route_name(execution_plan.selected_route),
  )
  next.metrics.set("route_reason", execution_plan.reason)
  next.metrics.set(
    "route_probe_summary",
    format_route_probe_summary(
      execution_plan.probe_summary_format,
      execution_plan.probe_summary_parts,
    ),
  )
  next.metrics.set(
    "requested_convert_mode",
    convert_mode_name(execution_plan.mode),
  )
  next.metrics.set(
    "execution_profile",
    @product.execution_profile_name(execution_plan.execution_profile),
  )
  next.metrics.set(
    "execution_profile_reason",
    execution_plan.execution_profile_reason,
  )
  next.metrics.set(
    "applied_render_profile",
    @product.render_profile_name(execution_plan.render_profile),
  )
  next.metrics.set(
    "applied_accurate_features",
    @product.accurate_feature_profile_names(
      execution_plan.accurate_feature_profile,
    ).join("|"),
  )
  next.metrics.set(
    "probe_signal_count",
    execution_plan.probe_signals.length().to_string(),
  )
  next.metrics.set(
    "probe_failure_count",
    execution_plan.probe_failures.length().to_string(),
  )
  if execution_plan.probe_signals.length() > 0 {
    next.metrics.set(
      "probe_signals",
      probe_signals_metric(execution_plan.probe_signals),
    )
  }
  if execution_plan.profile_trigger_signals.length() > 0 {
    next.metrics.set(
      "profile_trigger_signals",
      probe_signals_metric(execution_plan.profile_trigger_signals),
    )
  }
  if execution_plan.probe_failures.length() > 0 {
    next.metrics.set(
      "probe_failures",
      probe_failures_metric(execution_plan.probe_failures),
    )
  }
  if detected.notes.length() > 0 {
    next.metrics.set(
      "format_detector_notes",
      format_detector_notes(detected.notes),
    )
  }
  for strategy_switch in execution_plan.same_mode_strategy_switches {
    if !next.same_mode_strategy_switches.contains(strategy_switch) {
      next.same_mode_strategy_switches.push(strategy_switch)
    }
    if !next.same_mode_degradation.contains(strategy_switch) {
      next.same_mode_degradation.push(strategy_switch)
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
fn probe_signal_kind_name(kind : ProbeSignalKind) -> String {
  match kind {
    ProbeSignalKind::CharCount => "char_count"
    ProbeSignalKind::LineCount => "line_count"
    ProbeSignalKind::BlockCount => "block_count"
    ProbeSignalKind::ListItemCount => "list_item_count"
    ProbeSignalKind::NodeCount => "node_count"
    ProbeSignalKind::MaxDepth => "max_depth"
    ProbeSignalKind::RowCount => "row_count"
    ProbeSignalKind::ColCount => "col_count"
    ProbeSignalKind::CellCount => "cell_count"
    ProbeSignalKind::CellEstimate => "cell_estimate"
    ProbeSignalKind::OutputCount => "output_count"
    ProbeSignalKind::AttachmentCount => "attachment_count"
    ProbeSignalKind::AssetCount => "asset_count"
    ProbeSignalKind::EntryCount => "entry_count"
    ProbeSignalKind::PageCount => "page_count"
    ProbeSignalKind::SlideCount => "slide_count"
    ProbeSignalKind::SheetCount => "sheet_count"
    ProbeSignalKind::ScalarCount => "scalar_count"
    ProbeSignalKind::ObjectCount => "object_count"
    ProbeSignalKind::ArrayCount => "array_count"
    ProbeSignalKind::HiddenRowCount => "hidden_row_count"
    ProbeSignalKind::HiddenSheetCount => "hidden_sheet_count"
    ProbeSignalKind::CoveredCellCount => "covered_cell_count"
    ProbeSignalKind::NoteCount => "note_count"
    ProbeSignalKind::CommentCount => "comment_count"
    ProbeSignalKind::ScannedPageCount => "scanned_page_count"
    ProbeSignalKind::NativeTextPageCount => "native_text_page_count"
  }
}

///|
fn probe_signals_metric(signals : Array[ProbeSignal]) -> String {
  if signals.length() == 0 {
    return ""
  }
  let parts : Array[String] = []
  for signal in signals {
    let base = probe_signal_kind_name(signal.kind) +
      "=" +
      signal.observed.to_string()
    let with_limit = match signal.limit {
      Some(limit) => base + "/limit=" + limit.to_string()
      None => base
    }
    let entry = match signal.note {
      Some(note) => with_limit + "/note=" + note
      None => with_limit
    }
    parts.push(entry)
  }
  parts.join("|")
}

///|
fn probe_failures_metric(failures : Array[ProbeFailure]) -> String {
  if failures.length() == 0 {
    return ""
  }
  let parts : Array[String] = []
  for failure in failures {
    parts.push(failure.stage + ":" + failure.detail)
  }
  parts.join("|")
}

///|
fn parse_with_route_probe_artifact(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  context : @parser.ParseContext,
  artifacts : Array[RouteProbeArtifact],
) -> Result[@parser.ParseResult, String]? {
  for artifact in artifacts {
    let matched = match artifact {
      RouteProbeArtifact::MarkdownScan(scanned, inspect) =>
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
      RouteProbeArtifact::HtmlEvents(normalized_text, events) =>
        if format == @input.DetectedFormat::Html &&
          context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
          Some(
            Ok(
              @fhtml.html_parse_with_token_events(
                source, context, normalized_text, events,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::IpynbNotebook(notebook, inspect) =>
        if format == @input.DetectedFormat::Ipynb {
          let text = match source.text {
            Some(value) => value
            None => return None
          }
          Some(
            Ok(
              @fipynb.ipynb_parse_with_preparsed_notebook(
                source, context, text, notebook, inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::JsonStream(stream) =>
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
      RouteProbeArtifact::TextMarkupDocument(document, inspect) =>
        match format {
          @input.DetectedFormat::Tex => {
            let text = match source.text {
              Some(value) => value
              None => return None
            }
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_preparsed_document(
                  source,
                  context,
                  text,
                  document,
                  inspect,
                  @ftex.tex_text_markup_hooks(),
                ),
              ),
            )
          }
          @input.DetectedFormat::Rst => {
            let text = match source.text {
              Some(value) => value
              None => return None
            }
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_preparsed_document(
                  source,
                  context,
                  text,
                  document,
                  inspect,
                  @frst.rst_text_markup_hooks(),
                ),
              ),
            )
          }
          @input.DetectedFormat::Asciidoc => {
            let text = match source.text {
              Some(value) => value
              None => return None
            }
            Some(
              Ok(
                @fshared.parse_text_markup_result_with_preparsed_document(
                  source,
                  context,
                  text,
                  document,
                  inspect,
                  @fasciidoc.asciidoc_text_markup_hooks(),
                ),
              ),
            )
          }
          _ => None
        }
      RouteProbeArtifact::TomlDocument(document, inspect) =>
        if format == @input.DetectedFormat::Toml {
          let text = match source.text {
            Some(value) => value
            None => return None
          }
          Some(
            Ok(
              @ftoml.toml_parse_with_preparsed_document(
                source, context, text, document, inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::XmlTokens(tokens) =>
        if format == @input.DetectedFormat::Xml &&
          context.requested_mode == Some(@parser.ParserMode::StreamingEvent) {
          let text = match @fxml.read_xml_input_text(source) {
            Ok(value) => value
            Err(err) => return Some(Err(err))
          }
          Some(
            Ok(
              @fxml.xml_parse_with_structure_tokens(
                source, context, text, tokens,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdtDocument(document, inspect) =>
        if format == @input.DetectedFormat::Odt {
          Some(
            Ok(
              @fodt.odt_parse_with_open_document(
                source, context, document, inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdsDocument(document, inspect) =>
        if format == @input.DetectedFormat::Ods {
          Some(
            Ok(
              @fods.ods_parse_with_open_document(
                source, context, document, inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::OdpDocument(document, inspect) =>
        if format == @input.DetectedFormat::Odp {
          Some(
            Ok(
              @fodp.odp_parse_with_open_document(
                source, context, document, inspect,
              ),
            ),
          )
        } else {
          None
        }
      RouteProbeArtifact::XlsxPackage(pkg) =>
        if format == @input.DetectedFormat::Xlsx {
          Some(Ok(@dxlsx.xlsx_parse_with_package(source, context, pkg)))
        } else {
          None
        }
      RouteProbeArtifact::YamlEvents(events, inspect) =>
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
      RouteProbeArtifact::AudioProbe(_artifact) => None
    }
    if matched is Some(_) {
      return matched
    }
  }
  None
}
