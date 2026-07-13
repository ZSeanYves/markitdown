///|
/// Public convert strategy modes re-exported by the high-level API.
pub(all) enum ConvertMode {
  Balanced
  Accurate
  Stream
} derive(Eq)

///|
pub type FidelityMode = @product.FidelityMode

///|
pub type OutputMode = @product.OutputMode

///|
fn product_convert_mode(mode : ConvertMode) -> @product.ConvertMode {
  match mode {
    ConvertMode::Balanced => @product.ConvertMode::Balanced
    ConvertMode::Accurate => @product.ConvertMode::Accurate
    ConvertMode::Stream => @product.ConvertMode::Stream
  }
}

///|
/// External output views currently exposed by the high-level convert API.
///
/// These stay slightly narrower than internal `OutputMode` because they model
/// what callers can request directly from `convert_input`.
pub(all) enum OutputFormat {
  Markdown
  RagJson
  DebugJson
} derive(Eq)

///|
/// High-level convert-layer alias of the product execution profile.
pub type ExecutionProfile = @product.ExecutionProfile

///|
/// High-level convert-layer alias of the product lowering profile.
pub type LoweringProfile = @product.LoweringProfile

///|
/// High-level convert-layer alias of the product render profile.
pub type RenderProfile = @product.RenderProfile

///|
/// Public probe signal label re-exported from the product vocabulary.
pub type ProbeSignalKind = @product.ProbeSignalKind

///|
/// Public accurate-feature label re-exported from the product vocabulary.
pub type AccurateFeature = @product.AccurateFeature

///|
/// Public accurate-feature profile re-exported from the product vocabulary.
pub type AccurateFeatureProfile = @product.AccurateFeatureProfile

///|
/// OCR provider kind re-exported for route plan and provenance surfaces.
pub type OcrProviderKind = @focr.OcrProviderKind

///|
/// OCR provider selection target re-exported for route plan and provenance
/// surfaces.
pub type OcrProviderSelectionTarget = @focr.OcrProviderSelectionTarget

///|
priv struct DocxProbeArtifact {
  block_count : Int
  image_count : Int
  comment_count : Int
  textbox_count : Int
  header_count : Int
  footer_count : Int
  note_count : Int
}

///|
priv struct PptxProbeArtifact {
  hidden_slide_count : Int
  text_block_count : Int
  image_count : Int
}

///|
/// One quantitative signal captured during route probing.
///
/// `observed` is the measured value, `limit` is the threshold that mattered
/// for routing, and `note` keeps small human-readable context for summaries.
priv struct ProbeSignal {
  kind : ProbeSignalKind
  observed : Int
  limit : Int?
  note : String?
}

///|
/// One hard probe failure recorded during route planning.
priv struct ProbeFailure {
  stage : String
  detail : String
}

///|
fn make_probe_signal(
  kind : ProbeSignalKind,
  observed : Int,
  limit? : Int? = None,
  note? : String? = None,
) -> ProbeSignal {
  { kind, observed, limit, note }
}

///|
fn make_probe_failure(stage : String, detail : String) -> ProbeFailure {
  { stage, detail }
}

///|
/// High-level convert-layer alias of the product resource ceilings.
pub type ResourceLimits = @product.ResourceLimits

///|
/// High-level convert API options accepted by `convert_input`.
///
/// These are the user-facing knobs that eventually resolve into product
/// options, parser context, renderer selection, and route-planning policy.
pub struct ConvertOptions {
  mode : ConvertMode
  fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  output_format : OutputFormat
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  audio_options : @parser.AudioOptions
  limits : ResourceLimits
  rag_options : @rag.RagOptions
}

///|
/// Human-readable summary of the selected route before execution.
///
/// This is intentionally compact and user-facing, so CLI and tests can explain
/// why a specific parser mode or OCR provider was selected without dumping the
/// full internal execution plan.
pub struct RoutePlan {
  detected_format : @input.DetectedFormat
  selected_route : String
  route_reason : String
  route_probe_summary : String
  requested_parser_mode : @parser.ParserMode?
  ocr_provider_selection_target : String?
  ocr_provider_requested_kind : String?
  ocr_provider_resolved_kind : String?
}

///|
/// Provenance record describing how the product path actually executed.
///
/// Compared with `RoutePlan`, this captures the effective profiles, parser
/// result shape, feature switches, provider resolution, and strategy changes
/// that happened during real execution.
pub struct ConvertProvenance {
  route_plan : RoutePlan
  fidelity_mode : FidelityMode
  output_mode : OutputMode
  execution_profile : ExecutionProfile
  execution_profile_reason : String
  lowering_profile : LoweringProfile
  render_profile : RenderProfile
  profile_trigger_signals : Array[String]
  effective_parser_mode : @parser.ParserMode
  parse_result_kind : String
  pipeline_output_kind : String
  render_input_kind : String
  route_fidelity_status : String
  applied_accurate_features : Array[String]
  same_mode_strategy_switches : Array[String]
  ocr_provider_selection_target : String?
  ocr_provider_requested_kind : String?
  ocr_provider_resolved_kind : String?
  audio_backend_transport : String?
  audio_backend_name : String?
  audio_backend_version : String?
  requested_fidelity_mode : FidelityMode?
}

///|
/// Pairing of end-user output plus the provenance that produced it.
pub struct ConvertExecution {
  result : ConvertResult
  provenance : ConvertProvenance
}

///|
fn product_options_from_convert_options(
  options : ConvertOptions,
) -> @product.ProductOptions {
  @product.make_product_options(
    product_convert_mode(options.mode),
    options.limits,
    fidelity_mode=options.fidelity_mode,
    output_mode=options.output_mode,
    stream_requested=options.stream_requested,
    rag_options=options.rag_options,
  )
}

///|
type CanonicalRoute = @fmeta.FormatRoute

///|
/// Internal result of the probing stage before the route is frozen.
priv struct ProbeOutcome {
  probe_signals : Array[ProbeSignal]
  probe_failures : Array[ProbeFailure]
  summary_format : String
  summary_parts : Array[String]
  prepared_source : @input.InputSource
  probe_artifacts : Array[RouteProbeArtifact]
}

///|
/// Prepared source plus the probe artifacts that may be reused by execution.
priv struct PreparedParseRequest {
  source : @input.InputSource
  detected_format : @input.DetectedFormat
  probe_outcome : ProbeOutcome
  probe_artifact : RouteProbeArtifact?
}

///|
/// Caller intent after CLI/public defaults are normalized but before routing.
priv struct ExecutionIntent {
  strategy_mode : ConvertMode
  fidelity_mode : FidelityMode
  requested_fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  output_format : OutputFormat
  ocr_options : @parser.OcrOptions
  audio_options : @parser.AudioOptions
  limits : ResourceLimits
  rag_options : @rag.RagOptions
}

///|
/// Fully-resolved internal execution plan frozen after probing and route
/// policy selection.
priv struct ResolvedExecutionPlan {
  detected_format : @input.DetectedFormat
  mode : ConvertMode
  fidelity_mode : FidelityMode
  requested_fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  output_format : OutputFormat
  ocr_options : @parser.OcrOptions
  audio_options : @parser.AudioOptions
  limits : ResourceLimits
  rag_options : @rag.RagOptions
  selected_route : CanonicalRoute
  execution_profile : ExecutionProfile
  execution_profile_reason : String
  lowering_profile : LoweringProfile
  render_profile : RenderProfile
  accurate_feature_profile : AccurateFeatureProfile
  requested_parser_mode : @parser.ParserMode?
  pdf_native_runtime_policy : @parser.PdfNativeRuntimePolicy
  pdf_header_footer_filter_policy : @parser.PdfHeaderFooterFilterPolicy
  pdf_table_reconstruction_policy : @parser.PdfTableReconstructionPolicy
  reason : String
  probe_signals : Array[ProbeSignal]
  profile_trigger_signals : Array[ProbeSignal]
  probe_failures : Array[ProbeFailure]
  probe_summary_format : String
  probe_summary_parts : Array[String]
  same_mode_strategy_switches : Array[String]
  ocr_provider_selection_target : OcrProviderSelectionTarget?
  ocr_provider_requested_kind : OcrProviderKind?
  ocr_provider_resolved_kind : OcrProviderKind?
  audio_backend_transport : String?
  audio_backend_name : String?
  audio_backend_version : String?
  prepared_source : @input.InputSource
  probe_artifacts : Array[RouteProbeArtifact]
}

///|
priv enum RouteProbeArtifact {
  MarkdownPrepared(@dmd.PreparedMarkdownDocument)
  MarkdownLargeLiteral(@input.InputSource, String, Int)
  HtmlPrepared(@dhtml.PreparedHtmlDocument)
  IpynbPrepared(@dipynb.PreparedIpynbNotebook)
  JsonPrepared(@djson.PreparedJsonText)
  TextMarkupPrepared(@dtext.PreparedTextMarkupDocument)
  TomlPrepared(@dtoml.PreparedTomlDocument)
  XmlPrepared(@dxml.PreparedXmlText)
  DocxPrepared(@ddocx.PreparedDocxDocument, DocxProbeArtifact)
  PptxPrepared(@pptxdoc.PreparedPptxDocument, PptxProbeArtifact)
  OdtPrepared(@dodf.PreparedOdtDocument)
  OdsPrepared(@dodf.PreparedOdsDocument)
  OdpPrepared(@dodf.PreparedOdpDocument)
  XlsxPrepared(@drxlsx.PreparedXlsxPackage)
  PdfNativeDocument(@dpdfnative.PdfNativeDocument)
  ZipPrepared(@dzipsource.PreparedZipArchive)
  EpubPrepared(@depub.PreparedEpubPackage)
  YamlPrepared(@dyaml.PreparedYamlDocument)
}

///|
pub(all) enum ConvertError {
  DetectFailed(String)
  ParseFailed(String)
  RenderFailed(String)
  ResourceLimitExceeded(kind~ : String, observed~ : Int64, limit~ : Int64)
} derive(Eq)

///|
pub impl Show for ConvertError with fn to_string(self : ConvertError) -> String {
  match self {
    DetectFailed(msg) => "detect failed: " + msg
    ParseFailed(msg) => "parse failed: " + msg
    RenderFailed(msg) => "render failed: " + msg
    ResourceLimitExceeded(kind~, observed~, limit~) =>
      "resource limit exceeded: " +
      kind +
      "; observed=" +
      observed.to_string() +
      "; limit=" +
      limit.to_string()
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
/// Final public result returned by the high-level convert API.
///
/// It carries the rendered content plus the stable public side channels callers
/// most often need: diagnostics, metadata, assets, source map, chunks, and an
/// optional debug IR snapshot.
pub struct ConvertResult {
  content : String
  output_format : OutputFormat
  fidelity_mode : FidelityMode
  output_mode : OutputMode
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
/// Return the default convert-layer resource limits aligned with product
/// defaults.
pub fn default_resource_limits() -> ResourceLimits {
  @product.default_resource_limits()
}

///|
/// Build explicit convert-layer resource limits aligned with product policy.
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
  max_input_bytes? : Int64 = 512L * 1024L * 1024L,
  max_asset_bytes? : Int64 = 32L * 1024L * 1024L,
  max_total_asset_bytes? : Int64 = 128L * 1024L * 1024L,
  external_command_timeout_ms? : Int = 300000,
  max_external_output_bytes? : Int64 = 8L * 1024L * 1024L,
) -> ResourceLimits {
  @product.make_resource_limits(
    max_rows,
    max_cols,
    max_cells,
    max_line_chars~,
    max_input_bytes~,
    max_asset_bytes~,
    max_total_asset_bytes~,
    external_command_timeout_ms~,
    max_external_output_bytes~,
  )
}

///|
/// Return default convert options for the balanced Markdown path.
pub fn default_convert_options() -> ConvertOptions {
  let product_options = @product.default_product_options()
  {
    mode: ConvertMode::Balanced,
    fidelity_mode: FidelityMode::Balanced,
    output_mode: OutputMode::Markdown,
    stream_requested: false,
    output_format: OutputFormat::Markdown,
    explicit_format: None,
    ocr_options: @parser.default_ocr_options(),
    audio_options: @parser.default_audio_options(),
    limits: product_options.limits,
    rag_options: product_options.rag_options,
  }
}

///|
/// Build explicit convert options while keeping shared defaults aligned with
/// product-level policy.
pub fn make_convert_options(
  mode : ConvertMode,
  output_format : OutputFormat,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  limits : ResourceLimits,
  audio_options? : @parser.AudioOptions = @parser.default_audio_options(),
  fidelity_mode? : FidelityMode = fidelity_mode_for_convert_mode(mode),
  output_mode? : OutputMode = output_mode_for_output_format(output_format),
  stream_requested? : Bool = mode == ConvertMode::Stream,
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> ConvertOptions {
  {
    mode,
    fidelity_mode,
    output_mode,
    stream_requested,
    output_format,
    explicit_format,
    ocr_options,
    audio_options,
    limits,
    rag_options,
  }
}

///|
/// Stable name for the selected convert strategy mode.
pub fn convert_mode_name(mode : ConvertMode) -> String {
  @product.convert_mode_name(product_convert_mode(mode))
}

///|
/// Return the default fidelity associated with a convert mode.
pub fn fidelity_mode_for_convert_mode(mode : ConvertMode) -> FidelityMode {
  @product.fidelity_mode_for_convert_mode(product_convert_mode(mode))
}

///|
/// Stable diagnostics/provenance label for one fidelity mode.
pub fn fidelity_mode_name(mode : FidelityMode) -> String {
  @product.fidelity_mode_name(mode)
}

///|
/// Return the renderer-facing output mode implied by a convert mode.
pub fn output_mode_for_convert_mode(mode : ConvertMode) -> OutputMode {
  @product.output_mode_for_convert_mode(product_convert_mode(mode))
}

///|
/// Map a public output format to the renderer-facing output mode.
pub fn output_mode_for_output_format(format : OutputFormat) -> OutputMode {
  match format {
    OutputFormat::DebugJson => OutputMode::Debug
    OutputFormat::RagJson => OutputMode::Rag
    _ => OutputMode::Markdown
  }
}

///|
/// Stable diagnostics/provenance label for one output mode.
pub fn output_mode_name(mode : OutputMode) -> String {
  @product.output_mode_name(mode)
}

///|
/// Re-derive a convert mode from fidelity plus explicit stream request.
pub fn derived_convert_mode(
  fidelity_mode : FidelityMode,
  stream_requested : Bool,
) -> ConvertMode {
  if stream_requested {
    ConvertMode::Stream
  } else {
    match fidelity_mode {
      FidelityMode::Accurate => ConvertMode::Accurate
      FidelityMode::Balanced => ConvertMode::Balanced
    }
  }
}
