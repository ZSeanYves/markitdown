///|
/// Shared rectangle alias used by layout-aware formats and OCR helpers.
pub type LayoutBox = BBox

///|
/// Stable identifier type for one block inside `DocumentIR`.
pub type BlockId = String

///|
/// Hierarchical heading trail such as `["Chapter 1", "Section 2"]`.
pub type HeadingPath = Array[String]

///|
/// Format-neutral metadata map attached to the document root.
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
/// Block categories used by the canonical IR tree.
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
/// `children` carries nested structure, `attrs` holds stable string metadata,
/// and `signals` preserves extra parser/pipeline hints for later passes.
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
/// One recovered section node inside `DocumentAssembly`.
///
/// The section tree is stored separately from `blocks` so renderers and
/// provenance code can reason about heading hierarchy without rescanning the
/// block list.
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
/// Link between a recovered caption block and the block it describes.
pub(all) struct CaptionBinding {
  caption_block_id : BlockId
  target_block_id : BlockId
  relation : String
  confidence : Int?
}

///|
/// Relationship between split table fragments that were recovered as one
/// logical table.
pub(all) struct TableContinuation {
  table_block_id : BlockId
  continues_from_block_id : BlockId?
  relation : String
  confidence : Int?
}

///|
/// One normalized reading-order entry emitted by pipeline assembly.
pub(all) struct ReadingOrderEntry {
  block_id : BlockId
  ordinal : Int
  page : Int?
  slide : Int?
  sheet : String?
}

///|
/// Relationship between an extracted asset and the block that owns or mentions
/// it.
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
/// Inline categories preserved by richer parsers and renderers.
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
///
/// `href` and `title` are used by link/image-like nodes, while `attrs` keeps
/// extra stable annotations such as language or emphasis markers.
pub(all) struct CoreInline {
  kind : InlineKind
  text : String
  href : String?
  title : String?
  attrs : Map[String, String]
  source_ref : SourceRef?
}

///|
/// Semantic hint categories emitted by parsers or inferred during pipeline
/// recovery.
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
///
/// `confidence` stays intentionally coarse, and `payload` carries
/// format-specific evidence without expanding the public enum every time.
pub(all) struct CoreSignal {
  signal_type : SignalType
  confidence : Int
  payload : Map[String, JsonValue]
}

///|
/// Provenance for one public block or asset entry in a `SourceMap`.
///
/// `primary_ref` is the main location shown to users, `refs` stores all
/// equivalent references, and `merged_from` preserves source collapse history.
pub(all) struct SourceMapEntry {
  primary_ref : SourceRef?
  refs : Array[SourceRef]
  merged_from : Array[SourceRef]
  confidence : Int?
  relation : String?
}

///|
/// Public-facing provenance map kept alongside a `DocumentIR`.
///
/// `block_entries` and `asset_entries` are index-aligned with the exported
/// block and asset lists rather than keyed by raw parser internals.
pub(all) struct SourceMap {
  document_ref : SourceRef?
  block_entries : Array[SourceMapEntry]
  asset_entries : Array[SourceMapEntry]
}

///|
/// A location pointer that can target files, pages, slides, sheets, archive
/// entries, markup paths, or media time ranges.
///
/// Different formats populate different subsets of fields; absent fields mean
/// “not applicable”, not “unknown”.
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
/// Canonical kinds assigned to normalized container entries.
pub(all) enum ContainerEntryKind {
  Document
  Asset
  Metadata
  Directory
  Unsupported
  Unsafe
} derive(Eq)

///|
/// Security findings that can be attached to container or package entries.
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
///
/// `entry_path` keeps the raw archive path, `normalized_path` keeps the safe
/// normalized form, and `security_findings` records why an entry may be
/// rejected or downgraded.
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
///
/// Coordinates use the source format's local coordinate system and are not
/// normalized to screen pixels.
pub(all) struct BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// Lightweight recovered style identity attached to a block.
///
/// `attrs` holds extra stable style attributes when a dedicated field would be
/// too format-specific.
pub(all) struct StyleRef {
  style_id : String?
  style_name : String?
  attrs : Map[String, String]
}

///|
/// Asset categories exposed by the public document model.
pub(all) enum AssetKind {
  Image
  Attachment
  Link
  Embedded
  Unknown
} derive(Eq)

///|
/// Referenced binary or logical asset discovered during parsing.
///
/// `path` is the suggested relative output path when one exists, while
/// `attrs` can carry stable metadata such as size, role, or original filename.
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
///
/// The arrays preserve user-facing warnings, degradation traces, and fallback
/// history, while `metrics` is reserved for stable stringified counters and
/// switches.
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
/// Availability state for an external runtime or install dependency.
pub(all) enum DependencyDiagnosticStatus {
  Missing
  Available
  Degraded
} derive(Eq)

///|
/// Install or runtime dependency state surfaced with concrete remediation
/// hints.
///
/// The shell command lists are intentionally platform-specific so CLI and test
/// surfaces can render actionable guidance without inventing new text.
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
/// Event kinds used by streaming parsers and fast-path renderers.
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
///
/// `text` is the event payload, while `source_ref` lets streaming outputs keep
/// provenance without first materializing blocks.
pub(all) struct CoreEvent {
  kind : EventKind
  text : String
  source_ref : SourceRef?
}
