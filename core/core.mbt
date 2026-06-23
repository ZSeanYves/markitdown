///|
pub type LayoutBox = BBox

///|
pub type DocumentMetadata = Map[String, JsonValue]

///|
pub(all) enum IRInput {
  EventStream(Array[CoreEvent])
  BlockStream(Array[CoreBlock])
  Document(DocumentIR)
  ContainerManifest(ContainerManifest)
  ContainerPlan(ContainerPlan)
}

///|
pub(all) struct DocumentIR {
  blocks : Array[CoreBlock]
  metadata : DocumentMetadata
  diagnostics : Diagnostics
  assets : Array[AssetRef]
  signals : Array[CoreSignal]
  source_map : SourceMap?
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
pub(all) struct ContainerInnerDocument {
  entry : ContainerEntry
  source_name : String
  explicit_detected_format : String?
  inner_source_ref : SourceRef?
}

///|
pub(all) enum ContainerAssetCopyPolicy {
  MaterializeAtOutputBoundary
  ReferenceOnly
  RejectUnsafePath
} derive(Eq)

///|
pub(all) struct ContainerAssetPlan {
  entry_path : String
  output_relative_path : String
  media_type : String?
  size : Int?
  copy_policy : ContainerAssetCopyPolicy
  source_ref : SourceRef?
}

///|
pub(all) struct ContainerPlan {
  container_format : String
  container_path : String?
  ordered_entries : Array[ContainerEntry]
  inner_documents_to_convert : Array[ContainerInnerDocument]
  assets_to_materialize : Array[ContainerAssetPlan]
  skipped_entries : Array[ContainerEntry]
  merged_blocks : Array[CoreBlock]
  merged_assets : Array[AssetRef]
  diagnostics : Diagnostics
  source_ref : SourceRef?
}

///|
pub(all) struct ContainerManifest {
  container_format : String
  container_path : String?
  entries : Array[ContainerEntry]
  selected_entries : Array[ContainerEntry]
  skipped_entries : Array[ContainerEntry]
  diagnostics : Diagnostics
  source_ref : SourceRef?
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
  input_kind : String?
  detected_format : String?
  warnings : Array[String]
  errors : Array[String]
  degraded_features : Array[String]
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

///|
pub fn empty_document_ir() -> DocumentIR {
  {
    blocks: [],
    metadata: Map([]),
    diagnostics: empty_diagnostics(),
    assets: [],
    signals: [],
    source_map: None,
  }
}

///|
pub fn document_from_blocks(blocks : Array[CoreBlock]) -> DocumentIR {
  {
    blocks,
    metadata: Map([]),
    diagnostics: empty_diagnostics(),
    assets: [],
    signals: [],
    source_map: None,
  }
}

///|
pub fn document_with_diagnostics(
  document : DocumentIR,
  diagnostics : Diagnostics,
) -> DocumentIR {
  { ..document, diagnostics, }
}

///|
pub fn document_with_blocks(
  document : DocumentIR,
  blocks : Array[CoreBlock],
) -> DocumentIR {
  { ..document, blocks, }
}

///|
pub fn document_with_assets(
  document : DocumentIR,
  assets : Array[AssetRef],
) -> DocumentIR {
  { ..document, assets, }
}

///|
pub fn document_with_metadata(
  document : DocumentIR,
  metadata : DocumentMetadata,
) -> DocumentIR {
  { ..document, metadata, }
}

///|
pub fn document_with_signals(
  document : DocumentIR,
  signals : Array[CoreSignal],
) -> DocumentIR {
  { ..document, signals, }
}

///|
pub fn document_with_source_map(
  document : DocumentIR,
  source_map : SourceMap?,
) -> DocumentIR {
  { ..document, source_map, }
}

///|
pub fn empty_diagnostics() -> Diagnostics {
  {
    parser_name: None,
    parser_mode: None,
    convert_mode: None,
    input_kind: None,
    detected_format: None,
    warnings: [],
    errors: [],
    degraded_features: [],
    fallback_trace: [],
    pass_trace: [],
    metrics: Map([]),
  }
}

///|
pub fn diagnostics_with_parser(
  diagnostics : Diagnostics,
  parser_name : String?,
  parser_mode : String?,
) -> Diagnostics {
  { ..diagnostics, parser_name, parser_mode }
}

///|
pub fn diagnostics_with_mode(
  diagnostics : Diagnostics,
  parser_mode : String?,
  convert_mode : String?,
) -> Diagnostics {
  { ..diagnostics, parser_mode, convert_mode }
}

///|
pub fn diagnostics_with_input(
  diagnostics : Diagnostics,
  input_kind : String?,
  detected_format : String?,
) -> Diagnostics {
  { ..diagnostics, input_kind, detected_format }
}

///|
pub fn diagnostics_add_metric(
  diagnostics : Diagnostics,
  key : String,
  value : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.metrics.set(key, value)
  next
}

///|
pub fn diagnostics_add_warning(
  diagnostics : Diagnostics,
  warning : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.warnings.push(warning)
  next
}

///|
pub fn diagnostics_add_error(
  diagnostics : Diagnostics,
  error : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.errors.push(error)
  next
}

///|
pub fn diagnostics_add_degraded_feature(
  diagnostics : Diagnostics,
  feature : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.degraded_features.push(feature)
  next
}

///|
pub fn diagnostics_add_fallback_trace(
  diagnostics : Diagnostics,
  trace : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.fallback_trace.push(trace)
  next
}

///|
pub fn diagnostics_add_pass_trace(
  diagnostics : Diagnostics,
  trace : String,
) -> Diagnostics {
  let next = { ..diagnostics }
  next.pass_trace.push(trace)
  next
}

///|
pub fn empty_source_ref() -> SourceRef {
  {
    file_id: None,
    format: None,
    page: None,
    bbox: None,
    line_start: None,
    line_end: None,
    byte_start: None,
    byte_end: None,
    xpath: None,
    json_pointer: None,
    yaml_path: None,
    html_path: None,
    markdown_path: None,
    container_path: None,
    entry_path: None,
    entry_index: None,
    entry_format: None,
    inner_path: None,
    sheet: None,
    cell_range: None,
    slide: None,
    shape_id: None,
    relationship_id: None,
    chapter_href: None,
    extra: Map([]),
  }
}

///|
pub fn empty_source_map() -> SourceMap {
  { document_ref: None, block_entries: [], asset_entries: [] }
}

///|
pub fn source_ref_with_lines(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  line_start : Int?,
  line_end : Int?,
) -> SourceRef {
  { ..source_ref, file_id, format, line_start, line_end }
}

///|
pub fn source_ref_with_json_pointer(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  json_pointer : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, json_pointer }
}

///|
pub fn source_ref_with_yaml_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  yaml_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, yaml_path }
}

///|
pub fn source_ref_with_html_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  html_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, html_path }
}

///|
pub fn source_ref_with_markdown_path(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  markdown_path : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, markdown_path }
}

///|
pub fn source_ref_with_container_entry(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  container_path : String?,
  entry_path : String?,
  entry_index : Int?,
  entry_format : String?,
  inner_path : String?,
) -> SourceRef {
  {
    ..source_ref,
    file_id,
    format,
    container_path,
    entry_path,
    entry_index,
    entry_format,
    inner_path,
  }
}

///|
pub fn make_container_entry(
  entry_path : String,
  entry_kind : ContainerEntryKind,
  normalized_path? : String? = None,
  entry_index? : Int? = None,
  detected_format? : String? = None,
  media_type? : String? = None,
  compressed_size? : Int? = None,
  uncompressed_size? : Int? = None,
  is_encrypted? : Bool = false,
  compression_method? : String? = None,
  crc? : String? = None,
  source_ref? : SourceRef? = None,
  security_findings? : Array[ContainerSecurityFinding] = [],
) -> ContainerEntry {
  {
    entry_path,
    normalized_path,
    entry_index,
    entry_kind,
    detected_format,
    media_type,
    compressed_size,
    uncompressed_size,
    is_encrypted,
    compression_method,
    crc,
    source_ref,
    security_findings,
  }
}

///|
pub fn make_container_inner_document(
  entry : ContainerEntry,
  source_name : String,
  explicit_detected_format? : String? = None,
  inner_source_ref? : SourceRef? = None,
) -> ContainerInnerDocument {
  { entry, source_name, explicit_detected_format, inner_source_ref }
}

///|
pub fn make_container_asset_plan(
  entry_path : String,
  output_relative_path : String,
  media_type? : String? = None,
  size? : Int? = None,
  copy_policy? : ContainerAssetCopyPolicy = ContainerAssetCopyPolicy::MaterializeAtOutputBoundary,
  source_ref? : SourceRef? = None,
) -> ContainerAssetPlan {
  {
    entry_path,
    output_relative_path,
    media_type,
    size,
    copy_policy,
    source_ref,
  }
}

///|
pub fn make_container_manifest(
  container_format : String,
  entries : Array[ContainerEntry],
  container_path? : String? = None,
  selected_entries? : Array[ContainerEntry] = [],
  skipped_entries? : Array[ContainerEntry] = [],
  diagnostics? : Diagnostics = empty_diagnostics(),
  source_ref? : SourceRef? = None,
) -> ContainerManifest {
  {
    container_format,
    container_path,
    entries,
    selected_entries,
    skipped_entries,
    diagnostics,
    source_ref,
  }
}

///|
pub fn make_container_plan(
  container_format : String,
  ordered_entries : Array[ContainerEntry],
  inner_documents_to_convert : Array[ContainerInnerDocument],
  assets_to_materialize : Array[ContainerAssetPlan],
  container_path? : String? = None,
  skipped_entries? : Array[ContainerEntry] = [],
  merged_blocks? : Array[CoreBlock] = [],
  merged_assets? : Array[AssetRef] = [],
  diagnostics? : Diagnostics = empty_diagnostics(),
  source_ref? : SourceRef? = None,
) -> ContainerPlan {
  {
    container_format,
    container_path,
    ordered_entries,
    inner_documents_to_convert,
    assets_to_materialize,
    skipped_entries,
    merged_blocks,
    merged_assets,
    diagnostics,
    source_ref,
  }
}

///|
pub fn container_entry_kind_name(kind : ContainerEntryKind) -> String {
  match kind {
    ContainerEntryKind::Document => "document"
    ContainerEntryKind::Asset => "asset"
    ContainerEntryKind::Metadata => "metadata"
    ContainerEntryKind::Directory => "directory"
    ContainerEntryKind::Unsupported => "unsupported"
    ContainerEntryKind::Unsafe => "unsafe"
  }
}

///|
pub fn container_security_finding_name(
  finding : ContainerSecurityFinding,
) -> String {
  match finding {
    ContainerSecurityFinding::PathTraversal => "path_traversal"
    ContainerSecurityFinding::AbsolutePath => "absolute_path"
    ContainerSecurityFinding::EncryptedEntry => "encrypted_entry"
    ContainerSecurityFinding::UnsupportedCompression =>
      "unsupported_compression"
    ContainerSecurityFinding::CompressionRatioLimit => "compression_ratio_limit"
    ContainerSecurityFinding::DuplicateNormalizedPath =>
      "duplicate_normalized_path"
    ContainerSecurityFinding::NestedArchive => "nested_archive"
    ContainerSecurityFinding::ExternalReference => "external_reference"
    ContainerSecurityFinding::ResourceLimitHit => "resource_limit_hit"
  }
}

///|
pub fn container_asset_copy_policy_name(
  policy : ContainerAssetCopyPolicy,
) -> String {
  match policy {
    ContainerAssetCopyPolicy::MaterializeAtOutputBoundary =>
      "materialize_at_output_boundary"
    ContainerAssetCopyPolicy::ReferenceOnly => "reference_only"
    ContainerAssetCopyPolicy::RejectUnsafePath => "reject_unsafe_path"
  }
}

///|
pub fn source_ref_with_bytes(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  byte_start : Int?,
  byte_end : Int?,
) -> SourceRef {
  { ..source_ref, file_id, format, byte_start, byte_end }
}

///|
pub fn source_ref_with_cell_range(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  cell_range : String?,
) -> SourceRef {
  { ..source_ref, file_id, format, cell_range }
}

///|
pub fn source_ref_with_office_fields(
  source_ref : SourceRef,
  file_id : String?,
  format : String?,
  inner_path : String?,
  sheet : String?,
  cell_range : String?,
  slide : Int?,
  shape_id : String?,
  relationship_id : String?,
) -> SourceRef {
  {
    ..source_ref,
    file_id,
    format,
    inner_path,
    sheet,
    cell_range,
    slide,
    shape_id,
    relationship_id,
  }
}

///|
pub fn source_ref_with_extra(
  source_ref : SourceRef,
  key : String,
  value : String,
) -> SourceRef {
  let next = { ..source_ref }
  next.extra.set(key, value)
  next
}

///|
pub fn make_block(
  kind : BlockKind,
  text : String,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreBlock {
  {
    kind,
    text,
    rich_inlines: None,
    children: [],
    attrs: Map([]),
    source_ref: Some(source_ref),
    style: None,
    signals: [],
  }
}

///|
pub fn block_with_rich_inlines(
  block : CoreBlock,
  rich_inlines : Array[CoreInline]?,
) -> CoreBlock {
  { ..block, rich_inlines, }
}

///|
pub fn block_with_children(
  block : CoreBlock,
  children : Array[CoreBlock],
) -> CoreBlock {
  { ..block, children, }
}

///|
pub fn block_with_attr(
  block : CoreBlock,
  key : String,
  value : String,
) -> CoreBlock {
  let next = { ..block }
  next.attrs.set(key, value)
  next
}

///|
pub fn block_with_signals(
  block : CoreBlock,
  signals : Array[CoreSignal],
) -> CoreBlock {
  { ..block, signals, }
}

///|
pub fn make_inline_text(
  text : String,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: InlineKind::Text,
    text,
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_line_break(
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: InlineKind::LineBreak,
    text: "",
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_link(
  text : String,
  href : String,
  title? : String? = None,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: InlineKind::Link,
    text,
    href: Some(href),
    title,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_image(
  alt : String,
  path : String,
  title? : String? = None,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: InlineKind::Image,
    text: alt,
    href: Some(path),
    title,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_code(
  text : String,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: InlineKind::Code,
    text,
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn inline_with_attr(
  inline : CoreInline,
  key : String,
  value : String,
) -> CoreInline {
  let next = { ..inline }
  next.attrs.set(key, value)
  next
}

///|
pub fn make_asset_ref(
  asset_kind : AssetKind,
  asset_id : String,
  source_ref? : SourceRef = empty_source_ref(),
) -> AssetRef {
  {
    asset_kind,
    asset_id,
    path: None,
    mime_type: None,
    source_ref: Some(source_ref),
    attrs: Map([]),
  }
}

///|
pub fn make_signal(
  signal_type : SignalType,
  confidence : Int,
  payload? : Map[String, JsonValue] = Map([]),
) -> CoreSignal {
  { signal_type, confidence, payload }
}

///|
pub fn make_source_map_entry(
  primary_ref? : SourceRef? = None,
  refs? : Array[SourceRef] = [],
  merged_from? : Array[SourceRef] = [],
  confidence? : Int? = None,
  relation? : String? = None,
) -> SourceMapEntry {
  { primary_ref, refs, merged_from, confidence, relation }
}

///|
pub fn source_map_with_document_ref(
  source_map : SourceMap,
  document_ref : SourceRef?,
) -> SourceMap {
  { ..source_map, document_ref, }
}

///|
pub fn source_map_add_block_entry(
  source_map : SourceMap,
  entry : SourceMapEntry,
) -> SourceMap {
  let next = { ..source_map }
  next.block_entries.push(entry)
  next
}

///|
pub fn source_map_add_asset_entry(
  source_map : SourceMap,
  entry : SourceMapEntry,
) -> SourceMap {
  let next = { ..source_map }
  next.asset_entries.push(entry)
  next
}

///|
pub fn signal_type_name(signal_type : SignalType) -> String {
  match signal_type {
    SignalType::HeadingCandidate => "heading_candidate"
    SignalType::ListCandidate => "list_candidate"
    SignalType::TableCandidate => "table_candidate"
    SignalType::CaptionCandidate => "caption_candidate"
    SignalType::HeaderFooterCandidate => "header_footer_candidate"
    SignalType::PageBreak => "page_break"
    SignalType::SectionBreak => "section_break"
    SignalType::ReadingOrderHint => "reading_order_hint"
    SignalType::FontSignal => "font_signal"
    SignalType::StyleSignal => "style_signal"
    SignalType::LayoutSignal => "layout_signal"
    SignalType::OcrSignal => "ocr_signal"
    SignalType::TableContinuationCandidate => "table_continuation_candidate"
    SignalType::ArtifactCandidate => "artifact_candidate"
    SignalType::LanguageHint => "language_hint"
    SignalType::CodeLanguageHint => "code_language_hint"
    SignalType::NoteRef => "note_ref"
    SignalType::CommentRef => "comment_ref"
    SignalType::RenderHint => "render_hint"
  }
}

///|
pub fn block_kind_name(kind : BlockKind) -> String {
  match kind {
    BlockKind::Document => "document"
    BlockKind::Section => "section"
    BlockKind::Heading => "heading"
    BlockKind::Paragraph => "paragraph"
    BlockKind::List => "list"
    BlockKind::ListItem => "list_item"
    BlockKind::Table => "table"
    BlockKind::TableRow => "table_row"
    BlockKind::TableCell => "table_cell"
    BlockKind::Image => "image"
    BlockKind::Code => "code"
    BlockKind::BlockQuote => "blockquote"
    BlockKind::Raw => "raw"
  }
}

///|
pub fn inline_kind_name(kind : InlineKind) -> String {
  match kind {
    InlineKind::Text => "text"
    InlineKind::LineBreak => "line_break"
    InlineKind::Link => "link"
    InlineKind::Image => "image"
    InlineKind::Code => "code"
  }
}

///|
pub fn asset_kind_name(kind : AssetKind) -> String {
  match kind {
    AssetKind::Image => "image"
    AssetKind::Attachment => "attachment"
    AssetKind::Link => "link"
    AssetKind::Embedded => "embedded"
    AssetKind::Unknown => "unknown"
  }
}
