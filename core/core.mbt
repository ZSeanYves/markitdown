///|
pub type LayoutBox = BBox

///|
pub type BlockId = String

///|
pub type HeadingPath = Array[String]

///|
pub type DocumentMetadata = Map[String, JsonValue]

///|
/// Public IR entry shapes exchanged between parsers, the pass pipeline, and
/// renderers.
pub(all) enum IRInput {
  EventStream(Array[CoreEvent])
  BlockStream(Array[CoreBlock])
  Document(DocumentIR)
}

///|
/// Canonical document model carried through the unified product path.
///
/// `blocks` is the renderable tree. `signals`, `source_map`, and `assembly`
/// keep extra recovery results that later passes, renderers, and provenance
/// outputs can consume without rescanning raw parser state.
pub(all) struct DocumentIR {
  blocks : Array[CoreBlock]
  metadata : DocumentMetadata
  diagnostics : Diagnostics
  assets : Array[AssetRef]
  signals : Array[CoreSignal]
  source_map : SourceMap?
  assembly : DocumentAssembly?
}

///|
pub(all) enum BlockKind {
  Document
  Section
  Heading
  Paragraph
  List
  ListItem
  Table
  TableRow
  TableCell
  Image
  Code
  BlockQuote
  Raw
} derive(Eq)

///|
/// One recovered block in the canonical IR tree.
///
/// `text` is the plain-text fallback used by many render paths, while
/// `rich_inlines` preserves richer inline semantics when the parser has them.
pub(all) struct CoreBlock {
  block_id : BlockId
  kind : BlockKind
  text : String
  rich_inlines : Array[CoreInline]?
  children : Array[CoreBlock]
  attrs : Map[String, String]
  source_ref : SourceRef?
  style : StyleRef?
  signals : Array[CoreSignal]
}

///|
pub(all) struct SectionNode {
  section_id : BlockId
  heading_block_id : BlockId?
  title : String
  level : Int
  heading_path : HeadingPath
  child_section_ids : Array[BlockId]
  block_ids : Array[BlockId]
  source_ref : SourceRef?
}

///|
pub(all) struct CaptionBinding {
  caption_block_id : BlockId
  target_block_id : BlockId
  relation : String
  confidence : Int?
}

///|
pub(all) struct TableContinuation {
  table_block_id : BlockId
  continues_from_block_id : BlockId?
  relation : String
  confidence : Int?
}

///|
pub(all) struct ReadingOrderEntry {
  block_id : BlockId
  ordinal : Int
  page : Int?
  slide : Int?
  sheet : String?
}

///|
pub(all) struct AssetBinding {
  asset_id : String
  owner_block_id : BlockId
  relation : String
  confidence : Int?
}

///|
/// Recovered structural overlays built after parsing.
///
/// These indexes let downstream code reason about sections, captions, reading
/// order, and asset ownership without re-deriving them from the block tree.
pub(all) struct DocumentAssembly {
  root_block_ids : Array[BlockId]
  sections : Array[SectionNode]
  heading_paths : Map[String, HeadingPath]
  caption_bindings : Array[CaptionBinding]
  table_continuations : Array[TableContinuation]
  reading_order : Array[ReadingOrderEntry]
  asset_bindings : Array[AssetBinding]
}

///|
pub(all) enum InlineKind {
  Text
  LineBreak
  Link
  Image
  Code
} derive(Eq)

///|
/// Rich inline content attached to a block when plain text alone is not
/// enough.
pub(all) struct CoreInline {
  kind : InlineKind
  text : String
  href : String?
  title : String?
  attrs : Map[String, String]
  source_ref : SourceRef?
}

///|
pub(all) enum SignalType {
  HeadingCandidate
  ListCandidate
  TableCandidate
  CaptionCandidate
  HeaderFooterCandidate
  PageBreak
  SectionBreak
  ReadingOrderHint
  FontSignal
  StyleSignal
  LayoutSignal
  OcrSignal
  TableContinuationCandidate
  ArtifactCandidate
  LanguageHint
  CodeLanguageHint
  NoteRef
  CommentRef
  RenderHint
} derive(Eq)

///|
/// Parser- or pipeline-emitted semantic hints that help later passes recover
/// structure conservatively.
pub(all) struct CoreSignal {
  signal_type : SignalType
  confidence : Int
  payload : Map[String, JsonValue]
}

///|
/// Provenance for one public block or asset entry in a `SourceMap`.
pub(all) struct SourceMapEntry {
  primary_ref : SourceRef?
  refs : Array[SourceRef]
  merged_from : Array[SourceRef]
  confidence : Int?
  relation : String?
}

///|
/// Public-facing provenance map kept alongside a `DocumentIR`.
pub(all) struct SourceMap {
  document_ref : SourceRef?
  block_entries : Array[SourceMapEntry]
  asset_entries : Array[SourceMapEntry]
}

///|
/// A location pointer that can target files, pages, slides, sheets, archive
/// entries, markup paths, or media time ranges.
pub(all) struct SourceRef {
  file_id : String?
  format : String?
  page : Int?
  bbox : BBox?
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
}

///|
pub(all) enum ContainerEntryKind {
  Document
  Asset
  Metadata
  Directory
  Unsupported
  Unsafe
} derive(Eq)

///|
pub(all) enum ContainerSecurityFinding {
  PathTraversal
  AbsolutePath
  EncryptedEntry
  UnsupportedCompression
  CompressionRatioLimit
  DuplicateNormalizedPath
  NestedArchive
  ExternalReference
  ResourceLimitHit
} derive(Eq)

///|
/// Observed archive or package entry after normalization and security checks.
pub(all) struct ContainerEntry {
  entry_path : String
  normalized_path : String?
  entry_index : Int?
  entry_kind : ContainerEntryKind
  detected_format : String?
  media_type : String?
  compressed_size : Int?
  uncompressed_size : Int?
  is_encrypted : Bool
  compression_method : String?
  crc : String?
  source_ref : SourceRef?
  security_findings : Array[ContainerSecurityFinding]
}

///|
/// Raw geometry in page- or image-local coordinates.
pub(all) struct BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// Lightweight recovered style identity attached to a block.
pub(all) struct StyleRef {
  style_id : String?
  style_name : String?
  attrs : Map[String, String]
}

///|
pub(all) enum AssetKind {
  Image
  Attachment
  Link
  Embedded
  Unknown
} derive(Eq)

///|
/// Referenced binary or logical asset discovered during parsing.
pub(all) struct AssetRef {
  asset_kind : AssetKind
  asset_id : String
  path : String?
  mime_type : String?
  source_ref : SourceRef?
  attrs : Map[String, String]
}

///|
/// Cross-stage diagnostics and execution metadata accumulated along the product
/// path.
pub(all) struct Diagnostics {
  parser_name : String?
  parser_mode : String?
  convert_mode : String?
  fidelity_mode : String?
  output_mode : String?
  input_kind : String?
  detected_format : String?
  warnings : Array[String]
  errors : Array[String]
  degraded_features : Array[String]
  same_mode_degradation : Array[String]
  same_mode_strategy_switches : Array[String]
  fallback_trace : Array[String]
  pass_trace : Array[String]
  metrics : Map[String, String]
  dependency_diagnostics : Array[DependencyDiagnostic]
}

///|
pub(all) enum DependencyDiagnosticStatus {
  Missing
  Available
  Degraded
} derive(Eq)

///|
/// Install or runtime dependency state surfaced with concrete remediation
/// hints.
pub(all) struct DependencyDiagnostic {
  kind : String
  title : String
  summary : String
  status : DependencyDiagnosticStatus
  macos_commands : Array[String]
  ubuntu_commands : Array[String]
  footer : String?
}

///|
/// Minimal JSON value model used in metadata, signals, and debug output.
pub(all) enum JsonValue {
  Object(Map[String, JsonValue])
  Array(Array[JsonValue])
  String(String)
  Number(String)
  Bool(Bool)
  Null
} derive(Eq)

///|
pub(all) enum EventKind {
  StartDocument
  EndDocument
  StartBlock(BlockKind)
  EndBlock(BlockKind)
  Text
  TextLine
  BlankLine
  Cell
  RowBreak
  StructureStart
  StructureEnd
  Key
  Scalar
} derive(Eq)

///|
/// Lowest-common-denominator streaming event used by event parsers and fast
/// render paths.
pub(all) struct CoreEvent {
  kind : EventKind
  text : String
  source_ref : SourceRef?
}
