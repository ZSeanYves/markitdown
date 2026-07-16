///|
fn canonical_route_name(route : CanonicalRoute) -> String {
  @fmeta.route_name(route)
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
  if detected.format == Unknown {
    Err(DetectFailed("unknown format"))
  } else {
    Ok((effective_source, detected))
  }
}

///|
fn product_convert_mode_for_strategy(
  mode : ConvertMode,
) -> @product.ConvertMode {
  mode
}

///|
fn execution_intent(options : ConvertOptions) -> ExecutionIntent {
  let fidelity_mode = fidelity_mode_for_convert_mode(options.mode)
  {
    strategy_mode: options.mode,
    fidelity_mode,
    requested_fidelity_mode: fidelity_mode,
    output_mode: options.output_mode,
    stream_requested: options.mode == Stream,
    ocr_options: options.ocr_options,
    audio_options: options.audio_options,
    limits: options.limits,
    rag_options: options.rag_options,
  }
}

///|
fn pdf_header_footer_filter_policy_for_plan(
  detected_format : @input.DetectedFormat,
  fidelity_mode : FidelityMode,
  selected_route : CanonicalRoute,
) -> @parser.PdfHeaderFooterFilterPolicy {
  if detected_format == Pdf &&
    selected_route == LayoutTwoStage &&
    fidelity_mode == Accurate {
    InternalHighConfidenceOnly
  } else {
    Disabled
  }
}

///|
fn pdf_table_reconstruction_policy_for_plan(
  detected_format : @input.DetectedFormat,
  fidelity_mode : FidelityMode,
  selected_route : CanonicalRoute,
) -> @parser.PdfTableReconstructionPolicy {
  if detected_format == Pdf &&
    (
      (selected_route == LayoutTwoStage && fidelity_mode == Accurate) ||
      selected_route == PageSinglePass
    ) {
    InternalSimpleRowsOnly
  } else {
    Disabled
  }
}

///|
fn route_expects_stream_render(route : CanonicalRoute) -> Bool {
  match route {
    StreamingEvent => true
    BlockStreaming => true
    ContainerRecursive => true
    _ => false
  }
}

///|
fn strategy_route_parser_mode(
  route : @fmeta.StrategyRouteSpec,
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
  match matching_probe_signal(signals, ScannedPageCount) {
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
  selected : @fmeta.StrategyRouteSpec,
  mode_policy : @fmeta.ModeStrategyPolicy,
  execution_profile : ExecutionProfile,
) -> Array[String] {
  let switches : Array[String] = []
  if execution_profile == MediumAdaptive {
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
  selected : @fmeta.StrategyRouteSpec,
  mode_policy : @fmeta.ModeStrategyPolicy,
  hard_triggered : Bool,
) -> String {
  if intent.stream_requested && mode_policy.explicit_stream_supported {
    return "explicit_stream_mode"
  }
  if detected_format == Pdf && selected.route == LayoutTwoStage {
    return "pdf_accurate_layout_two_stage"
  }
  if detected_format == Pdf && selected.route == PageSinglePass {
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
  selected : @fmeta.StrategyRouteSpec,
  mode_policy : @fmeta.ModeStrategyPolicy,
  soft_trigger_signals : Array[ProbeSignal],
  hard_trigger_signals : Array[ProbeSignal],
) -> ExecutionProfile {
  ignore(selected)
  if mode_policy.hard_limit_route is Some(route) &&
    route.route == selected.route &&
    hard_trigger_signals.length() > 0 {
    LargeAdaptive
  } else if hard_trigger_signals.length() > 0 {
    LargeAdaptive
  } else if soft_trigger_signals.length() > 0 {
    MediumAdaptive
  } else {
    Standard
  }
}

///|
fn effective_render_profile(
  selected : @fmeta.StrategyRouteSpec,
  mode_policy : @fmeta.ModeStrategyPolicy,
  execution_profile : ExecutionProfile,
) -> RenderProfile {
  match execution_profile {
    MediumAdaptive =>
      mode_policy.soft_limit_render_profile.unwrap_or(
        mode_policy.render_profile,
      )
    LargeAdaptive =>
      if route_expects_stream_render(selected.route) {
        mode_policy.soft_limit_render_profile.unwrap_or(
          mode_policy.render_profile,
        )
      } else {
        mode_policy.render_profile
      }
    Standard => mode_policy.render_profile
  }
}

///|
fn effective_lowering_profile(
  selected : @fmeta.StrategyRouteSpec,
  intent : ExecutionIntent,
  execution_profile : ExecutionProfile,
) -> LoweringProfile {
  if execution_profile == LargeAdaptive {
    return LargeAdaptive
  }
  if intent.fidelity_mode == Accurate {
    return AccurateSemantic
  }
  if intent.stream_requested || route_expects_stream_render(selected.route) {
    return StreamCanonical
  }
  Canonical
}

///|
fn accurate_feature_profile_for_mode_policy(
  mode_policy : @fmeta.ModeStrategyPolicy,
) -> AccurateFeatureProfile {
  @product.make_accurate_feature_profile(mode_policy.accurate_features.copy())
}

///|
fn select_strategy_route(
  detected_format : @input.DetectedFormat,
  intent : ExecutionIntent,
  policy : @fmeta.FormatStrategyPolicy,
  mode_policy : @fmeta.ModeStrategyPolicy,
  hard_trigger_signals : Array[ProbeSignal],
) -> (@fmeta.StrategyRouteSpec, Bool) {
  if detected_format == Pdf && intent.fidelity_mode == Accurate {
    return (policy.accurate.canonical, false)
  }
  if detected_format == Pdf {
    return (policy.balanced.canonical, false)
  }
  if intent.stream_requested {
    return (mode_policy.explicit_stream.unwrap_or(mode_policy.canonical), false)
  }
  if hard_trigger_signals.length() > 0 {
    match mode_policy.hard_limit_route {
      Some(route) => return (route, true)
      None => ()
    }
  }
  ignore(detected_format)
  (mode_policy.canonical, false)
}

///|
fn resolve_execution_plan(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> ResolvedExecutionPlan {
  let intent = execution_intent(options)
  let effective_intent = intent
  let probe = preflight_probe(source, detected_format, options)
  let policy = @fmeta.route_contract_for_format(detected_format)
  let mode_policy = @fmeta.route_mode_contract_for_format(
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
    (Pdf, Some(signal)) => [signal]
    _ => hard_trigger_signals
  }
  let (selected, used_hard_limit) = select_strategy_route(
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
    detected_format, effective_intent, selected, mode_policy, execution_profile,
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
    Audio(_) =>
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
    ocr_options: effective_intent.ocr_options,
    audio_options: effective_intent.audio_options,
    limits: effective_intent.limits,
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
    pdf_header_footer_filter_policy: pdf_header_footer_filter_policy_for_plan(
      detected_format,
      effective_intent.fidelity_mode,
      selected.route,
    ),
    pdf_table_reconstruction_policy: pdf_table_reconstruction_policy_for_plan(
      detected_format,
      effective_intent.fidelity_mode,
      selected.route,
    ),
    reason: route_reason_for_plan(
      detected_format, effective_intent, selected, mode_policy, used_hard_limit,
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
      if fidelity_mode == Accurate {
        DirectImageAccurate
      } else {
        DirectImageBalanced
      },
    )
  }
  if detected_format == Pdf && requested_parser_mode == Some(LayoutTwoStage) {
    ignore(fidelity_mode)
    return Some(PdfAccurate)
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
  let input_size = match @input.input_source_size(source) {
    Ok(value) => value
    Err(_) => None
  }
  match input_size {
    Some(size) if size > options.limits.max_input_bytes =>
      return Err(
        ResourceLimitExceeded(
          kind="input_bytes",
          observed=size,
          limit=options.limits.max_input_bytes,
        ),
      )
    _ => ()
  }
  match detect_input(source, options) {
    Ok((effective_source, detected)) => {
      let policy = @fmeta.route_contract_for_format(detected.format)
      let accurate_requested = options.mode == Accurate
      let accurate_supported = @input.detected_format_is_image_candidate(
          detected.format,
        ) ||
        policy.accurate.accurate_features.length() > 0
      if accurate_requested && !accurate_supported {
        return Err(
          ParseFailed(
            "accurate mode is unsupported for `" +
            @input.detected_format_name(detected.format) +
            "`; use balance mode",
          ),
        )
      }
      let stream_requested = options.mode == Stream
      if stream_requested && !policy.balanced.explicit_stream_supported {
        return Err(
          ParseFailed(
            "stream mode is unsupported for `" +
            @input.detected_format_name(detected.format) +
            "`; use balance mode",
          ),
        )
      }
      Ok(
        (
          effective_source,
          detected,
          resolve_execution_plan(effective_source, detected.format, options),
        ),
      )
    }
    Err(err) => Err(err)
  }
}
