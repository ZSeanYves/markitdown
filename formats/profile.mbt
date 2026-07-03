///|
pub(all) enum FormatRoute {
  StreamingEvent
  BlockStreaming
  PackageSinglePass
  PageSinglePass
  DomAstModel
  LayoutTwoStage
  ContainerRecursive
} derive(Eq)

///|
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
pub fn explicit_stream_supported_for_format(
  format : @input.DetectedFormat,
) -> Bool {
  format_route_profile(format).explicit_stream_supported
}

///|
pub fn cli_supported_for_format(format : @input.DetectedFormat) -> Bool {
  format_route_profile(format).cli_supported
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
    FormatRoute::ContainerRecursive => "container_recursive"
  }
}
