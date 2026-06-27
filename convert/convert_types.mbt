///|
pub(all) enum ConvertMode {
  Fast
  Balanced
  Accurate
  Stream
  Rag
  Debug
} derive(Eq)

///|
fn product_convert_mode(mode : ConvertMode) -> @product.ConvertMode {
  match mode {
    ConvertMode::Fast => @product.ConvertMode::Fast
    ConvertMode::Balanced => @product.ConvertMode::Balanced
    ConvertMode::Accurate => @product.ConvertMode::Accurate
    ConvertMode::Stream => @product.ConvertMode::Stream
    ConvertMode::Rag => @product.ConvertMode::Rag
    ConvertMode::Debug => @product.ConvertMode::Debug
  }
}

///|
pub(all) enum OutputFormat {
  Markdown
  Json
  RagJson
  DebugJson
} derive(Eq)

///|
pub struct ResourceLimits {
  max_rows : Int
  max_cols : Int
  max_cells : Int
  max_line_chars : Int
}

///|
fn resource_limits_from_product(
  limits : @product.ResourceLimits,
) -> ResourceLimits {
  {
    max_rows: limits.max_rows,
    max_cols: limits.max_cols,
    max_cells: limits.max_cells,
    max_line_chars: limits.max_line_chars,
  }
}

///|
fn product_resource_limits(limits : ResourceLimits) -> @product.ResourceLimits {
  @product.make_resource_limits(
    limits.max_rows,
    limits.max_cols,
    limits.max_cells,
    max_line_chars=limits.max_line_chars,
  )
}

///|
pub(all) enum PdfCleanupMode {
  Disabled
  Conservative
} derive(Eq)

///|
fn product_pdf_cleanup_mode(mode : PdfCleanupMode) -> @product.PdfCleanupMode {
  match mode {
    PdfCleanupMode::Disabled => @product.PdfCleanupMode::Disabled
    PdfCleanupMode::Conservative => @product.PdfCleanupMode::Conservative
  }
}

///|
pub(all) enum PdfTableMode {
  Disabled
  Simple
} derive(Eq)

///|
fn product_pdf_table_mode(mode : PdfTableMode) -> @product.PdfTableMode {
  match mode {
    PdfTableMode::Disabled => @product.PdfTableMode::Disabled
    PdfTableMode::Simple => @product.PdfTableMode::Simple
  }
}

///|
pub struct ConvertOptions {
  mode : ConvertMode
  output_format : OutputFormat
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  limits : ResourceLimits
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
  rag_options : @rag.RagOptions
}

///|
pub struct RoutePlan {
  detected_format : @input.DetectedFormat
  selected_route : String
  route_reason : String
  route_probe_summary : String
  requested_parser_mode : @parser.ParserMode?
}

///|
pub fn make_route_plan(
  detected_format : @input.DetectedFormat,
  selected_route : String,
  route_reason : String,
  route_probe_summary : String,
  requested_parser_mode : @parser.ParserMode?,
) -> RoutePlan {
  {
    detected_format,
    selected_route,
    route_reason,
    route_probe_summary,
    requested_parser_mode,
  }
}

///|
pub struct ConvertProvenance {
  route_plan : RoutePlan
  effective_parser_mode : @parser.ParserMode
  parse_result_kind : String
  pipeline_output_kind : String
  render_input_kind : String
  route_fidelity_status : String
}

///|
pub fn make_convert_provenance(
  route_plan : RoutePlan,
  effective_parser_mode : @parser.ParserMode,
  parse_result_kind : String,
  pipeline_output_kind : String,
  render_input_kind : String,
  route_fidelity_status : String,
) -> ConvertProvenance {
  {
    route_plan,
    effective_parser_mode,
    parse_result_kind,
    pipeline_output_kind,
    render_input_kind,
    route_fidelity_status,
  }
}

///|
pub struct ConvertExecution {
  result : ConvertResult
  provenance : ConvertProvenance
}

///|
pub fn make_convert_execution(
  result : ConvertResult,
  provenance : ConvertProvenance,
) -> ConvertExecution {
  { result, provenance }
}

///|
fn product_options_from_convert_options(
  options : ConvertOptions,
) -> @product.ProductOptions {
  @product.make_product_options(
    product_convert_mode(options.mode),
    product_resource_limits(options.limits),
    pdf_cleanup_mode=product_pdf_cleanup_mode(options.pdf_cleanup_mode),
    pdf_table_mode=product_pdf_table_mode(options.pdf_table_mode),
    rag_options=options.rag_options,
  )
}

///|
priv enum CanonicalRoute {
  StreamingEvent
  BlockStreaming
  PackageSinglePass
  PageSinglePass
  DomAstModel
  LayoutTwoStage
  ContainerRecursive
} derive(Eq)

///|
priv struct PreflightProbe {
  selected_route : CanonicalRoute
  reason : String
  summary_format : String
  summary_parts : Array[String]
  prepared_source : @input.InputSource
  probe_artifact : RouteProbeArtifact?
}

///|
priv struct RouteDecision {
  selected_route : CanonicalRoute
  reason : String
  probe_summary_format : String
  probe_summary_parts : Array[String]
  same_mode_degradation : Array[String]
  prepared_source : @input.InputSource
  probe_artifact : RouteProbeArtifact?
}

///|
priv enum RouteProbeArtifact {
  MarkdownScan(@dmd.MarkdownDocument, @dmd.MarkdownInspectReport)
  HtmlEvents(Array[@dhtml.HtmlTokenEvent])
  JsonStream(@djson.JsonStreamDocument)
  XmlTokens(Array[@dxml.XmlToken])
  XlsxPackage(@ox.OoxmlPackage)
  YamlEvents(Array[@dyaml.YamlStructureEvent], @dyaml.YamlInspectReport)
}

///|
pub(all) enum ConvertError {
  DetectFailed(String)
  ParseFailed(String)
  RenderFailed(String)
} derive(Eq)

///|
pub impl Show for ConvertError with fn to_string(self : ConvertError) -> String {
  match self {
    DetectFailed(msg) => "detect failed: " + msg
    ParseFailed(msg) => "parse failed: " + msg
    RenderFailed(msg) => "render failed: " + msg
  }
}

///|
pub impl Show for ConvertError with fn output(
  self : ConvertError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct ConvertResult {
  content : String
  output_format : OutputFormat
  detected_format : @input.DetectedFormat
  parser_mode : @parser.ParserMode
  convert_mode : ConvertMode
  metadata : @core.DocumentMetadata
  diagnostics : @core.Diagnostics
  assets : Array[@core.AssetRef]
  source_map : @core.SourceMap?
  chunks : Array[@rag.RagChunk]?
  debug_ir : @core.DocumentIR?
}

///|
pub fn default_resource_limits() -> ResourceLimits {
  resource_limits_from_product(@product.default_resource_limits())
}

///|
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
) -> ResourceLimits {
  resource_limits_from_product(
    @product.make_resource_limits(
      max_rows,
      max_cols,
      max_cells,
      max_line_chars~,
    ),
  )
}

///|
pub fn default_convert_options() -> ConvertOptions {
  let product_options = @product.default_product_options()
  {
    mode: ConvertMode::Balanced,
    output_format: OutputFormat::Markdown,
    explicit_format: None,
    ocr_options: @parser.default_ocr_options(),
    limits: resource_limits_from_product(product_options.limits),
    pdf_cleanup_mode: default_pdf_cleanup_mode(),
    pdf_table_mode: default_pdf_table_mode(),
    rag_options: product_options.rag_options,
  }
}

///|
pub fn make_convert_options(
  mode : ConvertMode,
  output_format : OutputFormat,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  limits : ResourceLimits,
  pdf_cleanup_mode? : PdfCleanupMode = default_pdf_cleanup_mode(),
  pdf_table_mode? : PdfTableMode = default_pdf_table_mode(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> ConvertOptions {
  {
    mode,
    output_format,
    explicit_format,
    ocr_options,
    limits,
    pdf_cleanup_mode,
    pdf_table_mode,
    rag_options,
  }
}

///|
pub fn convert_mode_name(mode : ConvertMode) -> String {
  @product.convert_mode_name(product_convert_mode(mode))
}

///|
pub fn default_pdf_cleanup_mode() -> PdfCleanupMode {
  PdfCleanupMode::Disabled
}

///|
pub fn default_pdf_table_mode() -> PdfTableMode {
  PdfTableMode::Disabled
}

///|
fn pdf_cleanup_opt_in_mode() -> PdfCleanupMode {
  PdfCleanupMode::Conservative
}

///|
fn pdf_table_opt_in_mode() -> PdfTableMode {
  PdfTableMode::Simple
}

///|
pub fn pdf_cleanup_mode_name(mode : PdfCleanupMode) -> String {
  @product.pdf_cleanup_mode_name(product_pdf_cleanup_mode(mode))
}

///|
pub fn pdf_table_mode_name(mode : PdfTableMode) -> String {
  @product.pdf_table_mode_name(product_pdf_table_mode(mode))
}
