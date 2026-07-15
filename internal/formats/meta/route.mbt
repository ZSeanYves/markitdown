///|
/// Route family used by product strategy selection.
pub(all) enum FormatRoute {
  StreamingEvent
  BlockStreaming
  PackageSinglePass
  PageSinglePass
  DomAstModel
  LayoutTwoStage
  MediaPipeline
  ContainerRecursive
} derive(Eq)

///|
/// Concrete route description used by route contracts.
pub struct StrategyRouteSpec {
  route : FormatRoute
  parser_mode : @parser.ParserMode
  granularity : @parser.StreamingGranularity
  ir_input_kind : String
}

///|
fn make_strategy_route_spec(
  route : FormatRoute,
  parser_mode : @parser.ParserMode,
  granularity : @parser.StreamingGranularity,
  ir_input_kind : String,
) -> StrategyRouteSpec {
  { route, parser_mode, granularity, ir_input_kind }
}

///|
/// Per-mode route contract for one format, including large-route fallbacks.
pub struct ModeStrategyPolicy {
  canonical : StrategyRouteSpec
  explicit_stream_supported : Bool
  explicit_stream : StrategyRouteSpec?
  soft_limit_thresholds : Array[(@product.ProbeSignalKind, Int)]
  hard_limit_thresholds : Array[(@product.ProbeSignalKind, Int)]
  soft_limit_render_profile : @product.RenderProfile?
  hard_limit_route : StrategyRouteSpec?
  lowering_profile : @product.LoweringProfile
  render_profile : @product.RenderProfile
  accurate_features : Array[@product.AccurateFeature]
  current_state_label : String
}

///|
fn make_mode_strategy_policy(
  canonical : StrategyRouteSpec,
  explicit_stream_supported : Bool,
  lowering_profile : @product.LoweringProfile,
  render_profile : @product.RenderProfile,
  current_state_label : String,
  explicit_stream? : StrategyRouteSpec? = None,
  soft_limit_thresholds? : Array[(@product.ProbeSignalKind, Int)] = [],
  hard_limit_thresholds? : Array[(@product.ProbeSignalKind, Int)] = [],
  soft_limit_render_profile? : @product.RenderProfile? = None,
  hard_limit_route? : StrategyRouteSpec? = None,
  accurate_features? : Array[@product.AccurateFeature] = [],
) -> ModeStrategyPolicy {
  {
    canonical,
    explicit_stream_supported,
    explicit_stream,
    soft_limit_thresholds,
    hard_limit_thresholds,
    soft_limit_render_profile,
    hard_limit_route,
    lowering_profile,
    render_profile,
    accurate_features,
    current_state_label,
  }
}

///|
/// Full route contract for one detected format across balanced, accurate, and
/// stream modes.
pub struct FormatStrategyPolicy {
  format : @input.DetectedFormat
  cli_supported : Bool
  balanced : ModeStrategyPolicy
  accurate : ModeStrategyPolicy
  stream : ModeStrategyPolicy
}

///|
fn mode_strategy_for(
  policy : FormatStrategyPolicy,
  mode : @product.ConvertMode,
) -> ModeStrategyPolicy {
  match mode {
    Balanced => policy.balanced
    Accurate => policy.accurate
    Stream => policy.stream
  }
}

///|
/// Stable, inspectable route summary for one format.
pub struct FormatRouteProfile {
  format : @input.DetectedFormat
  cli_supported : Bool
  canonical_route : FormatRoute
  explicit_stream_supported : Bool
  explicit_stream_route : FormatRoute?
  over_limit_route : FormatRoute?
  canonical_parser_mode : @parser.ParserMode
  capability_granularity : @parser.StreamingGranularity
  large_route_parser_mode : @parser.ParserMode?
  large_route_granularity : @parser.StreamingGranularity?
  canonical_ir_input_kind : String
  large_route_ir_input_kind : String?
  current_state_label : String
}

///|
fn make_format_route_profile(
  format : @input.DetectedFormat,
  cli_supported : Bool,
  canonical_route : FormatRoute,
  explicit_stream_supported : Bool,
  canonical_parser_mode : @parser.ParserMode,
  capability_granularity : @parser.StreamingGranularity,
  canonical_ir_input_kind : String,
  current_state_label : String,
  explicit_stream_route? : FormatRoute? = None,
  over_limit_route? : FormatRoute? = None,
  large_route_parser_mode? : @parser.ParserMode? = None,
  large_route_granularity? : @parser.StreamingGranularity? = None,
  large_route_ir_input_kind? : String? = None,
) -> FormatRouteProfile {
  {
    format,
    cli_supported,
    canonical_route,
    explicit_stream_supported,
    explicit_stream_route,
    over_limit_route,
    canonical_parser_mode,
    capability_granularity,
    large_route_parser_mode,
    large_route_granularity,
    canonical_ir_input_kind,
    large_route_ir_input_kind,
    current_state_label,
  }
}

///|
/// Return a stable public route profile for the detected format.
pub fn format_route_profile(
  format : @input.DetectedFormat,
) -> FormatRouteProfile {
  match format {
    Txt =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Line,
        "event_stream",
        "txt canonical line-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Csv =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Row,
        "event_stream",
        "csv canonical row-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Tsv =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Row,
        "event_stream",
        "tsv canonical row-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Srt =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Record,
        "event_stream",
        "srt canonical record-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Vtt =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Record,
        "event_stream",
        "vtt canonical record-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Json =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        JsonStructure,
        "document",
        "json dom-ast with structure-event large route",
        explicit_stream_route=Some(StreamingEvent),
        over_limit_route=Some(StreamingEvent),
        large_route_parser_mode=Some(StreamingEvent),
        large_route_granularity=Some(JsonStructure),
        large_route_ir_input_kind=Some("event_stream"),
      )
    Jsonl =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Record,
        "event_stream",
        "jsonl canonical record-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Ndjson =>
      make_format_route_profile(
        format,
        true,
        StreamingEvent,
        true,
        StreamingEvent,
        Record,
        "event_stream",
        "ndjson canonical record-event",
        explicit_stream_route=Some(StreamingEvent),
      )
    Ipynb =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        NotebookCellOutputGroup,
        "document",
        "ipynb dom-ast with notebook-cell-output-group large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(NotebookCellOutputGroup),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Xml =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        XmlStructure,
        "document",
        "xml dom-ast with structure-event large route",
        explicit_stream_route=Some(StreamingEvent),
        over_limit_route=Some(StreamingEvent),
        large_route_parser_mode=Some(StreamingEvent),
        large_route_granularity=Some(XmlStructure),
        large_route_ir_input_kind=Some("event_stream"),
      )
    Yaml =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        YamlStructure,
        "document",
        "yaml dom-ast with structure-event large route",
        explicit_stream_route=Some(StreamingEvent),
        over_limit_route=Some(StreamingEvent),
        large_route_parser_mode=Some(StreamingEvent),
        large_route_granularity=Some(YamlStructure),
        large_route_ir_input_kind=Some("event_stream"),
      )
    Toml =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        false,
        DomAstModel,
        None,
        "document",
        "toml dom-ast canonical only",
      )
    Html =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        HtmlTokenStructure,
        "document",
        "html dom-ast hybrid readability with token-structure large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(HtmlTokenStructure),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Markdown =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        true,
        DomAstModel,
        MarkdownBlock,
        "document",
        "markdown dom-ast with markdown-block large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(MarkdownBlock),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Tex =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        false,
        DomAstModel,
        None,
        "document",
        "tex dom-ast typed-lowering canonical only",
      )
    Rst =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        false,
        DomAstModel,
        None,
        "document",
        "rst dom-ast typed-lowering canonical only",
      )
    Asciidoc =>
      make_format_route_profile(
        format,
        true,
        DomAstModel,
        false,
        DomAstModel,
        None,
        "document",
        "asciidoc dom-ast typed-lowering canonical only",
      )
    Eml =>
      make_format_route_profile(
        format,
        true,
        BlockStreaming,
        true,
        BlockStreaming,
        Message,
        "block_stream",
        "eml canonical mime-part block stream",
        explicit_stream_route=Some(BlockStreaming),
      )
    Zip =>
      make_format_route_profile(
        format,
        true,
        ContainerRecursive,
        false,
        ContainerRecursive,
        ArchiveEntry,
        "block_stream",
        "zip balance-only container-recursive",
      )
    Epub =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        true,
        PackageSinglePass,
        EpubSpineItem,
        "block_stream",
        "epub package-single-pass with explicit container-recursive stream route",
        explicit_stream_route=Some(ContainerRecursive),
        large_route_parser_mode=Some(ContainerRecursive),
        large_route_granularity=Some(ArchiveEntry),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Odt =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        true,
        PackageSinglePass,
        Block,
        "document",
        "odt package-single-pass with block large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(Block),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Ods =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        true,
        PackageSinglePass,
        Row,
        "document",
        "ods package-single-pass with row block large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(Row),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Odp =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        true,
        PackageSinglePass,
        Slide,
        "document",
        "odp package-single-pass with slide block large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(Slide),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Pdf =>
      make_format_route_profile(
        format,
        true,
        PageSinglePass,
        false,
        PageSinglePass,
        Page,
        "document",
        "pdf page-single-pass with explicit accurate/ocr layout route",
        large_route_parser_mode=Some(LayoutTwoStage),
      )
    Docx =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        false,
        PackageSinglePass,
        DocxBlock,
        "document",
        "docx package-single-pass canonical",
      )
    Pptx =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        false,
        PackageSinglePass,
        PptxSlide,
        "document",
        "pptx package-single-pass canonical",
      )
    Xlsx =>
      make_format_route_profile(
        format,
        true,
        PackageSinglePass,
        true,
        PackageSinglePass,
        XlsxRow,
        "document",
        "xlsx package-single-pass with row block large route",
        explicit_stream_route=Some(BlockStreaming),
        over_limit_route=Some(BlockStreaming),
        large_route_parser_mode=Some(BlockStreaming),
        large_route_granularity=Some(XlsxRow),
        large_route_ir_input_kind=Some("block_stream"),
      )
    Audio(_) =>
      make_format_route_profile(
        format,
        true,
        MediaPipeline,
        false,
        MediaPipeline,
        None,
        "document",
        @input.detected_format_name(format) + " canonical media pipeline",
      )
    Image(_) =>
      make_format_route_profile(
        format,
        true,
        LayoutTwoStage,
        false,
        LayoutTwoStage,
        Page,
        "document",
        "image ocr explicit layout route",
      )
    Unknown =>
      make_format_route_profile(
        format,
        false,
        DomAstModel,
        false,
        DomAstModel,
        None,
        "document",
        "unknown fallback dom-ast",
      )
  }
}

///|
fn default_render_profile_for_route(
  format : @input.DetectedFormat,
  route : FormatRoute,
) -> @product.RenderProfile {
  match route {
    StreamingEvent => DefaultMarkdown
    BlockStreaming =>
      match format {
        Csv | Tsv | Xlsx | Ods => SparseTableMarkdown
        _ => SectionFlushMarkdown
      }
    ContainerRecursive =>
      match format {
        Zip => DefaultMarkdown
        _ => AssetManifestFirst
      }
    PageSinglePass | LayoutTwoStage => PageWindowMarkdown
    _ => DefaultMarkdown
  }
}

///|
fn soft_limit_thresholds_for_format(
  format : @input.DetectedFormat,
) -> Array[(@product.ProbeSignalKind, Int)] {
  match format {
    Markdown => []
    Json => []
    Yaml => []
    Ipynb => [(BlockCount, 800), (OutputCount, 5000), (CharCount, 200000)]
    Xml => []
    Html => []
    Xlsx => []
    Odt => [(BlockCount, 4), (NoteCount, 1), (CommentCount, 1)]
    Ods => [(RowCount, 2), (CellEstimate, 20), (CoveredCellCount, 1)]
    Odp => [(SlideCount, 2), (BlockCount, 4), (NoteCount, 1)]
    _ => []
  }
}

///|
fn hard_limit_thresholds_for_format(
  format : @input.DetectedFormat,
) -> Array[(@product.ProbeSignalKind, Int)] {
  match format {
    Markdown => [(BlockCount, 0), (CharCount, 0)]
    Json => [(NodeCount, 0), (MaxDepth, 0)]
    Yaml => [(NodeCount, 0), (MaxDepth, 0)]
    Ipynb => [(BlockCount, 2000), (OutputCount, 10000), (AttachmentCount, 1000)]
    Xml => [(NodeCount, 0), (MaxDepth, 0), (CharCount, 0)]
    Toml | Tex | Rst | Asciidoc => [(CharCount, 1_048_576)]
    Html => [(BlockCount, 0), (MaxDepth, 0), (CharCount, 0)]
    Xlsx => [(RowCount, 0), (CellEstimate, 0)]
    Odt => [(BlockCount, 8), (NoteCount, 4), (CommentCount, 4)]
    Ods => [(RowCount, 4), (CellEstimate, 40)]
    Odp => [(SlideCount, 4), (BlockCount, 8)]
    _ => []
  }
}

///|
fn accurate_features_for_format(
  format : @input.DetectedFormat,
) -> Array[@product.AccurateFeature] {
  @product.accurate_features_for_detected_format(format)
}

///|
fn route_spec_from_profile(
  route : FormatRoute,
  parser_mode : @parser.ParserMode,
  granularity : @parser.StreamingGranularity,
  ir_input_kind : String,
) -> StrategyRouteSpec {
  make_strategy_route_spec(route, parser_mode, granularity, ir_input_kind)
}

///|
/// Return the full route contract used internally for the detected format.
pub fn route_contract_for_format(
  format : @input.DetectedFormat,
) -> FormatStrategyPolicy {
  let profile = format_route_profile(format)
  let canonical = route_spec_from_profile(
    profile.canonical_route,
    profile.canonical_parser_mode,
    profile.capability_granularity,
    profile.canonical_ir_input_kind,
  )
  let large_parser_mode = match profile.large_route_parser_mode {
    Some(mode) => mode
    None =>
      parser_mode_for_route(
        profile.over_limit_route.unwrap_or(profile.canonical_route),
      )
  }
  let large_granularity = profile.large_route_granularity.unwrap_or(
    profile.capability_granularity,
  )
  let large_ir_input_kind = profile.large_route_ir_input_kind.unwrap_or(
    profile.canonical_ir_input_kind,
  )
  let explicit_stream = match profile.explicit_stream_route {
    Some(route) =>
      if route == profile.canonical_route {
        Some(canonical)
      } else {
        Some(
          route_spec_from_profile(
            route,
            match profile.large_route_parser_mode {
              Some(mode) => mode
              None => parser_mode_for_route(route)
            },
            large_granularity,
            large_ir_input_kind,
          ),
        )
      }
    None => None
  }
  let hard_limit_route = match profile.over_limit_route {
    Some(route) =>
      Some(
        route_spec_from_profile(
          route, large_parser_mode, large_granularity, large_ir_input_kind,
        ),
      )
    None => None
  }
  let accurate_canonical = match format {
    Pdf =>
      route_spec_from_profile(LayoutTwoStage, LayoutTwoStage, Page, "document")
    Image(_) =>
      route_spec_from_profile(LayoutTwoStage, LayoutTwoStage, Page, "document")
    _ => canonical
  }
  let stream_canonical = match explicit_stream {
    Some(spec) => spec
    None => canonical
  }
  let balanced = make_mode_strategy_policy(
    canonical,
    profile.explicit_stream_supported,
    Canonical,
    default_render_profile_for_route(format, canonical.route),
    profile.current_state_label,
    explicit_stream~,
    soft_limit_thresholds=soft_limit_thresholds_for_format(format),
    hard_limit_thresholds=hard_limit_thresholds_for_format(format),
    soft_limit_render_profile=match hard_limit_route {
      Some(route) => Some(default_render_profile_for_route(format, route.route))
      None => None
    },
    hard_limit_route~,
  )
  let accurate = make_mode_strategy_policy(
    accurate_canonical,
    false,
    AccurateSemantic,
    default_render_profile_for_route(format, accurate_canonical.route),
    profile.current_state_label + " accurate",
    soft_limit_thresholds=soft_limit_thresholds_for_format(format),
    hard_limit_thresholds=hard_limit_thresholds_for_format(format),
    hard_limit_route=match hard_limit_route {
      Some(route) if route.route != accurate_canonical.route => Some(route)
      _ => None
    },
    accurate_features=accurate_features_for_format(format),
  )
  let stream = make_mode_strategy_policy(
    stream_canonical,
    profile.explicit_stream_supported,
    StreamCanonical,
    default_render_profile_for_route(format, stream_canonical.route),
    profile.current_state_label + " stream",
    explicit_stream~,
    soft_limit_thresholds=soft_limit_thresholds_for_format(format),
    hard_limit_thresholds=hard_limit_thresholds_for_format(format),
    hard_limit_route~,
  )
  { format, cli_supported: profile.cli_supported, balanced, accurate, stream }
}

///|
/// Return the route contract for one format under a specific convert mode.
pub fn route_mode_contract_for_format(
  format : @input.DetectedFormat,
  mode : @product.ConvertMode,
) -> ModeStrategyPolicy {
  mode_strategy_for(route_contract_for_format(format), mode)
}

///|
pub fn explicit_stream_supported_for_format(
  format : @input.DetectedFormat,
) -> Bool {
  format_route_profile(format).explicit_stream_supported
}

///|
pub fn canonical_route_for_format(
  format : @input.DetectedFormat,
) -> FormatRoute {
  format_route_profile(format).canonical_route
}

///|
pub fn explicit_stream_route_for_format(
  format : @input.DetectedFormat,
) -> FormatRoute? {
  format_route_profile(format).explicit_stream_route
}

///|
pub fn over_limit_route_for_format(
  format : @input.DetectedFormat,
) -> FormatRoute? {
  format_route_profile(format).over_limit_route
}

///|
pub fn parser_mode_for_route(route : FormatRoute) -> @parser.ParserMode {
  match route {
    StreamingEvent => StreamingEvent
    BlockStreaming => BlockStreaming
    PackageSinglePass => PackageSinglePass
    PageSinglePass => PageSinglePass
    DomAstModel => DomAstModel
    LayoutTwoStage => LayoutTwoStage
    MediaPipeline => MediaPipeline
    ContainerRecursive => ContainerRecursive
  }
}

///|
pub fn route_name(route : FormatRoute) -> String {
  match route {
    StreamingEvent => "streaming_event"
    BlockStreaming => "block_streaming"
    PackageSinglePass => "package_single_pass"
    PageSinglePass => "page_single_pass"
    DomAstModel => "dom_ast_model"
    LayoutTwoStage => "layout_two_stage"
    MediaPipeline => "media_pipeline"
    ContainerRecursive => "container_recursive"
  }
}
