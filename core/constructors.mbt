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
    column_index: None,
    rich_inlines: None,
    children: [],
    attrs: Map([]),
    source_ref: Some(source_ref),
    compact_source_ref: None,
    style: None,
    signals: [],
  }
}

///|
pub fn make_block_without_source_ref(
  kind : BlockKind,
  text : String,
) -> CoreBlock {
  {
    block_id: make_block_id(kind, text),
    kind,
    text,
    column_index: None,
    rich_inlines: None,
    children: [],
    attrs: Map([]),
    source_ref: None,
    compact_source_ref: None,
    style: None,
    signals: [],
  }
}

///|
pub fn block_with_block_id(block : CoreBlock, block_id : BlockId) -> CoreBlock {
  { ..block, block_id, }
}

///|
pub fn block_with_column_index(
  block : CoreBlock,
  column_index : Int,
) -> CoreBlock {
  { ..block, column_index: Some(column_index) }
}

///|
pub fn block_with_literal_rendering(
  block : CoreBlock,
  minimal_inline_escape? : Bool = false,
) -> CoreBlock {
  match block.compact_source_ref {
    Some(source_ref) =>
      {
        ..block,
        compact_source_ref: Some({
          ..source_ref,
          literal: true,
          minimal_inline_escape,
        }),
      }
    None => {
      let next = { ..block }
      next.attrs.set("literal", "true")
      if minimal_inline_escape {
        next.attrs.set("render_inline_escape_mode", "minimal")
      }
      next
    }
  }
}

///|
pub fn block_is_literal(block : CoreBlock) -> Bool {
  match block.compact_source_ref {
    Some(source_ref) =>
      source_ref.literal || block.attrs.get("literal") == Some("true")
    None => block.attrs.get("literal") == Some("true")
  }
}

///|
pub fn block_inline_escape_mode(block : CoreBlock) -> String? {
  match block.compact_source_ref {
    Some(source_ref) =>
      if source_ref.minimal_inline_escape {
        Some("minimal")
      } else {
        block.attrs.get("render_inline_escape_mode")
      }
    None => block.attrs.get("render_inline_escape_mode")
  }
}

///|
pub fn block_with_rendered_markdown(
  block : CoreBlock,
  rendered_markdown : String,
) -> CoreBlock {
  match block.compact_source_ref {
    Some(source_ref) =>
      {
        ..block,
        compact_source_ref: Some({
          ..source_ref,
          rendered_markdown: Some(rendered_markdown),
        }),
      }
    None => block_with_attr(block, "rendered_markdown", rendered_markdown)
  }
}

///|
pub fn block_rendered_markdown(block : CoreBlock) -> String? {
  match block.compact_source_ref {
    Some(source_ref) =>
      match source_ref.rendered_markdown {
        Some(rendered) => Some(rendered)
        None => block.attrs.get("rendered_markdown")
      }
    None => block.attrs.get("rendered_markdown")
  }
}

///|
pub fn block_with_compact_source_ref(
  block : CoreBlock,
  source_ref : CompactSourceRef,
) -> CoreBlock {
  { ..block, source_ref: None, compact_source_ref: Some(source_ref) }
}

///|
pub fn make_compact_source_ref(
  file_id : String,
  format : String,
  line_start : Int,
  line_end : Int,
  byte_start : Int,
  byte_end : Int,
) -> CompactSourceRef {
  {
    file_id,
    format,
    line_start,
    line_end,
    byte_start,
    byte_end,
    literal: false,
    minimal_inline_escape: false,
    rendered_markdown: None,
  }
}

///|
pub fn block_source_ref(block : CoreBlock) -> SourceRef? {
  match block.source_ref {
    Some(value) => Some(value)
    None =>
      block.compact_source_ref.map(value => {
        ..empty_source_ref(),
        file_id: Some(value.file_id),
        format: Some(value.format),
        line_start: Some(value.line_start),
        line_end: Some(value.line_end),
        byte_start: Some(value.byte_start),
        byte_end: Some(value.byte_end),
      })
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
    kind: Text,
    text,
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_text_without_source_ref(text : String) -> CoreInline {
  {
    kind: Text,
    text,
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: None,
  }
}

///|
pub fn make_inline_line_break(
  source_ref? : SourceRef = empty_source_ref(),
) -> CoreInline {
  {
    kind: LineBreak,
    text: "",
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_line_break_without_source_ref() -> CoreInline {
  {
    kind: LineBreak,
    text: "",
    href: None,
    title: None,
    attrs: Map([]),
    source_ref: None,
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
    kind: Link,
    text,
    href: Some(href),
    title,
    attrs: Map([]),
    source_ref: Some(source_ref),
  }
}

///|
pub fn make_inline_link_without_source_ref(
  text : String,
  href : String,
) -> CoreInline {
  {
    kind: Link,
    text,
    href: Some(href),
    title: None,
    attrs: Map([]),
    source_ref: None,
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
    kind: Image,
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
    kind: Code,
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
    payload: None,
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
    HeadingCandidate => "heading_candidate"
    ListCandidate => "list_candidate"
    TableCandidate => "table_candidate"
    CaptionCandidate => "caption_candidate"
    HeaderFooterCandidate => "header_footer_candidate"
    PageBreak => "page_break"
    SectionBreak => "section_break"
    ReadingOrderHint => "reading_order_hint"
    FontSignal => "font_signal"
    StyleSignal => "style_signal"
    LayoutSignal => "layout_signal"
    OcrSignal => "ocr_signal"
    TableContinuationCandidate => "table_continuation_candidate"
    ArtifactCandidate => "artifact_candidate"
    LanguageHint => "language_hint"
    CodeLanguageHint => "code_language_hint"
    NoteRef => "note_ref"
    CommentRef => "comment_ref"
    RenderHint => "render_hint"
  }
}

///|
pub fn block_kind_name(kind : BlockKind) -> String {
  match kind {
    Document => "document"
    Section => "section"
    Heading => "heading"
    Paragraph => "paragraph"
    List => "list"
    ListItem => "list_item"
    Table => "table"
    TableRow => "table_row"
    TableCell => "table_cell"
    Image => "image"
    Code => "code"
    BlockQuote => "blockquote"
    Raw => "raw"
  }
}

///|
pub fn inline_kind_name(kind : InlineKind) -> String {
  match kind {
    Text => "text"
    LineBreak => "line_break"
    Link => "link"
    Image => "image"
    Code => "code"
  }
}

///|
pub fn asset_kind_name(kind : AssetKind) -> String {
  match kind {
    Image => "image"
    Attachment => "attachment"
    Link => "link"
    Embedded => "embedded"
    Unknown => "unknown"
  }
}
