///|
fn convert_input_with_image_ocr_provider_and_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  convert_input_with_image_ocr_provider_and_pdf_rasterizer_and_provenance(
    source, options, image_ocr_provider, @fpdf.rasterize_pdf_with_pdftoppm_default,
  )
}

///|
fn convert_input_with_image_ocr_provider_and_pdf_rasterizer_and_provenance(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
  pdf_rasterizer : (@input.InputSource) -> Result[
    (@fpdf.PdfRasterResult, String),
    @fpdf.PdfRasterizerError,
  ],
) -> Result[ConvertExecution, ConvertError] {
  let execution_started = @env.now()
  let detect_started = execution_started
  let (effective_source, detected, execution_plan) = match
    detect_and_resolve_execution_plan(source, options) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let detect_elapsed_ms = @env.now() - detect_started
  let detect_trace = format_detection_trace(detected)
  let prepared_source = execution_plan.prepared_source
  let requested_mode = execution_plan.requested_parser_mode
  let parse_context = parse_context_from_execution_plan(
    detected.format,
    execution_plan,
  )
  let parse_started = @env.now()
  let parsed = if @input.detected_format_is_image_candidate(detected.format) {
    match
      @focr.image_ocr_parser_result_with_provider_target(
        prepared_source,
        detected.format,
        execution_plan.ocr_options,
        @focr.image_ocr_selection_target_for_accuracy(
          execution_plan.fidelity_mode == Accurate,
        ),
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(result) => result
      Err(err) => return Err(ParseFailed(err))
    }
  } else if detected.format == Pdf && requested_mode == Some(LayoutTwoStage) {
    match
      @fpdf.pdf_ocr_parser_result(
        prepared_source,
        parse_context,
        image_ocr_provider~,
        rasterizer=pdf_rasterizer,
      ) {
      Ok(result) => result
      Err(err) => return Err(ParseFailed(err))
    }
  } else {
    let probe_registry = match detected.format {
      Zip | Epub => @formats.builtin_registry()
      _ => @parser.empty_registry()
    }
    match
      parse_prepared_request(
        {
          source: prepared_source,
          detected_format: detected.format,
          probe_outcome: {
            probe_signals: execution_plan.probe_signals,
            probe_failures: execution_plan.probe_failures,
            summary_format: execution_plan.probe_summary_format,
            summary_parts: execution_plan.probe_summary_parts,
            prepared_source,
            probe_artifacts: execution_plan.probe_artifacts,
          },
          probe_artifact: None,
        },
        parse_context,
        probe_registry,
      ) {
      Some(Ok(result)) => result
      Some(Err(err)) => return Err(ParseFailed(err))
      None if heavy_probe_artifact_required(detected.format) =>
        return Err(
          ParseFailed(
            "route probe artifact missing or mismatched for format: " +
            @input.detected_format_name(detected.format),
          ),
        )
      None =>
        match
          @parser.registry_parse(
            @formats.builtin_registry(),
            prepared_source,
            parse_context,
          ) {
          Ok(result) => result
          Err(err) => return Err(ParseFailed(err))
        }
    }
  }
  let diagnostics = inject_preparse_diagnostics(
    parsed.diagnostics,
    detect_trace,
    execution_plan,
    detected,
  )
  diagnostics.metrics.set(
    "timing_detect_probe_ms",
    detect_elapsed_ms.to_string(),
  )
  diagnostics.metrics.set(
    "timing_parse_lower_ms",
    (@env.now() - parse_started).to_string(),
  )
  Ok(
    finalize_pipeline_execution(
      effective_source,
      detected.format,
      options,
      parsed,
      diagnostics,
      execution_plan,
      execution_started,
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
    execution_plan.output_mode == Debug,
    limits=execution_plan.limits,
  )
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
    CharCount => "char_count"
    LineCount => "line_count"
    BlockCount => "block_count"
    ListItemCount => "list_item_count"
    NodeCount => "node_count"
    MaxDepth => "max_depth"
    RowCount => "row_count"
    ColCount => "col_count"
    CellCount => "cell_count"
    CellEstimate => "cell_estimate"
    OutputCount => "output_count"
    AttachmentCount => "attachment_count"
    AssetCount => "asset_count"
    EntryCount => "entry_count"
    PageCount => "page_count"
    SlideCount => "slide_count"
    SheetCount => "sheet_count"
    ScalarCount => "scalar_count"
    ObjectCount => "object_count"
    ArrayCount => "array_count"
    HiddenRowCount => "hidden_row_count"
    HiddenSheetCount => "hidden_sheet_count"
    CoveredCellCount => "covered_cell_count"
    NoteCount => "note_count"
    CommentCount => "comment_count"
    ScannedPageCount => "scanned_page_count"
    NativeTextPageCount => "native_text_page_count"
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
