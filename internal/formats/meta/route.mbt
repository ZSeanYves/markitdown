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
    @product.ConvertMode::Balanced => policy.balanced
    @product.ConvertMode::Accurate => policy.accurate
    @product.ConvertMode::Stream => policy.stream
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
    @input.DetectedFormat::Txt =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Line,
        "event_stream",
        "txt canonical line-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Csv =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Row,
        "event_stream",
        "csv canonical row-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Tsv =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Row,
        "event_stream",
        "tsv canonical row-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Srt =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Record,
        "event_stream",
        "srt canonical record-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Vtt =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Record,
        "event_stream",
        "vtt canonical record-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Json =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::JsonStructure,
        "document",
        "json dom-ast with structure-event large route",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
        over_limit_route=Some(FormatRoute::StreamingEvent),
        large_route_parser_mode=Some(@parser.ParserMode::StreamingEvent),
        large_route_granularity=Some(
          @parser.StreamingGranularity::JsonStructure,
        ),
        large_route_ir_input_kind=Some("event_stream"),
      )
    @input.DetectedFormat::Jsonl =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Record,
        "event_stream",
        "jsonl canonical record-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Ndjson =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::StreamingEvent,
        true,
        @parser.ParserMode::StreamingEvent,
        @parser.StreamingGranularity::Record,
        "event_stream",
        "ndjson canonical record-event",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
      )
    @input.DetectedFormat::Ipynb =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::NotebookCellOutputGroup,
        "document",
        "ipynb dom-ast with notebook-cell-output-group large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(
          @parser.StreamingGranularity::NotebookCellOutputGroup,
        ),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Xml =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::XmlStructure,
        "document",
        "xml dom-ast with structure-event large route",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
        over_limit_route=Some(FormatRoute::StreamingEvent),
        large_route_parser_mode=Some(@parser.ParserMode::StreamingEvent),
        large_route_granularity=Some(@parser.StreamingGranularity::XmlStructure),
        large_route_ir_input_kind=Some("event_stream"),
      )
    @input.DetectedFormat::Yaml =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::YamlStructure,
        "document",
        "yaml dom-ast with structure-event large route",
        explicit_stream_route=Some(FormatRoute::StreamingEvent),
        over_limit_route=Some(FormatRoute::StreamingEvent),
        large_route_parser_mode=Some(@parser.ParserMode::StreamingEvent),
        large_route_granularity=Some(
          @parser.StreamingGranularity::YamlStructure,
        ),
        large_route_ir_input_kind=Some("event_stream"),
      )
    @input.DetectedFormat::Toml =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        false,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::None,
        "document",
        "toml dom-ast canonical only",
      )
    @input.DetectedFormat::Html =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::HtmlTokenStructure,
        "document",
        "html dom-ast hybrid readability with token-structure large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(
          @parser.StreamingGranularity::HtmlTokenStructure,
        ),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Markdown =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        true,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::MarkdownBlock,
        "document",
        "markdown dom-ast with markdown-block large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(
          @parser.StreamingGranularity::MarkdownBlock,
        ),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Tex =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        false,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::None,
        "document",
        "tex dom-ast typed-lowering canonical only",
      )
    @input.DetectedFormat::Rst =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        false,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::None,
        "document",
        "rst dom-ast typed-lowering canonical only",
      )
    @input.DetectedFormat::Asciidoc =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::DomAstModel,
        false,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::None,
        "document",
        "asciidoc dom-ast typed-lowering canonical only",
      )
    @input.DetectedFormat::Eml =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::BlockStreaming,
        true,
        @parser.ParserMode::BlockStreaming,
        @parser.StreamingGranularity::Message,
        "block_stream",
        "eml canonical mime-part block stream",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
      )
    @input.DetectedFormat::Zip =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::ContainerRecursive,
        true,
        @parser.ParserMode::ContainerRecursive,
        @parser.StreamingGranularity::ArchiveEntry,
        "block_stream",
        "zip canonical container-recursive",
        explicit_stream_route=Some(FormatRoute::ContainerRecursive),
      )
    @input.DetectedFormat::Epub =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        true,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::EpubSpineItem,
        "block_stream",
        "epub package-single-pass with explicit container-recursive stream route",
        explicit_stream_route=Some(FormatRoute::ContainerRecursive),
        large_route_parser_mode=Some(@parser.ParserMode::ContainerRecursive),
        large_route_granularity=Some(@parser.StreamingGranularity::ArchiveEntry),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Odt =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        true,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::Block,
        "document",
        "odt package-single-pass with block large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(@parser.StreamingGranularity::Block),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Ods =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        true,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::Row,
        "document",
        "ods package-single-pass with row block large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(@parser.StreamingGranularity::Row),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Odp =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        true,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::Slide,
        "document",
        "odp package-single-pass with slide block large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(@parser.StreamingGranularity::Slide),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Pdf =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PageSinglePass,
        false,
        @parser.ParserMode::PageSinglePass,
        @parser.StreamingGranularity::Page,
        "document",
        "pdf page-single-pass with explicit accurate/ocr layout route",
        large_route_parser_mode=Some(@parser.ParserMode::LayoutTwoStage),
      )
    @input.DetectedFormat::Docx =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        false,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::DocxBlock,
        "document",
        "docx package-single-pass canonical",
      )
    @input.DetectedFormat::Pptx =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        false,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::PptxSlide,
        "document",
        "pptx package-single-pass canonical",
      )
    @input.DetectedFormat::Xlsx =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::PackageSinglePass,
        true,
        @parser.ParserMode::PackageSinglePass,
        @parser.StreamingGranularity::XlsxRow,
        "document",
        "xlsx package-single-pass with row block large route",
        explicit_stream_route=Some(FormatRoute::BlockStreaming),
        over_limit_route=Some(FormatRoute::BlockStreaming),
        large_route_parser_mode=Some(@parser.ParserMode::BlockStreaming),
        large_route_granularity=Some(@parser.StreamingGranularity::XlsxRow),
        large_route_ir_input_kind=Some("block_stream"),
      )
    @input.DetectedFormat::Audio(_) =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::MediaPipeline,
        false,
        @parser.ParserMode::MediaPipeline,
        @parser.StreamingGranularity::None,
        "document",
        @input.detected_format_name(format) + " canonical media pipeline",
      )
    @input.DetectedFormat::Image(_) =>
      make_format_route_profile(
        format,
        true,
        FormatRoute::LayoutTwoStage,
        false,
        @parser.ParserMode::LayoutTwoStage,
        @parser.StreamingGranularity::Page,
        "document",
        "image ocr explicit layout route",
      )
    @input.DetectedFormat::Unknown =>
      make_format_route_profile(
        format,
        false,
        FormatRoute::DomAstModel,
        false,
        @parser.ParserMode::DomAstModel,
        @parser.StreamingGranularity::None,
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
    FormatRoute::StreamingEvent => @product.RenderProfile::DefaultMarkdown
    FormatRoute::BlockStreaming =>
      match format {
        @input.DetectedFormat::Csv
        | @input.DetectedFormat::Tsv
        | @input.DetectedFormat::Xlsx
        | @input.DetectedFormat::Ods =>
          @product.RenderProfile::SparseTableMarkdown
        _ => @product.RenderProfile::SectionFlushMarkdown
      }
    FormatRoute::ContainerRecursive =>
      match format {
        @input.DetectedFormat::Zip => @product.RenderProfile::DefaultMarkdown
        _ => @product.RenderProfile::AssetManifestFirst
      }
    FormatRoute::PageSinglePass | FormatRoute::LayoutTwoStage =>
      @product.RenderProfile::PageWindowMarkdown
    _ => @product.RenderProfile::DefaultMarkdown
  }
}

///|
fn soft_limit_thresholds_for_format(
  format : @input.DetectedFormat,
) -> Array[(@product.ProbeSignalKind, Int)] {
  match format {
    @input.DetectedFormat::Markdown => []
    @input.DetectedFormat::Json => []
    @input.DetectedFormat::Yaml => []
    @input.DetectedFormat::Ipynb =>
      [
        (@product.ProbeSignalKind::BlockCount, 800),
        (@product.ProbeSignalKind::OutputCount, 5000),
        (@product.ProbeSignalKind::CharCount, 200000),
      ]
    @input.DetectedFormat::Xml => []
    @input.DetectedFormat::Html => []
    @input.DetectedFormat::Xlsx => []
    @input.DetectedFormat::Odt =>
      [
        (@product.ProbeSignalKind::BlockCount, 4),
        (@product.ProbeSignalKind::NoteCount, 1),
        (@product.ProbeSignalKind::CommentCount, 1),
      ]
    @input.DetectedFormat::Ods =>
      [
        (@product.ProbeSignalKind::RowCount, 2),
        (@product.ProbeSignalKind::CellEstimate, 20),
        (@product.ProbeSignalKind::CoveredCellCount, 1),
      ]
    @input.DetectedFormat::Odp =>
      [
        (@product.ProbeSignalKind::SlideCount, 2),
        (@product.ProbeSignalKind::BlockCount, 4),
        (@product.ProbeSignalKind::NoteCount, 1),
      ]
    _ => []
  }
}

///|
fn hard_limit_thresholds_for_format(
  format : @input.DetectedFormat,
) -> Array[(@product.ProbeSignalKind, Int)] {
  match format {
    @input.DetectedFormat::Markdown =>
      [
        (@product.ProbeSignalKind::BlockCount, 0),
        (@product.ProbeSignalKind::CharCount, 0),
      ]
    @input.DetectedFormat::Json =>
      [
        (@product.ProbeSignalKind::NodeCount, 0),
        (@product.ProbeSignalKind::MaxDepth, 0),
      ]
    @input.DetectedFormat::Yaml =>
      [
        (@product.ProbeSignalKind::NodeCount, 0),
        (@product.ProbeSignalKind::MaxDepth, 0),
      ]
    @input.DetectedFormat::Ipynb =>
      [
        (@product.ProbeSignalKind::BlockCount, 2000),
        (@product.ProbeSignalKind::OutputCount, 10000),
        (@product.ProbeSignalKind::AttachmentCount, 1000),
      ]
    @input.DetectedFormat::Xml =>
      [
        (@product.ProbeSignalKind::NodeCount, 0),
        (@product.ProbeSignalKind::MaxDepth, 0),
        (@product.ProbeSignalKind::CharCount, 0),
      ]
    @input.DetectedFormat::Html =>
      [
        (@product.ProbeSignalKind::BlockCount, 0),
        (@product.ProbeSignalKind::MaxDepth, 0),
        (@product.ProbeSignalKind::CharCount, 0),
      ]
    @input.DetectedFormat::Xlsx =>
      [
        (@product.ProbeSignalKind::RowCount, 0),
        (@product.ProbeSignalKind::CellEstimate, 0),
      ]
    @input.DetectedFormat::Odt =>
      [
        (@product.ProbeSignalKind::BlockCount, 8),
        (@product.ProbeSignalKind::NoteCount, 4),
        (@product.ProbeSignalKind::CommentCount, 4),
      ]
    @input.DetectedFormat::Ods =>
      [
        (@product.ProbeSignalKind::RowCount, 4),
        (@product.ProbeSignalKind::CellEstimate, 40),
      ]
    @input.DetectedFormat::Odp =>
      [
        (@product.ProbeSignalKind::SlideCount, 4),
        (@product.ProbeSignalKind::BlockCount, 8),
      ]
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
    @input.DetectedFormat::Pdf =>
      route_spec_from_profile(
        FormatRoute::LayoutTwoStage,
        @parser.ParserMode::LayoutTwoStage,
        @parser.StreamingGranularity::Page,
        "document",
      )
    @input.DetectedFormat::Image(_) =>
      route_spec_from_profile(
        FormatRoute::LayoutTwoStage,
        @parser.ParserMode::LayoutTwoStage,
        @parser.StreamingGranularity::Page,
        "document",
      )
    _ => canonical
  }
  let stream_canonical = match explicit_stream {
    Some(spec) => spec
    None => canonical
  }
  let balanced = make_mode_strategy_policy(
    canonical,
    profile.explicit_stream_supported,
    @product.LoweringProfile::Canonical,
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
    @product.LoweringProfile::AccurateSemantic,
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
    @product.LoweringProfile::StreamCanonical,
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
    FormatRoute::StreamingEvent => @parser.ParserMode::StreamingEvent
    FormatRoute::BlockStreaming => @parser.ParserMode::BlockStreaming
    FormatRoute::PackageSinglePass => @parser.ParserMode::PackageSinglePass
    FormatRoute::PageSinglePass => @parser.ParserMode::PageSinglePass
    FormatRoute::DomAstModel => @parser.ParserMode::DomAstModel
    FormatRoute::LayoutTwoStage => @parser.ParserMode::LayoutTwoStage
    FormatRoute::MediaPipeline => @parser.ParserMode::MediaPipeline
    FormatRoute::ContainerRecursive => @parser.ParserMode::ContainerRecursive
  }
}

///|
pub fn route_name(route : FormatRoute) -> String {
  match route {
    FormatRoute::StreamingEvent => "streaming_event"
    FormatRoute::BlockStreaming => "block_streaming"
    FormatRoute::PackageSinglePass => "package_single_pass"
    FormatRoute::PageSinglePass => "page_single_pass"
    FormatRoute::DomAstModel => "dom_ast_model"
    FormatRoute::LayoutTwoStage => "layout_two_stage"
    FormatRoute::MediaPipeline => "media_pipeline"
    FormatRoute::ContainerRecursive => "container_recursive"
  }
}
