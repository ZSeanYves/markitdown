///|
/// High-level execution shapes exposed by parsers before pipeline recovery.
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
/// Granularity labels used when a parser can expose partial or streaming
/// results.
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
/// Public declaration of what a parser can emit and what route constraints it
/// has.
///
/// `supports_*` describes the exposed IR shapes, while `produces_*` describes
/// which semantics the implementation can preserve. The remaining fields let
/// routing decide whether the parser can handle streaming, random access,
/// losslessness, and ordering/style preservation requirements.
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
/// End-to-end execution knobs passed from route planning into a parser.
///
/// This carries requested route shape, fidelity/output profiles, OCR or audio
/// hints, PDF policy toggles, and coarse resource limits. It is the canonical
/// place for parser-visible runtime policy.
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
  audio_options : AudioOptions
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
/// OCR intent after CLI defaults and route planning have been resolved.
pub(all) enum OcrIntent {
  Disabled
  Auto
  Explicit
} derive(Eq)

///|
/// Whether native PDF text restoration is allowed to execute.
pub(all) enum PdfNativeRuntimePolicy {
  DisableTextRestore
  EnableTextRestore
} derive(Eq)

///|
/// Policy controlling internal PDF header/footer filtering during lowering.
pub(all) enum PdfHeaderFooterFilterPolicy {
  Disabled
  InternalHighConfidenceOnly
} derive(Eq)

///|
/// Policy controlling internal PDF table reconstruction heuristics.
pub(all) enum PdfTableReconstructionPolicy {
  Disabled
  InternalSimpleRowsOnly
} derive(Eq)

///|
/// OCR settings shared by image and PDF OCR routes.
///
/// `intent` records whether OCR is disabled, automatically selected, or
/// explicitly required, while `language` passes through a user hint when one
/// exists.
pub struct OcrOptions {
  intent : OcrIntent
  language : String?
}

///|
/// Audio-transcription hints shared by media-pipeline parsers.
///
/// `language` is advisory and may be ignored by runtimes that only support
/// auto-detection.
pub struct AudioOptions {
  language : String?
}

///|
/// One parser result exposed to the rest of the product path.
///
/// Exactly one of `event_stream`, `block_stream`, or `document` is expected to
/// be populated. The remaining fields are side channels that downstream stages
/// can consume without reopening parser-private state.
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
/// Parser registry entry used by canonical format dispatch.
///
/// `name` and `mode` stay stable for diagnostics and provenance, and `parse`
/// is expected to respect the declared `capability`.
pub struct Parser {
  name : String
  mode : ParserMode
  capability : ParserCapability
  parse : (@input.InputSource, ParseContext) -> Result[ParseResult, String]
}

///|
/// Async parser registry entry used by async product dispatch.
pub struct AsyncParser {
  name : String
  mode : ParserMode
  capability : ParserCapability
  parse : async (@input.InputSource, ParseContext) -> Result[
    ParseResult,
    String,
  ]
}

///|
/// Format-keyed parser registry used by the unified product path.
///
/// Each key maps to one canonical default parser plus optional later
/// registrations for mode-specific overrides.
pub struct ParserRegistry {
  parsers : Map[String, Array[Parser]]
}

///|
/// Format-keyed async parser registry used by async product dispatch.
pub struct AsyncParserRegistry {
  parsers : Map[String, Array[AsyncParser]]
}

///|
/// Stable diagnostics/provenance label for a parser mode.
pub fn mode_name(mode : ParserMode) -> String {
  match mode {
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

///|
/// Stable diagnostics/provenance label for one streaming granularity.
pub fn streaming_granularity_name(granularity : StreamingGranularity) -> String {
  match granularity {
    Byte => "byte"
    Line => "line"
    Record => "record"
    Row => "row"
    JsonStructure => "json_structure"
    NotebookCellOutputGroup => "notebook_cell_output_group"
    XmlStructure => "xml_structure"
    YamlStructure => "yaml_structure"
    HtmlTokenStructure => "html_token_structure"
    MarkdownBlock => "markdown_block"
    DocxBlock => "docx_block"
    PptxSlide => "pptx_slide"
    XlsxSheet => "xlsx_sheet"
    XlsxRow => "xlsx_row"
    ArchiveEntry => "archive_entry"
    EpubSpineItem => "epub_spine_item"
    Block => "block"
    Page => "page"
    Slide => "slide"
    Sheet => "sheet"
    Chapter => "chapter"
    Message => "message"
    None => "none"
  }
}
