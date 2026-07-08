///|
fn canonical_route_name(route : CanonicalRoute) -> String {
  @formats.route_name(route)
}

///|
fn detect_effective_source(
  source : @input.InputSource,
  options : ConvertOptions,
) -> @input.InputSource {
  match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
}

///|
fn detect_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[(@input.InputSource, @input.FormatDetectionResult), ConvertError] {
  let effective_source = detect_effective_source(source, options)
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    Err(ConvertError::DetectFailed("unknown format"))
  } else {
    Ok((effective_source, detected))
  }
}

///|
fn product_convert_mode_for_strategy(
  mode : ConvertMode,
) -> @product.ConvertMode {
  match mode {
    ConvertMode::Balanced => @product.ConvertMode::Balanced
    ConvertMode::Accurate => @product.ConvertMode::Accurate
    ConvertMode::Stream => @product.ConvertMode::Stream
  }
}

///|
fn execution_intent(options : ConvertOptions) -> ExecutionIntent {
  {
    strategy_mode: options.mode,
    fidelity_mode: options.fidelity_mode,
    requested_fidelity_mode: options.fidelity_mode,
    output_mode: options.output_mode,
    stream_requested: options.stream_requested,
    output_format: options.output_format,
    ocr_options: options.ocr_options,
    audio_options: options.audio_options,
    limits: options.limits,
    pdf_ocr_policy: options.pdf_ocr_policy,
    pdf_cleanup_mode: options.pdf_cleanup_mode,
    pdf_table_mode: options.pdf_table_mode,
    rag_options: options.rag_options,
  }
}

///|
fn pdf_header_footer_filter_policy_from_mode(
  mode : PdfCleanupMode,
) -> @parser.PdfHeaderFooterFilterPolicy {
  match mode {
    PdfCleanupMode::Disabled => @parser.PdfHeaderFooterFilterPolicy::Disabled
    PdfCleanupMode::Conservative =>
      @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly
  }
}

///|
fn pdf_table_reconstruction_policy_from_mode(
  mode : PdfTableMode,
) -> @parser.PdfTableReconstructionPolicy {
  match mode {
    PdfTableMode::Disabled => @parser.PdfTableReconstructionPolicy::Disabled
    PdfTableMode::Simple =>
      @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly
  }
}

///|
fn route_expects_stream_render(route : CanonicalRoute) -> Bool {
  match route {
    CanonicalRoute::StreamingEvent => true
    CanonicalRoute::BlockStreaming => true
    CanonicalRoute::ContainerRecursive => true
    _ => false
  }
}

///|
fn strategy_route_parser_mode(
  route : @formats.StrategyRouteSpec,
) -> @parser.ParserMode? {
  Some(route.parser_mode)
}

///|
fn matching_probe_signal(
  signals : Array[ProbeSignal],
  kind : ProbeSignalKind,
) -> ProbeSignal? {
  for signal in signals {
    if signal.kind == kind {
      return Some(signal)
    }
  }
  None
}

///|
fn exceeded_threshold_signals(
  signals : Array[ProbeSignal],
  thresholds : Array[(ProbeSignalKind, Int)],
) -> Array[ProbeSignal] {
  let matched : Array[ProbeSignal] = []
  for threshold in thresholds {
    match matching_probe_signal(signals, threshold.0) {
      Some(signal) =>
        match resolved_threshold_limit(signal, threshold.1) {
          Some(limit) =>
            if signal.observed > limit {
              matched.push({ ..signal, limit: Some(limit) })
            }
          None => ()
        }
      None => ()
    }
  }
  matched
}

///|
fn scanned_page_signal(signals : Array[ProbeSignal]) -> ProbeSignal? {
  match matching_probe_signal(signals, ProbeSignalKind::ScannedPageCount) {
    Some(signal) if signal.observed > 0 => Some(signal)
    _ => None
  }
}

///|
fn resolved_threshold_limit(
  signal : ProbeSignal,
  configured_limit : Int,
) -> Int? {
  if configured_limit > 0 {
    Some(configured_limit)
  } else if configured_limit == 0 {
    signal.limit
  } else {
    None
  }
}

///|
fn strategy_switches_for_plan(
  detected_format : @input.DetectedFormat,
  intent : ExecutionIntent,
  selected : @formats.StrategyRouteSpec,
  mode_policy : @formats.ModeStrategyPolicy,
  explicit_stream_fell_back : Bool,
  accurate_fell_back : Bool,
  execution_profile : ExecutionProfile,
) -> Array[String] {
  let switches : Array[String] = []
  if explicit_stream_fell_back {
    switches.push("explicit_stream_unsupported_fell_back")
  }
  if accurate_fell_back {
    switches.push("accurate_unsupported_fell_back")
  }
  if execution_profile == ExecutionProfile::MediumAdaptive {
    switches.push(
      @input.detected_format_name(detected_format) + "_medium_adaptive_profile",
    )
  }
  if mode_policy.hard_limit_route is Some(route) &&
    route.route == selected.route &&
    mode_policy.canonical.route != selected.route {
    switches.push(
      @input.detected_format_name(detected_format) +
      "_hard_limit_" +
      canonical_route_name(selected.route),
    )
  }
  if intent.stream_requested && route_expects_stream_render(selected.route) {
    switches.push(
      @input.detected_format_name(detected_format) + "_stream_render_profile",
    )
  }
  switches
}

///|
fn route_reason_for_plan(
  detected_format : @input.DetectedFormat,
  intent : ExecutionIntent,
  selected : @formats.StrategyRouteSpec,
  mode_policy : @formats.ModeStrategyPolicy,
  explicit_stream_fell_back : Bool,
  accurate_fell_back : Bool,
  hard_triggered : Bool,
) -> String {
  if explicit_stream_fell_back {
    return "explicit_stream_unsupported_fell_back"
  }
  if accurate_fell_back {
    return "accurate_unsupported_fell_back"
  }
  if intent.stream_requested && mode_policy.explicit_stream_supported {
    return "explicit_stream_mode"
  }
  if detected_format == @input.DetectedFormat::Pdf &&
    selected.route == CanonicalRoute::LayoutTwoStage {
    return "pdf_accurate_layout_two_stage"
  }
  if detected_format == @input.DetectedFormat::Pdf &&
    selected.route == CanonicalRoute::PageSinglePass {
    return "pdf_canonical_page_single_pass"
  }
  if hard_triggered {
    return @input.detected_format_name(detected_format) +
      "_over_limit_" +
      canonical_route_name(selected.route)
  }
  @input.detected_format_name(detected_format) +
  "_canonical_" +
  canonical_route_name(selected.route)
}

///|
fn effective_execution_profile(
  selected : @formats.StrategyRouteSpec,
  mode_policy : @formats.ModeStrategyPolicy,
  soft_trigger_signals : Array[ProbeSignal],
  hard_trigger_signals : Array[ProbeSignal],
) -> ExecutionProfile {
  ignore(selected)
  if mode_policy.hard_limit_route is Some(route) &&
    route.route == selected.route &&
    hard_trigger_signals.length() > 0 {
    ExecutionProfile::LargeAdaptive
  } else if hard_trigger_signals.length() > 0 {
    ExecutionProfile::LargeAdaptive
  } else if soft_trigger_signals.length() > 0 {
    ExecutionProfile::MediumAdaptive
  } else {
    ExecutionProfile::Standard
  }
}

///|
fn effective_render_profile(
  selected : @formats.StrategyRouteSpec,
  mode_policy : @formats.ModeStrategyPolicy,
  execution_profile : ExecutionProfile,
) -> RenderProfile {
  match execution_profile {
    ExecutionProfile::MediumAdaptive =>
      mode_policy.soft_limit_render_profile.unwrap_or(
        mode_policy.render_profile,
      )
    ExecutionProfile::LargeAdaptive =>
      if route_expects_stream_render(selected.route) {
        mode_policy.soft_limit_render_profile.unwrap_or(
          mode_policy.render_profile,
        )
      } else {
        mode_policy.render_profile
      }
    ExecutionProfile::Standard => mode_policy.render_profile
  }
}

///|
fn effective_lowering_profile(
  selected : @formats.StrategyRouteSpec,
  intent : ExecutionIntent,
  execution_profile : ExecutionProfile,
) -> LoweringProfile {
  if execution_profile == ExecutionProfile::LargeAdaptive {
    return LoweringProfile::LargeAdaptive
  }
  if intent.fidelity_mode == FidelityMode::Accurate {
    return LoweringProfile::AccurateSemantic
  }
  if intent.stream_requested || route_expects_stream_render(selected.route) {
    return LoweringProfile::StreamCanonical
  }
  LoweringProfile::Canonical
}

///|
fn accurate_feature_profile_for_mode_policy(
  mode_policy : @formats.ModeStrategyPolicy,
) -> AccurateFeatureProfile {
  @product.make_accurate_feature_profile(mode_policy.accurate_features.copy())
}

///|
fn select_strategy_route(
  detected_format : @input.DetectedFormat,
  intent : ExecutionIntent,
  policy : @formats.FormatStrategyPolicy,
  mode_policy : @formats.ModeStrategyPolicy,
  hard_trigger_signals : Array[ProbeSignal],
) -> (@formats.StrategyRouteSpec, Bool, Bool) {
  if detected_format == @input.DetectedFormat::Pdf &&
    intent.fidelity_mode == FidelityMode::Accurate {
    return (policy.accurate.canonical, false, false)
  }
  if detected_format == @input.DetectedFormat::Pdf {
    return (policy.balanced.canonical, false, false)
  }
  let explicit_stream_fell_back = intent.stream_requested &&
    !mode_policy.explicit_stream_supported
  if explicit_stream_fell_back {
    return (mode_policy.canonical, true, false)
  }
  if intent.stream_requested {
    return (
      mode_policy.explicit_stream.unwrap_or(mode_policy.canonical),
      false,
      false,
    )
  }
  if hard_trigger_signals.length() > 0 {
    match mode_policy.hard_limit_route {
      Some(route) => return (route, false, true)
      None => ()
    }
  }
  ignore(detected_format)
  (mode_policy.canonical, false, false)
}

///|
fn resolve_execution_plan(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ResolvedExecutionPlan {
  let intent = execution_intent(options)
  let preserves_runtime_accurate_semantics = @input.detected_format_is_image_candidate(
    detected_format,
  )
  let accurate_fell_back = detected_format != @input.DetectedFormat::Pdf &&
    !preserves_runtime_accurate_semantics &&
    intent.fidelity_mode == FidelityMode::Accurate &&
    @product.accurate_features_for_detected_format(detected_format).length() ==
    0
  let effective_intent = if accurate_fell_back {
    {
      ..intent,
      strategy_mode: ConvertMode::Balanced,
      fidelity_mode: FidelityMode::Balanced,
    }
  } else {
    intent
  }
  let probe = preflight_probe(source, detected_format, options)
  let policy = @formats.format_strategy_policy(detected_format)
  let mode_policy = @formats.format_mode_strategy_policy(
    detected_format,
    product_convert_mode_for_strategy(effective_intent.strategy_mode),
  )
  let hard_trigger_signals = exceeded_threshold_signals(
    probe.probe_signals,
    mode_policy.hard_limit_thresholds,
  )
  let soft_trigger_signals = exceeded_threshold_signals(
    probe.probe_signals,
    mode_policy.soft_limit_thresholds,
  )
  let pdf_scanned_signal = scanned_page_signal(probe.probe_signals)
  let route_probe_signals = match (detected_format, pdf_scanned_signal) {
    (@input.DetectedFormat::Pdf, Some(signal)) => [signal]
    _ => hard_trigger_signals
  }
  let (selected, explicit_stream_fell_back, used_hard_limit) = select_strategy_route(
    detected_format, effective_intent, policy, mode_policy, route_probe_signals,
  )
  let execution_profile = effective_execution_profile(
    selected, mode_policy, soft_trigger_signals, hard_trigger_signals,
  )
  let render_profile = effective_render_profile(
    selected, mode_policy, execution_profile,
  )
  let lowering_profile = effective_lowering_profile(
    selected, intent, execution_profile,
  )
  let accurate_feature_profile = accurate_feature_profile_for_mode_policy(
    mode_policy,
  )
  let switches = strategy_switches_for_plan(
    detected_format, effective_intent, selected, mode_policy, explicit_stream_fell_back,
    accurate_fell_back, execution_profile,
  )
  let ocr_provider_target = ocr_provider_target_for_plan(
    detected_format,
    effective_intent.fidelity_mode,
    strategy_route_parser_mode(selected),
  )
  let ocr_provider_requested_kind = ocr_provider_target.map(target => {
    @focr.default_ocr_provider_kind_for_target(target)
  })
  let ocr_provider_resolved_kind = ocr_provider_target.map(target => {
    @focr.resolved_ocr_provider_kind_for_target(target)
  })
  let strategy_mode = if effective_intent.stream_requested &&
    mode_policy.explicit_stream_supported &&
    selected.route == mode_policy.canonical.route &&
    policy.stream.canonical.route == selected.route {
    ConvertMode::Stream
  } else {
    effective_intent.strategy_mode
  }
  let (audio_backend_transport, audio_backend_name, audio_backend_version) = match
    detected_format {
    @input.DetectedFormat::Audio(_) =>
      (
        Some(@faudio.audio_backend_transport_name()),
        Some(@faudio.audio_backend_name()),
        None,
      )
    _ => (None, None, None)
  }
  {
    detected_format,
    mode: strategy_mode,
    fidelity_mode: effective_intent.fidelity_mode,
    requested_fidelity_mode: intent.requested_fidelity_mode,
    output_mode: effective_intent.output_mode,
    stream_requested: effective_intent.stream_requested,
    output_format: effective_intent.output_format,
    ocr_options: effective_intent.ocr_options,
    audio_options: effective_intent.audio_options,
    limits: effective_intent.limits,
    pdf_ocr_policy: effective_intent.pdf_ocr_policy,
    pdf_cleanup_mode: effective_intent.pdf_cleanup_mode,
    pdf_table_mode: effective_intent.pdf_table_mode,
    rag_options: effective_intent.rag_options,
    selected_route: selected.route,
    execution_profile,
    execution_profile_reason: if used_hard_limit {
      "hard_limit_threshold"
    } else if soft_trigger_signals.length() > 0 {
      "soft_limit_threshold"
    } else {
      "canonical_threshold_window"
    },
    lowering_profile,
    render_profile,
    accurate_feature_profile,
    requested_parser_mode: strategy_route_parser_mode(selected),
    pdf_native_runtime_policy: @parser.default_pdf_native_runtime_policy(),
    pdf_header_footer_filter_policy: pdf_header_footer_filter_policy_from_mode(
      effective_intent.pdf_cleanup_mode,
    ),
    pdf_table_reconstruction_policy: pdf_table_reconstruction_policy_from_mode(
      effective_intent.pdf_table_mode,
    ),
    reason: route_reason_for_plan(
      detected_format, effective_intent, selected, mode_policy, explicit_stream_fell_back,
      accurate_fell_back, used_hard_limit,
    ),
    probe_signals: probe.probe_signals,
    profile_trigger_signals: if used_hard_limit {
      hard_trigger_signals
    } else {
      soft_trigger_signals
    },
    probe_failures: probe.probe_failures,
    probe_summary_format: probe.summary_format,
    probe_summary_parts: probe.summary_parts,
    same_mode_strategy_switches: switches,
    ocr_provider_selection_target: ocr_provider_target,
    ocr_provider_requested_kind,
    ocr_provider_resolved_kind,
    audio_backend_transport,
    audio_backend_name,
    audio_backend_version,
    prepared_source: probe.prepared_source,
    probe_artifacts: probe.probe_artifacts,
  }
}

///|
fn ocr_provider_target_for_plan(
  detected_format : @input.DetectedFormat,
  fidelity_mode : FidelityMode,
  requested_parser_mode : @parser.ParserMode?,
) -> @focr.OcrProviderSelectionTarget? {
  if @input.detected_format_is_image_candidate(detected_format) {
    return Some(
      if fidelity_mode == FidelityMode::Accurate {
        @focr.OcrProviderSelectionTarget::DirectImageAccurate
      } else {
        @focr.OcrProviderSelectionTarget::DirectImageBalanced
      },
    )
  }
  if detected_format == @input.DetectedFormat::Pdf &&
    requested_parser_mode == Some(@parser.ParserMode::LayoutTwoStage) {
    ignore(fidelity_mode)
    return Some(@focr.OcrProviderSelectionTarget::PdfAccurate)
  }
  None
}

///|
fn detect_and_resolve_execution_plan(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[
  (@input.InputSource, @input.FormatDetectionResult, ResolvedExecutionPlan),
  ConvertError,
] {
  match detect_input(source, options) {
    Ok((effective_source, detected)) =>
      Ok(
        (
          effective_source,
          detected,
          resolve_execution_plan(effective_source, detected.format, options),
        ),
      )
    Err(err) => Err(err)
  }
}
