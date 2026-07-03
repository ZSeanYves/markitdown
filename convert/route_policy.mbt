///|
fn explicit_stream_supported_for_format(format : @input.DetectedFormat) -> Bool {
  @formats.explicit_stream_supported_for_format(format)
}

///|
fn parser_mode_for_route(route : CanonicalRoute) -> @parser.ParserMode? {
  Some(@formats.parser_mode_for_route(route))
}

///|
fn requested_parser_mode_for_route(
  format : @input.DetectedFormat,
  options : ConvertOptions,
  route_decision : RouteDecision,
) -> @parser.ParserMode? {
  if options.stream_requested && !explicit_stream_supported_for_format(format) {
    parser_mode_for_route(route_decision.selected_route)
  } else if options.stream_requested {
    let profile = @formats.format_route_profile(format)
    match profile.explicit_stream_route {
      Some(route) =>
        if route == route_decision.selected_route {
          match profile.large_route_parser_mode {
            Some(mode) => Some(mode)
            None => parser_mode_for_route(route)
          }
        } else {
          parser_mode_for_route(route_decision.selected_route)
        }
      None => parser_mode_for_route(route_decision.selected_route)
    }
  } else {
    parser_mode_for_route(route_decision.selected_route)
  }
}

///|
fn plan_route(
  source : @input.InputSource,
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> RouteDecision {
  let probe = preflight_probe(source, format, options)
  {
    selected_route: probe.selected_route,
    reason: probe.reason,
    probe_summary_format: probe.summary_format,
    probe_summary_parts: probe.summary_parts,
    same_mode_degradation: if options.stream_requested &&
      !explicit_stream_supported_for_format(format) {
      ["explicit_stream_unsupported_fell_back"]
    } else {
      []
    },
    prepared_source: probe.prepared_source,
    probe_artifact: probe.probe_artifact,
  }
}

///|
fn canonical_route_for_format(
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> CanonicalRoute {
  let profile = @formats.format_route_profile(format)
  if options.stream_requested {
    match profile.explicit_stream_route {
      Some(route) => return route
      None => return profile.canonical_route
    }
  }
  match format {
    @input.DetectedFormat::Pdf =>
      if options.fidelity_mode == FidelityMode::Accurate ||
        options.ocr_options.intent == @parser.OcrIntent::Explicit {
        CanonicalRoute::LayoutTwoStage
      } else {
        CanonicalRoute::PageSinglePass
      }
    _ => profile.canonical_route
  }
}

///|
fn canonical_route_name(route : CanonicalRoute) -> String {
  @formats.route_name(route)
}

///|
fn route_reason_for_format(
  format : @input.DetectedFormat,
  options : ConvertOptions,
  route : CanonicalRoute,
) -> String {
  if options.stream_requested && !explicit_stream_supported_for_format(format) {
    return "explicit_stream_unsupported_fell_back"
  }
  if options.stream_requested {
    return "explicit_stream_mode"
  }
  if format == @input.DetectedFormat::Pdf {
    if route == CanonicalRoute::LayoutTwoStage &&
      options.ocr_options.intent == @parser.OcrIntent::Explicit {
      return "pdf_explicit_ocr_layout_two_stage"
    }
    if route == CanonicalRoute::LayoutTwoStage &&
      options.fidelity_mode == FidelityMode::Accurate {
      return "pdf_accurate_layout_two_stage"
    }
    if route == CanonicalRoute::PageSinglePass {
      return "pdf_canonical_page_single_pass"
    }
  }
  @input.detected_format_name(format) +
  "_canonical_" +
  canonical_route_name(route)
}
