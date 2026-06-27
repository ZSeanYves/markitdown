///|
fn parser_mode_for_route(route : CanonicalRoute) -> @parser.ParserMode? {
  match route {
    CanonicalRoute::StreamingEvent => Some(@parser.ParserMode::StreamingEvent)
    CanonicalRoute::BlockStreaming => Some(@parser.ParserMode::BlockStreaming)
    CanonicalRoute::PackageSinglePass =>
      Some(@parser.ParserMode::PackageSinglePass)
    CanonicalRoute::PageSinglePass => Some(@parser.ParserMode::PageSinglePass)
    CanonicalRoute::DomAstModel => Some(@parser.ParserMode::DomAstModel)
    CanonicalRoute::LayoutTwoStage => Some(@parser.ParserMode::LayoutTwoStage)
    CanonicalRoute::ContainerRecursive =>
      Some(@parser.ParserMode::ContainerRecursive)
  }
}

///|
fn requested_parser_mode_for_route(
  format : @input.DetectedFormat,
  options : ConvertOptions,
  route_decision : RouteDecision,
) -> @parser.ParserMode? {
  match options.mode {
    ConvertMode::Stream =>
      match format {
        @input.DetectedFormat::Txt
        | @input.DetectedFormat::Csv
        | @input.DetectedFormat::Tsv
        | @input.DetectedFormat::Jsonl
        | @input.DetectedFormat::Ndjson =>
          Some(@parser.ParserMode::StreamingEvent)
        @input.DetectedFormat::Markdown =>
          Some(@parser.ParserMode::BlockStreaming)
        @input.DetectedFormat::Html => Some(@parser.ParserMode::BlockStreaming)
        _ => parser_mode_for_route(route_decision.selected_route)
      }
    _ => parser_mode_for_route(route_decision.selected_route)
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
    same_mode_degradation: [],
    prepared_source: probe.prepared_source,
    probe_artifact: probe.probe_artifact,
  }
}

///|
fn canonical_route_for_format(
  format : @input.DetectedFormat,
  options : ConvertOptions,
) -> CanonicalRoute {
  if options.mode == ConvertMode::Stream {
    match format {
      @input.DetectedFormat::Markdown => return CanonicalRoute::BlockStreaming
      @input.DetectedFormat::Html => return CanonicalRoute::BlockStreaming
      @input.DetectedFormat::Docx => return CanonicalRoute::PackageSinglePass
      @input.DetectedFormat::Pptx => return CanonicalRoute::PackageSinglePass
      @input.DetectedFormat::Xlsx => return CanonicalRoute::PackageSinglePass
      @input.DetectedFormat::Epub => return CanonicalRoute::ContainerRecursive
      @input.DetectedFormat::Zip => return CanonicalRoute::ContainerRecursive
      @input.DetectedFormat::Pdf => return CanonicalRoute::PageSinglePass
      _ => return CanonicalRoute::StreamingEvent
    }
  }
  match format {
    @input.DetectedFormat::Txt
    | @input.DetectedFormat::Csv
    | @input.DetectedFormat::Tsv
    | @input.DetectedFormat::Jsonl
    | @input.DetectedFormat::Ndjson => CanonicalRoute::StreamingEvent
    @input.DetectedFormat::Markdown => CanonicalRoute::DomAstModel
    @input.DetectedFormat::Json => CanonicalRoute::DomAstModel
    @input.DetectedFormat::Yaml => CanonicalRoute::DomAstModel
    @input.DetectedFormat::Xml => CanonicalRoute::DomAstModel
    @input.DetectedFormat::Html => CanonicalRoute::DomAstModel
    @input.DetectedFormat::Docx => CanonicalRoute::PackageSinglePass
    @input.DetectedFormat::Pptx => CanonicalRoute::PackageSinglePass
    @input.DetectedFormat::Xlsx => CanonicalRoute::PackageSinglePass
    @input.DetectedFormat::Epub => CanonicalRoute::PackageSinglePass
    @input.DetectedFormat::Pdf =>
      if options.mode == ConvertMode::Accurate ||
        options.ocr_options.intent == @parser.OcrIntent::Explicit {
        CanonicalRoute::LayoutTwoStage
      } else {
        CanonicalRoute::PageSinglePass
      }
    @input.DetectedFormat::Zip => CanonicalRoute::ContainerRecursive
    _ => CanonicalRoute::DomAstModel
  }
}

///|
fn canonical_route_name(route : CanonicalRoute) -> String {
  match route {
    CanonicalRoute::StreamingEvent => "streaming_event"
    CanonicalRoute::BlockStreaming => "block_streaming"
    CanonicalRoute::PackageSinglePass => "package_single_pass"
    CanonicalRoute::PageSinglePass => "page_single_pass"
    CanonicalRoute::DomAstModel => "dom_ast_model"
    CanonicalRoute::LayoutTwoStage => "layout_two_stage"
    CanonicalRoute::ContainerRecursive => "container_recursive"
  }
}

///|
fn route_reason_for_format(
  format : @input.DetectedFormat,
  options : ConvertOptions,
  route : CanonicalRoute,
) -> String {
  if options.mode == ConvertMode::Stream {
    return "explicit_stream_mode"
  }
  @input.detected_format_name(format) +
  "_canonical_" +
  canonical_route_name(route)
}
