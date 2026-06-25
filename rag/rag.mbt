///|
pub struct RagOptions {
  chunk_size : Int
  chunk_overlap : Int
  preserve_heading_path : Bool
  preserve_source_ref : Bool
  split_tables : Bool
  split_code_blocks : Bool
}

///|
pub(all) enum ChunkKind {
  Text
  Table
  Code
  ImageCaption
  Metadata
  Raw
} derive(Eq)

///|
pub struct RagChunk {
  id : String
  kind : ChunkKind
  text : String
  heading_path : Array[String]
  source_refs : Array[@core.SourceRef]
  asset_refs : Array[String]
  metadata : Map[String, @core.JsonValue]
}

///|
pub fn default_rag_options() -> RagOptions {
  {
    chunk_size: 1200,
    chunk_overlap: 150,
    preserve_heading_path: true,
    preserve_source_ref: true,
    split_tables: true,
    split_code_blocks: true,
  }
}

///|
pub fn make_rag_options(
  chunk_size : Int,
  chunk_overlap : Int,
  preserve_heading_path : Bool,
  preserve_source_ref : Bool,
  split_tables : Bool,
  split_code_blocks : Bool,
) -> RagOptions {
  {
    chunk_size: rag_chunk_size_or_default(chunk_size),
    chunk_overlap: rag_chunk_overlap_or_default(chunk_overlap),
    preserve_heading_path,
    preserve_source_ref,
    split_tables,
    split_code_blocks,
  }
}

///|
pub fn rag_chunk_size_or_default(value : Int) -> Int {
  if value <= 0 {
    default_rag_options().chunk_size
  } else {
    value
  }
}

///|
pub fn rag_chunk_overlap_or_default(value : Int) -> Int {
  if value < 0 {
    default_rag_options().chunk_overlap
  } else {
    value
  }
}

///|
pub fn chunk_kind_name(kind : ChunkKind) -> String {
  match kind {
    ChunkKind::Text => "text"
    ChunkKind::Table => "table"
    ChunkKind::Code => "code"
    ChunkKind::ImageCaption => "image_caption"
    ChunkKind::Metadata => "metadata"
    ChunkKind::Raw => "raw"
  }
}

///|
pub fn rag_chunk_char_count(chunk : RagChunk) -> Int {
  unicode_char_count(chunk.text)
}

///|
pub fn rag_chunk_text_total_chars(chunks : Array[RagChunk]) -> Int {
  let mut total = 0
  for chunk in chunks {
    total += rag_chunk_char_count(chunk)
  }
  total
}

///|
pub fn chunks_from_document(
  document : @core.DocumentIR,
  options : RagOptions,
) -> Array[RagChunk] {
  let normalized_options = normalize_rag_options(options)
  let document_format = match
    json_value_string(document.metadata.get("format")) {
    Some(value) => value
    None => document.diagnostics.detected_format.unwrap_or("")
  }
  let document_title = metadata_title(document.metadata)
  let chunks : Array[RagChunk] = []
  let mut ordinal = 0
  let assembly_heading_paths = document_assembly_heading_paths(document)
  let mut heading_path : Array[String] = []

  match
    metadata_chunk(
      document, normalized_options, ordinal, document_format, document_title,
    ) {
    Some(chunk) => {
      chunks.push(chunk)
      ordinal += 1
    }
    None => ()
  }

  let text_units : Array[ChunkUnit] = []
  let text_source_refs : Array[@core.SourceRef] = []
  let text_asset_refs : Array[String] = []
  let mut text_char_count = 0
  let mut text_location_key = ""
  let mut text_heading_path : Array[String] = []
  let mut text_contains_raw = false

  fn flush_text_chunks(
    chunks : Array[RagChunk],
    text_units : Array[ChunkUnit],
    text_source_refs : Array[@core.SourceRef],
    text_asset_refs : Array[String],
    text_heading_path : Array[String],
    text_char_count : Int,
    text_contains_raw : Bool,
    ordinal : Int,
    document_format : String,
    document_title : String?,
    options : RagOptions,
  ) -> Int {
    if text_units.length() == 0 || text_char_count <= 0 {
      return ordinal
    }
    let text_chunks = build_text_chunks(
      text_units, text_source_refs, text_asset_refs, text_heading_path, text_contains_raw,
      ordinal, document_format, document_title, options,
    )
    for chunk in text_chunks {
      chunks.push(chunk)
    }
    ordinal + text_chunks.length()
  }

  fn reset_text_accumulators(
    text_units : Array[ChunkUnit],
    text_source_refs : Array[@core.SourceRef],
    text_asset_refs : Array[String],
  ) -> Unit {
    text_units.clear()
    text_source_refs.clear()
    text_asset_refs.clear()
  }

  fn flush_special_chunks(
    chunks : Array[RagChunk],
    block : @core.CoreBlock,
    heading_path : Array[String],
    ordinal : Int,
    document_format : String,
    document_title : String?,
    options : RagOptions,
    assets : Array[@core.AssetRef],
  ) -> Int {
    let special_chunks = block_to_special_chunks(
      block, heading_path, ordinal, document_format, document_title, options, assets,
    )
    for chunk in special_chunks {
      chunks.push(chunk)
    }
    ordinal + special_chunks.length()
  }

  for block in document.blocks {
    if block.kind == @core.BlockKind::Heading {
      ordinal = flush_text_chunks(
        chunks, text_units, text_source_refs, text_asset_refs, text_heading_path,
        text_char_count, text_contains_raw, ordinal, document_format, document_title,
        normalized_options,
      )
      reset_text_accumulators(text_units, text_source_refs, text_asset_refs)
      text_char_count = 0
      text_location_key = ""
      text_heading_path = []
      text_contains_raw = false
      heading_path = block_heading_path(
        document, assembly_heading_paths, block, heading_path,
      )
      continue
    }
    let block_heading = block_heading_path(
      document, assembly_heading_paths, block, heading_path,
    )

    let location_key = block_location_bucket(block)
    let text_unit = block_to_text_unit(block)
    match text_unit {
      Some(unit) => {
        let next_heading_path = if text_heading_path.length() == 0 {
          block_heading.copy()
        } else {
          text_heading_path
        }
        if text_units.length() > 0 &&
          (
            text_location_key != location_key ||
            !string_arrays_eq(text_heading_path, block_heading) ||
            text_char_count + unit.char_count > normalized_options.chunk_size
          ) {
          ordinal = flush_text_chunks(
            chunks, text_units, text_source_refs, text_asset_refs, text_heading_path,
            text_char_count, text_contains_raw, ordinal, document_format, document_title,
            normalized_options,
          )
          reset_text_accumulators(text_units, text_source_refs, text_asset_refs)
          text_char_count = 0
          text_location_key = ""
          text_heading_path = []
          text_contains_raw = false
        }
        if text_units.length() == 0 {
          text_location_key = location_key
          text_heading_path = block_heading.copy()
        } else {
          text_heading_path = next_heading_path
        }
        text_units.push(unit)
        append_unique_source_ref(
          text_source_refs,
          block.source_ref,
          normalized_options.preserve_source_ref,
        )
        let block_asset_refs = block_asset_refs(block, document.assets)
        append_unique_strings(text_asset_refs, block_asset_refs)
        text_char_count += unit.char_count
        text_contains_raw = text_contains_raw ||
          block.kind == @core.BlockKind::Raw
      }
      None => {
        ordinal = flush_text_chunks(
          chunks, text_units, text_source_refs, text_asset_refs, text_heading_path,
          text_char_count, text_contains_raw, ordinal, document_format, document_title,
          normalized_options,
        )
        reset_text_accumulators(text_units, text_source_refs, text_asset_refs)
        text_char_count = 0
        text_location_key = ""
        text_heading_path = []
        text_contains_raw = false
        ordinal = flush_special_chunks(
          chunks,
          block,
          block_heading,
          ordinal,
          document_format,
          document_title,
          normalized_options,
          document.assets,
        )
      }
    }
  }

  ignore(
    flush_text_chunks(
      chunks, text_units, text_source_refs, text_asset_refs, text_heading_path, text_char_count,
      text_contains_raw, ordinal, document_format, document_title, normalized_options,
    ),
  )
  chunks
}

///|
pub fn rag_location_metadata(
  source_refs : Array[@core.SourceRef],
) -> Map[String, @core.JsonValue] {
  let pages : Array[String] = []
  let slides : Array[String] = []
  let sheets : Array[String] = []
  let cell_ranges : Array[String] = []
  let entry_paths : Array[String] = []
  let container_paths : Array[String] = []
  let chapter_hrefs : Array[String] = []
  for source_ref in source_refs {
    append_unique_optional_string(
      pages,
      source_ref.page.map(i => i.to_string()),
    )
    append_unique_optional_string(
      slides,
      source_ref.slide.map(i => i.to_string()),
    )
    append_unique_optional_string(sheets, source_ref.sheet)
    append_unique_optional_string(cell_ranges, source_ref.cell_range)
    append_unique_optional_string(entry_paths, source_ref.entry_path)
    append_unique_optional_string(container_paths, source_ref.container_path)
    append_unique_optional_string(chapter_hrefs, source_ref.chapter_href)
  }
  let metadata : Map[String, @core.JsonValue] = Map([])
  if pages.length() > 0 {
    metadata.set("pages", string_json_array(pages))
  }
  if slides.length() > 0 {
    metadata.set("slides", string_json_array(slides))
  }
  if sheets.length() > 0 {
    metadata.set("sheets", string_json_array(sheets))
  }
  if cell_ranges.length() > 0 {
    metadata.set("cell_ranges", string_json_array(cell_ranges))
  }
  if entry_paths.length() > 0 {
    metadata.set("entry_paths", string_json_array(entry_paths))
  }
  if container_paths.length() > 0 {
    metadata.set("container_paths", string_json_array(container_paths))
  }
  if chapter_hrefs.length() > 0 {
    metadata.set("chapter_hrefs", string_json_array(chapter_hrefs))
  }
  metadata
}

///|
pub fn rag_metadata_fields(
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  document_format : String,
  document_title : String?,
  block_kinds : Array[String],
  source_refs : Array[@core.SourceRef],
  asset_refs : Array[String],
) -> Map[String, @core.JsonValue] {
  let metadata : Map[String, @core.JsonValue] = Map([])
  metadata.set("ordinal", @core.JsonValue::Number(ordinal.to_string()))
  metadata.set(
    "char_count",
    @core.JsonValue::Number(unicode_char_count(text).to_string()),
  )
  metadata.set(
    "heading_depth",
    @core.JsonValue::Number(heading_path.length().to_string()),
  )
  metadata.set("document_format", @core.JsonValue::String(document_format))
  match document_title {
    Some(title) if title.trim() != "" =>
      metadata.set("document_title", @core.JsonValue::String(title))
    _ => ()
  }
  metadata.set("block_kinds", string_json_array(block_kinds))
  metadata.set(
    "source_count",
    @core.JsonValue::Number(source_refs.length().to_string()),
  )
  metadata.set(
    "asset_count",
    @core.JsonValue::Number(asset_refs.length().to_string()),
  )
  metadata.set(
    "location",
    @core.JsonValue::Object(rag_location_metadata(source_refs)),
  )
  metadata
}

///|
pub fn normalize_rag_options(options : RagOptions) -> RagOptions {
  {
    chunk_size: rag_chunk_size_or_default(options.chunk_size),
    chunk_overlap: rag_chunk_overlap_or_default(options.chunk_overlap),
    preserve_heading_path: options.preserve_heading_path,
    preserve_source_ref: options.preserve_source_ref,
    split_tables: options.split_tables,
    split_code_blocks: options.split_code_blocks,
  }
}

///|
priv struct ChunkUnit {
  text : String
  char_count : Int
  block_kind : String
}

///|
fn metadata_title(metadata : Map[String, @core.JsonValue]) -> String? {
  for key in ["title", "subject", "description"] {
    match json_value_string(metadata.get(key)) {
      Some(value) if value.trim() != "" => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn metadata_chunk(
  document : @core.DocumentIR,
  options : RagOptions,
  ordinal : Int,
  document_format : String,
  document_title : String?,
) -> RagChunk? {
  let fields : Array[String] = []
  let metadata_map : Map[String, @core.JsonValue] = Map([])
  for key in metadata_chunk_keys() {
    match document.metadata.get(key) {
      Some(value) => {
        metadata_map.set(key, value)
        match json_value_string(Some(value)) {
          Some(text) if text.trim() != "" => fields.push(key + ": " + text)
          _ => ()
        }
      }
      None => ()
    }
  }
  if fields.length() == 0 {
    return None
  }
  let text = fields.join("\n")
  let source_refs : Array[@core.SourceRef] = []
  let asset_refs : Array[String] = []
  let heading_path : Array[String] = if options.preserve_heading_path {
    []
  } else {
    []
  }
  let chunk_metadata = rag_metadata_fields(
    ordinal,
    text,
    heading_path,
    document_format,
    document_title,
    ["metadata"],
    source_refs,
    asset_refs,
  )
  for entry in metadata_map.to_array() {
    chunk_metadata.set("meta_" + entry.0, entry.1)
  }
  Some({
    id: make_chunk_id(
      ChunkKind::Metadata,
      ordinal,
      text,
      heading_path,
      source_refs,
    ),
    kind: ChunkKind::Metadata,
    text,
    heading_path,
    source_refs,
    asset_refs,
    metadata: chunk_metadata,
  })
}

///|
fn metadata_chunk_keys() -> Array[String] {
  [
    "title", "subject", "creator", "author", "keywords", "description", "category",
    "company", "manager", "application", "created", "modified",
  ]
}

///|
fn update_heading_path(
  current : Array[String],
  block : @core.CoreBlock,
) -> Array[String] {
  let next = current.copy()
  let level = block.attrs
    .get("level")
    .map(value => @string.parse_int(value) catch { _ => 1 })
    .unwrap_or(1)
  let heading = block_plain_text(block).trim().to_owned()
  let normalized_level = if level <= 0 { 1 } else { level }
  while next.length() >= normalized_level {
    ignore(next.pop())
  }
  next.push(heading)
  next
}

///|
fn document_assembly_heading_paths(
  document : @core.DocumentIR,
) -> Map[String, Array[String]] {
  match document.assembly {
    Some(assembly) => assembly.heading_paths
    None => Map([])
  }
}

///|
fn block_heading_path(
  document : @core.DocumentIR,
  assembly_heading_paths : Map[String, Array[String]],
  block : @core.CoreBlock,
  current : Array[String],
) -> Array[String] {
  if !document_has_assembly_heading_paths(document) {
    return if block.kind == @core.BlockKind::Heading {
      update_heading_path(current, block)
    } else {
      current.copy()
    }
  }
  match assembly_heading_paths.get(block.block_id) {
    Some(path) => path.copy()
    None =>
      if block.kind == @core.BlockKind::Heading {
        update_heading_path(current, block)
      } else {
        current.copy()
      }
  }
}

///|
fn document_has_assembly_heading_paths(document : @core.DocumentIR) -> Bool {
  match document.assembly {
    Some(assembly) => assembly.heading_paths.length() > 0
    None => false
  }
}

///|
fn string_arrays_eq(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
fn block_to_text_unit(block : @core.CoreBlock) -> ChunkUnit? {
  let text = block_text_for_chunk(block)
  if text.trim() == "" {
    return None
  }
  match block.kind {
    @core.BlockKind::Paragraph =>
      Some({
        text,
        char_count: unicode_char_count(text),
        block_kind: "paragraph",
      })
    @core.BlockKind::List =>
      Some({ text, char_count: unicode_char_count(text), block_kind: "list" })
    @core.BlockKind::ListItem =>
      Some({
        text,
        char_count: unicode_char_count(text),
        block_kind: "list_item",
      })
    @core.BlockKind::BlockQuote =>
      Some({
        text,
        char_count: unicode_char_count(text),
        block_kind: "blockquote",
      })
    @core.BlockKind::Raw =>
      Some({ text, char_count: unicode_char_count(text), block_kind: "raw" })
    _ => None
  }
}

///|
fn block_to_special_chunks(
  block : @core.CoreBlock,
  heading_path : Array[String],
  ordinal_start : Int,
  document_format : String,
  document_title : String?,
  options : RagOptions,
  assets : Array[@core.AssetRef],
) -> Array[RagChunk] {
  match block.kind {
    @core.BlockKind::Table =>
      table_chunks_from_block(
        block, heading_path, ordinal_start, document_format, document_title, options,
      )
    @core.BlockKind::Code =>
      code_chunks_from_block(
        block, heading_path, ordinal_start, document_format, document_title, options,
      )
    @core.BlockKind::Image =>
      image_chunks_from_block(
        block, heading_path, ordinal_start, document_format, document_title, options,
        assets,
      )
    _ => []
  }
}

///|
fn build_text_chunks(
  units : Array[ChunkUnit],
  source_refs : Array[@core.SourceRef],
  asset_refs : Array[String],
  heading_path : Array[String],
  contains_raw : Bool,
  ordinal_start : Int,
  document_format : String,
  document_title : String?,
  options : RagOptions,
) -> Array[RagChunk] {
  let chunks : Array[RagChunk] = []
  if units.length() == 0 {
    return chunks
  }
  let slices = split_text_units(
    units,
    options.chunk_size,
    options.chunk_overlap,
  )
  for i in 0..<slices.length() {
    let slice = slices[i]
    let chunk_text = slice_units_text(slice)
    let chunk_kind = if contains_raw { ChunkKind::Raw } else { ChunkKind::Text }
    let effective_heading = if options.preserve_heading_path {
      heading_path.copy()
    } else {
      []
    }
    let effective_refs = if options.preserve_source_ref {
      source_refs.copy()
    } else {
      []
    }
    let block_kinds = slice.map(unit => unit.block_kind)
    let metadata = rag_metadata_fields(
      ordinal_start + i,
      chunk_text,
      effective_heading,
      document_format,
      document_title,
      block_kinds,
      effective_refs,
      asset_refs,
    )
    chunks.push({
      id: make_chunk_id(
        chunk_kind,
        ordinal_start + i,
        chunk_text,
        effective_heading,
        effective_refs,
      ),
      kind: chunk_kind,
      text: chunk_text,
      heading_path: effective_heading,
      source_refs: effective_refs,
      asset_refs: asset_refs.copy(),
      metadata,
    })
  }
  chunks
}

///|
fn split_text_units(
  units : Array[ChunkUnit],
  chunk_size : Int,
  chunk_overlap : Int,
) -> Array[Array[ChunkUnit]] {
  let slices : Array[Array[ChunkUnit]] = []
  let mut i = 0
  while i < units.length() {
    let current : Array[ChunkUnit] = []
    let mut total = 0
    while i < units.length() {
      let unit = units[i]
      if current.length() > 0 && total + unit.char_count > chunk_size {
        break
      }
      current.push(unit)
      total += unit.char_count
      i += 1
      if total >= chunk_size {
        break
      }
    }
    if current.length() == 0 && i < units.length() {
      current.push(units[i])
      i += 1
    }
    slices.push(current)
    if i >= units.length() || chunk_overlap <= 0 {
      continue
    }
    let overlap_units_reversed : Array[ChunkUnit] = []
    let mut overlap_chars = 0
    let mut j = current.length() - 1
    while j >= 0 {
      let unit = current[j]
      overlap_units_reversed.push(unit)
      overlap_chars += unit.char_count
      if overlap_chars >= chunk_overlap || j == 0 {
        break
      }
      j -= 1
    }
    i -= overlap_units_reversed.length()
    if i < 0 {
      i = 0
    }
  }
  slices
}

///|
fn table_chunks_from_block(
  block : @core.CoreBlock,
  heading_path : Array[String],
  ordinal_start : Int,
  document_format : String,
  document_title : String?,
  options : RagOptions,
) -> Array[RagChunk] {
  let rows = table_rows_from_block(block)
  if rows.length() == 0 {
    return []
  }
  let header = rows[0]
  let body = rows[1:]
  let row_groups : Array[Array[String]] = []
  if !options.split_tables {
    row_groups.push(body.to_owned())
  } else if body.length() == 0 {
    row_groups.push([])
  } else {
    let mut cursor = 0
    while cursor < body.length() {
      let group : Array[String] = []
      let mut total = unicode_char_count(header)
      while cursor < body.length() {
        let row = body[cursor]
        let next_total = total + unicode_char_count(row)
        if group.length() > 0 && next_total > options.chunk_size {
          break
        }
        group.push(row)
        total = next_total
        cursor += 1
        if total >= options.chunk_size {
          break
        }
      }
      if group.length() == 0 && cursor < body.length() {
        group.push(body[cursor])
        cursor += 1
      }
      row_groups.push(group)
    }
  }
  let chunks : Array[RagChunk] = []
  for i in 0..<row_groups.length() {
    let lines : Array[String] = [header]
    for row in row_groups[i] {
      lines.push(row)
    }
    let text = lines.join("\n")
    let effective_heading = if options.preserve_heading_path {
      heading_path.copy()
    } else {
      []
    }
    let effective_refs = block_source_refs(block, options.preserve_source_ref)
    let asset_refs = block_asset_refs(block, [])
    let metadata = rag_metadata_fields(
      ordinal_start + i,
      text,
      effective_heading,
      document_format,
      document_title,
      ["table"],
      effective_refs,
      asset_refs,
    )
    chunks.push({
      id: make_chunk_id(
        ChunkKind::Table,
        ordinal_start + i,
        text,
        effective_heading,
        effective_refs,
      ),
      kind: ChunkKind::Table,
      text,
      heading_path: effective_heading,
      source_refs: effective_refs,
      asset_refs,
      metadata,
    })
  }
  chunks
}

///|
fn table_rows_from_block(block : @core.CoreBlock) -> Array[String] {
  let rows : Array[String] = []
  if block.children.length() == 0 {
    let text = render_table_row(block)
    if text.trim() != "" {
      rows.push(text)
    }
    return rows
  }
  for child in block.children {
    let row = render_table_row(child)
    if row.trim() != "" {
      rows.push(row)
    }
  }
  rows
}

///|
fn render_table_row(block : @core.CoreBlock) -> String {
  let cells : Array[String] = []
  if block.children.length() == 0 {
    let text = block_plain_text(block).trim().to_owned()
    if text == "" {
      return ""
    }
    return "| " + text + " |"
  }
  for cell in block.children {
    cells.push(block_plain_text(cell).trim().to_owned())
  }
  if cells.length() == 0 {
    return ""
  }
  "| " + cells.join(" | ") + " |"
}

///|
fn code_chunks_from_block(
  block : @core.CoreBlock,
  heading_path : Array[String],
  ordinal_start : Int,
  document_format : String,
  document_title : String?,
  options : RagOptions,
) -> Array[RagChunk] {
  let language = block.attrs.get("language").unwrap_or("")
  let lines = block.text.split("\n").to_array().map(line => line.to_owned())
  let windows : Array[Array[String]] = []
  if !options.split_code_blocks {
    windows.push(lines)
  } else {
    let mut cursor = 0
    while cursor < lines.length() {
      let window : Array[String] = []
      let mut total = unicode_char_count(language) + 8
      while cursor < lines.length() {
        let line = lines[cursor]
        let next_total = total + unicode_char_count(line) + 1
        if window.length() > 0 && next_total > options.chunk_size {
          break
        }
        window.push(line)
        total = next_total
        cursor += 1
        if total >= options.chunk_size {
          break
        }
      }
      if window.length() == 0 && cursor < lines.length() {
        window.push(lines[cursor])
        cursor += 1
      }
      windows.push(window)
    }
  }
  let chunks : Array[RagChunk] = []
  for i in 0..<windows.length() {
    let text = "```" + language + "\n" + windows[i].join("\n") + "\n```"
    let effective_heading = if options.preserve_heading_path {
      heading_path.copy()
    } else {
      []
    }
    let effective_refs = block_source_refs(block, options.preserve_source_ref)
    let asset_refs = block_asset_refs(block, [])
    let metadata = rag_metadata_fields(
      ordinal_start + i,
      text,
      effective_heading,
      document_format,
      document_title,
      ["code"],
      effective_refs,
      asset_refs,
    )
    chunks.push({
      id: make_chunk_id(
        ChunkKind::Code,
        ordinal_start + i,
        text,
        effective_heading,
        effective_refs,
      ),
      kind: ChunkKind::Code,
      text,
      heading_path: effective_heading,
      source_refs: effective_refs,
      asset_refs,
      metadata,
    })
  }
  chunks
}

///|
fn image_chunks_from_block(
  block : @core.CoreBlock,
  heading_path : Array[String],
  ordinal_start : Int,
  document_format : String,
  document_title : String?,
  options : RagOptions,
  assets : Array[@core.AssetRef],
) -> Array[RagChunk] {
  let text = image_caption_text(block)
  if text.trim() == "" {
    return []
  }
  let effective_heading = if options.preserve_heading_path {
    heading_path.copy()
  } else {
    []
  }
  let effective_refs = block_source_refs(block, options.preserve_source_ref)
  let asset_refs = block_asset_refs(block, assets)
  let metadata = rag_metadata_fields(
    ordinal_start,
    text,
    effective_heading,
    document_format,
    document_title,
    ["image"],
    effective_refs,
    asset_refs,
  )
  [
    {
      id: make_chunk_id(
        ChunkKind::ImageCaption,
        ordinal_start,
        text,
        effective_heading,
        effective_refs,
      ),
      kind: ChunkKind::ImageCaption,
      text,
      heading_path: effective_heading,
      source_refs: effective_refs,
      asset_refs,
      metadata,
    },
  ]
}

///|
fn image_caption_text(block : @core.CoreBlock) -> String {
  for key in ["caption", "alt", "title"] {
    match block.attrs.get(key) {
      Some(value) if value.trim() != "" => return value.trim().to_owned()
      _ => ()
    }
  }
  let text = block_plain_text(block).trim().to_owned()
  if text != "" {
    text
  } else {
    ""
  }
}

///|
fn slice_units_text(units : Array[ChunkUnit]) -> String {
  units.map(unit => unit.text).join("\n\n")
}

///|
fn block_text_for_chunk(block : @core.CoreBlock) -> String {
  match block.kind {
    @core.BlockKind::List => list_block_text(block, 0)
    @core.BlockKind::ListItem => list_item_text(block, 1, false, 0)
    @core.BlockKind::BlockQuote => blockquote_text(block)
    _ => block_plain_text(block)
  }
}

///|
fn block_plain_text(block : @core.CoreBlock) -> String {
  if block.rich_inlines is Some(_) {
    return inline_text(block.rich_inlines.unwrap_or([]))
  }
  if block.children.length() == 0 {
    return block.text.trim().to_owned()
  }
  let parts : Array[String] = []
  if block.text.trim() != "" {
    parts.push(block.text.trim().to_owned())
  }
  for child in block.children {
    let child_text = block_plain_text(child)
    if child_text.trim() != "" {
      parts.push(child_text)
    }
  }
  parts.join("\n")
}

///|
fn inline_text(inlines : Array[@core.CoreInline]) -> String {
  let parts : Array[String] = []
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::LineBreak => parts.push("\n")
      @core.InlineKind::Link =>
        parts.push(
          if inline.href == Some("") || inline.href == None {
            inline.text
          } else {
            inline.text + " (" + inline.href.unwrap_or("") + ")"
          },
        )
      @core.InlineKind::Image =>
        parts.push(
          if inline.title.unwrap_or("") != "" {
            inline.text + " [" + inline.title.unwrap_or("") + "]"
          } else {
            inline.text
          },
        )
      @core.InlineKind::Code => parts.push("`" + inline.text + "`")
      _ => parts.push(inline.text)
    }
  }
  parts.join("")
}

///|
fn list_block_text(block : @core.CoreBlock, depth : Int) -> String {
  if block.children.length() == 0 {
    return list_item_text(block, 1, false, depth)
  }
  let ordered = block.attrs.get("ordered").unwrap_or("false") == "true"
  let lines : Array[String] = []
  for i in 0..<block.children.length() {
    lines.push(list_item_text(block.children[i], i + 1, ordered, depth))
  }
  lines.join("\n")
}

///|
fn list_item_text(
  block : @core.CoreBlock,
  index : Int,
  ordered : Bool,
  depth : Int,
) -> String {
  let is_ordered = ordered ||
    block.attrs.get("ordered").unwrap_or("false") == "true"
  let indent = Array::make(depth * 2, " ").join("")
  let marker = if is_ordered { index.to_string() + ". " } else { "- " }
  let text = block_plain_text({ ..block, children: [] }).trim().to_owned()
  if block.children.length() == 0 {
    return indent + marker + text
  }
  let child_lines : Array[String] = []
  for i in 0..<block.children.length() {
    let child = block.children[i]
    match child.kind {
      @core.BlockKind::List =>
        child_lines.push(list_block_text(child, depth + 1))
      @core.BlockKind::ListItem =>
        child_lines.push(list_item_text(child, i + 1, false, depth + 1))
      _ => {
        let nested = block_plain_text(child).trim().to_owned()
        if nested != "" {
          child_lines.push(Array::make((depth + 1) * 2, " ").join("") + nested)
        }
      }
    }
  }
  let body = if child_lines.length() == 0 {
    ""
  } else {
    "\n" + child_lines.join("\n")
  }
  indent + marker + text + body
}

///|
fn blockquote_text(block : @core.CoreBlock) -> String {
  let text = block_plain_text(block)
  if text.trim() == "" {
    return ""
  }
  text
  .split("\n")
  .to_array()
  .map(line => "> " + line.trim_end().to_owned())
  .join("\n")
}

///|
fn block_location_bucket(block : @core.CoreBlock) -> String {
  match block.source_ref {
    Some(source_ref) =>
      [
        source_ref.page.map(i => i.to_string()).unwrap_or(""),
        source_ref.slide.map(i => i.to_string()).unwrap_or(""),
        source_ref.sheet.unwrap_or(""),
        source_ref.cell_range.unwrap_or(""),
        source_ref.entry_path.unwrap_or(""),
        source_ref.container_path.unwrap_or(""),
        source_ref.chapter_href.unwrap_or(""),
      ].join("|")
    None => ""
  }
}

///|
fn block_source_refs(
  block : @core.CoreBlock,
  preserve_source_ref : Bool,
) -> Array[@core.SourceRef] {
  let refs : Array[@core.SourceRef] = []
  if preserve_source_ref {
    append_unique_source_ref(refs, block.source_ref, true)
    collect_child_source_refs(refs, block)
  }
  refs
}

///|
fn collect_child_source_refs(
  refs : Array[@core.SourceRef],
  block : @core.CoreBlock,
) -> Unit {
  for child in block.children {
    append_unique_source_ref(refs, child.source_ref, true)
    collect_child_source_refs(refs, child)
  }
}

///|
fn block_asset_refs(
  block : @core.CoreBlock,
  assets : Array[@core.AssetRef],
) -> Array[String] {
  let refs : Array[String] = []
  for key in ["asset_id", "asset_ref", "image_asset_id"] {
    match block.attrs.get(key) {
      Some(value) if value.trim() != "" => append_unique_string(refs, value)
      _ => ()
    }
  }
  match block.source_ref {
    Some(source_ref) =>
      for asset in assets {
        if source_ref_eq(
            source_ref,
            asset.source_ref.unwrap_or(@core.empty_source_ref()),
          ) {
          append_unique_string(refs, asset.asset_id)
        }
      }
    None => ()
  }
  refs
}

///|
fn append_unique_source_ref(
  refs : Array[@core.SourceRef],
  source_ref : @core.SourceRef?,
  enabled : Bool,
) -> Unit {
  if !enabled {
    return
  }
  match source_ref {
    Some(value) =>
      if !refs.any(existing => source_ref_eq(existing, value)) {
        refs.push(value)
      }
    None => ()
  }
}

///|
fn append_unique_optional_string(
  values : Array[String],
  value : String?,
) -> Unit {
  match value {
    Some(text) if text.trim() != "" => append_unique_string(values, text)
    _ => ()
  }
}

///|
fn append_unique_strings(
  target : Array[String],
  values : Array[String],
) -> Unit {
  for value in values {
    append_unique_string(target, value)
  }
}

///|
fn append_unique_string(values : Array[String], value : String) -> Unit {
  if !values.any(existing => existing == value) {
    values.push(value)
  }
}

///|
fn string_json_array(values : Array[String]) -> @core.JsonValue {
  @core.JsonValue::Array(values.map(value => @core.JsonValue::String(value)))
}

///|
fn json_value_string(value : @core.JsonValue?) -> String? {
  match value {
    Some(@core.JsonValue::String(text)) => Some(text)
    Some(@core.JsonValue::Number(text)) => Some(text)
    Some(@core.JsonValue::Bool(flag)) =>
      Some(if flag { "true" } else { "false" })
    _ => None
  }
}

///|
fn unicode_char_count(text : String) -> Int {
  let bytes = @encoding.encode(text, encoding=@encoding.UTF16LE)
  bytes.length() / 2
}

///|
fn make_chunk_id(
  kind : ChunkKind,
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  source_refs : Array[@core.SourceRef],
) -> String {
  let signature = chunk_kind_name(kind) +
    "|" +
    heading_path.join("/") +
    "|" +
    text +
    "|" +
    first_last_source_ref_signature(source_refs)
  let encoded = @encoding.encode(signature, encoding=@encoding.UTF16LE)
  let hash = @crypto.bytes_to_hex_string(@crypto.sha1(encoded))
  chunk_kind_name(kind) + "-" + ordinal.to_string() + "-" + hash[:8].to_owned()
}

///|
fn first_last_source_ref_signature(
  source_refs : Array[@core.SourceRef],
) -> String {
  if source_refs.length() == 0 {
    return ""
  }
  source_ref_signature(source_refs[0]) +
  "|" +
  source_ref_signature(source_refs[source_refs.length() - 1])
}

///|
fn source_ref_signature(source_ref : @core.SourceRef) -> String {
  [
    source_ref.file_id.unwrap_or(""),
    source_ref.format.unwrap_or(""),
    source_ref.page.map(i => i.to_string()).unwrap_or(""),
    source_ref.slide.map(i => i.to_string()).unwrap_or(""),
    source_ref.sheet.unwrap_or(""),
    source_ref.cell_range.unwrap_or(""),
    source_ref.entry_path.unwrap_or(""),
    source_ref.container_path.unwrap_or(""),
    source_ref.chapter_href.unwrap_or(""),
    source_ref.line_start.map(i => i.to_string()).unwrap_or(""),
    source_ref.line_end.map(i => i.to_string()).unwrap_or(""),
  ].join("|")
}

///|
fn source_ref_eq(left : @core.SourceRef, right : @core.SourceRef) -> Bool {
  source_ref_signature(left) == source_ref_signature(right)
}
