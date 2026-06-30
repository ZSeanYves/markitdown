///|
pub type LayoutBox = BBox

///|
pub type BlockId = String

///|
pub type HeadingPath = Array[String]

///|
pub type DocumentMetadata = Map[String, JsonValue]

///|
pub(all) enum IRInput {
  EventStream(Array[CoreEvent])
  BlockStream(Array[CoreBlock])
  Document(DocumentIR)
}

///|
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
pub(all) struct CoreSignal {
  signal_type : SignalType
  confidence : Int
  payload : Map[String, JsonValue]
}

///|
pub(all) struct SourceMapEntry {
  primary_ref : SourceRef?
  refs : Array[SourceRef]
  merged_from : Array[SourceRef]
  confidence : Int?
  relation : String?
}

///|
pub(all) struct SourceMap {
  document_ref : SourceRef?
  block_entries : Array[SourceMapEntry]
  asset_entries : Array[SourceMapEntry]
}

///|
pub(all) struct SourceRef {
  file_id : String?
  format : String?
  page : Int?
  bbox : BBox?
  line_start : Int?
  line_end : Int?
  byte_start : Int?
  byte_end : Int?
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
pub(all) struct BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
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
pub(all) struct AssetRef {
  asset_kind : AssetKind
  asset_id : String
  path : String?
  mime_type : String?
  source_ref : SourceRef?
  attrs : Map[String, String]
}

///|
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
  fallback_trace : Array[String]
  pass_trace : Array[String]
  metrics : Map[String, String]
}

///|
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
pub(all) struct CoreEvent {
  kind : EventKind
  text : String
  source_ref : SourceRef?
}
