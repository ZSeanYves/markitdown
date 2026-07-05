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
/// Public declaration of what a parser can emit and what route constraints it
/// has.
///
/// `supports_*` describes the exposed IR shapes, while `produces_*` describes
/// which semantics the implementation can preserve.
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
/// hints, and coarse resource limits.
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
  pdf_ocr_policy : PdfOcrPolicy
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
pub type PdfOcrPolicy = @product.PdfOcrPolicy

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
/// OCR settings shared by image and PDF OCR routes.
pub struct OcrOptions {
  intent : OcrIntent
  language : String?
}

///|
/// Audio-transcription hints shared by media-pipeline parsers.
pub struct AudioOptions {
  language : String?
}

///|
/// One parser result exposed to the rest of the product path.
///
/// Exactly one of `event_stream`, `block_stream`, or `document` is expected to
/// be populated.
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
pub struct ParserRegistry {
  parsers : Map[String, Array[Parser]]
}

///|
/// Format-keyed async parser registry used by async product dispatch.
pub struct AsyncParserRegistry {
  parsers : Map[String, Array[AsyncParser]]
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
