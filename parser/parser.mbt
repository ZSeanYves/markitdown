///|
pub(all) enum ParserMode {
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
pub(all) enum StreamingGranularity {
  Byte
  Line
  Record
  Row
  JsonStructure
  NotebookCellOutputGroup
  XmlStructure
  YamlStructure
  HtmlTokenStructure
  MarkdownBlock
  DocxBlock
  PptxSlide
  XlsxSheet
  XlsxRow
  ArchiveEntry
  EpubSpineItem
  Block
  Page
  Slide
  Sheet
  Chapter
  Message
  None
} derive(Eq)

///|
pub struct ParserCapability {
  parser_mode : ParserMode
  supports_streaming : Bool
  streaming_granularity : StreamingGranularity
  requires_random_access : Bool
  source_single_pass_preferred : Bool
  source_single_pass_strict : Bool
  supports_events : Bool
  supports_blocks : Bool
  supports_document_ir : Bool
  produces_text : Bool
  produces_structure : Bool
  produces_layout : Bool
  produces_tables : Bool
  produces_images : Bool
  produces_metadata : Bool
  produces_source_map : Bool
  can_be_lossless : Bool
  can_preserve_order : Bool
  can_preserve_styles : Bool
}

///|
pub struct ParseContext {
  detected_format : @input.DetectedFormat
  requested_mode : ParserMode?
  fidelity_mode : @product.FidelityMode
  output_mode : @product.OutputMode
  execution_profile : @product.ExecutionProfile
  lowering_profile : @product.LoweringProfile
  render_profile : @product.RenderProfile
  accurate_features : @product.AccurateFeatureProfile
  ocr_options : OcrOptions
  pdf_native_runtime_policy : PdfNativeRuntimePolicy
  pdf_header_footer_filter_policy : PdfHeaderFooterFilterPolicy
  pdf_table_reconstruction_policy : PdfTableReconstructionPolicy
  max_rows : Int?
  max_cols : Int?
  max_cells : Int?
  max_line_chars : Int?
  debug : Bool
}

///|
pub(all) enum OcrIntent {
  Disabled
  Auto
  Explicit
} derive(Eq)

///|
pub(all) enum PdfNativeRuntimePolicy {
  DisableTextRestore
  EnableTextRestore
} derive(Eq)

///|
pub(all) enum PdfHeaderFooterFilterPolicy {
  Disabled
  InternalHighConfidenceOnly
} derive(Eq)

///|
pub(all) enum PdfTableReconstructionPolicy {
  Disabled
  InternalSimpleRowsOnly
} derive(Eq)

///|
pub struct OcrOptions {
  intent : OcrIntent
  language : String?
}

///|
pub struct ParseResult {
  parser_name : String
  mode : ParserMode
  capabilities : ParserCapability
  event_stream : Array[@core.CoreEvent]?
  block_stream : Array[@core.CoreBlock]?
  document : @core.DocumentIR?
  metadata : @core.DocumentMetadata
  assets : Array[@core.AssetRef]
  source_map : @core.SourceMap?
  assembly : @core.DocumentAssembly?
  diagnostics : @core.Diagnostics
}

///|
pub struct Parser {
  name : String
  mode : ParserMode
  capability : ParserCapability
  parse : (@input.InputSource, ParseContext) -> Result[ParseResult, String]
}

///|
pub struct ParserRegistry {
  parsers : Map[String, Parser]
}

///|
pub fn default_parser_capability() -> ParserCapability {
  make_parser_capability(
    ParserMode::DomAstModel,
    false,
    StreamingGranularity::None,
    true,
    false,
    false,
    false,
    false,
    true,
    true,
    false,
    false,
    false,
    true,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
pub fn parser_capability(
  supports_events : Bool,
  supports_blocks : Bool,
  supports_document_ir : Bool,
) -> ParserCapability {
  let parser_mode = if supports_events {
    ParserMode::StreamingEvent
  } else if supports_blocks {
    ParserMode::BlockStreaming
  } else {
    ParserMode::DomAstModel
  }
  let granularity = if supports_events {
    StreamingGranularity::Record
  } else if supports_blocks {
    StreamingGranularity::Block
  } else {
    StreamingGranularity::None
  }
  make_parser_capability(
    parser_mode,
    supports_events || supports_blocks,
    granularity,
    !supports_document_ir,
    supports_events || supports_blocks,
    false,
    supports_events,
    supports_blocks,
    supports_document_ir,
    supports_document_ir || supports_events || supports_blocks,
    false,
    supports_events || supports_blocks,
    false,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
    supports_document_ir,
  )
}

///|
pub fn make_parser_capability(
  parser_mode : ParserMode,
  supports_streaming : Bool,
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  source_single_pass_strict : Bool,
  supports_events : Bool,
  supports_blocks : Bool,
  supports_document_ir : Bool,
  produces_text : Bool,
  produces_structure : Bool,
  produces_layout : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  {
    parser_mode,
    supports_streaming,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    source_single_pass_strict,
    supports_events,
    supports_blocks,
    supports_document_ir,
    produces_text,
    produces_structure,
    produces_layout,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  }
}

///|
pub fn dom_ast_parser_capability(
  streaming_granularity : StreamingGranularity,
  supports_streaming : Bool,
  supports_events : Bool,
  supports_blocks : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::DomAstModel,
    supports_streaming,
    streaming_granularity,
    false,
    true,
    false,
    supports_events,
    supports_blocks,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
pub fn block_stream_parser_capability(
  streaming_granularity : StreamingGranularity,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::BlockStreaming,
    true,
    streaming_granularity,
    false,
    true,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
pub fn streaming_event_parser_capability(
  streaming_granularity : StreamingGranularity,
  supports_document_ir : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::StreamingEvent,
    true,
    streaming_granularity,
    false,
    true,
    false,
    true,
    false,
    supports_document_ir,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
pub fn package_with_block_route_parser_capability(
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  source_single_pass_strict : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::PackageSinglePass,
    true,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    source_single_pass_strict,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
pub fn container_recursive_parser_capability(
  streaming_granularity : StreamingGranularity,
  requires_random_access : Bool,
  source_single_pass_preferred : Bool,
  produces_tables : Bool,
  produces_images : Bool,
  produces_metadata : Bool,
  produces_source_map : Bool,
  can_be_lossless : Bool,
  can_preserve_order : Bool,
  can_preserve_styles : Bool,
) -> ParserCapability {
  make_parser_capability(
    ParserMode::ContainerRecursive,
    true,
    streaming_granularity,
    requires_random_access,
    source_single_pass_preferred,
    false,
    false,
    true,
    true,
    true,
    true,
    false,
    produces_tables,
    produces_images,
    produces_metadata,
    produces_source_map,
    can_be_lossless,
    can_preserve_order,
    can_preserve_styles,
  )
}

///|
pub fn make_parser(
  name : String,
  mode : ParserMode,
  capability : ParserCapability,
  parse : (@input.InputSource, ParseContext) -> Result[ParseResult, String],
) -> Parser {
  { name, mode, capability, parse }
}

///|
pub fn new_parse_context(
  detected_format : @input.DetectedFormat,
) -> ParseContext {
  {
    detected_format,
    requested_mode: None,
    fidelity_mode: @product.FidelityMode::Balanced,
    output_mode: @product.OutputMode::Markdown,
    execution_profile: @product.ExecutionProfile::Standard,
    lowering_profile: @product.LoweringProfile::Canonical,
    render_profile: @product.RenderProfile::DefaultMarkdown,
    accurate_features: @product.empty_accurate_feature_profile(),
    ocr_options: default_ocr_options(),
    pdf_native_runtime_policy: default_pdf_native_runtime_policy(),
    pdf_header_footer_filter_policy: default_pdf_header_footer_filter_policy(),
    pdf_table_reconstruction_policy: default_pdf_table_reconstruction_policy(),
    max_rows: None,
    max_cols: None,
    max_cells: None,
    max_line_chars: None,
    debug: false,
  }
}

///|
pub fn default_ocr_options() -> OcrOptions {
  { intent: OcrIntent::Auto, language: None }
}

///|
pub fn default_pdf_native_runtime_policy() -> PdfNativeRuntimePolicy {
  PdfNativeRuntimePolicy::EnableTextRestore
}

///|
pub fn default_pdf_header_footer_filter_policy() -> PdfHeaderFooterFilterPolicy {
  PdfHeaderFooterFilterPolicy::Disabled
}

///|
pub fn default_pdf_table_reconstruction_policy() -> PdfTableReconstructionPolicy {
  PdfTableReconstructionPolicy::Disabled
}

///|
pub fn disabled_ocr_options(language? : String? = None) -> OcrOptions {
  { intent: OcrIntent::Disabled, language }
}

///|
pub fn explicit_ocr_options(language? : String? = None) -> OcrOptions {
  { intent: OcrIntent::Explicit, language }
}

///|
pub fn parse_context_with_ocr_options(
  context : ParseContext,
  ocr_options : OcrOptions,
) -> ParseContext {
  { ..context, ocr_options, }
}

///|
pub fn parse_context_with_product_modes(
  context : ParseContext,
  fidelity_mode : @product.FidelityMode,
  output_mode : @product.OutputMode,
) -> ParseContext {
  let accurate_features = if fidelity_mode == @product.FidelityMode::Accurate {
    @product.make_accurate_feature_profile(
      @product.accurate_features_for_detected_format(context.detected_format).copy(),
    )
  } else {
    @product.empty_accurate_feature_profile()
  }
  {
    ..context,
    fidelity_mode,
    output_mode,
    lowering_profile: if fidelity_mode == @product.FidelityMode::Accurate {
      @product.LoweringProfile::AccurateSemantic
    } else {
      context.lowering_profile
    },
    accurate_features,
  }
}

///|
pub fn parse_context_with_execution_profiles(
  context : ParseContext,
  execution_profile : @product.ExecutionProfile,
  lowering_profile : @product.LoweringProfile,
  render_profile : @product.RenderProfile,
  accurate_features : @product.AccurateFeatureProfile,
) -> ParseContext {
  {
    ..context,
    execution_profile,
    lowering_profile,
    render_profile,
    accurate_features,
  }
}

///|
pub fn parse_context_with_pdf_native_runtime_policy(
  context : ParseContext,
  pdf_native_runtime_policy : PdfNativeRuntimePolicy,
) -> ParseContext {
  { ..context, pdf_native_runtime_policy, }
}

///|
pub fn parse_context_with_pdf_header_footer_filter_policy(
  context : ParseContext,
  pdf_header_footer_filter_policy : PdfHeaderFooterFilterPolicy,
) -> ParseContext {
  { ..context, pdf_header_footer_filter_policy, }
}

///|
pub fn parse_context_with_pdf_table_reconstruction_policy(
  context : ParseContext,
  pdf_table_reconstruction_policy : PdfTableReconstructionPolicy,
) -> ParseContext {
  { ..context, pdf_table_reconstruction_policy, }
}

///|
pub fn parse_context_with_limits(
  context : ParseContext,
  requested_mode : ParserMode?,
  max_rows : Int?,
  max_cols : Int?,
  max_cells : Int?,
  max_line_chars : Int?,
  debug : Bool,
) -> ParseContext {
  {
    ..context,
    requested_mode,
    max_rows,
    max_cols,
    max_cells,
    max_line_chars,
    debug,
  }
}

///|
pub fn ocr_intent_name(intent : OcrIntent) -> String {
  match intent {
    OcrIntent::Disabled => "disabled"
    OcrIntent::Auto => "auto"
    OcrIntent::Explicit => "explicit"
  }
}

///|
pub fn pdf_native_runtime_policy_name(
  policy : PdfNativeRuntimePolicy,
) -> String {
  match policy {
    PdfNativeRuntimePolicy::DisableTextRestore => "disable_text_restore"
    PdfNativeRuntimePolicy::EnableTextRestore => "enable_text_restore"
  }
}

///|
pub fn pdf_header_footer_filter_policy_name(
  policy : PdfHeaderFooterFilterPolicy,
) -> String {
  match policy {
    PdfHeaderFooterFilterPolicy::Disabled => "disabled"
    PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly =>
      "internal_high_confidence_only"
  }
}

///|
pub fn pdf_table_reconstruction_policy_name(
  policy : PdfTableReconstructionPolicy,
) -> String {
  match policy {
    PdfTableReconstructionPolicy::Disabled => "disabled"
    PdfTableReconstructionPolicy::InternalSimpleRowsOnly =>
      "internal_simple_rows_only"
  }
}

///|
pub fn empty_registry() -> ParserRegistry {
  { parsers: Map([]) }
}

///|
pub fn registry_key(format : @input.DetectedFormat) -> String {
  @input.detected_format_name(format)
}

///|
pub fn registry_register(
  registry : ParserRegistry,
  format : @input.DetectedFormat,
  parser : Parser,
) -> Unit {
  registry.parsers.set(registry_key(format), parser)
}

///|
pub fn registry_lookup(
  registry : ParserRegistry,
  format : @input.DetectedFormat,
) -> Parser? {
  registry.parsers.get(registry_key(format))
}

///|
pub fn registry_parse(
  registry : ParserRegistry,
  source : @input.InputSource,
  context : ParseContext,
) -> Result[ParseResult, String] {
  match registry_lookup(registry, context.detected_format) {
    Some(parser) => (parser.parse)(source, context)
    None =>
      Err(
        "no parser registered for format: " +
        @input.detected_format_name(context.detected_format),
      )
  }
}

///|
pub fn mode_name(mode : ParserMode) -> String {
  match mode {
    ParserMode::StreamingEvent => "streaming_event"
    ParserMode::BlockStreaming => "block_streaming"
    ParserMode::PackageSinglePass => "package_single_pass"
    ParserMode::PageSinglePass => "page_single_pass"
    ParserMode::DomAstModel => "dom_ast_model"
    ParserMode::LayoutTwoStage => "layout_two_stage"
    ParserMode::MediaPipeline => "media_pipeline"
    ParserMode::ContainerRecursive => "container_recursive"
  }
}

///|
pub fn streaming_granularity_name(granularity : StreamingGranularity) -> String {
  match granularity {
    StreamingGranularity::Byte => "byte"
    StreamingGranularity::Line => "line"
    StreamingGranularity::Record => "record"
    StreamingGranularity::Row => "row"
    StreamingGranularity::JsonStructure => "json_structure"
    StreamingGranularity::NotebookCellOutputGroup =>
      "notebook_cell_output_group"
    StreamingGranularity::XmlStructure => "xml_structure"
    StreamingGranularity::YamlStructure => "yaml_structure"
    StreamingGranularity::HtmlTokenStructure => "html_token_structure"
    StreamingGranularity::MarkdownBlock => "markdown_block"
    StreamingGranularity::DocxBlock => "docx_block"
    StreamingGranularity::PptxSlide => "pptx_slide"
    StreamingGranularity::XlsxSheet => "xlsx_sheet"
    StreamingGranularity::XlsxRow => "xlsx_row"
    StreamingGranularity::ArchiveEntry => "archive_entry"
    StreamingGranularity::EpubSpineItem => "epub_spine_item"
    StreamingGranularity::Block => "block"
    StreamingGranularity::Page => "page"
    StreamingGranularity::Slide => "slide"
    StreamingGranularity::Sheet => "sheet"
    StreamingGranularity::Chapter => "chapter"
    StreamingGranularity::Message => "message"
    StreamingGranularity::None => "none"
  }
}

///|
pub fn parse_result_with_events(
  parser_name : String,
  mode : ParserMode,
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(true, false, false),
    event_stream: Some(events),
    block_stream: None,
    document: None,
    metadata: Map([]),
    assets: [],
    source_map: None,
    assembly: None,
    diagnostics,
  }
}

///|
pub fn parse_result_with_events_capability(
  parser_name : String,
  mode : ParserMode,
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
  metadata? : @core.DocumentMetadata = Map([]),
  assets? : Array[@core.AssetRef] = [],
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "event_stream")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: Some(events),
    block_stream: None,
    document: None,
    metadata,
    assets,
    source_map,
    assembly,
    diagnostics,
  }
}

///|
pub fn parse_result_with_blocks(
  parser_name : String,
  mode : ParserMode,
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(false, true, false),
    event_stream: None,
    block_stream: Some(blocks),
    document: None,
    metadata: Map([]),
    assets: [],
    source_map: None,
    assembly: None,
    diagnostics,
  }
}

///|
pub fn parse_result_with_blocks_capability(
  parser_name : String,
  mode : ParserMode,
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
  metadata? : @core.DocumentMetadata = Map([]),
  assets? : Array[@core.AssetRef] = [],
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "block_stream")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: None,
    block_stream: Some(blocks),
    document: None,
    metadata,
    assets,
    source_map,
    assembly,
    diagnostics,
  }
}

///|
pub fn parse_result_with_document(
  parser_name : String,
  mode : ParserMode,
  document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
) -> ParseResult {
  {
    parser_name,
    mode,
    capabilities: parser_capability(false, false, true),
    event_stream: None,
    block_stream: None,
    document: Some(document),
    metadata: document.metadata,
    assets: document.assets,
    source_map: document.source_map,
    assembly: document.assembly,
    diagnostics,
  }
}

///|
pub fn parse_result_with_document_capability(
  parser_name : String,
  mode : ParserMode,
  document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
  capability : ParserCapability,
) -> ParseResult {
  if diagnostics.metrics.get("builder_input_kind") == None {
    diagnostics.metrics.set("builder_input_kind", "document")
  }
  {
    parser_name,
    mode,
    capabilities: capability,
    event_stream: None,
    block_stream: None,
    document: Some(document),
    metadata: document.metadata,
    assets: document.assets,
    source_map: document.source_map,
    assembly: document.assembly,
    diagnostics,
  }
}
