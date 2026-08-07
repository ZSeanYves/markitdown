///|
/// Stable input kinds accepted by the 0.8 API.
pub(all) enum InputKind {
  Path
  Text
  Bytes
  Reader
} derive(Eq, @debug.Debug)

///|
/// An input whose storage details remain private to the API adapter.
///
/// Use the `Input::from_*` constructors instead of depending on the legacy
/// `input` package. This keeps the parser and source implementation replaceable.
pub struct Input {
  priv source : @input.InputSource
  priv kind : InputKind
}

///|
/// Product conversion strategies supported by the stable API.
pub(all) enum ConvertMode {
  Balanced
  Accurate
  Stream
} derive(Eq, @debug.Debug)

///|
/// Stable output representations.
pub(all) enum OutputMode {
  Markdown
  Debug
  Rag
} derive(Eq, @debug.Debug)

///|
/// OCR selection policy. OCR runtimes remain optional extensions.
#warnings("-unused_constructor")
pub(all) enum OcrMode {
  Auto
  Enabled
  Disabled
} derive(Eq, @debug.Debug)

///|
/// Stable resource ceilings for one conversion.
pub struct ResourceLimits {
  max_rows : Int
  max_cols : Int
  max_cells : Int
  max_line_chars : Int
  max_input_bytes : Int64
  max_asset_bytes : Int64
  max_total_asset_bytes : Int64
  external_command_timeout_ms : Int
  max_external_output_bytes : Int64
} derive(Eq, @debug.Debug)

///|
/// Stable RAG chunking policy.
pub struct RagOptions {
  chunk_size : Int
  chunk_overlap : Int
  preserve_heading_path : Bool
  preserve_source_ref : Bool
  split_tables : Bool
  split_code_blocks : Bool
} derive(Eq, @debug.Debug)

///|
/// Stable 0.8 conversion options.
pub struct ConvertOptions {
  mode : ConvertMode
  output_mode : OutputMode
  format_hint : String?
  ocr_mode : OcrMode
  ocr_language : String?
  audio_language : String?
  limits : ResourceLimits
  rag : RagOptions
} derive(Eq, @debug.Debug)

///|
/// Diagnostic severity exposed independently from internal parser models.
pub(all) enum DiagnosticSeverity {
  Warning
  Error
} derive(Eq, @debug.Debug)

///|
/// One stable, machine-classifiable conversion diagnostic.
pub struct Diagnostic {
  code : String
  severity : DiagnosticSeverity
  message : String
} derive(Eq, @debug.Debug)

///|
/// Stable execution provenance. Every field is implementation-neutral text.
pub struct Provenance {
  detected_format : String
  selected_route : String
  route_reason : String
  parser_mode : String
  fidelity_mode : String
  output_mode : String
  execution_profile : String
  lowering_profile : String
  render_profile : String
  route_fidelity_status : String
  applied_accurate_features : Array[String]
  strategy_switches : Array[String]
} derive(Eq, @debug.Debug)

///|
/// Stable source-local geometry.
pub struct BoundingBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
} derive(Eq, @debug.Debug)

///|
/// Stable source location independent of parser and IR implementation types.
pub struct SourceRef {
  file_id : String?
  format : String?
  page : Int?
  bbox : BoundingBox?
  line_start : Int?
  line_end : Int?
  byte_start : Int?
  byte_end : Int?
  time_start : String?
  time_end : String?
  xpath : String?
  json_pointer : String?
  yaml_path : String?
  html_path : String?
  markdown_path : String?
  container_path : String?
  entry_path : String?
  entry_index : Int?
  entry_format : String?
  inner_path : String?
  sheet : String?
  cell_range : String?
  slide : Int?
  shape_id : String?
  relationship_id : String?
  chapter_href : String?
  extra : Map[String, String]
} derive(Eq, @debug.Debug)

///|
/// Stable provenance entry for one block or asset.
pub struct SourceMapEntry {
  primary_ref : SourceRef?
  refs : Array[SourceRef]
  merged_from : Array[SourceRef]
  confidence : Int?
  relation : String?
} derive(Eq, @debug.Debug)

///|
/// Stable source map aligned with converted block and asset order.
pub struct SourceMap {
  document_ref : SourceRef?
  block_entries : Array[SourceMapEntry]
  asset_entries : Array[SourceMapEntry]
} derive(Eq, @debug.Debug)

///|
/// Asset categories emitted by conversion.
pub(all) enum AssetKind {
  Image
  Attachment
  Link
  Embedded
  Unknown
} derive(Eq, @debug.Debug)

///|
/// Materializable stable asset content.
pub(all) enum AssetPayload {
  Bytes(Bytes)
  Utf8(String)
  SourcePath(String)
} derive(Eq, @debug.Debug)

///|
/// One materializable or logical asset discovered during conversion.
pub struct Asset {
  kind : AssetKind
  id : String
  path : String?
  mime_type : String?
  source_ref : SourceRef?
  payload : AssetPayload?
  attrs : Map[String, String]
} derive(Eq, @debug.Debug)

///|
/// One retrieval-oriented output chunk.
pub struct Chunk {
  id : String
  kind : String
  text : String
  heading_path : Array[String]
  source_refs : Array[SourceRef]
  asset_refs : Array[String]
  metadata_json : String
} derive(Eq, @debug.Debug)

///|
/// Stable conversion output shared by Markdown, debug, and RAG modes.
pub struct Output {
  content : String
  detected_format : String
  convert_mode : ConvertMode
  output_mode : OutputMode
  metadata_json : String
  diagnostics : Array[Diagnostic]
  provenance : Provenance
  assets : Array[Asset]
  source_map : SourceMap?
  chunks : Array[Chunk]
} derive(Eq, @debug.Debug)

///|
/// Stability level of a format capability.
#warnings("-unused_constructor")
pub(all) enum CapabilityStatus {
  Stable
  Experimental
  ExternalRuntime
  Unsupported
} derive(Eq, @debug.Debug)

///|
/// Public capability declaration for one accepted format label.
pub struct Capability {
  format : String
  canonical_format : String
  status : CapabilityStatus
  input_kinds : Array[InputKind]
  convert_modes : Array[ConvertMode]
  output_modes : Array[OutputMode]
  external_requirements : Array[String]
} derive(Eq, @debug.Debug)

///|
/// Stable machine-readable conversion error identifiers.
pub(all) enum ErrorCode {
  DetectionFailed
  ParseFailed
  RenderFailed
  ResourceLimitExceeded
  InvalidOption
} derive(Eq, @debug.Debug)

///|
/// Typed conversion failures returned by the 0.8 API.
pub(all) suberror ConvertError {
  DetectionFailed(String)
  ParseFailed(String)
  RenderFailed(String)
  ResourceLimitExceeded(kind~ : String, observed~ : Int64, limit~ : Int64)
  InvalidOption(String)
} derive(Eq, @debug.Debug)

///|
/// Marker for the compatibility surface frozen for the 0.8 release line.
pub struct ApiV0_8 {
  priv marker : Unit
}

///|
/// Version bridge data that callers can inspect before a future 1.0 migration.
pub struct ApiV1Migration {
  source_version : String
  target_version : String
  stable_package : String
  breaking_changes_allowed_before_target : Bool
} derive(Eq, @debug.Debug)
