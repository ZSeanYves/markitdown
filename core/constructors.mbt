///|
pub fn make_block(
  kind : BlockKind,
  text : String,
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreBlock {
  {
    block_id: make_block_id(kind, text, source_ref=Some(source_ref)),
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
pub fn block_with_block_id(block : CoreBlock, block_id : BlockId) -> CoreBlock {
  { ..block, block_id, }
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
pub fn make_block_id(
  kind : BlockKind,
  text : String,
  source_ref? : SourceRef? = None,
) -> BlockId {
  finish_block_id(make_block_content_crc(kind, text), source_ref)
}

///|
pub fn make_block_content_crc(kind : BlockKind, text : String) -> UInt {
  let mut crc = crc32_init()
  crc = crc32_append_string(crc, block_kind_name(kind))
  crc = crc32_append_separator(crc)
  crc = crc32_append_string(crc, text)
  crc = crc32_append_separator(crc)
  crc
}

///|
pub fn finish_block_id(content_crc : UInt, source_ref : SourceRef?) -> BlockId {
  let crc = crc32_append_source_ref_signature(content_crc, source_ref)
  "b_" + crc32_finish(crc).to_string()
}

///|
fn crc32_append_source_ref_signature(
  crc : UInt,
  source_ref : SourceRef?,
) -> UInt {
  match source_ref {
    Some(value) => {
      let mut next = crc
      next = crc32_append_optional_string(next, value.file_id)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.format)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.page)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.line_start)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.line_end)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.byte_start)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.byte_end)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.time_start)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.time_end)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.xpath)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.json_pointer)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.yaml_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.html_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.markdown_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.container_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.entry_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.inner_path)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.sheet)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.cell_range)
      next = crc32_append_separator(next)
      next = crc32_append_optional_int(next, value.slide)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.shape_id)
      next = crc32_append_separator(next)
      next = crc32_append_optional_string(next, value.relationship_id)
      next = crc32_append_separator(next)
      crc32_append_optional_string(next, value.chapter_href)
    }
    None => crc
  }
}

///|
fn crc32_append_optional_string(crc : UInt, value : String?) -> UInt {
  match value {
    Some(text) => crc32_append_string(crc, text)
    None => crc
  }
}

///|
fn crc32_append_optional_int(crc : UInt, value : Int?) -> UInt {
  match value {
    Some(number) => crc32_append_string(crc, number.to_string())
    None => crc
  }
}

///|
fn crc32_init() -> UInt {
  0xFFFFFFFF
}

///|
fn crc32_finish(crc : UInt) -> UInt {
  UInt::lxor(crc, 0xFFFFFFFF)
}

///|
fn crc32_append_separator(crc : UInt) -> UInt {
  crc32_update_uint(crc, '|'.to_int().reinterpret_as_uint())
}

///|
fn crc32_append_string(crc : UInt, text : String) -> UInt {
  let mut next = crc
  for ch in text.to_array() {
    next = crc32_update_uint(next, ch.to_int().reinterpret_as_uint())
  }
  next
}

///|
fn crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
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
