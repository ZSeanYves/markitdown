///|
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
pub(all) enum OutputFormat {
  Markdown
  RagJson
  DebugJson
} derive(Eq)

///|
pub type ExecutionProfile = @product.ExecutionProfile

///|
pub type LoweringProfile = @product.LoweringProfile

///|
pub type RenderProfile = @product.RenderProfile

///|
pub type ProbeSignalKind = @product.ProbeSignalKind

///|
pub type AccurateFeature = @product.AccurateFeature

///|
pub type AccurateFeatureProfile = @product.AccurateFeatureProfile

///|
pub type OcrProviderKind = @focr.OcrProviderKind

///|
pub type OcrProviderSelectionTarget = @focr.OcrProviderSelectionTarget

///|
/// Route-probe summary for an audio input before parsing begins.
pub struct AudioProbeArtifact {
  format : String
  codec : String?
  duration_ms : Int?
  sample_rate_hz : Int?
  channel_count : Int?
  language : String?
  probe_notes : Array[String]
}

///|
pub fn make_audio_probe_artifact(
  format : String,
  codec? : String? = None,
  duration_ms? : Int? = None,
  sample_rate_hz? : Int? = None,
  channel_count? : Int? = None,
  language? : String? = None,
  probe_notes? : Array[String] = [],
) -> AudioProbeArtifact {
  {
    format,
    codec,
    duration_ms,
    sample_rate_hz,
    channel_count,
    language,
    probe_notes,
  }
}

///|
/// One quantitative signal captured during route probing.
pub struct ProbeSignal {
  kind : ProbeSignalKind
  observed : Int
  limit : Int?
  note : String?
}

///|
pub fn make_probe_signal(
  kind : ProbeSignalKind,
  observed : Int,
  limit? : Int? = None,
  note? : String? = None,
) -> ProbeSignal {
  { kind, observed, limit, note }
}

///|
/// One hard probe failure recorded during route planning.
pub struct ProbeFailure {
  stage : String
  detail : String
}

///|
pub fn make_probe_failure(stage : String, detail : String) -> ProbeFailure {
  { stage, detail }
}

///|
/// Public convert-layer copy of product resource ceilings.
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
pub type PdfOcrPolicy = @product.PdfOcrPolicy

///|
fn product_pdf_ocr_policy(policy : PdfOcrPolicy) -> @product.PdfOcrPolicy {
  policy
}

///|
/// High-level convert API options accepted by `convert_input`.
///
/// These are the user-facing knobs that eventually resolve into product
/// options, parser context, and renderer selection.
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
  pdf_ocr_policy : PdfOcrPolicy
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
  rag_options : @rag.RagOptions
}

///|
/// Human-readable summary of the selected route before execution.
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
pub fn make_route_plan(
  detected_format : @input.DetectedFormat,
  selected_route : String,
  route_reason : String,
  route_probe_summary : String,
  requested_parser_mode : @parser.ParserMode?,
  ocr_provider_selection_target? : String? = None,
  ocr_provider_requested_kind? : String? = None,
  ocr_provider_resolved_kind? : String? = None,
) -> RoutePlan {
  {
    detected_format,
    selected_route,
    route_reason,
    route_probe_summary,
    requested_parser_mode,
    ocr_provider_selection_target,
    ocr_provider_requested_kind,
    ocr_provider_resolved_kind,
  }
}

///|
/// Provenance record describing how the product path actually executed.
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
pub fn make_convert_provenance(
  route_plan : RoutePlan,
  fidelity_mode : FidelityMode,
  output_mode : OutputMode,
  execution_profile : ExecutionProfile,
  execution_profile_reason : String,
  lowering_profile : LoweringProfile,
  render_profile : RenderProfile,
  profile_trigger_signals : Array[String],
  effective_parser_mode : @parser.ParserMode,
  parse_result_kind : String,
  pipeline_output_kind : String,
  render_input_kind : String,
  route_fidelity_status : String,
  applied_accurate_features : Array[String],
  same_mode_strategy_switches : Array[String],
  ocr_provider_selection_target? : String? = None,
  ocr_provider_requested_kind? : String? = None,
  ocr_provider_resolved_kind? : String? = None,
  audio_backend_transport? : String? = None,
  audio_backend_name? : String? = None,
  audio_backend_version? : String? = None,
  requested_fidelity_mode? : FidelityMode? = None,
) -> ConvertProvenance {
  {
    route_plan,
    fidelity_mode,
    output_mode,
    execution_profile,
    execution_profile_reason,
    lowering_profile,
    render_profile,
    profile_trigger_signals,
    effective_parser_mode,
    parse_result_kind,
    pipeline_output_kind,
    render_input_kind,
    route_fidelity_status,
    applied_accurate_features,
    same_mode_strategy_switches,
    ocr_provider_selection_target,
    ocr_provider_requested_kind,
    ocr_provider_resolved_kind,
    audio_backend_transport,
    audio_backend_name,
    audio_backend_version,
    requested_fidelity_mode,
  }
}

///|
/// Pairing of end-user output plus the provenance that produced it.
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
    fidelity_mode=options.fidelity_mode,
    output_mode=options.output_mode,
    stream_requested=options.stream_requested,
    pdf_ocr_policy=product_pdf_ocr_policy(options.pdf_ocr_policy),
    pdf_cleanup_mode=product_pdf_cleanup_mode(options.pdf_cleanup_mode),
    pdf_table_mode=product_pdf_table_mode(options.pdf_table_mode),
    rag_options=options.rag_options,
  )
}

///|
type CanonicalRoute = @formats.FormatRoute

///|
priv struct ProbeOutcome {
  probe_signals : Array[ProbeSignal]
  probe_failures : Array[ProbeFailure]
  summary_format : String
  summary_parts : Array[String]
  prepared_source : @input.InputSource
  probe_artifacts : Array[RouteProbeArtifact]
}

///|
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
  pdf_ocr_policy : PdfOcrPolicy
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
  rag_options : @rag.RagOptions
}

///|
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
  pdf_ocr_policy : PdfOcrPolicy
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
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
  MarkdownScan(@dmd.MarkdownDocument, @dmd.MarkdownInspectReport)
  HtmlEvents(String, Array[@dhtml.HtmlTokenEvent])
  IpynbNotebook(@dipynb.IpynbNotebook, @dipynb.IpynbInspectReport)
  JsonStream(@djson.JsonStreamDocument)
  TextMarkupDocument(@dtext.TextMarkupDocument, @dtext.TextMarkupInspectReport)
  TomlDocument(@dtoml.TomlDocument, @dtoml.TomlInspectReport)
  XmlTokens(Array[@dxml.XmlToken])
  OdtDocument(@dodf.OdtDocument, @dodf.OdtInspectReport)
  OdsDocument(@dodf.OdsDocument, @dodf.OdsInspectReport)
  OdpDocument(@dodf.OdpDocument, @dodf.OdpInspectReport)
  XlsxPackage(@ox.OoxmlPackage)
  PdfNativeDocument(@fpdf.PdfNativeDocument)
  ZipArchiveInspect(@dzip.ZipArchive, @dzip.ZipArchiveInspectReport)
  EpubPackageInspect(@depub.EpubPackage, @depub.EpubInspectReport)
  YamlEvents(Array[@dyaml.YamlStructureEvent], @dyaml.YamlInspectReport)
  AudioProbe(AudioProbeArtifact)
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
/// Final public result returned by the high-level convert API.
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
    limits: resource_limits_from_product(product_options.limits),
    pdf_ocr_policy: @product.default_pdf_ocr_policy(),
    pdf_cleanup_mode: default_pdf_cleanup_mode(),
    pdf_table_mode: default_pdf_table_mode(),
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
  pdf_ocr_policy? : PdfOcrPolicy = @product.default_pdf_ocr_policy(),
  pdf_cleanup_mode? : PdfCleanupMode = default_pdf_cleanup_mode(),
  pdf_table_mode? : PdfTableMode = default_pdf_table_mode(),
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
    pdf_ocr_policy,
    pdf_cleanup_mode,
    pdf_table_mode,
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
pub fn fidelity_mode_name(mode : FidelityMode) -> String {
  @product.fidelity_mode_name(mode)
}

///|
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

///|
pub fn default_pdf_cleanup_mode() -> PdfCleanupMode {
  PdfCleanupMode::Disabled
}

///|
pub fn default_pdf_table_mode() -> PdfTableMode {
  PdfTableMode::Disabled
}

///|
pub fn default_pdf_ocr_policy() -> PdfOcrPolicy {
  @product.default_pdf_ocr_policy()
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

///|
pub fn pdf_ocr_policy_name(policy : PdfOcrPolicy) -> String {
  @product.pdf_ocr_policy_name(policy)
}
